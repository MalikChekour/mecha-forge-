# Circuits d'obstacles & Level Design Tactique (v12.21) - progression
Tag de retour : pre_circuits_20261107 (HEAD df464bf, v12.20)

## Etapes
- [x] 1. Installation des 151 compétences gamedev & studio (awesome-gamedev + Claude-Code-Game-Studios)
- [x] 2. Conception des 5 motifs de circuits dans game/systems/CircuitPatterns.gd (Open Hub, Ring, Slalom, Chokepoint, Trench Lane)
- [x] 3. Raccordement dans game/actors/PropScatter.gd (_load_chunk)
- [x] 4. Validation QA & banc de captures : qa_circuits/1_circuit_depart.png, 2_circuit_exploration.png, 3_circuit_combat.png
- [x] 5. Bump version 12.21 dans project.godot
- [x] 6. Export Web + Android et déploiement itch.io via butler

## Principes appliqués
1. Zéro cul-de-sac mortel : chaque motif maintient au moins 320 px de passage libre.
2. Boucles de kiting 360° (Ring) autour d'un bloc central structuré.
3. Chicanes en baïonnette (Slalom) pour forcer le regroupement des monstres.
4. Goulets d'étranglement (Chokepoints) équipés de barils explosifs ou cuves IEM.
5. Respect de la clairière de spawn au centre pour un démarrage propre et aéré.
