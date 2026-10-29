# Prompts Meshy — variants ennemis par rôle (18 chapitres × 3)

Objectif : remplacer le partage d'un seul `chassis` par biome. Aujourd'hui `mechNN`, `mechNN_swarm`, `mechNN_shield`, `mechNN_sniper` et `mechNN_elite` pointent tous vers le même `enNN_*`.

Pipeline inchangé : Gemini/image → `meshy image-to-3D` → remesh 40k → rig → anim → `bake_meshy.py --dirs 8` → sprites sous `res://assets/enemies/<chassis>/`.

Noms de chassis cibles :
- fodder : `enNN_<biome>_swarm`
- tank : `enNN_<biome>_shield`
- sniper : `enNN_<biome>_sniper`
- base existante `enNN_<biome>` : garder pour soldat mid + élite (scale/FX).

## Bloc technique (coller à la FIN de CHAQUE prompt)

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

## Checklist pré-Meshy (identique à GEMINI_MECHA_MESHY_PROMPTS.md)

1. Bras loin du torse / hanches
2. Jambes écartées, pieds à plat
3. Corps entier, rien de coupé
4. Pas d'antenne fine / câble / cape
5. Pas d'ombre au sol
6. Arme INTÉGRÉE à l'avant-bras (pas tenue)
7. Silhouette bipède lisible + fond gris #808080

---

## Ch01 — Assembly Walker (`tech`)

Base actuelle (ne pas régénérer) : `en01_tech` — industrial assembly-bay mecha, palette steel blue, white plating, amber hazard stripes.

### FODDER / SWARM → `en01_tech_swarm`

```
A badass SMALL lightweight skirmisher (about 70 percent the bulk of a standard mecha) industrial assembly-bay mecha, front view, standing in a neutral A-pose. Narrow shoulders, thin waist, athletic legs, head small and sharp. Armor colors: steel blue, white plating, amber hazard stripes. Compact factory-worker proportions. Must read instantly as a cheap disposable drone swarm unit, NOT a heavy soldier. Its weapons: TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short chunky barrels pointing forward from each wrist, plus small thruster blocks bolted on the calves. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### TANK / SHIELD → `en01_tech_shield`

```
A badass LARGE bulky vanguard (about 130 percent the bulk of a standard mecha) industrial assembly-bay mecha, front view, standing in a neutral A-pose. Wide shoulders, thick layered torso plating, wide stable legs, heavy helmeted head. Armor colors: steel blue, white plating, amber hazard stripes. Compact factory-worker proportions. Must read instantly as a walking fortress that protects allies. Its weapons: a THICK SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO THE LEFT FOREARM (shield tight against the forearm, must NOT touch torso or legs). Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### SNIPER / RANGED → `en01_tech_sniper`

```
A badass LEAN tall marksman (same height as standard but visibly thinner) industrial assembly-bay mecha, front view, standing in a neutral A-pose. Narrow torso, long limbs, digitigrade-looking but still human feet, elongated visored head. Armor colors: steel blue, white plating, amber hazard stripes. Compact factory-worker proportions. Must read instantly as a fragile long-range killer, NOT a tank. Its weapons: a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT FOREARM extending forward past the fist with a thick rectangular coil housing, and a smaller matching rangefinder block on the left forearm. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

---

## Ch02 — Dune Drifter (`desert`)

Base actuelle (ne pas régénérer) : `en02_desert` — desert dune mecha, palette sand beige, rust brown, sun-bleached white.

### FODDER / SWARM → `en02_desert_swarm`

```
A badass SMALL lightweight skirmisher (about 70 percent the bulk of a standard mecha) desert dune mecha, front view, standing in a neutral A-pose. Narrow shoulders, thin waist, athletic legs, head small and sharp. Armor colors: sand beige, rust brown, sun-bleached white. Arid scavenger proportions. Must read instantly as a cheap disposable drone swarm unit, NOT a heavy soldier. Its weapons: TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short chunky barrels pointing forward from each wrist, plus small thruster blocks bolted on the calves. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### TANK / SHIELD → `en02_desert_shield`

```
A badass LARGE bulky vanguard (about 130 percent the bulk of a standard mecha) desert dune mecha, front view, standing in a neutral A-pose. Wide shoulders, thick layered torso plating, wide stable legs, heavy helmeted head. Armor colors: sand beige, rust brown, sun-bleached white. Arid scavenger proportions. Must read instantly as a walking fortress that protects allies. Its weapons: a THICK SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO THE LEFT FOREARM (shield tight against the forearm, must NOT touch torso or legs). Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### SNIPER / RANGED → `en02_desert_sniper`

```
A badass LEAN tall marksman (same height as standard but visibly thinner) desert dune mecha, front view, standing in a neutral A-pose. Narrow torso, long limbs, digitigrade-looking but still human feet, elongated visored head. Armor colors: sand beige, rust brown, sun-bleached white. Arid scavenger proportions. Must read instantly as a fragile long-range killer, NOT a tank. Its weapons: a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT FOREARM extending forward past the fist with a thick rectangular coil housing, and a smaller matching rangefinder block on the left forearm. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

---

## Ch03 — Flora Crusher (`jungle`)

Base actuelle (ne pas régénérer) : `en03_jungle` — jungle canopy mecha, palette deep moss green, bark brown, bioluminescent lime accents.

### FODDER / SWARM → `en03_jungle_swarm`

```
A badass SMALL lightweight skirmisher (about 70 percent the bulk of a standard mecha) jungle canopy mecha, front view, standing in a neutral A-pose. Narrow shoulders, thin waist, athletic legs, head small and sharp. Armor colors: deep moss green, bark brown, bioluminescent lime accents. Organic-armored proportions. Must read instantly as a cheap disposable drone swarm unit, NOT a heavy soldier. Its weapons: TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short chunky barrels pointing forward from each wrist, plus small thruster blocks bolted on the calves. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### TANK / SHIELD → `en03_jungle_shield`

```
A badass LARGE bulky vanguard (about 130 percent the bulk of a standard mecha) jungle canopy mecha, front view, standing in a neutral A-pose. Wide shoulders, thick layered torso plating, wide stable legs, heavy helmeted head. Armor colors: deep moss green, bark brown, bioluminescent lime accents. Organic-armored proportions. Must read instantly as a walking fortress that protects allies. Its weapons: a THICK SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO THE LEFT FOREARM (shield tight against the forearm, must NOT touch torso or legs). Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### SNIPER / RANGED → `en03_jungle_sniper`

```
A badass LEAN tall marksman (same height as standard but visibly thinner) jungle canopy mecha, front view, standing in a neutral A-pose. Narrow torso, long limbs, digitigrade-looking but still human feet, elongated visored head. Armor colors: deep moss green, bark brown, bioluminescent lime accents. Organic-armored proportions. Must read instantly as a fragile long-range killer, NOT a tank. Its weapons: a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT FOREARM extending forward past the fist with a thick rectangular coil housing, and a smaller matching rangefinder block on the left forearm. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

---

## Ch04 — Magma Foundry (`volcanic`)

Base actuelle (ne pas régénérer) : `en04_volcanic` — volcanic forge mecha, palette charcoal black, molten orange, slag grey.

### FODDER / SWARM → `en04_volcanic_swarm`

```
A badass SMALL lightweight skirmisher (about 70 percent the bulk of a standard mecha) volcanic forge mecha, front view, standing in a neutral A-pose. Narrow shoulders, thin waist, athletic legs, head small and sharp. Armor colors: charcoal black, molten orange, slag grey. Heat-shielded industrial proportions. Must read instantly as a cheap disposable drone swarm unit, NOT a heavy soldier. Its weapons: TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short chunky barrels pointing forward from each wrist, plus small thruster blocks bolted on the calves. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### TANK / SHIELD → `en04_volcanic_shield`

```
A badass LARGE bulky vanguard (about 130 percent the bulk of a standard mecha) volcanic forge mecha, front view, standing in a neutral A-pose. Wide shoulders, thick layered torso plating, wide stable legs, heavy helmeted head. Armor colors: charcoal black, molten orange, slag grey. Heat-shielded industrial proportions. Must read instantly as a walking fortress that protects allies. Its weapons: a THICK SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO THE LEFT FOREARM (shield tight against the forearm, must NOT touch torso or legs). Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### SNIPER / RANGED → `en04_volcanic_sniper`

```
A badass LEAN tall marksman (same height as standard but visibly thinner) volcanic forge mecha, front view, standing in a neutral A-pose. Narrow torso, long limbs, digitigrade-looking but still human feet, elongated visored head. Armor colors: charcoal black, molten orange, slag grey. Heat-shielded industrial proportions. Must read instantly as a fragile long-range killer, NOT a tank. Its weapons: a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT FOREARM extending forward past the fist with a thick rectangular coil housing, and a smaller matching rangefinder block on the left forearm. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

---

## Ch05 — Sludge Excavator (`swamp`)

Base actuelle (ne pas régénérer) : `en05_swamp` — swamp excavator mecha, palette olive sludge green, muddy brown, sickly yellow lights.

### FODDER / SWARM → `en05_swamp_swarm`

```
A badass SMALL lightweight skirmisher (about 70 percent the bulk of a standard mecha) swamp excavator mecha, front view, standing in a neutral A-pose. Narrow shoulders, thin waist, athletic legs, head small and sharp. Armor colors: olive sludge green, muddy brown, sickly yellow lights. Waterproof dredger proportions. Must read instantly as a cheap disposable drone swarm unit, NOT a heavy soldier. Its weapons: TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short chunky barrels pointing forward from each wrist, plus small thruster blocks bolted on the calves. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### TANK / SHIELD → `en05_swamp_shield`

```
A badass LARGE bulky vanguard (about 130 percent the bulk of a standard mecha) swamp excavator mecha, front view, standing in a neutral A-pose. Wide shoulders, thick layered torso plating, wide stable legs, heavy helmeted head. Armor colors: olive sludge green, muddy brown, sickly yellow lights. Waterproof dredger proportions. Must read instantly as a walking fortress that protects allies. Its weapons: a THICK SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO THE LEFT FOREARM (shield tight against the forearm, must NOT touch torso or legs). Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### SNIPER / RANGED → `en05_swamp_sniper`

```
A badass LEAN tall marksman (same height as standard but visibly thinner) swamp excavator mecha, front view, standing in a neutral A-pose. Narrow torso, long limbs, digitigrade-looking but still human feet, elongated visored head. Armor colors: olive sludge green, muddy brown, sickly yellow lights. Waterproof dredger proportions. Must read instantly as a fragile long-range killer, NOT a tank. Its weapons: a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT FOREARM extending forward past the fist with a thick rectangular coil housing, and a smaller matching rangefinder block on the left forearm. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

---

## Ch06 — Glacier Borer (`cryo`)

Base actuelle (ne pas régénérer) : `en06_cryo` — cryogenic glacier mecha, palette ice white, glacial blue, pale cyan lights.

### FODDER / SWARM → `en06_cryo_swarm`

```
A badass SMALL lightweight skirmisher (about 70 percent the bulk of a standard mecha) cryogenic glacier mecha, front view, standing in a neutral A-pose. Narrow shoulders, thin waist, athletic legs, head small and sharp. Armor colors: ice white, glacial blue, pale cyan lights. Insulated arctic proportions. Must read instantly as a cheap disposable drone swarm unit, NOT a heavy soldier. Its weapons: TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short chunky barrels pointing forward from each wrist, plus small thruster blocks bolted on the calves. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### TANK / SHIELD → `en06_cryo_shield`

```
A badass LARGE bulky vanguard (about 130 percent the bulk of a standard mecha) cryogenic glacier mecha, front view, standing in a neutral A-pose. Wide shoulders, thick layered torso plating, wide stable legs, heavy helmeted head. Armor colors: ice white, glacial blue, pale cyan lights. Insulated arctic proportions. Must read instantly as a walking fortress that protects allies. Its weapons: a THICK SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO THE LEFT FOREARM (shield tight against the forearm, must NOT touch torso or legs). Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### SNIPER / RANGED → `en06_cryo_sniper`

```
A badass LEAN tall marksman (same height as standard but visibly thinner) cryogenic glacier mecha, front view, standing in a neutral A-pose. Narrow torso, long limbs, digitigrade-looking but still human feet, elongated visored head. Armor colors: ice white, glacial blue, pale cyan lights. Insulated arctic proportions. Must read instantly as a fragile long-range killer, NOT a tank. Its weapons: a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT FOREARM extending forward past the fist with a thick rectangular coil housing, and a smaller matching rangefinder block on the left forearm. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

---

## Ch07 — Radiation Core (`reacteur`)

Base actuelle (ne pas régénérer) : `en07_reacteur` — nuclear reactor mecha, palette hazard yellow, lead grey, radioactive green glow vents.

### FODDER / SWARM → `en07_reacteur_swarm`

```
A badass SMALL lightweight skirmisher (about 70 percent the bulk of a standard mecha) nuclear reactor mecha, front view, standing in a neutral A-pose. Narrow shoulders, thin waist, athletic legs, head small and sharp. Armor colors: hazard yellow, lead grey, radioactive green glow vents. Containment-suit proportions. Must read instantly as a cheap disposable drone swarm unit, NOT a heavy soldier. Its weapons: TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short chunky barrels pointing forward from each wrist, plus small thruster blocks bolted on the calves. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### TANK / SHIELD → `en07_reacteur_shield`

```
A badass LARGE bulky vanguard (about 130 percent the bulk of a standard mecha) nuclear reactor mecha, front view, standing in a neutral A-pose. Wide shoulders, thick layered torso plating, wide stable legs, heavy helmeted head. Armor colors: hazard yellow, lead grey, radioactive green glow vents. Containment-suit proportions. Must read instantly as a walking fortress that protects allies. Its weapons: a THICK SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO THE LEFT FOREARM (shield tight against the forearm, must NOT touch torso or legs). Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### SNIPER / RANGED → `en07_reacteur_sniper`

```
A badass LEAN tall marksman (same height as standard but visibly thinner) nuclear reactor mecha, front view, standing in a neutral A-pose. Narrow torso, long limbs, digitigrade-looking but still human feet, elongated visored head. Armor colors: hazard yellow, lead grey, radioactive green glow vents. Containment-suit proportions. Must read instantly as a fragile long-range killer, NOT a tank. Its weapons: a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT FOREARM extending forward past the fist with a thick rectangular coil housing, and a smaller matching rangefinder block on the left forearm. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

---

## Ch08 — Hive Breaker (`ruche`)

Base actuelle (ne pas régénérer) : `en08_ruche` — insectoid hive mecha, palette amber chitin, black steel, honey-gold accents.

### FODDER / SWARM → `en08_ruche_swarm`

```
A badass SMALL lightweight skirmisher (about 70 percent the bulk of a standard mecha) insectoid hive mecha, front view, standing in a neutral A-pose. Narrow shoulders, thin waist, athletic legs, head small and sharp. Armor colors: amber chitin, black steel, honey-gold accents. Semi-insectoid but still biped proportions. Must read instantly as a cheap disposable drone swarm unit, NOT a heavy soldier. Its weapons: TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short chunky barrels pointing forward from each wrist, plus small thruster blocks bolted on the calves. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### TANK / SHIELD → `en08_ruche_shield`

```
A badass LARGE bulky vanguard (about 130 percent the bulk of a standard mecha) insectoid hive mecha, front view, standing in a neutral A-pose. Wide shoulders, thick layered torso plating, wide stable legs, heavy helmeted head. Armor colors: amber chitin, black steel, honey-gold accents. Semi-insectoid but still biped proportions. Must read instantly as a walking fortress that protects allies. Its weapons: a THICK SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO THE LEFT FOREARM (shield tight against the forearm, must NOT touch torso or legs). Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### SNIPER / RANGED → `en08_ruche_sniper`

```
A badass LEAN tall marksman (same height as standard but visibly thinner) insectoid hive mecha, front view, standing in a neutral A-pose. Narrow torso, long limbs, digitigrade-looking but still human feet, elongated visored head. Armor colors: amber chitin, black steel, honey-gold accents. Semi-insectoid but still biped proportions. Must read instantly as a fragile long-range killer, NOT a tank. Its weapons: a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT FOREARM extending forward past the fist with a thick rectangular coil housing, and a smaller matching rangefinder block on the left forearm. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

---

## Ch09 — Orbital Bastion (`citadelle`)

Base actuelle (ne pas régénérer) : `en09_citadelle` — orbital citadel mecha, palette polished white, gold trim, deep navy.

### FODDER / SWARM → `en09_citadelle_swarm`

```
A badass SMALL lightweight skirmisher (about 70 percent the bulk of a standard mecha) orbital citadel mecha, front view, standing in a neutral A-pose. Narrow shoulders, thin waist, athletic legs, head small and sharp. Armor colors: polished white, gold trim, deep navy. Ceremonial fortress proportions. Must read instantly as a cheap disposable drone swarm unit, NOT a heavy soldier. Its weapons: TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short chunky barrels pointing forward from each wrist, plus small thruster blocks bolted on the calves. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### TANK / SHIELD → `en09_citadelle_shield`

```
A badass LARGE bulky vanguard (about 130 percent the bulk of a standard mecha) orbital citadel mecha, front view, standing in a neutral A-pose. Wide shoulders, thick layered torso plating, wide stable legs, heavy helmeted head. Armor colors: polished white, gold trim, deep navy. Ceremonial fortress proportions. Must read instantly as a walking fortress that protects allies. Its weapons: a THICK SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO THE LEFT FOREARM (shield tight against the forearm, must NOT touch torso or legs). Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### SNIPER / RANGED → `en09_citadelle_sniper`

```
A badass LEAN tall marksman (same height as standard but visibly thinner) orbital citadel mecha, front view, standing in a neutral A-pose. Narrow torso, long limbs, digitigrade-looking but still human feet, elongated visored head. Armor colors: polished white, gold trim, deep navy. Ceremonial fortress proportions. Must read instantly as a fragile long-range killer, NOT a tank. Its weapons: a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT FOREARM extending forward past the fist with a thick rectangular coil housing, and a smaller matching rangefinder block on the left forearm. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

---

## Ch10 — Nautilus (`abyss`)

Base actuelle (ne pas régénérer) : `en10_abyss` — deep-sea trench mecha, palette abyssal navy, teal bioluminescence, barnacle grey.

### FODDER / SWARM → `en10_abyss_swarm`

```
A badass SMALL lightweight skirmisher (about 70 percent the bulk of a standard mecha) deep-sea trench mecha, front view, standing in a neutral A-pose. Narrow shoulders, thin waist, athletic legs, head small and sharp. Armor colors: abyssal navy, teal bioluminescence, barnacle grey. Submersible diver proportions. Must read instantly as a cheap disposable drone swarm unit, NOT a heavy soldier. Its weapons: TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short chunky barrels pointing forward from each wrist, plus small thruster blocks bolted on the calves. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### TANK / SHIELD → `en10_abyss_shield`

```
A badass LARGE bulky vanguard (about 130 percent the bulk of a standard mecha) deep-sea trench mecha, front view, standing in a neutral A-pose. Wide shoulders, thick layered torso plating, wide stable legs, heavy helmeted head. Armor colors: abyssal navy, teal bioluminescence, barnacle grey. Submersible diver proportions. Must read instantly as a walking fortress that protects allies. Its weapons: a THICK SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO THE LEFT FOREARM (shield tight against the forearm, must NOT touch torso or legs). Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### SNIPER / RANGED → `en10_abyss_sniper`

```
A badass LEAN tall marksman (same height as standard but visibly thinner) deep-sea trench mecha, front view, standing in a neutral A-pose. Narrow torso, long limbs, digitigrade-looking but still human feet, elongated visored head. Armor colors: abyssal navy, teal bioluminescence, barnacle grey. Submersible diver proportions. Must read instantly as a fragile long-range killer, NOT a tank. Its weapons: a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT FOREARM extending forward past the fist with a thick rectangular coil housing, and a smaller matching rangefinder block on the left forearm. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

---

## Ch11 — Spore Strider (`ether`)

Base actuelle (ne pas régénérer) : `en11_ether` — ethereal spore mecha, palette violet mist, pale lavender, soft cyan spores.

### FODDER / SWARM → `en11_ether_swarm`

```
A badass SMALL lightweight skirmisher (about 70 percent the bulk of a standard mecha) ethereal spore mecha, front view, standing in a neutral A-pose. Narrow shoulders, thin waist, athletic legs, head small and sharp. Armor colors: violet mist, pale lavender, soft cyan spores. Light ethereal proportions. Must read instantly as a cheap disposable drone swarm unit, NOT a heavy soldier. Its weapons: TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short chunky barrels pointing forward from each wrist, plus small thruster blocks bolted on the calves. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### TANK / SHIELD → `en11_ether_shield`

```
A badass LARGE bulky vanguard (about 130 percent the bulk of a standard mecha) ethereal spore mecha, front view, standing in a neutral A-pose. Wide shoulders, thick layered torso plating, wide stable legs, heavy helmeted head. Armor colors: violet mist, pale lavender, soft cyan spores. Light ethereal proportions. Must read instantly as a walking fortress that protects allies. Its weapons: a THICK SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO THE LEFT FOREARM (shield tight against the forearm, must NOT touch torso or legs). Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### SNIPER / RANGED → `en11_ether_sniper`

```
A badass LEAN tall marksman (same height as standard but visibly thinner) ethereal spore mecha, front view, standing in a neutral A-pose. Narrow torso, long limbs, digitigrade-looking but still human feet, elongated visored head. Armor colors: violet mist, pale lavender, soft cyan spores. Light ethereal proportions. Must read instantly as a fragile long-range killer, NOT a tank. Its weapons: a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT FOREARM extending forward past the fist with a thick rectangular coil housing, and a smaller matching rangefinder block on the left forearm. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

---

## Ch12 — Goliath Relic (`titans`)

Base actuelle (ne pas régénérer) : `en12_titans` — ancient titan relic mecha, palette bronze, cracked stone grey, ember gold.

### FODDER / SWARM → `en12_titans_swarm`

```
A badass SMALL lightweight skirmisher (about 70 percent the bulk of a standard mecha) ancient titan relic mecha, front view, standing in a neutral A-pose. Narrow shoulders, thin waist, athletic legs, head small and sharp. Armor colors: bronze, cracked stone grey, ember gold. Monumental archaic proportions. Must read instantly as a cheap disposable drone swarm unit, NOT a heavy soldier. Its weapons: TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short chunky barrels pointing forward from each wrist, plus small thruster blocks bolted on the calves. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### TANK / SHIELD → `en12_titans_shield`

```
A badass LARGE bulky vanguard (about 130 percent the bulk of a standard mecha) ancient titan relic mecha, front view, standing in a neutral A-pose. Wide shoulders, thick layered torso plating, wide stable legs, heavy helmeted head. Armor colors: bronze, cracked stone grey, ember gold. Monumental archaic proportions. Must read instantly as a walking fortress that protects allies. Its weapons: a THICK SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO THE LEFT FOREARM (shield tight against the forearm, must NOT touch torso or legs). Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### SNIPER / RANGED → `en12_titans_sniper`

```
A badass LEAN tall marksman (same height as standard but visibly thinner) ancient titan relic mecha, front view, standing in a neutral A-pose. Narrow torso, long limbs, digitigrade-looking but still human feet, elongated visored head. Armor colors: bronze, cracked stone grey, ember gold. Monumental archaic proportions. Must read instantly as a fragile long-range killer, NOT a tank. Its weapons: a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT FOREARM extending forward past the fist with a thick rectangular coil housing, and a smaller matching rangefinder block on the left forearm. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

---

## Ch13 — Astro Vecteur (`orbit`)

Base actuelle (ne pas régénérer) : `en13_orbit` — zero-g orbital mecha, palette matte black, white panels, cyan thruster rings.

### FODDER / SWARM → `en13_orbit_swarm`

```
A badass SMALL lightweight skirmisher (about 70 percent the bulk of a standard mecha) zero-g orbital mecha, front view, standing in a neutral A-pose. Narrow shoulders, thin waist, athletic legs, head small and sharp. Armor colors: matte black, white panels, cyan thruster rings. Space-frame proportions. Must read instantly as a cheap disposable drone swarm unit, NOT a heavy soldier. Its weapons: TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short chunky barrels pointing forward from each wrist, plus small thruster blocks bolted on the calves. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### TANK / SHIELD → `en13_orbit_shield`

```
A badass LARGE bulky vanguard (about 130 percent the bulk of a standard mecha) zero-g orbital mecha, front view, standing in a neutral A-pose. Wide shoulders, thick layered torso plating, wide stable legs, heavy helmeted head. Armor colors: matte black, white panels, cyan thruster rings. Space-frame proportions. Must read instantly as a walking fortress that protects allies. Its weapons: a THICK SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO THE LEFT FOREARM (shield tight against the forearm, must NOT touch torso or legs). Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### SNIPER / RANGED → `en13_orbit_sniper`

```
A badass LEAN tall marksman (same height as standard but visibly thinner) zero-g orbital mecha, front view, standing in a neutral A-pose. Narrow torso, long limbs, digitigrade-looking but still human feet, elongated visored head. Armor colors: matte black, white panels, cyan thruster rings. Space-frame proportions. Must read instantly as a fragile long-range killer, NOT a tank. Its weapons: a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT FOREARM extending forward past the fist with a thick rectangular coil housing, and a smaller matching rangefinder block on the left forearm. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

---

## Ch14 — Cipher Byte (`quantum`)

Base actuelle (ne pas régénérer) : `en14_quantum` — quantum cipher mecha, palette iridescent black, electric magenta circuit lines, chrome.

### FODDER / SWARM → `en14_quantum_swarm`

```
A badass SMALL lightweight skirmisher (about 70 percent the bulk of a standard mecha) quantum cipher mecha, front view, standing in a neutral A-pose. Narrow shoulders, thin waist, athletic legs, head small and sharp. Armor colors: iridescent black, electric magenta circuit lines, chrome. Angular digital proportions. Must read instantly as a cheap disposable drone swarm unit, NOT a heavy soldier. Its weapons: TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short chunky barrels pointing forward from each wrist, plus small thruster blocks bolted on the calves. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### TANK / SHIELD → `en14_quantum_shield`

```
A badass LARGE bulky vanguard (about 130 percent the bulk of a standard mecha) quantum cipher mecha, front view, standing in a neutral A-pose. Wide shoulders, thick layered torso plating, wide stable legs, heavy helmeted head. Armor colors: iridescent black, electric magenta circuit lines, chrome. Angular digital proportions. Must read instantly as a walking fortress that protects allies. Its weapons: a THICK SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO THE LEFT FOREARM (shield tight against the forearm, must NOT touch torso or legs). Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### SNIPER / RANGED → `en14_quantum_sniper`

```
A badass LEAN tall marksman (same height as standard but visibly thinner) quantum cipher mecha, front view, standing in a neutral A-pose. Narrow torso, long limbs, digitigrade-looking but still human feet, elongated visored head. Armor colors: iridescent black, electric magenta circuit lines, chrome. Angular digital proportions. Must read instantly as a fragile long-range killer, NOT a tank. Its weapons: a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT FOREARM extending forward past the fist with a thick rectangular coil housing, and a smaller matching rangefinder block on the left forearm. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

---

## Ch15 — Volt Jumper (`ozone`)

Base actuelle (ne pas régénérer) : `en15_ozone` — ozone storm mecha, palette electric blue, storm grey, crackling white arcs on thick vents.

### FODDER / SWARM → `en15_ozone_swarm`

```
A badass SMALL lightweight skirmisher (about 70 percent the bulk of a standard mecha) ozone storm mecha, front view, standing in a neutral A-pose. Narrow shoulders, thin waist, athletic legs, head small and sharp. Armor colors: electric blue, storm grey, crackling white arcs on thick vents. Lightning-skirmisher proportions. Must read instantly as a cheap disposable drone swarm unit, NOT a heavy soldier. Its weapons: TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short chunky barrels pointing forward from each wrist, plus small thruster blocks bolted on the calves. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### TANK / SHIELD → `en15_ozone_shield`

```
A badass LARGE bulky vanguard (about 130 percent the bulk of a standard mecha) ozone storm mecha, front view, standing in a neutral A-pose. Wide shoulders, thick layered torso plating, wide stable legs, heavy helmeted head. Armor colors: electric blue, storm grey, crackling white arcs on thick vents. Lightning-skirmisher proportions. Must read instantly as a walking fortress that protects allies. Its weapons: a THICK SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO THE LEFT FOREARM (shield tight against the forearm, must NOT touch torso or legs). Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### SNIPER / RANGED → `en15_ozone_sniper`

```
A badass LEAN tall marksman (same height as standard but visibly thinner) ozone storm mecha, front view, standing in a neutral A-pose. Narrow torso, long limbs, digitigrade-looking but still human feet, elongated visored head. Armor colors: electric blue, storm grey, crackling white arcs on thick vents. Lightning-skirmisher proportions. Must read instantly as a fragile long-range killer, NOT a tank. Its weapons: a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT FOREARM extending forward past the fist with a thick rectangular coil housing, and a smaller matching rangefinder block on the left forearm. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

---

## Ch16 — Spectra Mech (`prism`)

Base actuelle (ne pas régénérer) : `en16_prism` — prismatic refraction mecha, palette opal white, rainbow refraction panels, silver edges.

### FODDER / SWARM → `en16_prism_swarm`

```
A badass SMALL lightweight skirmisher (about 70 percent the bulk of a standard mecha) prismatic refraction mecha, front view, standing in a neutral A-pose. Narrow shoulders, thin waist, athletic legs, head small and sharp. Armor colors: opal white, rainbow refraction panels, silver edges. Crystalline light proportions. Must read instantly as a cheap disposable drone swarm unit, NOT a heavy soldier. Its weapons: TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short chunky barrels pointing forward from each wrist, plus small thruster blocks bolted on the calves. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### TANK / SHIELD → `en16_prism_shield`

```
A badass LARGE bulky vanguard (about 130 percent the bulk of a standard mecha) prismatic refraction mecha, front view, standing in a neutral A-pose. Wide shoulders, thick layered torso plating, wide stable legs, heavy helmeted head. Armor colors: opal white, rainbow refraction panels, silver edges. Crystalline light proportions. Must read instantly as a walking fortress that protects allies. Its weapons: a THICK SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO THE LEFT FOREARM (shield tight against the forearm, must NOT touch torso or legs). Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### SNIPER / RANGED → `en16_prism_sniper`

```
A badass LEAN tall marksman (same height as standard but visibly thinner) prismatic refraction mecha, front view, standing in a neutral A-pose. Narrow torso, long limbs, digitigrade-looking but still human feet, elongated visored head. Armor colors: opal white, rainbow refraction panels, silver edges. Crystalline light proportions. Must read instantly as a fragile long-range killer, NOT a tank. Its weapons: a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT FOREARM extending forward past the fist with a thick rectangular coil housing, and a smaller matching rangefinder block on the left forearm. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

---

## Ch17 — Steam Dread (`steampunk`)

Base actuelle (ne pas régénérer) : `en17_steampunk` — steampunk dreadnought mecha, palette brass, copper, soot black, riveted iron.

### FODDER / SWARM → `en17_steampunk_swarm`

```
A badass SMALL lightweight skirmisher (about 70 percent the bulk of a standard mecha) steampunk dreadnought mecha, front view, standing in a neutral A-pose. Narrow shoulders, thin waist, athletic legs, head small and sharp. Armor colors: brass, copper, soot black, riveted iron. Victorian industrial proportions. Must read instantly as a cheap disposable drone swarm unit, NOT a heavy soldier. Its weapons: TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short chunky barrels pointing forward from each wrist, plus small thruster blocks bolted on the calves. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### TANK / SHIELD → `en17_steampunk_shield`

```
A badass LARGE bulky vanguard (about 130 percent the bulk of a standard mecha) steampunk dreadnought mecha, front view, standing in a neutral A-pose. Wide shoulders, thick layered torso plating, wide stable legs, heavy helmeted head. Armor colors: brass, copper, soot black, riveted iron. Victorian industrial proportions. Must read instantly as a walking fortress that protects allies. Its weapons: a THICK SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO THE LEFT FOREARM (shield tight against the forearm, must NOT touch torso or legs). Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### SNIPER / RANGED → `en17_steampunk_sniper`

```
A badass LEAN tall marksman (same height as standard but visibly thinner) steampunk dreadnought mecha, front view, standing in a neutral A-pose. Narrow torso, long limbs, digitigrade-looking but still human feet, elongated visored head. Armor colors: brass, copper, soot black, riveted iron. Victorian industrial proportions. Must read instantly as a fragile long-range killer, NOT a tank. Its weapons: a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT FOREARM extending forward past the fist with a thick rectangular coil housing, and a smaller matching rangefinder block on the left forearm. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

---

## Ch18 — Arena Gladiator (`colosseum`)

Base actuelle (ne pas régénérer) : `en18_colosseum` — colosseum gladiator mecha, palette blood red, polished bronze, ivory white.

### FODDER / SWARM → `en18_colosseum_swarm`

```
A badass SMALL lightweight skirmisher (about 70 percent the bulk of a standard mecha) colosseum gladiator mecha, front view, standing in a neutral A-pose. Narrow shoulders, thin waist, athletic legs, head small and sharp. Armor colors: blood red, polished bronze, ivory white. Arena fighter proportions. Must read instantly as a cheap disposable drone swarm unit, NOT a heavy soldier. Its weapons: TWIN COMPACT SUBMACHINE CANNONS INTEGRATED INTO BOTH FOREARMS, short chunky barrels pointing forward from each wrist, plus small thruster blocks bolted on the calves. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### TANK / SHIELD → `en18_colosseum_shield`

```
A badass LARGE bulky vanguard (about 130 percent the bulk of a standard mecha) colosseum gladiator mecha, front view, standing in a neutral A-pose. Wide shoulders, thick layered torso plating, wide stable legs, heavy helmeted head. Armor colors: blood red, polished bronze, ivory white. Arena fighter proportions. Must read instantly as a walking fortress that protects allies. Its weapons: a THICK SHORT SHOTGUN CANNON BUILT INTO THE RIGHT FOREARM and a SOLID ARMORED SHIELD PLATE BOLTED FLAT ONTO THE LEFT FOREARM (shield tight against the forearm, must NOT touch torso or legs). Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

### SNIPER / RANGED → `en18_colosseum_sniper`

```
A badass LEAN tall marksman (same height as standard but visibly thinner) colosseum gladiator mecha, front view, standing in a neutral A-pose. Narrow torso, long limbs, digitigrade-looking but still human feet, elongated visored head. Armor colors: blood red, polished bronze, ivory white. Arena fighter proportions. Must read instantly as a fragile long-range killer, NOT a tank. Its weapons: a LONG RAILGUN BARREL INTEGRATED ALONG THE RIGHT FOREARM extending forward past the fist with a thick rectangular coil housing, and a smaller matching rangefinder block on the left forearm. Painted 3D render, crisp and clean, same visual language as a premium real-robot mecha game enemy.
+ [TECHNICAL REQUIREMENTS]
```

---

## Après génération

1. Valider la checklist sur chaque image.
2. Meshy image-to-3D → remesh → rig → walk/idle.
3. `bake_meshy.py --dirs 8` vers `game/assets/enemies/<chassis>/`.
4. Dans `EnemySpawner.gd` DEFS : changer le champ `chassis` de `mechNN_swarm|shield|sniper` vers les nouveaux ids (élite peut rester sur la base + scale).
5. Kami / summoner : réutiliser `_swarm` (kami) et base/sniper (summoner) jusqu'à variants dédiés.
