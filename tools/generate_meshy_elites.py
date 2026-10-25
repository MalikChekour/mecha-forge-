#!/usr/bin/env python3
"""
MECHA-FORGE — Pipeline Meshy 3D pour les 18 Méchas Supérieurs Gundam (Élites)
Génération Text-to-3D, Rigging Bipède, et Bakes d'animations.

Usage:
  python tools/generate_meshy_elites.py list
  python tools/generate_meshy_elites.py gen <chapitre_num_1_to_18> [--pbr]
  python tools/generate_meshy_elites.py rig <mecha_name>
  python tools/generate_meshy_elites.py all [--pbr]
"""
import os, sys, json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

ELITE_MECHAS = {
    1: {
        "id": "MS-01K",
        "name": "Vulcan-Enforcer",
        "biome": "tech",
        "chapter_name": "L'Usine",
        "vfx_effect": "IEM Industrial Shockwave & Heated Vibro-Cleave",
        "vfx_desc": "Rafale Gatling lourde + Onde de choc IEM étourdissante (2.5s) à l'impact de la vibrolame de contact avec gerbe d'étincelles électriques et traînée jaune.",
        "rig_profile": {
            "type": "Bipedal Mecha Rig",
            "root": "Root",
            "cockpit_bone": "Spine_Cockpit (damping hydraulic mount)",
            "weapon_r": "Forearm.R_GatlingHardpoint",
            "weapon_l": "Hand.L_VibroBladeSocket",
            "legs": "Dual bipedal hydraulic pistons with calf verniers",
            "anims": ["idle", "walk", "fire_gatling", "sword_slash", "guard_shield", "meltdown"]
        },
        "meshy_prompt": "Heavy industrial Gundam mecha, Mobile Suit Katoki ver Ka style, Level 1 Tech Factory. Prominent orange tinted armored glass pilot cockpit pod on central chest. Two mechanical bipedal legs with chrome pistons and broad footing pads in A-pose. Right arm has heavy 30mm Gatling cannon. Left arm wields heavy serrated industrial vibro-blade sword for melee combat. Hazard yellow and matte white armor with hazard stripes. Isolated light grey background, hard-surface 8k."
    },
    2: {
        "id": "MS-02D",
        "name": "Dust-Vanguard",
        "biome": "desert",
        "chapter_name": "Terres Arides",
        "vfx_effect": "Thermal Sandstorm & 1200°C Heat Scimitar Slash",
        "vfx_desc": "Tir linéaire 120mm supersonique + taille circulaire au cimeterre incandescent laissant un sillage de braises au sol et réduisant la vitesse du joueur.",
        "rig_profile": {
            "type": "Bipedal Mecha Rig",
            "root": "Root",
            "cockpit_bone": "Spine_Cockpit (sand-sealed enclosure)",
            "weapon_r": "Forearm.R_LinearCannon",
            "weapon_l": "Hand.L_HeatScimitarSocket",
            "legs": "Dust-sealed bipedal runner legs with wide sand-pads",
            "anims": ["idle", "walk", "fire_linear", "sword_slash", "guard_parry", "meltdown"]
        },
        "meshy_prompt": "Desert combat Gundam mecha, Mobile Suit Katoki ver Ka style, Level 2 Desert Wasteland. Sealed coyote-tan pilot cockpit pod on central torso with narrow visor. Two heavy bipedal mechanical legs with dust dampers and broad sand combat pads in A-pose. Right arm mounts long-range 120mm linear cannon. Left arm wields glowing red heat scimitar sword for melee contact. Coyote tan and charcoal plating. Isolated light grey background, hard-surface 8k."
    },
    3: {
        "id": "MS-03J",
        "name": "Jungle-Striker",
        "biome": "jungle",
        "chapter_name": "La Ruine Verte",
        "vfx_effect": "Canopy Rocket Barrage & Tungsten Kinetic Cleave",
        "vfx_desc": "Salves de 4 roquettes perforantes + coup de machette en tungstène fendant le sol provoquant une onde tellurique à courte portée.",
        "rig_profile": {
            "type": "Bipedal Mecha Rig",
            "root": "Root",
            "cockpit_bone": "Spine_Cockpit (reinforced brush-guarded pod)",
            "weapon_r": "Forearm.R_QuadRocketPod",
            "weapon_l": "Hand.L_TungstenMacheteSocket",
            "legs": "High-clearance all-terrain bipedal legs with root treads",
            "anims": ["idle", "walk", "fire_rockets", "sword_slash", "guard_cover", "meltdown"]
        },
        "meshy_prompt": "Overgrowth jungle Gundam mecha, Mobile Suit Katoki ver Ka style, Level 3 Jungle. Armored low-profile pilot cockpit canopy on torso with steel brush guards. Two high-clearance bipedal legs with heavy knee pistons and treaded combat feet in A-pose. Right arm mounts quad rocket launcher. Left arm wields heavy tungsten machete sword for brutal melee chopping. Military olive drab and forest green armor. Isolated light grey background, hard-surface 8k."
    },
    4: {
        "id": "MS-04V",
        "name": "Magma-Executioner",
        "biome": "volcanic",
        "chapter_name": "La Forge",
        "vfx_effect": "Incandescent Magma Blast & 180° Plasma Greatsword Wave",
        "vfx_desc": "Orbe de plasma lourd explosif + balayage frontal dévastateur à l'espadon de plasma projetant un arc de feu écarlate.",
        "rig_profile": {
            "type": "Bipedal Mecha Rig",
            "root": "Root",
            "cockpit_bone": "Spine_Cockpit (heat-insulated ceramic pod)",
            "weapon_r": "Forearm.R_MagmaPlasmaCannon",
            "weapon_l": "Hand.L_PlasmaGreatswordSocket",
            "legs": "Heat-shielded bipedal legs with thermal radiator fins",
            "anims": ["idle", "walk", "fire_plasma", "sword_slash", "guard_thermal", "meltdown"]
        },
        "meshy_prompt": "Volcanic foundry Gundam mecha, Mobile Suit Katoki ver Ka style, Level 4 Volcanic biome. Thermally insulated pilot cockpit pod in black ceramic with crimson quartz window. Two heavy bipedal legs with radiator fins and flared heat-shielded boots in A-pose. Right arm mounts heavy magma plasma cannon. Left arm wields colossal superheated glowing red plasma greatsword for melee. Basalt black and industrial crimson armor. Isolated light grey background, 8k."
    },
    5: {
        "id": "MS-05S",
        "name": "Corrosion-Warlord",
        "biome": "swamp",
        "chapter_name": "La Cité Déchue",
        "vfx_effect": "Acid Jet Burst & Corrosive Armor-Piercing Vibro-Claymore",
        "vfx_desc": "Nappe d'acide vert toxique au sol + estocade crantée infligeant une réduction d'armure temporaire au joueur.",
        "rig_profile": {
            "type": "Bipedal Mecha Rig",
            "root": "Root",
            "cockpit_bone": "Spine_Cockpit (acid-resistant composite pod)",
            "weapon_r": "Forearm.R_AcidDispersionGun",
            "weapon_l": "Hand.L_SerratedClaymoreSocket",
            "legs": "Rubberized joint-booted amphibious bipedal legs",
            "anims": ["idle", "walk", "fire_acid", "sword_slash", "guard_brace", "meltdown"]
        },
        "meshy_prompt": "Fallen city swamp Gundam mecha, Mobile Suit Katoki ver Ka style, Level 5 Swamp. Airtight pilot cockpit capsule with anti-acid composite plating and thick viewport. Two sealed bipedal combat legs with protective boots over pistons and wide mud footing pads in A-pose. Right arm mounts pressurized acid cannon. Left arm wields massive serrated vibro-claymore sword for contact slicing. Rust orange and toxic swamp green plating. Isolated light grey background, 8k."
    },
    6: {
        "id": "MS-06C",
        "name": "Frost-Paladin",
        "biome": "cryo",
        "chapter_name": "Le Cryo-Laboratoire",
        "vfx_effect": "Absolute-Zero Cryo-Beam & Glacier-Blue Laser Saber Pierce",
        "vfx_desc": "Rayon cryogénique à dispersion d'azote ralentissant à 50% + fente au sabre laser bleu glacier gelant les projectiles ennemis.",
        "rig_profile": {
            "type": "Bipedal Mecha Rig",
            "root": "Root",
            "cockpit_bone": "Spine_Cockpit (anti-freeze insulated pod)",
            "weapon_r": "Forearm.R_CryoRifle",
            "weapon_l": "Hand.L_CryoSaberSocket",
            "legs": "Arctic bipedal legs with deployable steel ice-cleats",
            "anims": ["idle", "walk", "fire_cryo", "sword_slash", "guard_frost", "meltdown"]
        },
        "meshy_prompt": "Arctic cryo Gundam mecha, Mobile Suit Katoki ver Ka style, Level 6 Cryo Lab. Insulated pilot cockpit pod with faceted hexagonal ice-blue anti-freeze glass canopy. Two angular Arctic bipedal legs with heating coils and ice-cleat boots in A-pose. Right arm mounts cryogenic beam rifle. Left arm wields glowing glacier-blue cryo-energy beam saber sword for precision contact dueling. Arctic white and frosted blue armor. Isolated light grey background, 8k."
    },
    7: {
        "id": "MS-07R",
        "name": "Meltdown-Centurion",
        "biome": "reacteur",
        "chapter_name": "Le Noyau Instable",
        "vfx_effect": "Ionizing Particle Beam & High-Frequency Radiation Blade",
        "vfx_desc": "Faisceau de particules ionisées tournoyant + coup de lame vibratoire irradiant avec onde verte de fission et zone de danger.",
        "rig_profile": {
            "type": "Bipedal Mecha Rig",
            "root": "Root",
            "cockpit_bone": "Spine_Cockpit (lead-lined nuclear survival pod)",
            "weapon_r": "Forearm.R_IonAccelerator",
            "weapon_l": "Hand.L_RadiationBladeSocket",
            "legs": "Nuclear-grade bipedal legs with heavy cooling vanes",
            "anims": ["idle", "walk", "fire_ion", "sword_slash", "guard_absorb", "meltdown"]
        },
        "meshy_prompt": "Nuclear reactor Gundam mecha, Mobile Suit Katoki ver Ka style, Level 7 Reactor. Lead-lined pilot cockpit pod with green glowing thick barium glass viewport. Two heavy bipedal legs with large radiator vanes and heavy hydraulic rams in A-pose. Right arm mounts heavy particle accelerator cannon. Left arm wields high-frequency radiation blade sword crackling with neon-green energy. Nuclear hazard yellow and matte black armor. Isolated light grey background, 8k."
    },
    8: {
        "id": "MS-08H",
        "name": "Cell-Exterminator",
        "biome": "ruche",
        "chapter_name": "La Ruche",
        "vfx_effect": "Flechette Rotary Barrage & Twin-Edged Amber Laser Cleave",
        "vfx_desc": "Nuée dense de fléchettes en spirale + double tranchant laser ambre tournoyant infligeant des attaques rapides et déstabilisantes.",
        "rig_profile": {
            "type": "Bipedal Mecha Rig",
            "root": "Root",
            "cockpit_bone": "Spine_Cockpit (high-g diamond canopy pod)",
            "weapon_r": "Forearm.R_FlechetteCannon",
            "weapon_l": "Hand.L_TwinLaserSwordSocket",
            "legs": "High-agility geometric bipedal legs with torque actuators",
            "anims": ["idle", "walk", "fire_flechettes", "sword_slash", "guard_evade", "meltdown"]
        },
        "meshy_prompt": "Biomechanical hive combat Gundam mecha, Mobile Suit Katoki ver Ka style, Level 8 Hive. Angular pilot control cockpit with diamond optical visor in gold tint. Two high-agility bipedal mecha legs with exposed torque actuators and sharp-heeled combat footing pads in A-pose. Right arm has rotary flechette cannon. Left arm wields glowing amber-gold twin-edged laser longsword for contact slicing. Deep imperial purple and gold armor. Isolated light grey background, 8k."
    },
    9: {
        "id": "MS-09O",
        "name": "Citadel-Dominator",
        "biome": "citadelle",
        "chapter_name": "La Citadelle Orbitale",
        "vfx_effect": "Orbital Mega-Beam Strike & Royal Gold 2-Meter Beam Saber",
        "vfx_desc": "Faisceau orbital beam surpuissant télégraphié + fente royale dorée créant une onde de choc lumineuse repoussant les tirs du joueur.",
        "rig_profile": {
            "type": "Bipedal Mecha Rig",
            "root": "Root",
            "cockpit_bone": "Spine_Cockpit (panoramic holographic commander pod)",
            "weapon_r": "Forearm.R_MegaBeamRifle",
            "weapon_l": "Hand.L_GoldBeamSaberSocket",
            "legs": "High-spec orbital bipedal legs with vernier thrusters",
            "anims": ["idle", "walk", "fire_megabeam", "sword_slash", "guard_deflect", "meltdown"]
        },
        "meshy_prompt": "Orbital citadel command Gundam mecha, Mobile Suit Katoki ver Ka style, Level 9 Citadel. Aristocratic pilot cockpit pod with sleek golden panoramic canopy showing holographic HUD. Two high-spec bipedal legs with vernier bells and pristine footing pads in A-pose. Right arm mounts orbital mega-beam rifle with cooling fins. Left arm wields high-output golden beam saber sword projecting intense 2-meter laser blade. Pearlescent white and royal gold armor. Isolated background, 8k."
    },
    10: {
        "id": "MS-10A",
        "name": "Trench-Colossus",
        "biome": "abyss",
        "chapter_name": "Les Abysses",
        "vfx_effect": "Vortex Cavitation Torpedo & Hydraulic Vibro-Cutlass Slam",
        "vfx_desc": "Torpille à vortex implosif aspirant brièvement le joueur + coup de coutelas hydraulique sous-marin percutant et destructeur.",
        "rig_profile": {
            "type": "Bipedal Mecha Rig",
            "root": "Root",
            "cockpit_bone": "Spine_Cockpit (hyperbaric bathysphere pod)",
            "weapon_r": "Forearm.R_TorpedoLauncher",
            "weapon_l": "Hand.L_VibroCutlassSocket",
            "legs": "Massive deep-sea bipedal legs with ballast calf tanks",
            "anims": ["idle", "walk", "fire_torpedo", "sword_slash", "guard_anchor", "meltdown"]
        },
        "meshy_prompt": "Abyssal trench combat Gundam mecha, Mobile Suit Katoki ver Ka style, Level 10 Abyss. Spherical hyperbaric bathysphere pilot cockpit pod with bolted hull and thick circular quartz window glowing cyan. Two massive deep-sea bipedal legs with ballast tanks and claw-padded footing plates in A-pose. Right arm mounts heavy torpedo cannon. Left arm wields massive underwater vibro-cutlass sword with hydraulic assist spine. Abyssal dark teal and submarine grey. Isolated, 8k."
    },
    11: {
        "id": "MS-11E",
        "name": "Spore-Phantom",
        "biome": "ether",
        "chapter_name": "Forêt Psychédélique",
        "vfx_effect": "Conical Spore Plasma Wave & Phonic UV Laser Rapier Thrust",
        "vfx_desc": "Onde conique de plasma fluorescent + triple estocade ultra-rapide à la rapière laser UV avec traînée de lumière violette.",
        "rig_profile": {
            "type": "Bipedal Mecha Rig",
            "root": "Root",
            "cockpit_bone": "Spine_Cockpit (catalytic NBC filter canopy)",
            "weapon_r": "Forearm.R_PlasmaDiffuser",
            "weapon_l": "Hand.L_LaserRapierSocket",
            "legs": "Sleek agile bipedal legs with vectoring micro-thrusters",
            "anims": ["idle", "walk", "fire_sporewave", "sword_slash", "guard_phase", "meltdown"]
        },
        "meshy_prompt": "Ether forest combat Gundam mecha, Mobile Suit Katoki ver Ka style, Level 11 Ether. Airtight pilot cockpit pod with iridescent prism canopy. Two sleek agile bipedal mecha legs with enclosed linkages and precision combat footing pads in A-pose. Right arm mounts conical plasma wave rifle. Left arm wields ultra-sharp phonic laser rapier sword with pulsating ultraviolet beam blade for lethal thrusts. Midnight purple, neon cyan, and magenta armor. Isolated background, 8k."
    },
    12: {
        "id": "MS-12T",
        "name": "Olympus-Dreadnought",
        "biome": "titans",
        "chapter_name": "La Nécropole d'Acier",
        "vfx_effect": "203mm Seismic Siege Impact & Monomolecular Buster Greatsword",
        "vfx_desc": "Obus de 203mm à tremblement d'écran + écrasement brutal au sol de l'épée colossale monomoléculaire pulvérisant tout dans un rayon de 180px.",
        "rig_profile": {
            "type": "Bipedal Mecha Rig",
            "root": "Root",
            "cockpit_bone": "Spine_Cockpit (bunker vault chest enclosure)",
            "weapon_r": "Forearm.R_HeavySiegeCannon",
            "weapon_l": "Hand.L_BusterSwordSocket",
            "legs": "Monumental fortress bipedal legs with external hydraulic oil rams",
            "anims": ["idle", "walk", "fire_siege", "sword_slash", "guard_ironwall", "meltdown"]
        },
        "meshy_prompt": "Titan necropolis siege Gundam mecha, Mobile Suit Katoki ver Ka style, Level 12 Titans. Heavy armored vault pilot cockpit bunker embedded in chest armor with periscope vision slits. Two monumental bipedal fortress legs with external hydraulic oil rams and huge combat boots in A-pose. Right arm mounts massive 203mm siege cannon. Left arm wields colossal monomolecular buster greatsword for crushing melee strikes. Weathered steel and antique bronze. Isolated, 8k."
    },
    13: {
        "id": "MS-13Z",
        "name": "Zero-Interceptor",
        "biome": "orbit",
        "chapter_name": "Le Champ Orbital",
        "vfx_effect": "Heat-Sink Focused Beam & Electric Blue Plasma Beam Katana Dash",
        "vfx_desc": "Tir concentré continu + ruée éclair zéro-G au katana laser bleu électrique avec post-combustion et traînée étincelante.",
        "rig_profile": {
            "type": "Bipedal Mecha Rig",
            "root": "Root",
            "cockpit_bone": "Spine_Cockpit (astronautic zero-g gold canopy)",
            "weapon_r": "Forearm.R_FocusedBeamCannon",
            "weapon_l": "Hand.L_BeamKatanaSocket",
            "legs": "Zero-g bipedal legs with omni-directional RCS thrusters",
            "anims": ["idle", "walk", "fire_beam", "sword_slash", "guard_dodge", "meltdown"]
        },
        "meshy_prompt": "Zero-G orbital combat Gundam mecha, Mobile Suit Katoki ver Ka style, Level 13 Orbit. Pressurized pilot cockpit pod with reflective gold canopy. Two high-mobility bipedal legs with omni-directional RCS thruster bells and mag-lock footing pads in A-pose. Right arm mounts long focused beam cannon. Left arm wields exquisite plasma beam katana sword with narrow electric blue laser blade for contact slicing. Carbon fiber black, polished chrome and deep space blue. Isolated, 8k."
    },
    14: {
        "id": "MS-14Q",
        "name": "Tesseract-Sentinel",
        "biome": "quantum",
        "chapter_name": "Station Quantique",
        "vfx_effect": "Tachyon Binary Burst & Geometric Crystalline Phase-Blade",
        "vfx_desc": "Tirs binaires quantiques déphasés + coupe dimensionnelle à la lame de phase fractale ignorant les réductions de dégâts.",
        "rig_profile": {
            "type": "Bipedal Mecha Rig",
            "root": "Root",
            "cockpit_bone": "Spine_Cockpit (faceted polyhedral tesseract pod)",
            "weapon_r": "Forearm.R_TachyonRepeater",
            "weapon_l": "Hand.L_PhaseBladeSocket",
            "legs": "Razor-sharp geometric bipedal legs with mag-lev actuators",
            "anims": ["idle", "walk", "fire_tachyon", "sword_slash", "guard_distortion", "meltdown"]
        },
        "meshy_prompt": "Quantum geometric station Gundam mecha, Mobile Suit Katoki ver Ka style, Level 14 Quantum. Faceted polyhedral pilot cockpit pod with violet holographic canopy. Two razor-sharp geometric bipedal legs with mag-lev actuators and angular footing pads in A-pose. Right arm mounts tachyon particle repeater with accelerator rings. Left arm wields geometric phase-blade sword shimmering with crystalline violet energy that slices physical matter. Matte silver and ultraviolet. Isolated, 8k."
    },
    15: {
        "id": "MS-15O",
        "name": "Thunder-Tempest",
        "biome": "ozone",
        "chapter_name": "Faille d'Ozone",
        "vfx_effect": "Twin-Electrode Voltaic Discharge & Arc-Lightning Beam Saber",
        "vfx_desc": "Éclairs voltaïques en chaîne rebondissants + taillade au sabre d'arcs électriques créant un flash aveuglant et paralysant les commandes 1s.",
        "rig_profile": {
            "type": "Bipedal Mecha Rig",
            "root": "Root",
            "cockpit_bone": "Spine_Cockpit (Faraday mesh shielded pod)",
            "weapon_r": "Forearm.R_VoltaicCannon",
            "weapon_l": "Hand.L_ArcSaberSocket",
            "legs": "High-voltage grounded bipedal legs with rubber insulators",
            "anims": ["idle", "walk", "fire_voltaic", "sword_slash", "guard_discharge", "meltdown"]
        },
        "meshy_prompt": "Ozone lightning storm Gundam mecha, Mobile Suit Katoki ver Ka style, Level 15 Ozone. Faraday-shielded heavy pilot cockpit pod with copper mesh in storm-blue tinted glass. Two high-voltage grounded bipedal legs with rubber insulator boots and broad insulated pads in A-pose. Right arm mounts twin-electrode voltaic arc cannon. Left arm wields arc-lightning beam saber sword surrounded by dancing blinding electrical arcs. Lightning yellow and storm navy blue. Isolated, 8k."
    },
    16: {
        "id": "MS-16P",
        "name": "Refraction-Avenger",
        "biome": "prism",
        "chapter_name": "Grotte Prismatique",
        "vfx_effect": "Split Prismatic Laser Fan & Crystalline Hard-Light Rainbow Blade",
        "vfx_desc": "Éventail de 5 lasers réfractés convergents + estocade de lumière solide créant une explosion d'éclats prismatiques multicolores.",
        "rig_profile": {
            "type": "Bipedal Mecha Rig",
            "root": "Root",
            "cockpit_bone": "Spine_Cockpit (diamond-cut quartz canopy pod)",
            "weapon_r": "Forearm.R_PrismaticLaser",
            "weapon_l": "Hand.L_HardLightBladeSocket",
            "legs": "Crystal-armored geometric bipedal legs with chrome pistons",
            "anims": ["idle", "walk", "fire_prismatic", "sword_slash", "guard_mirror", "meltdown"]
        },
        "meshy_prompt": "Prismatic crystal Gundam mecha, Mobile Suit Katoki ver Ka style, Level 16 Prism. Angular pilot cockpit capsule with multi-faceted diamond-cut quartz canopy reflecting rainbow highlights. Two crystal-armored geometric bipedal legs with chrome pistons and multi-angled footing pads in A-pose. Right arm mounts multi-lens prismatic laser cannon. Left arm wields crystalline hard-light energy broadsword projecting luminous rainbow-edged blade. Pearlescent white and silver. Isolated, 8k."
    },
    17: {
        "id": "MS-17B",
        "name": "Dread-Warhammer",
        "biome": "steampunk",
        "chapter_name": "Le Bastion Galactique",
        "vfx_effect": "Pneumatic High-Pressure Steam Burst & Steam-Piston Heavy Broadsword",
        "vfx_desc": "Nuage de vapeur brûlante masquant le mécha + frappe d'estoc propulsée par piston pneumatique repoussant violemment le joueur.",
        "rig_profile": {
            "type": "Bipedal Mecha Rig",
            "root": "Root",
            "cockpit_bone": "Spine_Cockpit (riveted cast-steel & brass porthole pod)",
            "weapon_r": "Forearm.R_PneumaticSteamCannon",
            "weapon_l": "Hand.L_PistonBroadswordSocket",
            "legs": "Heavy industrial bipedal walker legs with visible steam pistons",
            "anims": ["idle", "walk", "fire_steam", "sword_slash", "guard_vent", "meltdown"]
        },
        "meshy_prompt": "Galactic bastion industrial Gundam mecha, Mobile Suit Katoki ver Ka style, Level 17 Steampunk. Riveted cast-steel and brass pilot cockpit pod with circular bolted porthole window showing pressure gauges. Two mighty bipedal walker legs with visible steam pistons, brass linkages, and relief exhaust vents in A-pose. Right arm mounts massive pneumatic steam-cannon. Left arm wields colossal steam-assisted heavy broadsword with pneumatic piston spine. Boiler steel and brass. Isolated, 8k."
    },
    18: {
        "id": "MS-18C",
        "name": "Arena-Champion",
        "biome": "colosseum",
        "chapter_name": "Le Colisée Virtuel",
        "vfx_effect": "Triple Heavy Burst Barrage & Supreme Red Beam Gladius Execution",
        "vfx_desc": "Barrage de 3 salves d'assaut perforantes + tourbillon d'arène au gladius laser écarlate avec onde de choc finale rouge rubis.",
        "rig_profile": {
            "type": "Bipedal Mecha Rig",
            "root": "Root",
            "cockpit_bone": "Spine_Cockpit (ruby-red neural throne pod)",
            "weapon_r": "Forearm.R_TripleAssaultCannon",
            "weapon_l": "Hand.L_RedBeamGladiusSocket",
            "legs": "Master-crafted bipedal legs with gold vernier cowlings",
            "anims": ["idle", "walk", "fire_burst", "sword_slash", "guard_championship", "meltdown"]
        },
        "meshy_prompt": "Ultimate champion combat Gundam mecha, Mobile Suit Katoki ver Ka style, Level 18 Colosseum. Ornate reinforced champion pilot cockpit throne pod with faceted ruby-red armored canopy. Two master-crafted bipedal mecha legs with multiple gold-plated vernier cowlings and broad gladiator footing pads in A-pose. Right arm mounts triple-barrel heavy burst assault cannon. Left arm wields legendary wide-bladed red energy beam gladius sword. Carbon black, crimson and polished gold. Isolated, 8k."
    }
}

def print_list():
    print("=" * 80)
    print("MECHA-FORGE — 18 MÉCHAS SUPÉRIEURS GUNDAM (ÉLITES) - PIPELINE MESHY 3D")
    print("=" * 80)
    for num, m in ELITE_MECHAS.items():
        print(f"[{num:02d}] {m['id']} {m['name']} — Biome: {m['biome']} ({m['chapter_name']})")
        print(f"     ⚡ Effet Spécial: {m['vfx_effect']}")
        print(f"     🦴 Rig: {m['rig_profile']['type']} | Arme D: {m['rig_profile']['weapon_r']} | Épée G: {m['rig_profile']['weapon_l']}")
        print(f"     🎬 Anims: {', '.join(m['rig_profile']['anims'])}")
        print(f"     📝 Prompt Meshy: {m['meshy_prompt'][:90]}...")
        print("-" * 80)

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] == "list":
        print_list()
    elif sys.argv[1] == "gen":
        ch = int(sys.argv[2])
        m = ELITE_MECHAS.get(ch)
        if not m:
            print(f"Erreur: Chapitre {ch} inconnu (1-18)")
            sys.exit(1)
        import meshy_client
        pbr = "--pbr" in sys.argv
        print(f"Lancement de la génération Meshy pour {m['id']} {m['name']}...")
        meshy_client.gen_text(m["meshy_prompt"], f"elite_{m['biome']}", pbr=pbr)
    else:
        print_list()
