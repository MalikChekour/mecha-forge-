# Prompts Gemini — MACHINES DE GUERRE pilotées (mobile suits), pour Meshy

Ces mechas ne sont **PAS** des androïdes de 2 m ni des armures portées. Ce sont des **colosses de
guerre pilotés** (logique "mobile suit" : un humain s'installe à l'intérieur et le manœuvre).

## Comment on rend ça SANS tricher
- ❌ **AUCUNE référence d'échelle** dans l'image : pas de pilote visible, pas d'humain à côté, pas
  de véhicule/bâtiment de comparaison, pas de sol avec des gens.
- ❌ **Le cockpit n'a PAS à être montré** : pas de trappe ouverte obligatoire, pas de verrière avec
  un pilote dedans.
- ✅ La sensation de **machine géante pilotée** vient du **langage de conception**, pas d'un indice
  de taille :
  - **torse = coque/fuselage blindé** (un volume massif qui *pourrait* contenir un pilote), pas un
    buste musclé humain,
  - **proportions de véhicule** : lourdes, porteuses, industrielles — plus "engin de chantier de
    combat" qu'"athlète",
  - **détails d'engin de guerre** : grosses tuyères de propulsion, prises d'air blindées, lignes de
    panneaux comme un char ou un avion, points d'ancrage d'armes, vérins épais aux articulations,
  - **blindage en plaques épaisses boulonnées**, pas une carrosserie lisse d'androïde.

## Bloc technique — à coller à la FIN de chaque prompt

```
TECHNICAL REQUIREMENTS (this image becomes a rigged, animated 3D model — accuracy is critical):
Full body, head to toe, nothing cropped. Single mech, centered, filling the frame with a small margin.
Strict symmetrical A-POSE: both arms held clearly AWAY from the hull at ~40 degrees, elbows slightly
bent, hands/manipulators separated from the hips, legs straight and shoulder-width apart, feet flat
and apart. NO limb touching the hull, NO limb touching another limb, NO overlapping parts.
Weapons INTEGRATED INTO THE FOREARMS or MOUNTED ON THE SHOULDERS — never held in a hand.
Orthographic front view, camera at chest height, zero perspective distortion.
Flat even studio lighting, no harsh shadows, no rim light, no lens flare, no bloom.
Plain flat neutral grey background (#808080), no ground plane, no cast shadow.
NO scale reference of any kind: no pilot, no human figure, no vehicle, no building, no props.
Sharp focus, no motion blur, no text, no watermark, no logo.
NO thin antenna, NO V-shaped forehead fin, NO cables, NO wires, NO cape, NO chains, NO flags,
NO transparent canopy, NO thin pistons — every part thicker than a wrist, solidly attached.
Chunky heavy volumes, clean humanoid biped silhouette: two legs, two arms, one head.
ORIGINAL design — do not imitate any existing robot franchise, model kit or copyrighted mecha.
```

---

## Les 6 machines de guerre

### W1 — TITAN D'ASSAUT (le pilier polyvalent) ⭐
```
A colossal ORIGINAL piloted battle mecha, a heavy war machine (mobile suit), front view, neutral
A-pose. Massive armored HULL-LIKE torso built from thick bolted armor plates like a walking tank,
heavy load-bearing legs with big armored feet, chunky powered joints with thick pistons, a compact
armored sensor head with twin glowing cyan optics and a thick low crest. Deep gunmetal grey and
steel blue armor with orange hazard accents and glowing cyan seams. Large thruster nozzles on the
back and calves, armored vents on the chest. Its weapons are a HEAVY AUTOCANNON INTEGRATED INTO
EACH FOREARM, thick barrels forward. Painted 3D render, crisp and clean.
+ [TECHNICAL REQUIREMENTS]
```

### W2 — BATTERIE MOBILE (artillerie longue portée)
```
A colossal ORIGINAL piloted battle mecha, a long-range artillery war machine, front view, neutral
A-pose. Broad armored fuselage torso, extremely wide reinforced shoulders, thick stable legs, a
small armored head sunk between the shoulders with a single wide glowing amber optic band. Slate
grey and dark crimson armor with brass trim and glowing amber vents. Its weapons are TWO HUGE
ARTILLERY CANNONS MOUNTED ON TOP OF THE SHOULDERS pointing forward, solidly bolted to the pauldrons,
plus a blocky cannon built into the right forearm. Heavy rear counterweight and thruster block.
Painted 3D render, crisp and clean.
+ [TECHNICAL REQUIREMENTS]
```

### W3 — INTERCEPTEUR (rapide, propulsé)
```
A colossal ORIGINAL piloted battle mecha, a fast interceptor war machine, front view, neutral
A-pose. Aerodynamic armored hull torso, lean but heavy limbs, large thruster nozzle clusters on the
back and on the calves, an angular armored head with a thin horizontal glowing violet optic. Matte
charcoal black and gunmetal armor with electric violet glowing strips. Its weapon is a LONG HEAVY
RAILGUN INTEGRATED ALONG THE RIGHT FOREARM extending forward past the manipulator, with thick
rectangular coil housings, and a matching shorter emitter block on the left forearm. Painted 3D
render, crisp and clean.
+ [TECHNICAL REQUIREMENTS]
```

### W4 — FORTERESSE (siège, écrasant)
```
A colossal ORIGINAL piloted battle mecha, a siege fortress war machine, front view, neutral A-pose.
Enormous boxy armored hull torso like an armored bunker, very short thick legs, huge splayed feet,
massive shoulders, a tiny armored head with glowing red slit optics. Industrial olive green and
dark steel armor with black hazard stripes and glowing red vents. Its weapons are BLOCKY MISSILE
POD BANKS MOUNTED ON BOTH SHOULDERS (solid armored boxes) and a THICK ROTARY GATLING CANNON
INTEGRATED INTO THE RIGHT FOREARM. Painted 3D render, crisp and clean.
+ [TECHNICAL REQUIREMENTS]
```

### W5 — COMMANDANT (équilibré, imposant)
```
A colossal ORIGINAL piloted battle mecha, a command-type war machine, front view, neutral A-pose.
Balanced heavy armored hull torso with a prominent armored chest block, broad pauldrons, strong
legs, a helmeted armored head with twin glowing green optics and a thick blunt crown. Arctic white
and deep navy armor with gold accents and glowing green seams. A large armored backpack with four
thick thruster nozzles. Its weapons are a CHUNKY BEAM CANNON INTEGRATED INTO EACH FOREARM, thick
muzzles forward. Painted 3D render, crisp and clean.
+ [TECHNICAL REQUIREMENTS]
```

### W6 — BRISEUR (brutal, canon large)
```
A colossal ORIGINAL piloted battle mecha, a brutal breacher war machine, front view, neutral
A-pose. Aggressive heavy armored hull torso, enormous angular pauldrons made of thick solid plates,
thick thighs, armored skirt plates that stay clear of the legs, a fierce armored head with twin
glowing orange optics and a thick horned brow (short, blunt). Rusted red and black steel armor with
glowing orange furnace vents in the chest. Its weapon is a WIDE SHORT SCATTER CANNON INTEGRATED
INTO THE RIGHT FOREARM (very thick muzzle) and a solid armored ram-block on the left forearm.
Painted 3D render, crisp and clean.
+ [TECHNICAL REQUIREMENTS]
```

---

## Contrôle avant Meshy (un seul point raté = régénère, c'est gratuit)
1. ❌ Bras/manipulateur qui touche la coque ou la hanche ? → **rig mort**
2. ❌ Jambes qui se touchent ? → **fusion**
3. ❌ Pied ou tête coupé au bord ? → **moignon**
4. ❌ Antenne fine / vérin fin / câble / verrière transparente ? → **casse au remesh 40k**
5. ❌ Arme tenue en main ? → **fusion main/arme/cuisse**
6. ❌ Une échelle glissée dans l'image (humain, véhicule) ? → **régénère** (Meshy le modéliserait aussi)
7. ❌ Antenne en V frontale / design de franchise reconnaissable ? → **régénère**
8. ✅ Torse-coque massif, proportions d'engin lourd, bras écartés, fond gris uni

## Livraison
`refs/mecha_meshy/` → `w1.png` … `w6.png` (1024×1024). Je repasse mon test objectif de séparation
des membres avant tout achat de crédits.
