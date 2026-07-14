En tant que Directeur Artistique Technique, voici mon diagnostic franc et ma proposition pour transformer *mecha-forge* en un jeu "clipable" et juteux, malgré tes contraintes de build sans GPU et de cible mobile GLES3.

### 1. DIAGNOSTIC FRANC : L'état actuel
**On jette :**
- **Le spritesheet 4-directions pour le Mecha joueur :** C'est la cause numéro un de la rigidité. Séparer l'arme du corps sur une sprite 2D plate casse l'illusion de profondeur et donne un rendu "papier découpé" bas de gamme.
- **Les CPUParticles2D pour les impacts :** Sur mobile, c'est un tueur de perf si tu as 190 ennemis, et le rendu est par nature "programmeur" (des petits carrés qui s'étirent).

**On garde et on améliore :**
- **Le pipeline Meshy -> bpy :** C'est une mine d'or, mais on change la façon de l'exporter.
- **Le shader de sol :** Bonne base, mais il manque de profondeur 2.5D.
- **La palette Cyan/Chaud :** Parfaite pour la lisibilité, on va la pousser dans le retranchement (contrastes).

---

### 2. PROPOSITION AMBITIEUSE & DIRECTION ARTISTIQUE
Pour que le jeu paraisse "AAA" sur mobile sans post-processing, **tout doit venir de la matière, des normales et de l'éclairage dynamique 2D.**

*   **Le Mecha en "Cut-out 2.5D" :** On arrête les sheets complets. On découpe le Mecha en parties (Torse, Bras Gauche, Bras Droit, Jambes). On rend ces parties en **Orthographic** dans bpy avec une **Normal Map 2D**. Dans Godot, on reconstruit le Mecha avec un `Skeleton2D` et un `Bone2D` IK pour le bras armé. Le torse peut viser à 360° pendant que les jambes marchent.
*   **La Horde en MultiMesh2D :** 190 ennemis = 190 draw calls si mal fait. On passe tout en `MultiMeshInstance2D` avec un atlas de spritesheets. Les ennemis n'ont pas de squelette, juste une animation par frame.
*   **VFX Baked + Shaders :** Les explosions seront des spritesheets pré-rendus (via bpy Cycles ou FLUX), mais on ajoute un shader de *Heat Haze* (distortion) localisé et des éclairs procéduraux en shaders.
*   **Décors en Billboards Normals-Mapped :** Pas de vraie 3D. On utilise des sprites de props avec des normal maps, réagissant aux `PointLight2D` des tirs pour un rendu dynamique sans coût 3D.

---

### 3. CODE & SHADERS : LES 3 GROS GAINS

#### GAIN 1 : Le Mecha 2.5D avec IK et Normal Mapping
Le bras du Mecha suit la cible à 360°. On utilise un `Skeleton2D` avec une modification IK.

**Le GDScript (`mecha_rig.gd`) :**
```gdscript
extends Node2D

@onready var skeleton: Skeleton2D = $Skeleton2D
@onready var right_arm_bone: Bone2D = skeleton.find_bone("RightArm")
@onready var right_forearm_bone: Bone2D = skeleton.find_bone("RightForearm")
@onready var ik_modifier: SkeletonModification2DCCDIK = skeleton.get_modification_stack().get_modification(0)

var target_position: Vector2 = Vector2.ZERO

func _process(delta):
    # La cible (ex: le joystick droit ou la souris)
    target_position = get_global_mouse_position()
    
    # Mettre à jour la cible de l'IK
    ik_modifier.target_node = self # On suppose que le target est un Node2D enfant
    $IK_Target.global_position = target_position
    
    # Faire pivoter le torse légèrement vers la cible
    var aim_dir = (target_position - global_position).normalized()
    var angle = atan2(aim_dir.y, aim_dir.x)
    # Limiter la rotation du torse pour qu'il ne se casse pas
    $Skeleton2D/Torso.rotation = lerp_angle($Skeleton2D/Torso.rotation, angle * 0.5, delta * 10.0)
```

**Le Shader du Mecha (`.gdshader`) :** (Éclairage 2D dynamique sans WorldEnvironment)
```glsl
shader_type canvas_item;

uniform sampler2D normal_map;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float specular_intensity : hint_range(0.0, 5.0) = 1.0;

void fragment() {
    vec4 col = texture(TEXTURE, UV) * base_color;
    
    // Lumière dynamique 2D (PointLight2D de Godot)
    vec3 normal = texture(normal_map, UV).rgb * 2.0 - 1.0;
    normal = normalize(normal);
    
    // Godot 4 injecte LIGHT_VEC et LIGHT_COLOR automatiquement si on utilise un Light2D
    vec3 light_dir = normalize(vec3(LIGHT_VEC, 0.0));
    float diffuse = max(dot(normal, light_dir), 0.0);
    
    // Spécularité pour le look "Métal/Mecha"
    vec3 view_dir = vec3(0.0, 0.0, 1.0);
    vec3 half_vec = normalize(light_dir + view_dir);
    float spec = pow(max(dot(normal, half_vec), 0.0), 16.0) * specular_intensity;
    
    // Mélanger la lumière ambiante (cyan), la diffuse et la spéculaire
    col.rgb += LIGHT_COLOR.rgb * diffuse * 0.8;
    col.rgb += LIGHT_COLOR.rgb * spec;
    
    COLOR = col;
}
```

#### GAIN 2 : La Horde en MultiMeshInstance2D
Pour 190 ennemis sans tuer le CPU, on injecte les matrices de transformation et les UVs dans un MultiMesh.

**Le GDScript (`horde_manager.gd`) :**
```gdscript
extends MultiMeshInstance2D

@export var max_enemies: int = 200
@onready var multimesh: MultiMesh = self.multimesh

# Structure ennemi: {pos, frame_idx, scale, rot}
var enemies: Array = []

func _ready():
    multimesh.instance_count = max_enemies # Allouer une fois
    multimesh.visible_instance_count = 0

func _process(delta):
    var visible_count = enemies.size()
    multimesh.visible_instance_count = visible_count
    
    var t = Time.get_ticks_msec() / 1000.0
    
    for i in visible_count:
        var e = enemies[i]
        # Mise à jour de la position
        e.pos += e.vel * delta
        
        # Calcul de la frame d'animation (ex: 8 frames, 10 fps)
        var frame = int(t * 10.0 + e.phase) % 8
        var uv_size = Vector2(0.125, 1.0) # 8 frames sur X
        var uv_offset = Vector2(frame * uv_size.x, 0.0)
        
        # Appliquer au MultiMesh
        var t_pos = Transform2D(e.rot, e.pos)
        multimesh.set_instance_transform_2d(i, t_pos)
        # Godot 4.3 permet de set l'UV via custom data si le shader le supporte, 
        # ou on duplique la mesh. Ici on utilise le custom_data pour l'UV offset.
        multimesh.set_instance_custom_data(i, Color(uv_offset.x, uv_offset.y, 0.0, 0.0))
```

**Le Shader de la Horde (`.gdshader`) :** (Batching des UVs)
```glsl
shader_type canvas_item;

uniform sampler2D atlas;
// On utilise INSTANCE_CUSTOM pour offset les UVs

void fragment() {
    vec2 custom_uv = UV;
    // custom_data.xy contient l'offset de la frame
    custom_uv.x *= 0.125; // Diviser par le nombre de frames (8)
    custom_uv += INSTANCE_CUSTOM.xy;
    
    vec4 col = texture(atlas, custom_uv);
    
    // Ajouter une variation de teinte pour cacher la répétition
    float hue_shift = INSTANCE_CUSTOM.z * 0.1;
    col.rgb = mix(col.rgb, col.rgb.gbr, hue_shift);
    
    COLOR = col;
}
```

#### GAIN 3 : VFX "Heat Haze" (Distortion locale) sans Post-Process
Le manque de WorldEnvironment sur mobile empêche la distortion d'écran. On utilise un nœud `Sprite2D` avec un shader qui échantillonne la texture de l'écran (`hint_screen_texture`) localement. Attention, en `gl_compatibility` il faut que le CanvasLayer ait `follow_viewport` activé.

**Le Shader de Distortion (`.gdshader`) :**
```glsl
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_texture;
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.02;
uniform float scroll_speed = 5.0;

void fragment() {
    vec2 screen_uv = SCREEN_UV;
    
    // Masque de distortion (seulement au centre de la sprite, en cercle)
    float mask = smoothstep(0.5, 0.0, length(UV - 0.5));
    
    // Bruit de déplacement
    float time = TIME * scroll_speed;
    vec2 noise_uv = UV * 3.0 + vec2(time, time * 0.5);
    vec2 noise = texture(noise_texture, noise_uv).rg * 2.0 - 1.0;
    
    // Déplacer l'écran
    vec2 distorted_uv = screen_uv + noise * distortion_strength * mask;
    
    vec4 screen_col = texture(screen_texture, distorted_uv);
    
    // Ajouter un peu de chaleur (teinte orange) sur les bords
    vec3 heat_tint = vec3(1.0, 0.5, 0.0);
    screen_col.rgb = mix(screen_col.rgb, screen_col.rgb + heat_tint * 0.2, mask * 0.5);
    
    COLOR = screen_col;
}
```

#### GAIN 4 : Sol avec Faux Parallaxe 2.5D
On modifie le shader existant pour que le sol réagisse à la "profondeur" en biaisant les UVs selon la position de la caméra, donnant l'illusion de volume.

**Le Shader de Sol (`.gdshader`) :**
```glsl
shader_type canvas_item;

uniform sampler2D main_texture;
uniform sampler2D detail_texture;
uniform vec2 cam_offset;

void vertex() {
    // Faux parallaxe: décaler les UVs en Z
    vec2 view_dir = (cam_offset - VERTEX);
    float depth = 1.0 - UV.y; // Plus on est bas, plus c'est proche
    UV += view_dir * depth * 0.05;
}

void fragment() {
    vec4 main_col = texture(main_texture, UV * 4.0);
    vec4 detail_col = texture(detail_texture, UV * 12.0);
    
    // Mélange et dé-tuilage simple
    vec3 final_col = main_col.rgb * detail_col.rgb * 2.0;
    
    // Vignette dynamique
    float vig = smoothstep(1.0, 0.2, length(UV - 0.5));
    final_col *= vig;
    
    COLOR = vec4(final_col, 1.0);
}
```

---

### 4. PIPELINE D'ASSETS (Sans GPU de build)

Puisque tu n'as pas de GPU sur le serveur de build, la parallélisation est clé.

1.  **Mecha & Ennemis (Meshy.ai -> bpy -> Godot) :**
    *   **Meshy génère le mesh 3D** (Mecha, Tank, Drone).
    *   **bpy (Python script) en Cycles CPU :**
        *   On ne rend plus de spritesheet complet.
        *   On sépare le mesh en parties (Torse, Bras G, Bras D, Jambes).
        *   On rend chaque partie en **Orthographic** (vue de face, de côté).
        *   **ÉTAPE CRUCIALE :** On rend la `Normal Map` correspondante en activant le node "Normal Map" dans bpy (bake).
        *   On exporte en PNG sans fond (alpha).
    *   **Godot :** On importe les PNG + Normal Maps. On place les parties dans un `Skeleton2D`. L'IK gère la visée.
2.  **VFX (FLUX.1 schnell / bpy Cycles) :**
    *   **FLUX génère des textures :** "Top-down explosion fireball, transparent background, 8x8 grid spritesheet". Tu récupères une texture propre.
    *   **bpy génère des fumées procédurales :** Via le système de particules de bpy, rendu en Cycles CPU, tu génères des loops de fumée noire additif.
    *   **Godot :** On découpe l'atlas de FLUX en 64 frames, on le met sur un `AnimatedSprite2D`. On superpose le shader de *Heat Haze*.
3.  **Props & Décors :**
    *   **bpy :** Modélisation simple (bloc, rocher). Rendu Albedo + Normal Map.
    *   **Godot :** Sprite2D avec le shader de normal map (comme le Mecha). Y-sorted.

---

### 5. PRIORISATION & QUICK WINS

1.  **Semaine 1 (Quick Win Perf & Lisibilité) :** Implémenter le `MultiMeshInstance2D` pour les ennemis basiques. Passer de 190 draw calls à 1. Ça va libérer énormément de budget frame time pour les VFX. Ajouter le normal mapping sur le sol.
2.  **Semaine 2 (Le "Juciy" VFX) :** Intégrer le shader de Heat Haze. Remplacer les CPUParticles2D par des AnimatedSprites pré-rendus via FLUX. C'est ce qui rendra le jeu "TikTok".
3.  **Semaine 3 (Le Mecha Rig) :** Le plus gros travail technique. Refaire le pipeline bpy pour exporter les parties séparées. Monter le `Skeleton2D` avec l'IK. C'est ici que tu vaincs la rigidité.
4.  **Semaine 4 (Ennemis Spéciaux & Boss) :** Appliquer le même pipeline cut-out 2.5D que le Mecha pour les ennemis tier 2 et les Boss. Un boss qui tourelle son canon vers toi pendant que son corps avance, c'est immédiatement AAA.