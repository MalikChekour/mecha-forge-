# Prompts Gemini — mechas badass ARMÉS, destinés à Meshy (image → 3D → rig → animations)

⚠️ **Ces images ne sont PAS des illustrations : ce sont des plans de fabrication 3D.**
Chaque image passe dans : `meshy image-to-3D` → `remesh 40k` → `rigging` → `animations` →
`bake_meshy.py --dirs 8` → sprites 8 directions. Chaque erreur = **des crédits Meshy brûlés**
pour un modèle inutilisable. D'où les règles ci-dessous, non négociables.

---

## Pourquoi ces règles (le "pourquoi" compte, Gemini les respecte mieux)

| Règle | Raison technique |
|---|---|
| **Pose en A, membres écartés, RIEN qui se touche** | Meshy reconstruit un volume unique. Deux surfaces qui se touchent **fusionnent** : bras soudé au torse = le rig ne trouve plus l'articulation → rig raté ou monstrueux. |
| **Arme INTÉGRÉE À L'AVANT-BRAS** (pas tenue en main) | Un fusil tenu colle la main + l'arme + la cuisse → fusion. Un canon d'avant-bras fait partie du membre : le rig le suit naturellement, et **le canon bouge avec le bras**. |
| **Corps entier, rien de coupé** | Meshy ne devine pas hors-cadre : un pied coupé = un moignon en 3D. |
| **Vue de face orthographique, à hauteur de poitrine** | La perspective forte fait interpréter des volumes faux (tête géante, pieds minuscules). |
| **Lumière plate et homogène** | Ombres dures et contre-jours se **cuisent dans la texture** → salissures permanentes impossibles à retirer. |
| **Fond gris uni, aucune ombre portée** | La segmentation détoure proprement ; une ombre au sol devient une galette de géométrie. |
| **Pas d'antennes fines, câbles, capes, chaînes** | Le remesh à 40k faces **casse** tout ce qui est plus fin que ~2 cm : ça part en confettis. |
| **Silhouette bipède humanoïde lisible** | Le rig Meshy ne gère **que** les bipèdes humanoïdes. Deux jambes, deux bras, une tête. |
| **Net, sans flou** | Le flou devient du bruit de surface. |

---

## Le bloc technique — à coller à la FIN de chaque prompt

```
TECHNICAL REQUIREMENTS (this image will be converted to a rigged 3D model — accuracy is critical):
Full body, head to toe, nothing cropped or cut off. Single character, centered.
Strict symmetrical A-POSE: both arms held clearly AWAY from the torso at ~40 degrees, elbows
slightly bent, hands open and separated from the hips, legs straight and shoulder-width apart,
feet flat and apart. NO limb touching the body, NO limb touching another limb, NO overlapping parts.
Orthographic front view, camera at chest height, zero perspective distortion.
Flat even studio lighting, no harsh shadows, no rim light, no lens flare, no glow bloom.
Plain flat neutral grey background (#808080), no ground plane, no cast shadow, no floor.
Sharp focus, no motion blur, no depth of field. No text, no logo, no watermark, no UI.
NO thin antennas, NO cables, NO wires, NO cape, NO chains, NO flags — every part must be thicker
than a finger and solidly attached. Clean readable humanoid biped silhouette: two legs, two arms, one head.
```

---

## Les 6 mechas

### M1 — VANGUARD (assaut polyvalent) ⭐ le plus sûr
```
A badass humanoid battle mecha, front view, standing in a neutral A-pose. Sleek armored plating
in white and steel blue with orange accents, a visored head with a glowing cyan eye slit, broad
shoulder pauldrons, powerful legs. Its weapon is a heavy AUTOCANNON INTEGRATED INTO EACH FOREARM:
thick chunky barrels emerging from the wrists, pointing straight forward, clearly part of the arm
itself and not held in the hands. Painted 3D render, crisp and clean.
+ [TECHNICAL REQUIREMENTS]
```

### M2 — ARTILLEUR (lourd, longue portée)
```
A badass heavy artillery mecha, front view, standing in a neutral A-pose. Massive armored torso in
gunmetal grey and dark yellow with hazard stripes, thick armored legs, a compact sensor head. Its
weapons are a BIG CANNON BUILT INTO THE RIGHT FOREARM (wide muzzle pointing forward) and a blocky
MISSILE POD MOUNTED ON EACH SHOULDER, tightly attached to the armor. The arms hang away from the
body. Painted 3D render, crisp and clean.
+ [TECHNICAL REQUIREMENTS]
```

### M3 — LANCIER (railgun, élancé)
```
A badass sleek sniper mecha, front view, standing in a neutral A-pose. Slim aerodynamic armor in
dark navy and white with magenta energy lines, a narrow visored head, long digitigrade-style legs
but with clear human-like feet. Its weapon is a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT
FOREARM, extending forward past the fist, with a thick rectangular energy coil housing. The left
forearm has a smaller matching emitter. Painted 3D render, crisp and clean.
+ [TECHNICAL REQUIREMENTS]
```

### M4 — GARDE (bouclier, tank)
```
A badass riot-guard mecha, front view, standing in a neutral A-pose. Bulky layered armor in olive
green and steel with amber lights, a heavy helmeted head, wide stable legs. Its weapons are a THICK
SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO
THE LEFT FOREARM (the shield must stay tight against the forearm and must NOT touch the torso or
the legs). Painted 3D render, crisp and clean.
+ [TECHNICAL REQUIREMENTS]
```

### M5 — CHASSEUR (agile, bi-armes)
```
A badass agile skirmisher mecha, front view, standing in a neutral A-pose. Lightweight armor in
burnt orange and dark grey with cyan glowing vents, a sharp angular head with twin optics, athletic
proportions. Its weapons are TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short
barrels pointing forward from each wrist, plus small thruster blocks on the back of the calves.
Painted 3D render, crisp and clean.
+ [TECHNICAL REQUIREMENTS]
```

### M6 — DESTRUCTEUR (gatling, brutal)
```
A badass brutal assault mecha, front view, standing in a neutral A-pose. Heavy industrial armor in
rusted red and black steel with glowing orange furnace vents in the chest, a brutish armored head,
massive shoulders and thick legs. Its weapon is an ENORMOUS ROTARY GATLING CANNON INTEGRATED INTO
THE RIGHT FOREARM (thick multi-barrel cluster pointing forward) and a heavy armored fist on the
left arm. Painted 3D render, crisp and clean.
+ [TECHNICAL REQUIREMENTS]
```

---

## Contrôle avant de dépenser des crédits

Regarde l'image et vérifie **dans cet ordre** — si un seul point échoue, régénère :

1. ❌ Un bras touche-t-il le torse ou la hanche ? → **rig mort**
2. ❌ Les jambes se touchent-elles ? → **jambes fusionnées**
3. ❌ Un pied / le sommet du crâne est-il coupé ? → **moignon**
4. ❌ Y a-t-il une antenne fine, un câble, une cape ? → **casse au remesh**
5. ❌ Une ombre portée au sol ? → **galette de géométrie**
6. ❌ L'arme est-elle **tenue en main** au lieu d'être dans l'avant-bras ? → **fusion main/arme/cuisse**
7. ✅ Silhouette bipède nette, bras écartés, fond gris uni, lumière plate

## Livraison
Déposer dans `refs/mecha_meshy/` sous `m1.png` … `m6.png` (1024×1024).
Je lance ensuite : image→3D → remesh 40k → rig → animations → sprites 8 directions → ancrages de canon.

## Repli si le rig échoue quand même
Générer le mecha **sans aucune arme** (bras nus en pose A) : je rig le corps, puis j'attache le
canon en **sprite séparé** ancré à la main. C'est même supérieur — un canon attaché **pivote avec
ta visée**, alors qu'un canon fondu dans le maillage est figé dans l'axe du bras.
