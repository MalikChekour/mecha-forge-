extends Node
class_name EnemySpawner
## Ring-spawns Meshy enemies around the player, ramping rate over the run.
## Data-driven; the 'motion' field maps to the baked animation sheet
## (enemies/<kind>_<motion>.png).

var game: Node
var player: Node2D
var _t: float = 0.0
var _spawn_t: float = 0.0
var speed_mult: float = 1.0   # biome modifier on enemy movement speed
var spawn_mult: float = 1.0   # biome modifier on spawn density
var arena_half: float = 0.0   # bounded-arena clamp for spawns (0 = unbounded)
var arena: Rect2 = Rect2(-1000000, -1000000, 2000000, 2000000)
var difficulty_bonus: float = 0.0   # permanent step-up per cleared zone (set by Game.next_map)
var current_biome: String = "tech"   # set by Game per zone -> filtre le pool d ennemis
## Quel chapitre a ete choisi au demarrage de la run (pas par zone -> jamais touche par
## next_map()/_apply_chapter_biome, seulement au lancement). Sert UNIQUEMENT a distinguer
## "chapitre 1" pour BELIER-01 (voir plus bas) ; ne change jamais en cours de run.
var chapter: int = 1
var enemy_tint: Color = Color(1, 1, 1)   # corruption visuelle du biome, appliquee a chaque ennemi
# Scripted HORDES: a massive coordinated wave that crashes in at timed moments. First at
# ~1 min, then on an interval; each wave grows with run time and stays mobile-safe (capped).
var _wave_t: float = 38.0
const WAVE_INTERVAL: float = 50.0
const ENEMY_CAP: int = 220   # weak swarm dies fast -> allow a denser horde on screen

# SURVIVOR.IO DIFFICULTY MODEL. Their chapter 1 does NOT dump every archetype at once: it
# introduces them one at a time so each new threat reads, then punctuates with scripted elites
# and bosses. Timeline we replicate ('unlock' = when the kind may spawn at all, in seconds):
#   0:00 melee swarm only      1:00 ranged units join      1:30 a 2nd melee type
#   3:00 intermediates + ELITE event      5:00 boss      12:00 ELITE event      15:00 final boss
# 30/09 : roster entier retire a la demande du patron (47 entrees). Vide deliberement, pas un
# oubli — toutes les fonctions de spawn plus bas sont gardees contre un DEFS/BIOME_POOL vide
# (kind absent -> no-op silencieux, jamais un crash). L'art (assets/enemies/) et le dispatch de
# comportement generique (Enemy.gd) restent en place, prets si des ennemis reviennent un jour.
const DEFS: Dictionary = {
	# 04/10, DESACTIVES pour la publication itch (demande explicite du patron : "sans ennemis,
	# juste decors/maps"). Code/tests/phases intacts, prets a etre reactives (decommenter les 4
	# lignes) des que le vrai art Meshy de ces 4 boss sera pret - voir _test_boss_chapitres.gd,
	# toujours vert, qui construit ces Enemy directement sans passer par DEFS.
	# 17/10 (patron : « integre les ennemis de base pour tester ») : les 3 ennemis UNIVERSELS reviennent (Rodeur, Guepe, Belier), copies telles
	# quelles de EnemySpawner.gd.fullroster. Les specialistes par biome et les boss restent desactives.
	"brute":     {"name": "Rodeur", "chassis": "u_rodeur", "proc": true, "hp": 14.0, "speed": 185.0, "dmg": 6.0, "radius": 30.0, "size": 124.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "unlock": 0.0},
	"drone":     {"name": "Guepe", "chassis": "u_guepe", "proc": true, "hp": 10.0, "speed": 235.0, "dmg": 3.0, "radius": 18.0, "size": 78.0, "motion": "hover", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 4.0, "attack_cd": 1.9, "prefer_dist": 280.0, "unlock": 40.0},
	"quadshell": {"name": "Belier", "chassis": "u_belier", "proc": true, "hp": 18.0, "speed": 178.0, "dmg": 9.0, "radius": 26.0, "size": 122.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "dasher", "unlock": 55.0},
	# 19/10 : ENNEMIS DE BASE DE CHAQUE NIVEAU (mecha des 18 chapitres, Meshy -> 8 directions). Un par chapitre, ajoutes un a un.
	"mech01": {"name": "Walker d'assemblage", "chassis": "en01_tech", "hp": 28.5, "speed": 172.0, "dmg": 7.4, "radius": 40.0, "size": 148.8, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 4.3, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech02": {"name": "Rodeur des dunes", "chassis": "en02_desert", "hp": 31.0, "speed": 176.0, "dmg": 7.8, "radius": 40.0, "size": 153.6, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 4.7, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech03": {"name": "Broyeur forestier", "chassis": "en03_jungle", "hp": 33.5, "speed": 180.0, "dmg": 8.2, "radius": 40.0, "size": 158.4, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 5.0, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech04": {"name": "Constructeur d'Acier", "chassis": "en04_volcanic", "hp": 36.0, "speed": 168.0, "dmg": 8.6, "radius": 40.0, "size": 153.6, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 5.4, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech05": {"name": "Excavateur de vase", "chassis": "en05_swamp", "hp": 38.5, "speed": 172.0, "dmg": 9.0, "radius": 40.0, "size": 151.2, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 5.8, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech06": {"name": "Foreur glaciaire", "chassis": "en06_cryo", "hp": 41.0, "speed": 176.0, "dmg": 9.4, "radius": 40.0, "size": 156.0, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 6.1, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech07": {"name": "Noyau irradie", "chassis": "en07_reacteur", "hp": 43.5, "speed": 180.0, "dmg": 9.8, "radius": 40.0, "size": 146.4, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 6.4, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech08": {"name": "Brise-ruche", "chassis": "en08_ruche", "hp": 46.0, "speed": 168.0, "dmg": 10.2, "radius": 40.0, "size": 153.6, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 6.8, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech09": {"name": "Bastion orbital", "chassis": "en09_citadelle", "hp": 48.5, "speed": 172.0, "dmg": 10.6, "radius": 40.0, "size": 160.8, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 7.2, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech10": {"name": "Nautilus", "chassis": "en10_abyss", "hp": 51.0, "speed": 176.0, "dmg": 11.0, "radius": 40.0, "size": 158.4, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 7.5, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech11": {"name": "Marcheur de spores", "chassis": "en11_ether", "hp": 53.5, "speed": 180.0, "dmg": 11.4, "radius": 40.0, "size": 156.0, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 7.8, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech12": {"name": "Relique titan", "chassis": "en12_titans", "hp": 56.0, "speed": 168.0, "dmg": 11.8, "radius": 40.0, "size": 170.4, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 8.2, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech13": {"name": "Astro-vecteur", "chassis": "en13_orbit", "hp": 58.5, "speed": 172.0, "dmg": 12.2, "radius": 40.0, "size": 153.6, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 8.6, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech14": {"name": "Cipher-byte", "chassis": "en14_quantum", "hp": 61.0, "speed": 176.0, "dmg": 12.6, "radius": 40.0, "size": 151.2, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 8.9, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech15": {"name": "Sauteur de foudre", "chassis": "en15_ozone", "hp": 63.5, "speed": 180.0, "dmg": 13.0, "radius": 40.0, "size": 153.6, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 9.2, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech16": {"name": "Spectra-mecha", "chassis": "en16_prism", "hp": 66.0, "speed": 168.0, "dmg": 13.4, "radius": 40.0, "size": 156.0, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 9.6, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech17": {"name": "Terreur a vapeur", "chassis": "en17_steampunk", "hp": 68.5, "speed": 172.0, "dmg": 13.8, "radius": 40.0, "size": 158.4, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 9.9, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},
	"mech18": {"name": "Gladiateur", "chassis": "en18_colosseum", "hp": 71.0, "speed": 176.0, "dmg": 14.2, "radius": 40.0, "size": 160.8, "motion": "walk", "rank": 0, "w": 5, "behavior": "ranged", "attack_dmg": 10.3, "attack_cd": 2.2, "prefer_dist": 240.0, "unlock": 0.0},

	# --- ESCOUADES TRIPARTITES PAR BIOME (Pilier 1 : Diversification) ---
	# Swarmers (drones rapides de meute, rush + zigzag, AoE requis)
	"mech01_swarm": {"name": "Drone d'atelier", "chassis": "en01_tech_swarm", "hp": 14.0, "speed": 245.0, "dmg": 4.2, "radius": 28.0, "size": 110.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "zigzag": 0.35, "unlock": 0.0},
	"mech02_swarm": {"name": "Scorpion des sables", "chassis": "en02_desert_swarm", "hp": 15.0, "speed": 248.0, "dmg": 4.5, "radius": 28.0, "size": 112.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "zigzag": 0.35, "unlock": 0.0},
	"mech03_swarm": {"name": "Essaim de canopée", "chassis": "en03_jungle_swarm", "hp": 16.5, "speed": 252.0, "dmg": 4.8, "radius": 28.0, "size": 114.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "zigzag": 0.35, "unlock": 0.0},
	"mech04_swarm": {"name": "Éclat de lave", "chassis": "en04_volcanic", "hp": 18.0, "speed": 242.0, "dmg": 5.1, "radius": 28.0, "size": 110.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "zigzag": 0.35, "unlock": 0.0},
	"mech05_swarm": {"name": "Sangsue des marais", "chassis": "en05_swamp", "hp": 19.5, "speed": 245.0, "dmg": 5.4, "radius": 28.0, "size": 112.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "zigzag": 0.35, "unlock": 0.0},
	"mech06_swarm": {"name": "Drone de givre", "chassis": "en06_cryo", "hp": 21.0, "speed": 248.0, "dmg": 5.7, "radius": 28.0, "size": 114.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "zigzag": 0.35, "unlock": 0.0},
	"mech07_swarm": {"name": "Particule fugitive", "chassis": "en07_reacteur", "hp": 22.5, "speed": 252.0, "dmg": 6.0, "radius": 28.0, "size": 110.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "zigzag": 0.35, "unlock": 0.0},
	"mech08_swarm": {"name": "Ouvrière carnassière", "chassis": "en08_ruche", "hp": 24.0, "speed": 244.0, "dmg": 6.3, "radius": 28.0, "size": 112.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "zigzag": 0.35, "unlock": 0.0},
	"mech09_swarm": {"name": "Intercepteur orbital", "chassis": "en09_citadelle", "hp": 25.5, "speed": 248.0, "dmg": 6.6, "radius": 28.0, "size": 115.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "zigzag": 0.35, "unlock": 0.0},
	"mech10_swarm": {"name": "Harponneur abyssal", "chassis": "en10_abyss", "hp": 27.0, "speed": 250.0, "dmg": 6.9, "radius": 28.0, "size": 112.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "zigzag": 0.35, "unlock": 0.0},
	"mech11_swarm": {"name": "Parasite d'éther", "chassis": "en11_ether", "hp": 28.5, "speed": 254.0, "dmg": 7.2, "radius": 28.0, "size": 114.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "zigzag": 0.35, "unlock": 0.0},
	"mech12_swarm": {"name": "Scarabée titanique", "chassis": "en12_titans", "hp": 30.0, "speed": 242.0, "dmg": 7.5, "radius": 28.0, "size": 116.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "zigzag": 0.35, "unlock": 0.0},
	"mech13_swarm": {"name": "Sonde orbitale", "chassis": "en13_orbit", "hp": 31.5, "speed": 246.0, "dmg": 7.8, "radius": 28.0, "size": 112.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "zigzag": 0.35, "unlock": 0.0},
	"mech14_swarm": {"name": "Fragment binaire", "chassis": "en14_quantum", "hp": 33.0, "speed": 250.0, "dmg": 8.1, "radius": 28.0, "size": 110.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "zigzag": 0.35, "unlock": 0.0},
	"mech15_swarm": {"name": "Étincelle d'ozone", "chassis": "en15_ozone", "hp": 34.5, "speed": 254.0, "dmg": 8.4, "radius": 28.0, "size": 112.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "zigzag": 0.35, "unlock": 0.0},
	"mech16_swarm": {"name": "Réfracteur agile", "chassis": "en16_prism", "hp": 36.0, "speed": 244.0, "dmg": 8.7, "radius": 28.0, "size": 114.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "zigzag": 0.35, "unlock": 0.0},
	"mech17_swarm": {"name": "Bielle à vapeur", "chassis": "en17_steampunk", "hp": 37.5, "speed": 248.0, "dmg": 9.0, "radius": 28.0, "size": 115.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "zigzag": 0.35, "unlock": 0.0},
	"mech18_swarm": {"name": "Légionnaire rapide", "chassis": "en18_colosseum", "hp": 39.0, "speed": 252.0, "dmg": 9.3, "radius": 28.0, "size": 116.0, "motion": "walk", "rank": 0, "w": 6, "behavior": "rush", "zigzag": 0.35, "unlock": 0.0},

	# Tanks / Vanguards Blindés (châssis lourds, dôme garde, shield front, protecteur)
	"mech01_shield": {"name": "Rempart d'avant-garde", "chassis": "en01_tech_shield", "hp": 52.0, "speed": 136.0, "dmg": 8.5, "radius": 46.0, "size": 164.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "garde": true, "shield": 24.0, "protecteur": true, "attack_dmg": 4.8, "attack_cd": 2.5, "prefer_dist": 220.0, "unlock": 35.0},
	"mech02_shield": {"name": "Forteresse des dunes", "chassis": "en02_desert_shield", "hp": 56.0, "speed": 138.0, "dmg": 9.0, "radius": 46.0, "size": 166.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "garde": true, "shield": 26.0, "protecteur": true, "attack_dmg": 5.2, "attack_cd": 2.5, "prefer_dist": 220.0, "unlock": 35.0},
	"mech03_shield": {"name": "Colosse d'écorce", "chassis": "en03_jungle_shield", "hp": 60.0, "speed": 140.0, "dmg": 9.5, "radius": 46.0, "size": 168.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "garde": true, "shield": 28.0, "protecteur": true, "attack_dmg": 5.5, "attack_cd": 2.5, "prefer_dist": 220.0, "unlock": 35.0},
	"mech04_shield": {"name": "Cuirassé de magma", "chassis": "en04_volcanic", "hp": 64.0, "speed": 132.0, "dmg": 10.0, "radius": 46.0, "size": 165.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "garde": true, "shield": 30.0, "protecteur": true, "attack_dmg": 5.9, "attack_cd": 2.5, "prefer_dist": 220.0, "unlock": 35.0},
	"mech05_shield": {"name": "Blindé des bourbiers", "chassis": "en05_swamp", "hp": 68.0, "speed": 135.0, "dmg": 10.5, "radius": 46.0, "size": 166.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "garde": true, "shield": 32.0, "protecteur": true, "attack_dmg": 6.3, "attack_cd": 2.5, "prefer_dist": 220.0, "unlock": 35.0},
	"mech06_shield": {"name": "Bastion permafrost", "chassis": "en06_cryo", "hp": 72.0, "speed": 138.0, "dmg": 11.0, "radius": 46.0, "size": 168.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "garde": true, "shield": 34.0, "protecteur": true, "attack_dmg": 6.6, "attack_cd": 2.5, "prefer_dist": 220.0, "unlock": 35.0},
	"mech07_shield": {"name": "Bouclier isotopique", "chassis": "en07_reacteur", "hp": 76.0, "speed": 140.0, "dmg": 11.5, "radius": 46.0, "size": 164.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "garde": true, "shield": 36.0, "protecteur": true, "attack_dmg": 7.0, "attack_cd": 2.5, "prefer_dist": 220.0, "unlock": 35.0},
	"mech08_shield": {"name": "Garde royal de ruche", "chassis": "en08_ruche", "hp": 80.0, "speed": 134.0, "dmg": 12.0, "radius": 46.0, "size": 166.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "garde": true, "shield": 38.0, "protecteur": true, "attack_dmg": 7.4, "attack_cd": 2.5, "prefer_dist": 220.0, "unlock": 35.0},
	"mech09_shield": {"name": "Rempart de citadelle", "chassis": "en09_citadelle", "hp": 84.0, "speed": 136.0, "dmg": 12.5, "radius": 46.0, "size": 170.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "garde": true, "shield": 40.0, "protecteur": true, "attack_dmg": 7.8, "attack_cd": 2.5, "prefer_dist": 220.0, "unlock": 35.0},
	"mech10_shield": {"name": "Léviathan cuirassé", "chassis": "en10_abyss", "hp": 88.0, "speed": 138.0, "dmg": 13.0, "radius": 46.0, "size": 168.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "garde": true, "shield": 42.0, "protecteur": true, "attack_dmg": 8.1, "attack_cd": 2.5, "prefer_dist": 220.0, "unlock": 35.0},
	"mech11_shield": {"name": "Tronc d'éther", "chassis": "en11_ether", "hp": 92.0, "speed": 140.0, "dmg": 13.5, "radius": 46.0, "size": 168.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "garde": true, "shield": 44.0, "protecteur": true, "attack_dmg": 8.5, "attack_cd": 2.5, "prefer_dist": 220.0, "unlock": 35.0},
	"mech12_shield": {"name": "Garde de titan", "chassis": "en12_titans", "hp": 96.0, "speed": 132.0, "dmg": 14.0, "radius": 46.0, "size": 174.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "garde": true, "shield": 46.0, "protecteur": true, "attack_dmg": 8.9, "attack_cd": 2.5, "prefer_dist": 220.0, "unlock": 35.0},
	"mech13_shield": {"name": "Bouclier stellaire", "chassis": "en13_orbit", "hp": 100.0, "speed": 135.0, "dmg": 14.5, "radius": 46.0, "size": 166.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "garde": true, "shield": 48.0, "protecteur": true, "attack_dmg": 9.3, "attack_cd": 2.5, "prefer_dist": 220.0, "unlock": 35.0},
	"mech14_shield": {"name": "Firewall quantique", "chassis": "en14_quantum", "hp": 104.0, "speed": 138.0, "dmg": 15.0, "radius": 46.0, "size": 165.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "garde": true, "shield": 50.0, "protecteur": true, "attack_dmg": 9.6, "attack_cd": 2.5, "prefer_dist": 220.0, "unlock": 35.0},
	"mech15_shield": {"name": "Cage de Faraday", "chassis": "en15_ozone", "hp": 108.0, "speed": 140.0, "dmg": 15.5, "radius": 46.0, "size": 166.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "garde": true, "shield": 52.0, "protecteur": true, "attack_dmg": 10.0, "attack_cd": 2.5, "prefer_dist": 220.0, "unlock": 35.0},
	"mech16_shield": {"name": "Miroir prismatique", "chassis": "en16_prism", "hp": 112.0, "speed": 132.0, "dmg": 16.0, "radius": 46.0, "size": 168.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "garde": true, "shield": 54.0, "protecteur": true, "attack_dmg": 10.4, "attack_cd": 2.5, "prefer_dist": 220.0, "unlock": 35.0},
	"mech17_shield": {"name": "Cuirassé à chaudière", "chassis": "en17_steampunk", "hp": 116.0, "speed": 135.0, "dmg": 16.5, "radius": 46.0, "size": 170.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "garde": true, "shield": 56.0, "protecteur": true, "attack_dmg": 10.8, "attack_cd": 2.5, "prefer_dist": 220.0, "unlock": 35.0},
	"mech18_shield": {"name": "Centurion blindé", "chassis": "en18_colosseum", "hp": 120.0, "speed": 138.0, "dmg": 17.0, "radius": 46.0, "size": 172.0, "motion": "walk", "rank": 0, "w": 3, "behavior": "ranged", "garde": true, "shield": 58.0, "protecteur": true, "attack_dmg": 11.2, "attack_cd": 2.5, "prefer_dist": 220.0, "unlock": 35.0},

	# Snipers / Sentinelles Laser (tir_style sniper, ligne de télégraphe Line2D, dégâts lourds)
	"mech01_sniper": {"name": "Sentinelle Laser", "chassis": "en01_tech_sniper", "hp": 22.0, "speed": 158.0, "dmg": 5.5, "radius": 34.0, "size": 134.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 9.5, "attack_cd": 3.2, "prefer_dist": 380.0, "unlock": 50.0},
	"mech02_sniper": {"name": "Tireur des mirages", "chassis": "en02_desert_sniper", "hp": 24.0, "speed": 160.0, "dmg": 6.0, "radius": 34.0, "size": 136.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 12.2, "attack_cd": 3.2, "prefer_dist": 380.0, "unlock": 50.0},
	"mech03_sniper": {"name": "Archer de sous-bois", "chassis": "en03_jungle_sniper", "hp": 26.0, "speed": 162.0, "dmg": 6.4, "radius": 34.0, "size": 138.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 12.8, "attack_cd": 3.2, "prefer_dist": 380.0, "unlock": 50.0},
	"mech04_sniper": {"name": "Pointeur thermique", "chassis": "en04_volcanic", "hp": 28.0, "speed": 154.0, "dmg": 6.8, "radius": 34.0, "size": 135.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 13.5, "attack_cd": 3.2, "prefer_dist": 380.0, "unlock": 50.0},
	"mech05_sniper": {"name": "Guetteur de brume", "chassis": "en05_swamp", "hp": 30.0, "speed": 156.0, "dmg": 7.2, "radius": 34.0, "size": 136.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 14.1, "attack_cd": 3.2, "prefer_dist": 380.0, "unlock": 50.0},
	"mech06_sniper": {"name": "Sniper cryogénique", "chassis": "en06_cryo", "hp": 32.0, "speed": 158.0, "dmg": 7.6, "radius": 34.0, "size": 138.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 14.7, "attack_cd": 3.2, "prefer_dist": 380.0, "unlock": 50.0},
	"mech07_sniper": {"name": "Focaliseur gamma", "chassis": "en07_reacteur", "hp": 34.0, "speed": 160.0, "dmg": 8.0, "radius": 34.0, "size": 134.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 15.3, "attack_cd": 3.2, "prefer_dist": 380.0, "unlock": 50.0},
	"mech08_sniper": {"name": "Dard perforant", "chassis": "en08_ruche", "hp": 36.0, "speed": 155.0, "dmg": 8.4, "radius": 34.0, "size": 136.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 16.0, "attack_cd": 3.2, "prefer_dist": 380.0, "unlock": 50.0},
	"mech09_sniper": {"name": "Canon rail orbital", "chassis": "en09_citadelle", "hp": 38.0, "speed": 158.0, "dmg": 8.8, "radius": 34.0, "size": 140.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 16.6, "attack_cd": 3.2, "prefer_dist": 380.0, "unlock": 50.0},
	"mech10_sniper": {"name": "Sonar longue-vue", "chassis": "en10_abyss", "hp": 40.0, "speed": 160.0, "dmg": 9.2, "radius": 34.0, "size": 138.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 17.2, "attack_cd": 3.2, "prefer_dist": 380.0, "unlock": 50.0},
	"mech11_sniper": {"name": "Tireur fongique", "chassis": "en11_ether", "hp": 42.0, "speed": 162.0, "dmg": 9.6, "radius": 34.0, "size": 138.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 17.8, "attack_cd": 3.2, "prefer_dist": 380.0, "unlock": 50.0},
	"mech12_sniper": {"name": "Canonnier titan", "chassis": "en12_titans", "hp": 44.0, "speed": 154.0, "dmg": 10.0, "radius": 34.0, "size": 142.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 18.5, "attack_cd": 3.2, "prefer_dist": 380.0, "unlock": 50.0},
	"mech13_sniper": {"name": "Faisceau d'orbite", "chassis": "en13_orbit", "hp": 46.0, "speed": 156.0, "dmg": 10.4, "radius": 34.0, "size": 136.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 19.1, "attack_cd": 3.2, "prefer_dist": 380.0, "unlock": 50.0},
	"mech14_sniper": {"name": "Pointeur quantique", "chassis": "en14_quantum", "hp": 48.0, "speed": 158.0, "dmg": 10.8, "radius": 34.0, "size": 135.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 19.7, "attack_cd": 3.2, "prefer_dist": 380.0, "unlock": 50.0},
	"mech15_sniper": {"name": "Éclair téléguidé", "chassis": "en15_ozone", "hp": 50.0, "speed": 160.0, "dmg": 11.2, "radius": 34.0, "size": 136.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 20.3, "attack_cd": 3.2, "prefer_dist": 380.0, "unlock": 50.0},
	"mech16_sniper": {"name": "Faisceau spectral", "chassis": "en16_prism", "hp": 52.0, "speed": 154.0, "dmg": 11.6, "radius": 34.0, "size": 138.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 21.0, "attack_cd": 3.2, "prefer_dist": 380.0, "unlock": 50.0},
	"mech17_sniper": {"name": "Fusilier haute pression", "chassis": "en17_steampunk", "hp": 54.0, "speed": 156.0, "dmg": 12.0, "radius": 34.0, "size": 140.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 21.6, "attack_cd": 3.2, "prefer_dist": 380.0, "unlock": 50.0},
	"mech18_sniper": {"name": "Sagittaire de l'arène", "chassis": "en18_colosseum", "hp": 56.0, "speed": 158.0, "dmg": 12.4, "radius": 34.0, "size": 142.0, "motion": "walk", "rank": 0, "w": 4, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 22.2, "attack_cd": 3.2, "prefer_dist": 380.0, "unlock": 50.0},

	# --- MÉCHAS ÉLITES SUPÉRIEURS (Gundam Dual-Arms : Tir + Épée de Contact & Effets Spéciaux) ---
	"mech01_elite": {"name": "MS-01K Vulcan-Enforcer", "chassis": "en01_tech", "hp": 75.0, "speed": 165.0, "dmg": 10.0, "radius": 46.0, "size": 172.0, "motion": "walk", "rank": 1, "w": 5, "behavior": "ranged", "tir_style": "rafale", "attack_dmg": 8.5, "attack_cd": 2.0, "prefer_dist": 220.0, "contact_sword": true, "sword_dmg": 16.0, "sword_range": 160.0, "special_vfx": "iem_slash", "unlock": 35.0},
	"mech02_elite": {"name": "MS-02D Dust-Vanguard", "chassis": "en02_desert", "hp": 80.0, "speed": 168.0, "dmg": 10.5, "radius": 46.0, "size": 174.0, "motion": "walk", "rank": 1, "w": 5, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 14.0, "attack_cd": 2.8, "prefer_dist": 300.0, "contact_sword": true, "sword_dmg": 17.0, "sword_range": 160.0, "special_vfx": "fire_trail", "unlock": 35.0},
	"mech03_elite": {"name": "MS-03J Jungle-Striker", "chassis": "en03_jungle", "hp": 85.0, "speed": 170.0, "dmg": 11.0, "radius": 46.0, "size": 176.0, "motion": "walk", "rank": 1, "w": 5, "behavior": "ranged", "tir_style": "eventail", "attack_dmg": 7.5, "attack_cd": 2.2, "prefer_dist": 240.0, "contact_sword": true, "sword_dmg": 18.0, "sword_range": 160.0, "special_vfx": "tungsten_slam", "unlock": 35.0},
	"mech04_elite": {"name": "MS-04V Magma-Executioner", "chassis": "en04_volcanic", "hp": 90.0, "speed": 162.0, "dmg": 11.5, "radius": 46.0, "size": 175.0, "motion": "walk", "rank": 1, "w": 5, "behavior": "ranged", "tir_style": "orbe", "attack_dmg": 16.0, "attack_cd": 3.0, "prefer_dist": 250.0, "contact_sword": true, "sword_dmg": 19.0, "sword_range": 165.0, "special_vfx": "magma_wave", "unlock": 35.0},
	"mech05_elite": {"name": "MS-05S Corrosion-Warlord", "chassis": "en05_swamp", "hp": 95.0, "speed": 164.0, "dmg": 12.0, "radius": 46.0, "size": 174.0, "motion": "walk", "rank": 1, "w": 5, "behavior": "ranged", "tir_style": "eventail", "attack_dmg": 8.0, "attack_cd": 2.3, "prefer_dist": 230.0, "contact_sword": true, "sword_dmg": 20.0, "sword_range": 160.0, "special_vfx": "acid_corrosion", "unlock": 35.0},
	"mech06_elite": {"name": "MS-06C Frost-Paladin", "chassis": "en06_cryo", "hp": 100.0, "speed": 166.0, "dmg": 12.5, "radius": 46.0, "size": 176.0, "motion": "walk", "rank": 1, "w": 5, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 15.0, "attack_cd": 2.8, "prefer_dist": 300.0, "contact_sword": true, "sword_dmg": 21.0, "sword_range": 160.0, "special_vfx": "cryo_freeze", "unlock": 35.0},
	"mech07_elite": {"name": "MS-07R Meltdown-Centurion", "chassis": "en07_reacteur", "hp": 105.0, "speed": 168.0, "dmg": 13.0, "radius": 46.0, "size": 172.0, "motion": "walk", "rank": 1, "w": 5, "behavior": "ranged", "tir_style": "guide", "attack_dmg": 9.5, "attack_cd": 2.4, "prefer_dist": 260.0, "contact_sword": true, "sword_dmg": 22.0, "sword_range": 160.0, "special_vfx": "radiation_aura", "unlock": 35.0},
	"mech08_elite": {"name": "MS-08H Cell-Exterminator", "chassis": "en08_ruche", "hp": 110.0, "speed": 172.0, "dmg": 13.5, "radius": 46.0, "size": 174.0, "motion": "walk", "rank": 1, "w": 5, "behavior": "ranged", "tir_style": "rafale", "attack_dmg": 9.0, "attack_cd": 1.9, "prefer_dist": 230.0, "contact_sword": true, "sword_dmg": 23.0, "sword_range": 160.0, "special_vfx": "amber_cleave", "unlock": 35.0},
	"mech09_elite": {"name": "MS-09O Citadel-Dominator", "chassis": "en09_citadelle", "hp": 115.0, "speed": 168.0, "dmg": 14.0, "radius": 46.0, "size": 178.0, "motion": "walk", "rank": 1, "w": 5, "behavior": "ranged", "tir_style": "sniper", "attack_dmg": 18.0, "attack_cd": 2.9, "prefer_dist": 320.0, "contact_sword": true, "sword_dmg": 24.0, "sword_range": 165.0, "special_vfx": "gold_blast", "unlock": 35.0},
	"mech10_elite": {"name": "MS-10A Trench-Colossus", "chassis": "en10_abyss", "hp": 120.0, "speed": 164.0, "dmg": 14.5, "radius": 46.0, "size": 176.0, "motion": "walk", "rank": 1, "w": 5, "behavior": "ranged", "tir_style": "orbe", "attack_dmg": 17.0, "attack_cd": 3.0, "prefer_dist": 260.0, "contact_sword": true, "sword_dmg": 25.0, "sword_range": 160.0, "special_vfx": "hydro_vortex", "unlock": 35.0},
	"mech11_elite": {"name": "MS-11E Spore-Phantom", "chassis": "en11_ether", "hp": 122.0, "speed": 174.0, "dmg": 15.0, "radius": 46.0, "size": 172.0, "motion": "walk", "rank": 1, "w": 5, "behavior": "ranged", "tir_style": "eventail", "attack_dmg": 9.2, "attack_cd": 2.1, "prefer_dist": 240.0, "contact_sword": true, "sword_dmg": 26.0, "sword_range": 160.0, "special_vfx": "uv_rapier", "unlock": 35.0},
	"mech12_elite": {"name": "MS-12T Olympus-Dreadnought", "chassis": "en12_titans", "hp": 130.0, "speed": 160.0, "dmg": 15.5, "radius": 48.0, "size": 182.0, "motion": "walk", "rank": 1, "w": 5, "behavior": "ranged", "tir_style": "orbe", "attack_dmg": 20.0, "attack_cd": 3.2, "prefer_dist": 280.0, "contact_sword": true, "sword_dmg": 28.0, "sword_range": 170.0, "special_vfx": "titan_cleave", "unlock": 35.0},
	"mech13_elite": {"name": "MS-13Z Zero-Interceptor", "chassis": "en13_orbit", "hp": 125.0, "speed": 175.0, "dmg": 16.0, "radius": 46.0, "size": 174.0, "motion": "walk", "rank": 1, "w": 5, "behavior": "ranged", "tir_style": "rafale", "attack_dmg": 10.5, "attack_cd": 2.0, "prefer_dist": 240.0, "contact_sword": true, "sword_dmg": 27.0, "sword_range": 160.0, "special_vfx": "zero_g_dash", "unlock": 35.0},
	"mech14_elite": {"name": "MS-14Q Tesseract-Sentinel", "chassis": "en14_quantum", "hp": 128.0, "speed": 172.0, "dmg": 16.5, "radius": 46.0, "size": 172.0, "motion": "walk", "rank": 1, "w": 5, "behavior": "ranged", "tir_style": "guide", "attack_dmg": 11.0, "attack_cd": 2.4, "prefer_dist": 270.0, "contact_sword": true, "sword_dmg": 28.0, "sword_range": 160.0, "special_vfx": "phase_warp", "unlock": 35.0},
	"mech15_elite": {"name": "MS-15O Thunder-Tempest", "chassis": "en15_ozone", "hp": 130.0, "speed": 170.0, "dmg": 17.0, "radius": 46.0, "size": 174.0, "motion": "walk", "rank": 1, "w": 5, "behavior": "ranged", "tir_style": "rafale", "attack_dmg": 11.5, "attack_cd": 2.1, "prefer_dist": 250.0, "contact_sword": true, "sword_dmg": 29.0, "sword_range": 160.0, "special_vfx": "arc_lightning", "unlock": 35.0},
	"mech16_elite": {"name": "MS-16P Refraction-Avenger", "chassis": "en16_prism", "hp": 132.0, "speed": 168.0, "dmg": 17.5, "radius": 46.0, "size": 176.0, "motion": "walk", "rank": 1, "w": 5, "behavior": "ranged", "tir_style": "eventail", "attack_dmg": 10.0, "attack_cd": 2.2, "prefer_dist": 260.0, "contact_sword": true, "sword_dmg": 30.0, "sword_range": 160.0, "special_vfx": "prismatic_burst", "unlock": 35.0},
	"mech17_elite": {"name": "MS-17B Dread-Warhammer", "chassis": "en17_steampunk", "hp": 135.0, "speed": 165.0, "dmg": 18.0, "radius": 48.0, "size": 180.0, "motion": "walk", "rank": 1, "w": 5, "behavior": "ranged", "tir_style": "orbe", "attack_dmg": 19.0, "attack_cd": 3.1, "prefer_dist": 270.0, "contact_sword": true, "sword_dmg": 31.0, "sword_range": 165.0, "special_vfx": "steam_burst", "unlock": 35.0},
	"mech18_elite": {"name": "MS-18C Arena-Champion", "chassis": "en18_colosseum", "hp": 140.0, "speed": 172.0, "dmg": 18.5, "radius": 48.0, "size": 182.0, "motion": "walk", "rank": 1, "w": 5, "behavior": "ranged", "tir_style": "rafale", "attack_dmg": 12.0, "attack_cd": 1.9, "prefer_dist": 240.0, "contact_sword": true, "sword_dmg": 32.0, "sword_range": 170.0, "special_vfx": "arena_execution", "unlock": 35.0},
}

const BOSS_PHASE_THRESHOLDS: Dictionary = {
	# 2 seuils -> la phase 3 (idx==2) est atteignable ; le defaut [0.5] (un seul seuil) ne
	# l'atteindrait jamais, cf. _check_boss_phase() dans Enemy.gd.
	"cryoboss": [0.5, 0.2],
	"reacteurboss": [0.5, 0.2],
	"rucheboss": [0.5, 0.2],
	"citadelleboss": [0.5, 0.2],
}

# 19/10 : Escouades tripartites + Méchas Élites Supérieurs par biome
const BIOME_POOL: Dictionary = {
	"earth": [], "spaceship": [], "ice": [], "ruines": [],
	"tech": ["mech01", "mech01_swarm", "mech01_shield", "mech01_sniper", "mech01_elite"],
	"desert": ["mech02", "mech02_swarm", "mech02_shield", "mech02_sniper", "mech02_elite"],
	"jungle": ["mech03", "mech03_swarm", "mech03_shield", "mech03_sniper", "mech03_elite"],
	"volcanic": ["mech04", "mech04_swarm", "mech04_shield", "mech04_sniper", "mech04_elite"],
	"swamp": ["mech05", "mech05_swarm", "mech05_shield", "mech05_sniper", "mech05_elite"],
	"cryo": ["mech06", "mech06_swarm", "mech06_shield", "mech06_sniper", "mech06_elite"],
	"reacteur": ["mech07", "mech07_swarm", "mech07_shield", "mech07_sniper", "mech07_elite"],
	"ruche": ["mech08", "mech08_swarm", "mech08_shield", "mech08_sniper", "mech08_elite"],
	"citadelle": ["mech09", "mech09_swarm", "mech09_shield", "mech09_sniper", "mech09_elite"],
	"abyss": ["mech10", "mech10_swarm", "mech10_shield", "mech10_sniper", "mech10_elite"],
	"ether": ["mech11", "mech11_swarm", "mech11_shield", "mech11_sniper", "mech11_elite"],
	"titans": ["mech12", "mech12_swarm", "mech12_shield", "mech12_sniper", "mech12_elite"],
	"orbit": ["mech13", "mech13_swarm", "mech13_shield", "mech13_sniper", "mech13_elite"],
	"quantum": ["mech14", "mech14_swarm", "mech14_shield", "mech14_sniper", "mech14_elite"],
	"ozone": ["mech15", "mech15_swarm", "mech15_shield", "mech15_sniper", "mech15_elite"],
	"prism": ["mech16", "mech16_swarm", "mech16_shield", "mech16_sniper", "mech16_elite"],
	"steampunk": ["mech17", "mech17_swarm", "mech17_shield", "mech17_sniper", "mech17_elite"],
	"colosseum": ["mech18", "mech18_swarm", "mech18_shield", "mech18_sniper", "mech18_elite"],
}

# CORRUPTION visuelle par biome : teinte multiplicative sur CHAQUE ennemi (self_modulate). Subtile.
const BIOME_TINT: Dictionary = {
	"tech":      Color(0.82, 0.92, 1.10),
	"earth":     Color(1.10, 0.92, 0.70),
	"spaceship": Color(0.90, 0.88, 1.14),
	"volcanic":  Color(0.85, 1.05, 1.20),
	"desert":    Color(1.16, 1.00, 0.68),
	"ice":       Color(0.74, 0.94, 1.18),
	"jungle":    Color(0.76, 1.14, 0.74),
	"swamp":     Color(0.86, 1.04, 0.68),
	"ruines":    Color(1.08, 0.90, 0.78),
	"cryo":      Color(0.80, 0.94, 1.15),
	"reacteur":  Color(0.80, 1.10, 0.75),
	"ruche":     Color(1.05, 0.80, 1.10),
	"citadelle": Color(1.15, 1.05, 0.75),
	"abyss":     Color(0.65, 0.95, 1.20),
	"ether":     Color(0.85, 0.65, 1.15),
	"titans":    Color(1.15, 0.85, 0.65),
	"orbit":     Color(0.80, 0.95, 1.15),
	"quantum":   Color(1.10, 1.05, 0.70),
	"ozone":     Color(1.10, 0.70, 1.15),
	"prism":     Color(0.95, 1.10, 1.15),
	"steampunk": Color(1.15, 0.90, 0.70),
	"colosseum": Color(0.90, 1.05, 1.10),
}

# Timed run structure: bosses at 5 min (build filter), 10 min, 15 min (final -> victory).
# Matches Survivor.io's chapter 1 beats exactly (boss 5:00, boss ~10:00, final boss 15:00).
# 🚨 Plan direction artistique (26/09) : "chaque environnement devrait avoir un boss qui
# reutilise ses materiaux et ses mecaniques" — jusqu'ici les 5min/10min etaient FIXES
# (midboss/crusherboss) quel que soit le biome. Les slots 0/1 sont maintenant resolus par
# _mid_boss_for() ci-dessous, qui fait tourner 4 chassis mi-boss existants (dont midboss_a/
# midboss_b, "Le Bombardier"/"Le Devastateur" — voir le commentaire au-dessus des DEFS : ils
# n'etaient cables NULLE PART, "pas un bug, un choix produit non tranche" ; le choix est fait).
# endboss (Souverain) reste universel a 15 min : boss FINAL de victoire, deja lie au chapitre 5
# "La Cite Dechue" par son propre nom — pas un boss de zone comme les deux autres.
const BOSS_SCHEDULE: Array = [
	{"t": 300.0, "slot": 0},           # 5 min : mi-boss n°1, depend du biome
	{"t": 600.0, "slot": 1},           # 10 min : mi-boss n°2, depend du biome (toujours != n°1)
	{"t": 900.0, "kind": "endboss"},   # 15 min : SOUVERAIN (boss final = victoire, obsidienne)
]
var _bosses_fired: int = 0
const BIOME_ORDER: Array = ["tech", "earth", "spaceship", "volcanic", "desert", "ice", "jungle", "swamp", "cryo", "reacteur", "ruche", "citadelle", "abyss", "ether", "titans", "orbit", "quantum", "ozone", "prism", "steampunk", "colosseum"]
const MID_BOSSES: Array = ["midboss", "midboss_a", "crusherboss", "midboss_b"]
func _mid_boss_for(offset: int) -> String:
	var bi: int = maxi(0, BIOME_ORDER.find(current_biome))
	return String(MID_BOSSES[(bi + offset) % MID_BOSSES.size()])

# 03/10, "5 arenes de boss" (plan "15 maps") : certains chapitres remplacent le Souverain
# universel par LEUR propre cloture a 15 min. Chapitre 1 = BELIER-01 (27/09, deja en prod) ;
# chapitres 6-9 = les 4 nouveaux boss de biome. Dict + fonction pure plutot qu'un "if" par
# chapitre : testable directement, sans faire tourner 900s d'horloge de run.
const CHAPTER_FINAL_BOSS: Dictionary = {
	1: "belier01", 6: "cryoboss", 7: "reacteurboss", 8: "rucheboss", 9: "citadelleboss",
}
## Quel "kind" remplace "endboss" pour ce chapitre (ou "endboss" lui-meme si ce chapitre n'a pas
## de cloture dediee, ou si SANS FIN est actif - meme garde qu'avant, jamais de boss de campagne
## en SANS FIN).
func _final_boss_for(chapter_n: int, endless: bool) -> String:
	if endless or not CHAPTER_FINAL_BOSS.has(chapter_n):
		return "endboss"
	return String(CHAPTER_FINAL_BOSS[chapter_n])
# SANS FIN: once the scheduled bosses are spent, endbosses keep coming on this cadence forever.
const ENDLESS_BOSS_INTERVAL: float = 210.0
var _endless_next_boss: float = 0.0
## Regression-test only (`-- --fast-bosses`): compresses the boss clock so an automated run can
## actually reach the endboss and the SANS FIN waves after it, instead of needing 15 real minutes.
@onready var _boss_scale: float = 0.02 if OS.get_cmdline_user_args().has("--fast-bosses") else 1.0

# Scripted ELITE events: a single tanky foe announced as an event, between the bosses — the
# "an elite monster will come, stronger than normal units, takes longer to kill" beat at 3:00
# and 12:00. Distinct from the rare intermediates that trickle out of the random pool.
const ELITE_SCHEDULE: Array = [
	{"t": 25.0, "kind": "elite"},
	{"t": 180.0, "kind": "crusher"},
	{"t": 720.0, "kind": "warden"},
]
var _elites_fired: int = 0

# PHASE 1 — murs soft. Fenetres inclusives a gauche, exclusives a droite : [180,200) et [480,500).
# Le plancher multiplie est floor_pop APRES la grace existante (ligne mini(..., 2+3*grace)).
# Tant que _t ou run_time < 18 s, aucune fenetre ne s'applique, meme si les bornes changent.
const SOFT_WALLS: Array[Vector2] = [Vector2(180.0, 200.0), Vector2(300.0, 318.0), Vector2(480.0, 500.0), Vector2(690.0, 710.0)]   # v12.15 : 1er encerclement a 1:10
const SOFT_WALL_MULT: float = 1.6
const SOFT_WALL_GRACE: float = 18.0
var _soft_wall_squad_done: Dictionary = {}

# Phase 2 — kami / summoner. Hors BIOME_POOL (les 5 slots d'escouade restent intacts).
var _p2_ready: bool = false
var PHASE2_DEFS: Dictionary = {}
var PHASE2_EXTRA: Dictionary = {}

func _ensure_phase2() -> void:
	if _p2_ready:
		return
	_p2_ready = true
	for biome in BIOME_POOL.keys():
		var pool: Array = BIOME_POOL[biome]
		if pool.size() < 2:
			continue
		var base_id: String = String(pool[0])
		if not DEFS.has(base_id):
			continue
		var base: Dictionary = DEFS[base_id]
		var kami_id: String = base_id + "_kami"
		var sum_id: String = base_id + "_summoner"
		var kami: Dictionary = base.duplicate()
		kami["name"] = String(base.get("name", "Kami")) + " Kamikaze"
		kami["behavior"] = "kami"
		kami["hp"] = float(base.get("hp", 20.0)) * 0.70
		kami["speed"] = float(base.get("speed", 170.0)) * 1.45
		kami["w"] = 3
		kami["rank"] = 0
		kami["unlock"] = 40.0
		kami["radius"] = float(base.get("radius", 40.0)) * 0.85
		kami["attack_dmg"] = float(base.get("attack_dmg", 8.0)) * 1.4
		kami["bull"] = false
		kami["archetype"] = "kami"
		var summoner: Dictionary = base.duplicate()
		summoner["name"] = String(base.get("name", "Invocateur")) + " Invocateur"
		summoner["behavior"] = "summoner"
		summoner["hp"] = float(base.get("hp", 20.0)) * 1.60
		summoner["speed"] = float(base.get("speed", 170.0)) * 0.85
		summoner["w"] = 2
		summoner["rank"] = 0
		summoner["unlock"] = 70.0
		summoner["prefer_dist"] = 320.0
		summoner["attack_cd"] = 2.4
		summoner["summon_kind"] = String(pool[1])
		summoner["bull"] = false
		summoner["archetype"] = "summoner"
		# DIVERSITE (29/10) : ARTILLEUR (mortier telegraphie, EnemyDiv) et REPARATEUR (comportement "healer" existant)
		var art_id: String = base_id + "_artillery"
		var rep_id: String = base_id + "_repair"
		var art: Dictionary = base.duplicate()
		art["name"] = String(base.get("name", "Artilleur")) + " Artilleur"
		art["role"] = "artilleur"
		art["behavior"] = "ranged"
		art["hp"] = float(base.get("hp", 20.0)) * 1.25
		art["speed"] = float(base.get("speed", 170.0)) * 0.8
		art["w"] = 3
		art["rank"] = 0
		art["unlock"] = 45.0
		art["prefer_dist"] = 430.0
		art["attack_cd"] = 999.0
		art["tir_style"] = ""
		art["bull"] = false
		art["archetype"] = "artillery"
		var repd: Dictionary = base.duplicate()
		repd["name"] = String(base.get("name", "Reparateur")) + " Reparateur"
		repd["role"] = "reparateur"
		repd["behavior"] = "healer"
		repd["hp"] = float(base.get("hp", 20.0)) * 1.1
		repd["speed"] = float(base.get("speed", 170.0)) * 0.9
		repd["w"] = 2
		repd["rank"] = 0
		repd["unlock"] = 75.0
		repd["prefer_dist"] = 300.0
		repd["bull"] = false
		repd["archetype"] = "repair"
		PHASE2_DEFS[kami_id] = kami
		PHASE2_DEFS[sum_id] = summoner
		PHASE2_DEFS[art_id] = art
		PHASE2_DEFS[rep_id] = repd
		# 30/10 (patron : ? supprime les ennemis qui n'ont pas ete rigues ?) : kamikaze / invocateur / artilleur / reparateur
		# n'ont pas de modele rigge propre (planches empruntees) -> retires des apparitions. Definitions gardees (reactivables).
		PHASE2_EXTRA[String(biome)] = []

func _has_def(k: String) -> bool:
	_ensure_phase2()
	return DEFS.has(k) or PHASE2_DEFS.has(k)

func _raw(k: String) -> Dictionary:
	_ensure_phase2()
	if DEFS.has(k):
		return DEFS[k]
	return PHASE2_DEFS.get(k, {})

func spawn_spiral_squad() -> bool:
	return _spawn_squad(true, "spirale")

## DIVERSITE (29/10) : palier courant = bloc du chapitre (rang du biome dans PROFILES) + difficulte, cf. EnemyDiv.
func _sync_div() -> int:
	EnemyDiv.cur_chapter = int((PROFILES.get(current_biome, {}) as Dictionary).get("tier", chapter))
	return EnemyDiv.tier()

func _process(delta: float) -> void:
	if not GameState.alive:
		return
	_ensure_phase2()
	_sync_div()
	_drain_wave()   # spread a queued horde over frames (no spawn hitch)
	_ak_tick(delta)   # 31/10 ANTI-FUITE : vitesse moyenne, detection de fuite, interception
	_squad_tick(delta)
	_t += delta
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		# swarm cadence: already dense at the start, ramps to a heavy horde (weak foes -> OK)
		var rate: float = clampf(0.82 - _t * 0.0016, 0.15, 0.82)
		# --- PRESSION DE FOND ----------------------------------------------------------
		# 🚨 MESURE DU TESTEUR SENSATIONS : sur 125 captures d'une partie de 3:11, « 65 % des
		# images sont quasi vides et 4 % montrent un mur de 55 ennemis ». Ecran totalement
		# vide a 00:16, a 00:25 et encore a 03:06 — puis 55 ennemis 5 secondes plus tard.
		# On passe du desert au mur sans plateau. Cause : la cadence de fond est FIXE, donc
		# des que le joueur tue plus vite qu'elle ne produit, l'ecran se vide et plus rien
		# ne le remplit avant la vague suivante (50 s d'intervalle).
		# Correctif : un PLANCHER de population vivante qui monte avec le temps. Tant qu'on
		# est sous ce plancher, la cadence s'accelere (jusqu'a x4) ; des qu'il est atteint,
		# on retombe exactement sur l'ancien comportement. Les pics de vague sont conserves.
		var live: int = get_tree().get_nodes_in_group("enemies").size()
		var floor_pop: int = clampi(5 + int(_t / 22.0) + int(maxf(0.0, _t - 200.0) / 40.0), 5, 34)   # v12.15 : 5+t/22 (max 24) -> 6+t/20 (max 28)
		# 🚨 Rapport de test Manus (26/09, P0) : « mort possible en 20-30s des la difficulte
		# Facile » — le plancher etait deja a 5 des t=0, et le rattrapage pouvait multiplier la
		# cadence par x4 ; un joueur qui n'a pas encore appris le deplacement encaisse la pleine
		# pression avant d'avoir compris les controles. GRACE adoucit plancher ET rattrapage
		# pendant les 18 premieres secondes de CHAQUE partie, puis s'efface completement —
		# aucun effet passe ce cap, ni sur la vague scriptee (38s), ni sur le sans-fin.
		var grace: float = clampf(_t / 18.0, 0.0, 1.0)   # v12.15 : grace 18 s -> 12 s
		floor_pop = clampi(mini(floor_pop, 2 + int(4.0 * grace)), 2, 34)
		floor_pop = _apply_soft_wall_pressure(floor_pop)
		if live < floor_pop:
			var deficit: float = float(floor_pop - live) / float(floor_pop)
			rate /= (1.0 + 3.0 * deficit * lerpf(0.4, 1.0, grace))
		# 🚨 Rapport Manus (26/09, session suivante) : mort a 12-23s CONFIRMEE, MALGRE le
		# correctif ci-dessus — celui-ci n'adoucissait que le rattrapage de population, pas le
		# reste du calcul. Or un biome (Jungle "nuees denses" = spawn_mult 1.35) ou une
		# combinaison de Protocoles (jusqu'a spawn_rate 2.4, cf. Protocols.gd) multiplient CE
		# diviseur directement, des t=0, sans jamais passer par le rattrapage — pour un nouveau
		# joueur qui tombe sur cette combinaison au tout premier essai, la grace precedente
		# n'avait donc pratiquement aucun effet. Meme fenetre de 18s, mais elle plafonne
		# maintenant le produit ENTIER (biome x difficulte x protocoles) a 1.0 au depart (jamais
		# pire qu'un rythme normal), puis le laisse remonter jusqu'a sa vraie valeur.
		var full_mult: float = spawn_mult * float(GameState.diff().get("spawn", 1.0)) * Protocols.spawn_rate
		var eff_mult: float = lerpf(minf(1.0, full_mult), full_mult, grace)
		_spawn_t = rate / maxf(0.2, eff_mult * (1.25 + 0.025 * float(int((PROFILES.get(current_biome, {}) as Dictionary).get("tier", 1)) - 1)) * _phase_rate())
		_spawn()
	if _bosses_fired < BOSS_SCHEDULE.size() and GameState.run_time >= float(BOSS_SCHEDULE[_bosses_fired]["t"]) * _boss_scale:
		if not _boss_alive():   # never let two bosses coexist -> avoids double next_map in one frame
			var sched: Dictionary = BOSS_SCHEDULE[_bosses_fired]
			var kind: String = String(sched["kind"]) if sched.has("kind") else _mid_boss_for(int(sched["slot"]) * 2)
			# BELIER-01/boss de biome (03/10, generalise depuis le seul "chapitre 1 -> belier01"
			# du 27/09) : certains chapitres recoivent LEUR propre cloture a 15 min au lieu du
			# Souverain universel. Garde SANS FIN indispensable : ce mode ne fixe jamais `chapter`
			# (reste a 1 par defaut) -> sans elle, une run SANS FIN spawnerait un boss de campagne
			# comme-final ici au lieu de l'endboss RECURRENT attendu plus bas.
			if kind == "endboss":
				kind = _final_boss_for(chapter, GameState.endless)
			_spawn_boss(kind, _bosses_fired == 0)
			_bosses_fired += 1
	elif GameState.endless and _bosses_fired >= BOSS_SCHEDULE.size():
		# schedule the first endless boss relative to when the scripted run ran out, not to t=0
		if _endless_next_boss <= 0.0:
			_endless_next_boss = GameState.run_time + ENDLESS_BOSS_INTERVAL * _boss_scale
		elif GameState.run_time >= _endless_next_boss and not _boss_alive():
			_spawn_boss("endboss")
			_endless_next_boss = GameState.run_time + ENDLESS_BOSS_INTERVAL * _boss_scale
	if _elites_fired < ELITE_SCHEDULE.size() and GameState.run_time >= float(ELITE_SCHEDULE[_elites_fired]["t"]):
		_spawn_elite(String(ELITE_SCHEDULE[_elites_fired]["kind"]))
		_elites_fired += 1
	_wave_t -= delta
	if _wave_t <= 0.0:
		_wave_t = WAVE_INTERVAL
		_spawn_wave()
	_pulse_soft_wall_squad()

## Hold off spawning for `s` seconds (used by the run-start teleport intro).
func delay_spawns(s: float) -> void:
	_spawn_t = maxf(_spawn_t, s)

# Pending wave members, drained a few per frame by _drain_wave() so a 50-strong horde never
# builds in a single frame. Cleared implicitly as it drains.
var _wave_queue: Array = []
const WAVE_PER_FRAME: int = 4      # ~50 foes spread over ~12 frames (0.2s) instead of 1

func _drain_wave() -> void:
	if _wave_queue.is_empty() or player == null or not is_instance_valid(player):
		return
	var budget: int = WAVE_PER_FRAME
	while budget > 0 and not _wave_queue.is_empty():
		if get_tree().get_nodes_in_group("enemies").size() >= ENEMY_CAP:
			_wave_queue.clear()   # cap reached mid-drain: drop the rest, don't queue forever
			return
		budget -= 1
		var w: Dictionary = _wave_queue.pop_front()
		var kind: String = String(w["kind"])
		if not _has_def(kind):
			continue
		var e: Enemy = Enemy.new()
		e.global_position = player.global_position + Vector2(cos(w["ang"]), sin(w["ang"])) * float(w["dist"])
		game.enemy_layer.add_child(e)
		e.setup(kind, _def_for(kind), player, game)
		_scale_enemy(e)

## Spawn one specific enemy at an exact spot (used by the robot carcass awakening).
## Scaled like any other foe so a late-run carcass stays a real threat.
## 30/10 : Rodeur/Guepe/Belier (u_rodeur/u_guepe/u_belier) sont des planches FIXES (pas de rig). Les balises et
## epaves qui les appelaient font maintenant apparaitre l'ennemi RIGGE du chapitre (base ou essaim).
const NON_RIGGED_REDIRECT: Dictionary = {"brute": 0, "drone": 1, "quadshell": 0}
func _rigged_kind(kind: String) -> String:
	if not NON_RIGGED_REDIRECT.has(kind):
		return kind
	var pool: Array = BIOME_POOL.get(current_biome, [])
	if pool.is_empty():
		pool = BIOME_POOL["tech"]
	return String(pool[mini(int(NON_RIGGED_REDIRECT[kind]), pool.size() - 1)])

## v12.19 : la carte est bornee (ArenaWall.MAP_R) -> aucune apparition hors carte.
func _in_map(pos: Vector2) -> Vector2:
	if game != null and game.get("arena_wall") != null and game.arena_wall.active and game.arena_wall.has_method("clamp_to_map"):
		return game.arena_wall.clamp_to_map(pos, 80.0)
	return pos

func spawn_kind_at(kind: String, pos: Vector2) -> Enemy:
	kind = _rigged_kind(kind)
	if not _has_def(kind) or player == null or not is_instance_valid(player):
		return null
	_sync_div()
	var e: Enemy = Enemy.new()
	e.global_position = _in_map(pos)
	game.enemy_layer.add_child(e)
	var def: Dictionary = _def_for(kind) if PHASE2_DEFS.has(kind) else DEFS[kind]
	e.setup(kind, def, player, game)
	_scale_enemy(e)
	return e

## Scripted elite event (Survivor.io beat at 3:00 / 12:00): ONE tanky foe, announced, beefed up
## over its pool version so it reads as a named threat rather than another intermediate.
func _spawn_elite(kind: String) -> void:
	# Biome-aware: pick a rank>=1 specialist from THIS biome's pool (the schedule's old hard-coded
	# names are gone). Falls back to the passed kind if the pool has no elite.
	var pool: Array = BIOME_POOL.get(current_biome, [])
	var elites: Array = []
	for k in pool:
		if DEFS.has(k) and int(DEFS[k].get("rank", 0)) >= 1 and int(DEFS[k].get("w", 0)) > 0:
			elites.append(k)
	if not elites.is_empty():
		kind = String(elites[randi() % elites.size()])
	var e: Enemy = spawn_kind_at(kind, Vector2.ZERO)
	if e == null:
		return
	var ang: float = randf() * TAU
	e.global_position = player.global_position + Vector2(cos(ang), sin(ang)) * 680.0
	e.hp_max *= 2.4          # "takes longer to kill" — a real speed bump between bosses
	e.hp = e.hp_max
	e.contact_dmg *= 1.2
	e.set_meta("phase1_elite", true)   # drop rare Phase 1 a la mort (GameState.roll_phase1_drop)
	EnemyDiv.make_elite(e)             # pouvoir de biome (plus de surcouche visuelle)
	if game != null and game.has_method("spawn_vfx"):
		game.spawn_vfx("shockwave", e.global_position, 0.0, 2.2, Color(1.0, 0.7, 0.3))
	if game != null and game.has_method("show_banner"):
		game.show_banner("!  ELITE  !", Color(1.0, 0.75, 0.35))
	Audio.sfx("boss", 0.1)

func _spawn_boss(kind: String, mastery_clock: bool = false) -> void:
	if not DEFS.has(kind):
		return
	if player == null or not is_instance_valid(player):
		return
	print("[game] BOSS kind=%s chapter=%d endless=%s final=%s t=%.1f" % [
		kind, chapter, str(GameState.endless), str(bool(DEFS[kind].get("final", false))), GameState.run_time])
	var e: Enemy = Enemy.new()
	var ang: float = randf() * TAU
	e.global_position = player.global_position + Vector2(cos(ang), sin(ang)) * 760.0
	game.enemy_layer.add_child(e)
	e.setup(kind, DEFS[kind], player, game)
	_scale_enemy(e)   # bosses scale with run time + cleared-zone bonus + difficulty, like the trash
	if mastery_clock:
		e.set_meta("mastery_boss5", true)
		GameState.mastery_boss5_active = true
		GameState.mastery_boss5_clean = true
		GameState.mastery_boss5_ok = false
	if game != null and game.has_method("spawn_vfx"):
		game.spawn_vfx("shockwave", e.global_position, 0.0, 3.0, Color(1.0, 0.5, 0.4))   # menacing arrival ring
	if game != null:
		if game.has_method("show_horde_warning"):
			game.show_horde_warning("🚨 MENACE COLOSSALE EN APPROCHE 🚨", "Alerte rouge : Boss détecté !")
		elif game.has_method("show_banner"):
			game.show_banner("!  MENACE MAJEURE  !", Color(1.0, 0.4, 0.3))
	Audio.sfx("boss")
	Audio.music("boss")

func _boss_alive() -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and (e as Enemy).alive and int((e as Enemy).rank) >= 3:
			return true
	return false

func _kind_unlocked(k: String, t: float) -> bool:
	# Survivor.io-style STAGED introduction: each archetype has its own entry time (see DEFS),
	# so the player meets one new threat at a time instead of all of them at 0:00.
	return t >= float(_raw(k).get("unlock", 0.0))

func _weighted_pick(fodder_only: bool = false) -> String:
	var t: float = GameState.run_time
	var picks: Array = []
	var total: int = 0
	var pool: Array = BIOME_POOL.get(current_biome, [])   # filtre PAR BIOME
	var dtier: int = _sync_div()
	for k in pool:
		if not DEFS.has(k):
			continue
		if not EnemyDiv.kind_allowed(String(k), DEFS[k], dtier):
			continue                       # DIVERSITE : les roles presents suivent le palier
		var w: int = int(DEFS[k]["w"])
		if w <= 0:
			continue                       # bosses (spawned on schedule, not here)
		if fodder_only and int(DEFS[k]["rank"]) > 0:
			continue                       # massive waves = the weak swarm only (no tanky intermediates)
		if not _kind_unlocked(k, t):
			continue
		picks.append([k, w]); total += w
	_ensure_phase2()
	for k2 in PHASE2_EXTRA.get(current_biome, []):
		var id2: String = String(k2)
		if not PHASE2_DEFS.has(id2):
			continue
		var d2: Dictionary = PHASE2_DEFS[id2]
		var w2: int = int(d2.get("w", 0))
		if w2 <= 0:
			continue
		if fodder_only and String(d2.get("archetype", "")) in ["summoner", "repair"]:
			continue
		if not EnemyDiv.kind_allowed(id2, d2, dtier):
			continue
		if not _kind_unlocked(id2, t):
			continue
		picks.append([id2, w2])
		total += w2
	if picks.is_empty():
		return ""                          # aucun ennemi defini/debloque -> rien a piocher
	var r: int = randi() % maxi(1, total)
	for pw in picks:
		r -= int(pw[1])
		if r < 0:
			return String(pw[0])
	return String(picks[0][0])

## Where a fresh enemy appears, relative to the player.
##
## THE POINT: spawning on a uniform ring meant a straight-line retreat was free forever — you
## simply outran the ring and everything trailed behind you in a queue. Now, while the player is
## actually fleeing, most spawns land in an arc AHEAD of their movement, so retreating walks you
## INTO the new wave. Standing and fighting keeps the old even ring.
## Reversing direction is still an out, which is exactly the decision we want to force.
const SPAWN_R: float = 640.0
const FLEE_SPEED: float = 240.0     # above this the player is running, not repositioning
const AHEAD_SHARE: float = 0.62     # share of spawns placed in the flight arc
const AHEAD_ARC: float = 1.15       # half-width of that arc (rad) — a wall, not a single point
func _spawn_offset() -> Vector2:
	# 31/10 : la regle « devant la fuite » (62 % a > 240 px/s instantane) est remplacee par la couche
	# generique AK_AHEAD_SHARE de _spawn() (vitesse MOYENNE sur ~2 s, tous motifs, juste hors ecran).
	if not AK_ON and "velocity" in player and (player.velocity as Vector2).length() > FLEE_SPEED and randf() < AHEAD_SHARE:
		var a0: float = (player.velocity as Vector2).angle() + randf_range(-AHEAD_ARC, AHEAD_ARC)
		return Vector2(cos(a0), sin(a0)) * SPAWN_R
	var ang: float = randf() * TAU
	return Vector2(cos(ang), sin(ang)) * SPAWN_R

## >>> PROFILS DE NIVEAU (21/10, patron : « une strategie d'apparition ET de combat par ennemi de base, plus dure a chaque niveau, mais pas impossible »)
## Chaque niveau a : un MOTIF d'apparition (ou/comment ils arrivent), un ROLE principal et un role secondaire (part `share`).
## Le rang `tier` (1..18) durcit : cadence +2 %/niveau, tirs plus rapides, boucliers plus epais, plus de roles speciaux
## simultanes. GARDE-FOUS (jamais impossible) : vitesse <= 80 % du joueur (cf. _scale_enemy), plafond de roles speciaux
## vivants (_special_cap), ENEMY_CAP, et aucun motif ne pose un ennemi a moins de ~420 px du joueur.
##   motifs : ring anneau regulier | ahead mur devant la fuite | pincer deux flancs | ambush grappe d'un cote
##            line rangee tangente | burst petites salves serrees | close anneau serre | encircle 4 points tournants
##            dropin proche mais rare | gates deux portes cardinales | fan trois eventails | sandwich devant/derriere
##   roles  : tir | charge (dasher) | mine (zones au sol) | kamikaze | bull (melee a charge) | blinde (bouclier) | lourd | barrage
const PROFILES: Dictionary = {
	"tech":      {"tier": 1, "forms": ["ligne","colonne","tenaille","encerclement"],  "pat": "ring",     "main": ["tir"],              "alt": ["rafale", "zigzag"],    "share": 0.08},   # v12.15 : plus de profil « tir seul »
	"desert":    {"tier": 2, "forms": ["tenaille","colonne","ligne"],  "pat": "pincer",   "main": ["charge", "esquive"],           "alt": ["tir", "rafale"],              "share": 0.20},
	"jungle":    {"tier": 3, "forms": ["embuscade","tirailleurs"],  "pat": "ambush",   "main": ["eventail"],              "alt": ["bull", "garde"],             "share": 0.25},
	"volcanic":  {"tier": 4, "forms": ["coin","feu_et_mouvement"],  "pat": "ahead",    "main": ["mine", "esquive"],             "alt": ["orbe"],              "share": 0.25},
	"swamp":     {"tier": 5, "forms": ["colonne","fer_a_cheval"],  "pat": "pincer",   "main": ["tir", "garde"],             "alt": ["bull", "mine"],             "share": 0.25},
	"cryo":      {"tier": 6, "forms": ["ligne","vague","tirailleurs"],  "pat": "line",     "main": ["sniper", "blinde", "garde"], "alt": ["charge"],       "share": 0.25},
	"reacteur":  {"tier": 7, "forms": ["coin","vague","embuscade"],  "pat": "burst",    "main": ["kamikaze", "esquive"],         "alt": ["anneau"],              "share": 0.30},
	"ruche":     {"tier": 8, "forms": ["encerclement","vague"],  "pat": "burst",    "main": ["rafale", "esquive"],           "alt": ["bull", "garde"],              "share": 0.25},
	"citadelle": {"tier": 9, "forms": ["vague","echelon","feu_et_mouvement"],  "pat": "pincer",   "main": ["tir", "blinde", "lourd", "garde"], "alt": ["tir", "protecteur"], "share": 0.25},
	"abyss":     {"tier": 10, "forms": ["encerclement","spirale","fer_a_cheval"], "pat": "encircle", "main": ["guide", "garde"],     "alt": ["charge", "esquive"],           "share": 0.25},
	"ether":     {"tier": 11, "forms": ["leurre","embuscade","tenaille"], "pat": "dropin",   "main": ["charge", "esquive"],           "alt": ["kamikaze"],         "share": 0.20},
	"titans":    {"tier": 12, "forms": ["coin","echelon","ligne"], "pat": "ahead",    "main": ["mine", "blinde", "garde"], "alt": ["orbe", "protecteur"],       "share": 0.25},
	"orbit":     {"tier": 13, "forms": ["spirale","feu_et_mouvement","encerclement"], "pat": "fan",      "main": ["tir", "barrage", "esquive"],   "alt": ["charge"],           "share": 0.30},
	"quantum":   {"tier": 14, "forms": ["tenaille","leurre","encerclement"], "pat": "sandwich", "main": ["kamikaze", "esquive"],         "alt": ["sniper", "blinde", "garde"], "share": 0.35},
	"ozone":     {"tier": 15, "forms": ["echelon","tenaille","tirailleurs"], "pat": "line",     "main": ["charge", "esquive"],           "alt": ["rafale", "garde"],   "share": 0.30},
	"prism":     {"tier": 16, "forms": ["fer_a_cheval","feu_et_mouvement","spirale"], "pat": "fan",      "main": ["eventail", "blinde", "garde"], "alt": ["tir", "protecteur"],   "share": 0.30},
	"steampunk": {"tier": 17, "forms": ["vague","tenaille","echelon","fer_a_cheval"], "pat": "sandwich", "main": ["mine", "blinde", "garde"], "alt": ["tir", "protecteur"],     "share": 0.35},
	"colosseum": {"tier": 18, "forms": ["encerclement","tenaille","leurre","vague","feu_et_mouvement","spirale"], "pat": "gates",    "main": ["anneau", "blinde", "garde"], "alt": ["charge", "kamikaze", "rafale"], "share": 0.40},
}
## PHASES DE NIVEAU (lecons opensurvivor « wave_profiles » + survivor-td « enemyPool par minute ») : 4 phases annoncees par un
## bandeau, qui ajustent la part du role secondaire, la cadence d'apparition et la chance d'elite. Debut a 60 % de la part
## nominale (avant : constante), fin a 150 % : un niveau monte en pression au lieu de rester plat.
const PHASES: Array = [
	{"t": 0.0,   "label": "PRISE DE CONTACT",     "share": 0.6, "rate": 1.00, "elite": 1.0},
	{"t": 60.0,  "label": "PRESSION MONTANTE",    "share": 0.9, "rate": 1.05, "elite": 1.2},
	{"t": 180.0, "label": "MENACE D'ELITE",       "share": 1.2, "rate": 1.15, "elite": 1.6},
	{"t": 360.0, "label": "COTE D'ALERTE",        "share": 1.5, "rate": 1.30, "elite": 2.0},
]
var _phase_idx: int = -1
func _phase() -> Dictionary:
	var t: float = GameState.run_time
	var k: int = 0
	for i in PHASES.size():
		if t >= float(PHASES[i]["t"]):
			k = i
	return PHASES[k]
func _phase_rate() -> float:
	return float(_phase()["rate"]) * (0.6 if _boss_up() else 1.0)
var _prof_defs: Dictionary = {}     # cache (biome|tier|alt) -> def fusionne
var _pat_n: int = 0
var _anchor: float = 0.0
var _anchor_t: float = -99.0

## Plafond de roles « speciaux » (charge/kamikaze/mine) vivants en meme temps : 4 au niveau 1 -> 8 au 18.
func _special_cap(tier: int) -> int:
	return 4 + tier / 4

func _is_special(d: Dictionary) -> bool:
	var b: String = String(d.get("behavior", ""))
	return b == "dasher" or b == "kamikaze" or b == "miner" or b == "rush" or bool(d.get("bull", false))

func _role_def(kind: String, flags: Array, tier: int) -> Dictionary:
	var d: Dictionary = (DEFS[kind] as Dictionary).duplicate()
	var t: float = float(tier)
	# VITESSE (22/10, patron : « la vitesse doit etre recalculee mecha joueur vs ennemi ») : ratio 0,50 au niveau 1 -> 0,53 au niveau 18 (banc : 0,64 = rushes mortels aux niveaux 10-16 en moins de 90 s ; la vitesse est le reglage le plus sensible)
	# du joueur de REFERENCE (336 px/s, ameliorations exclues : elles restent un avantage). Facteurs de role plus bas. _scale_enemy
	# ajoute <= +25 % avec le temps puis plafonne a 80 % de la vitesse reelle du joueur.
	d["speed"] = 336.0 * (0.50 + 0.002 * (t - 1.0))
	d["behavior"] = "ranged"
	d["attack_cd"] = lerpf(2.0, 1.4, (t - 1.0) / 17.0)   # 21/10 : debuts trop faciles -> plus dur des le niveau 1
	d["attack_dmg"] = float(d["attack_dmg"]) * lerpf(1.4, 1.0, clampf((t - 1.0) / 8.0, 0.0, 1.0))
	d["aim_rate"] = lerpf(2.4, 5.5, (t - 1.0) / 17.0)
	d["aim_lead"] = clampf(0.25 + 0.035 * t, 0.25, 0.85) if not AK_ON else clampf((0.30 + 0.03 * t) * EnemyDiv.LEAD_DIFF[EnemyDiv.difficulty()], 0.15, 0.9)   # 31/10 anti-fuite : 0,285 -> 0,33 au niveau 1 (Normal)
	d["prefer_dist"] = lerpf(270.0, 215.0, (t - 1.0) / 17.0)
	for f in flags:
		match String(f):
			"charge":
				d["behavior"] = "dasher"
			"mine":
				d["speed"] = float(d["speed"]) * 0.85
				d["behavior"] = "miner"
				d["attack_dmg"] = float(d["attack_dmg"]) * 1.25   # banc : 1,6 tuait le bot en 19 s au niveau 17
			"kamikaze":
				d["behavior"] = "kamikaze"
				d["attack_dmg"] = 8.0 + 0.4 * t
				d["hp"] = float(d["hp"]) * 0.6
			"bull":
				d["behavior"] = "rush"
				d["bull"] = true
				d["zigzag"] = 0.4   # approche en lacets (Runner de survivor-td) : moins previsible qu'une ligne droite
			"rafale", "eventail", "sniper", "guide", "anneau", "orbe":
				d["tir_style"] = String(f)
			"esquive":
				d["esquive"] = true
			"zigzag":
				d["zigzag"] = 0.4
			"protecteur":
				d["protecteur"] = true
				d["tint_proteur"] = true
			"garde":
				d["garde"] = true
				d["garde_cd"] = lerpf(11.0, 6.5, (t - 1.0) / 17.0)
			"blinde":
				d["shield"] = 8.0 + 1.2 * t   # banc 22/10 : 14+2.2t rendait le niveau 9 intuable (77 ennemis vivants a 63 s)
			"lourd":
				d["speed"] = float(d["speed"]) * 0.9
				d["heavy"] = true
				d["attack_cd"] = float(d["attack_cd"]) * 1.25
			"barrage":
				d["barrage"] = true
				d["attack_cd"] = float(d["attack_cd"]) * 1.2
	return d

## Definition a utiliser pour CE spawn : role principal, ou secondaire selon `share`.
func _def_for(kind: String) -> Dictionary:
	_ensure_phase2()
	if PHASE2_DEFS.has(kind):
		var d_p2: Dictionary = (PHASE2_DEFS[kind] as Dictionary).duplicate()
		var prof_p2: Dictionary = PROFILES.get(current_biome, {})
		var tier_p2: float = float(prof_p2.get("tier", 1))
		d_p2["speed"] = float(d_p2.get("speed", 180.0)) * (0.95 + 0.005 * (tier_p2 - 1.0))
		d_p2["hp"] = float(d_p2.get("hp", 20.0)) * (1.0 + 0.03 * (tier_p2 - 1.0))
		return d_p2
	var prof: Dictionary = PROFILES.get(current_biome, {})
	if prof.is_empty() or not DEFS.has(kind):
		return DEFS[kind] if DEFS.has(kind) else {}
	# Archétypes spécialisés d'escouades (swarm, shield, sniper) : préservent leurs rôles tactiques
	if kind.contains("_") and not kind.contains("_mk2") and not kind.contains("_inter") and not kind.contains("_mini") and not kind.contains("_boss"):
		var d_spec: Dictionary = (DEFS[kind] as Dictionary).duplicate()
		var tier_s: float = float(prof.get("tier", 1))
		d_spec["speed"] = float(d_spec.get("speed", 180.0)) * (0.95 + 0.005 * (tier_s - 1.0))
		d_spec["hp"] = float(d_spec.get("hp", 20.0)) * (1.0 + 0.03 * (tier_s - 1.0))
		# 31/10 ANTI-FUITE : les specialistes a distance (sniper, bouclier...) n'anticipaient PAS (aim_lead absent = 0).
		# v12.19 (bancs ak4/ak5/bm1/bm2 : 1 mort Normal sur 4 vers 3:30, toujours un sniper) : snipers apparus avant 4:00 frappent a 75 %.
		if String(d_spec.get("tir_style", "")) == "sniper" and GameState.run_time < 240.0:
			d_spec["dmg"] = float(d_spec.get("dmg", 5.0)) * 0.75
		if AK_ON and String(d_spec.get("behavior", "")) == "ranged" and not d_spec.has("aim_lead"):
			# banc ak1 : 0,6 au sniper = 1re cause de mort des 1:50 (le laser suit deja la cible pendant la charge) -> 0,3
			# banc ak3/ak4 (04/11) : le sniper reste la 1re source de degats (35-50 %) -> anticipation quasi nulle pour lui (son laser suit deja
			# la cible pendant la charge) ; les autres tireurs specialistes gardent 0,3.
			var base_l: float = 0.08 if String(d_spec.get("tir_style", "")) == "sniper" else 0.3
			var ramp: float = clampf(GameState.run_time / 180.0, 0.25, 1.0)   # montee en charge : pleine anticipation a 3:00
			d_spec["aim_lead"] = clampf((base_l + 0.03 * (tier_s - 1.0)) * EnemyDiv.LEAD_DIFF[EnemyDiv.difficulty()] * ramp, 0.05, 0.85)
		return d_spec
	if not kind.begins_with("mech"):
		return DEFS[kind] if DEFS.has(kind) else {}
	var tier: int = int(prof["tier"])
	if randf() < _mk2_share():
		var dm: Dictionary = _tier_def("mk2")
		if not dm.is_empty():
			return dm
	var use_alt: bool = not (prof["alt"] as Array).is_empty() and randf() < minf((float(prof["share"]) + 0.004 * float(tier)) * float(_phase()["share"]), 0.65)
	var key: String = "%s|%d|%d" % [current_biome, tier, 1 if use_alt else 0]
	if not _prof_defs.has(key):
		_prof_defs[key] = _role_def(kind, prof["alt"] if use_alt else prof["main"], tier)
	var d: Dictionary = _prof_defs[key]
	# MONTEE EN CHARGE (banc 22/10 : niveaux 6/9/10/12/14/16/18 mortels en 25-70 s, le bot n'avait pas le temps de monter en niveau) :
	# les ajouts de rang (bouclier, garde, PV) arrivent progressivement sur les 2 premieres minutes.
	var t0: float = GameState.run_time
	if t0 < 120.0:
		var ease: float = clampf(t0 / 120.0, 0.25, 1.0)
		d = d.duplicate()
		if t0 < 90.0:
			d.erase("shield")
			d.erase("garde")
		elif d.has("shield"):
			d["shield"] = float(d["shield"]) * clampf((t0 - 90.0) / 30.0, 0.25, 1.0)
		if t0 < 120.0:
			d.erase("protecteur")
		d["hp"] = float(d["hp"]) * lerpf(0.70, 1.0, ease)
	if t0 < 90.0 and _is_special(d):
		d = _role_def(kind, ["tir"], tier)   # banc : pas de charge/kamikaze/mine/rush avant 1:30
	var lf: float = _lead_factor()
	if lf != 1.0 and d.has("aim_lead"):
		d = d.duplicate()
		d["aim_lead"] = clampf(float(d["aim_lead"]) * lf, 0.0, 0.95)
	if _is_special(d):
		var n: int = 0
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Enemy and ((e as Enemy).behavior in ["dasher", "kamikaze", "miner", "rush"] or (e as Enemy).bull):
				n += 1
		if n >= mini(_special_cap(tier), 2 + int(t0 / 30.0)):
			return _role_def(kind, ["tir"], tier)   # plafond atteint : tireur banal, jamais un mur de charges
	return d

## Point d'apparition selon le motif du niveau (relatif au joueur).
func _pattern_offset() -> Vector2:
	var prof: Dictionary = PROFILES.get(current_biome, {})
	if prof.is_empty():
		return _spawn_offset()
	_pat_n += 1
	var v: Vector2 = Vector2.ZERO
	if "velocity" in player:
		v = player.velocity
	var face: float = v.angle() if v.length() > 60.0 else _anchor
	var ang: float = 0.0
	var r: float = SPAWN_R
	match String(prof["pat"]):
		"ahead":
			if v.length() > 60.0 and randf() < 0.85:
				ang = face + randf_range(-AHEAD_ARC, AHEAD_ARC)
			else:
				ang = randf() * TAU
		"pincer":
			ang = face + (PI * 0.5 if _pat_n % 2 == 0 else -PI * 0.5) + randf_range(-0.3, 0.3)
		"ambush", "burst":
			var is_ambush: bool = String(prof["pat"]) == "ambush"
			if _t - _anchor_t > (7.0 if is_ambush else 3.5):
				_anchor_t = _t
				_anchor = randf() * TAU
			ang = _anchor + randf_range(-0.42, 0.42) * (1.0 if is_ambush else 0.5)
			r += randf_range(-40.0, 80.0)
		"line":
			if _t - _anchor_t > 9.0:
				_anchor_t = _t
				_anchor = randf() * TAU
			var along: float = float((_pat_n % 7) - 3) * 80.0
			return Vector2(cos(_anchor), sin(_anchor)) * r + Vector2(-sin(_anchor), cos(_anchor)) * along
		"close":
			ang = randf() * TAU
			r = 520.0
		"encircle":
			ang = float(_pat_n % 4) * PI * 0.5 + _t * 0.15 + randf_range(-0.2, 0.2)
			r = 560.0 + randf_range(0.0, 80.0)
		"dropin":
			ang = randf() * TAU
			r = 420.0 + randf_range(0.0, 70.0)
			if game != null and game.has_method("spawn_vfx"):
				game.spawn_vfx("shockwave", player.global_position + Vector2(cos(ang), sin(ang)) * r, 0.0, 0.5, Color(0.75, 0.5, 1.0))
		"gates":
			if _t - _anchor_t > 8.0:
				_anchor_t = _t
				_anchor = float(randi() % 4) * PI * 0.5
			ang = _anchor + (PI if _pat_n % 2 == 0 else 0.0) + randf_range(-0.14, 0.14)
		"fan":
			if _t - _anchor_t > 6.0:
				_anchor_t = _t
				_anchor = randf() * TAU
			ang = _anchor + float(_pat_n % 3) * TAU / 3.0 + randf_range(-0.2, 0.2)
		"sandwich":
			ang = face + (0.0 if _pat_n % 2 == 0 else PI) + randf_range(-0.5, 0.5)
		_:
			return _spawn_offset()
	return Vector2(cos(ang), sin(ang)) * r

## ======================= IA SYNTHETIQUE : adaptation au mecha du joueur =======================
## (patron : « une IA synthetique en fonction du mecha du joueur »). Deux sources :
##  - le CHASSIS (statique) : VORTEX perce et aligne -> on evite ligne/colonne (une rangee se fait traverser) et on le
##    prend en flanc ; BLUESTRIKE est un tireur de courte portee -> on le harcele a distance (feu et mouvement,
##    tirailleurs) et on anticipe plus (il bouge beaucoup) ; TITAN est lent et blinde -> on l'enferme (encerclement,
##    spirale, tenaille, embuscade) et on anticipe moins.
##  - le COMPORTEMENT (dynamique, vitesse moyenne lissee sur ~3 s) : un joueur qui court se fait couper la route
##    (tenaille, encerclement, embuscade, fer a cheval) ; un joueur statique se fait user (feu et mouvement, tirailleurs).
var _pspeed: float = 0.0
var _squads: Array = []
var _squad_t: float = 40.0   # premiere escouade a 40 s (banc : escouade + roles speciaux des les premieres secondes = morts precoces)
var _banner_t: Dictionary = {}

func _lead_factor() -> float:
	var fam: String = String(player.chassis_family) if player != null and "chassis_family" in player else ""
	match fam:
		"bluestrike": return 1.15
		"titan": return 0.7
	return 1.0

func _player_style() -> Dictionary:
	var fam: String = String(player.chassis_family) if player != null and "chassis_family" in player else ""
	var prefer: Array = []
	var avoid: Array = []
	match fam:
		"bluestrike":
			prefer = ["feu_et_mouvement", "tirailleurs", "ligne"]
		"titan":
			prefer = ["encerclement", "spirale", "tenaille", "embuscade"]
		"vortex":
			prefer = ["tenaille", "vague", "echelon"]
			avoid = ["ligne", "colonne"]
	var bs: float = float(player.base_speed) if player != null and "base_speed" in player else 300.0
	var ratio: float = _pspeed / maxf(bs, 1.0)
	if ratio > 0.6:
		prefer = prefer + ["tenaille", "encerclement", "embuscade", "fer_a_cheval"]
	elif ratio < 0.2 and _t > 20.0:
		prefer = prefer + ["feu_et_mouvement", "tirailleurs", "vague"]
	return {"prefer": prefer, "avoid": avoid, "ratio": ratio}

func _pick_formation(prof: Dictionary) -> String:
	var forms: Array = prof["forms"]
	var st: Dictionary = _player_style()
	var ok: Array = forms.filter(func(f: String) -> bool: return not (st["avoid"] as Array).has(f))
	if ok.is_empty():
		ok = forms
	var pref: Array = ok.filter(func(f: String) -> bool: return (st["prefer"] as Array).has(f))
	if not pref.is_empty() and randf() < 0.7:
		return String(pref.pick_random())
	return String(ok.pick_random())

func _announce(form: String, text: String, col: Color) -> void:
	if game != null and game.has_method("show_banner") and _t - float(_banner_t.get(text, -99.0)) > 40.0:
		_banner_t[text] = _t
		game.show_banner(text, col)

func _squad_tick(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not PROFILES.has(current_biome):
		return
	if "velocity" in player:
		_pspeed = lerpf(_pspeed, (player.velocity as Vector2).length(), 1.0 - exp(-delta / 3.0))
	var p: Vector2 = player.global_position
	Enemy.fire_rate = clampf(3.5 + 0.30 * float(int((PROFILES[current_biome] as Dictionary)["tier"])) + GameState.run_time / 100.0, 3.5, 14.0) * clampf(GameState.run_time / 60.0, 0.6, 1.0)   # budget de tir global (cf. Enemy._fire_ok)
	var ph: Dictionary = _phase()
	var pi: int = PHASES.find(ph)
	if pi != _phase_idx:
		if _phase_idx >= 0:
			_announce("", "PHASE : " + String(ph["label"]), Color(1.0, 0.45, 0.3))
		_phase_idx = pi
	_tier_tick(delta)
	for q in _squads:
		var ms: Array = q.live()
		if ms.is_empty():
			q.done = true
			continue
		q.update(delta, p, float((ms[0] as Enemy).speed))
		if q.chef_down:
			q.chef_down = false
			_announce("", "CHEF ABATTU - L'ESCOUADE HESITE", Color(1.0, 0.8, 0.3))
	_squads = _squads.filter(func(q: Squad) -> bool: return not q.done)
	_squad_t -= delta
	if _squad_t <= 0.0:
		var tier: int = int((PROFILES[current_biome] as Dictionary)["tier"])
		_squad_t = lerpf(24.0, 11.0, float(tier - 1) / 17.0)
		_spawn_squad()

## ELITE ALEATOIRE (survivor-td §8.2 : 5 % + 0,5 %/min) : un ennemi isole sur ~20 devient elite (or-rose, 3x PV, 1,6x degats, +10 %
## de vitesse sous le plafond de 80 % du joueur) et laisse un butin. Les escouades ont deja leurs grades.
func _maybe_elite(e: Enemy) -> void:
	if not PROFILES.has(current_biome) or not e.kind.begins_with("mech") or e.grade != "":
		return
	var minutes: float = GameState.run_time / 60.0
	if randf() >= minf((0.05 + 0.005 * minutes) * float(_phase()["elite"]), 0.3):
		return
	e.grade = "elite"
	e.hp *= minf(2.0 + 0.5 * minutes, 5.0)   # opensurvivor : l'elite devient plus coriace avec le temps
	e.hp_max = e.hp
	e.contact_dmg *= 1.6
	e.attack_dmg *= 1.6
	e.speed = minf(e.speed * 1.1, float(player.base_speed) * 0.8) if "base_speed" in player else e.speed
	e.drops_bonus = GameState.run_time < 90.0 or randf() < 0.7   # v12.16 : 70 % (la cadence est plafonnee dans Game.spawn_bonus)
	e.set_meta("phase1_elite", true)   # meme table de drop que l'elite scriptee (_spawn_elite)
	e._spr.self_modulate = Color(1.5, 0.7, 1.4)
	EnemyDiv.make_elite(e)   # pouvoir de biome (30/10 : plus de cape/epee/nom dessines)
	pass   # 29/10 (patron : meme taille pour tous sauf mini-boss/boss) : plus de grossissement elite, la teinte suffit

func _spawn_squad(force: bool = false, formation: String = "") -> bool:
	var prof: Dictionary = PROFILES.get(current_biome, {})
	var pool: Array = BIOME_POOL.get(current_biome, [])
	if prof.is_empty() or pool.is_empty() or game == null:
		return false
	var tier: int = int(prof["tier"])
	var dtier: int = _sync_div()
	if _squads.size() >= 1 + tier / 7 and not force:
		return false
	var n: int = clampi(4 + tier / 3, 4, 10)
	n = maxi(4, int(round(float(n) * clampf(0.5 + GameState.run_time / 240.0, 0.5, 1.0))))   # escouades d'au moins 4 membres pour les 4 rôles
	if get_tree().get_nodes_in_group("enemies").size() + n > ENEMY_CAP:
		return false
	var kind: String = String(pool[0])
	if not DEFS.has(kind):
		return false
	var form: String = formation if formation != "" else _pick_formation(prof)
	var p: Vector2 = player.global_position
	var anchor: float = randf() * TAU
	if "velocity" in player and (player.velocity as Vector2).length() > 60.0 and form in ["ligne", "colonne", "coin", "echelon", "vague", "embuscade"]:
		anchor = (player.velocity as Vector2).angle() + randf_range(-0.5, 0.5)   # ils se dressent sur sa route
	var q: Squad = Squad.new()
	q.setup(form, anchor, p + Vector2.from_angle(anchor) * 640.0, p)
	for i in n:
		var pos: Vector2 = q.slot(i, n, p)
		var off: Vector2 = pos - p
		if off.length() < 520.0:
			pos = p + (off.normalized() if off.length() > 1.0 else Vector2.RIGHT) * 560.0   # jamais d'apparition sur le joueur
		if arena_half > 0.0:
			pos.x = clampf(pos.x, arena.position.x, arena.end.x)
			pos.y = clampf(pos.y, arena.position.y, arena.end.y)
		var member_kind: String = kind
		if pool.size() >= 5 and i == 0:
			member_kind = String(pool[4])   # Gundam Elite leads the squad
		elif pool.size() >= 4 and i > 0:
			if i == 1:
				member_kind = String(pool[1])   # fast swarm skirmisher
			elif i == 2:
				member_kind = String(pool[2])   # shield vanguard
			elif i == 3:
				member_kind = String(pool[3])   # sniper rear-guard
			elif i % 2 == 0:
				member_kind = String(pool[1])   # swarm
			else:
				member_kind = kind              # frontline mecha
		if not EnemyDiv.kind_allowed(member_kind, _raw(member_kind), dtier):
			member_kind = kind
		var e: Enemy = Enemy.new()
		e.global_position = pos
		game.enemy_layer.add_child(e)
		e.setup(member_kind, _def_for(member_kind), player, game)
		_scale_enemy(e)
		q.members.append(e)
	q.assign_ranks()
	_squads.append(q)
	_announce(form, "FORMATION : " + Squad.label(form), Color(1.0, 0.62, 0.3))
	return true

## Cle de la fenetre soft en cours (180 ou 480), ou -1 hors fenetre / pendant la grace t<18s.
func _soft_wall_key(t: float) -> int:
	if t < SOFT_WALL_GRACE or _t < SOFT_WALL_GRACE:
		return -1
	for span in SOFT_WALLS:
		if t >= span.x and t < span.y:
			return int(span.x)
	return -1

## pressure_floor du spec = floor_pop (plancher de population). x1.6 seulement dans la fenetre,
## apres la grace, sans lever le plafond historique de 24.
func _apply_soft_wall_pressure(floor_pop: int) -> int:
	if _soft_wall_key(GameState.run_time) < 0:
		return floor_pop
	return clampi(int(ceil(float(floor_pop) * SOFT_WALL_MULT)), 2, 44)

## Une escouade tenaille par fenetre. Reessaie tant que _spawn_squad echoue (plafond d'ennemis),
## puis se tait. has_method garde le hook si la fonction etait renommee.
func _pulse_soft_wall_squad() -> void:
	var key: int = _soft_wall_key(GameState.run_time)
	if key < 0 or _soft_wall_squad_done.has(key):
		return
	if player == null or not is_instance_valid(player):
		return
	if not has_method("_spawn_squad"):
		return
	if _spawn_squad(true, "tenaille"):
		_soft_wall_squad_done[key] = true

## ======================= HIERARCHIE D'ENNEMIS PAR NIVEAU (22/10, patron : « integrer les Mark 2, intermediaires, mini-boss, boss ») =======================
## Meme modele 3D que l'ennemi de base du niveau (pas de nouvelle modelisation) ; ce qui change : taille, PV, teinte, armement, defenses.
##   mk2   : variante renforcee, melee au flux normal des 2 min a ~35 % des apparitions (bouclier actif + blinde)
##   inter : intermediaire (rang 1), 1 toutes les ~80 s des 2 min 30 (2 max vivants), lourd + blinde + garde
##   mini  : mini-boss (rang 2) a 5:00 et 10:00, salve en barrage + blinde + garde + esquive
##   boss  : boss de fin de niveau (rang 4, `final`) a 15:00 : sa mort = VICTOIRE ; invoque une escouade toutes les ~22 s ;
##           les apparitions normales ralentissent (x0,6) tant qu'il vit (survivor-td : pause des spawns pendant un boss)
const TIERS: Dictionary = {
	"mk2":   {"flags": ["blinde"],                                    "hp": 2.0,   "dmg": 1.15, "size": 1.15, "radius": 1.1,  "rank": 0, "tint": Color(1.5, 0.85, 0.65), "label": "MARK 2"},
	"inter": {"flags": ["lourd", "blinde"],                           "hp": 5.0,   "dmg": 1.25, "size": 1.45, "radius": 1.35, "rank": 1, "tint": Color(1.6, 0.55, 0.5),  "label": "INTERMEDIAIRE"},
	"mini":  {"flags": ["barrage", "blinde"],                         "hp": 8.5,   "dmg": 1.3,  "size": 1.8,  "radius": 1.7,  "rank": 2, "tint": Color(1.7, 0.4, 0.9),   "label": "MINI-BOSS", "shield": 25.0},
	"boss1": {"flags": ["barrage", "blinde"],                         "hp": 18.0,  "dmg": 1.4, "size": 2.0,  "radius": 1.9,  "rank": 3, "tint": Color(1.8, 0.5, 0.35), "label": "BOSS", "shield": 35.0, "zone_shift": false},
	"boss2": {"flags": ["barrage", "lourd", "blinde"],               "hp": 32.0,  "dmg": 1.5, "size": 2.15, "radius": 2.0,  "rank": 3, "tint": Color(1.8, 0.4, 0.3),  "label": "BOSS", "shield": 60.0, "zone_shift": false},
	"boss":  {"flags": ["barrage", "lourd", "blinde"],               "hp": 58.0,  "dmg": 1.6, "size": 2.3,  "radius": 2.1,  "rank": 4, "tint": Color(1.8, 0.35, 0.3),  "label": "BOSS", "shield": 90.0},
}
var _boss_ref: Variant = null
var _tier_last: Dictionary = {"inter": 120.0, "summon": 0.0}
var _tier_fired: Dictionary = {}

func _tier_def(tier_name: String) -> Dictionary:
	var pool: Array = BIOME_POOL.get(current_biome, [])
	var prof: Dictionary = PROFILES.get(current_biome, {})
	if pool.is_empty() or prof.is_empty() or not DEFS.has(String(pool[0])):
		return {}
	var key: String = "T|%s|%s" % [current_biome, tier_name]
	if _prof_defs.has(key):
		return _prof_defs[key]
	var tp: Dictionary = TIERS[tier_name]
	var tier: int = int(prof["tier"])
	var d: Dictionary = _role_def(String(pool[0]), (prof["main"] as Array) + (tp["flags"] as Array), tier)
	d["name"] = "%s %s" % [String(DEFS[String(pool[0])]["name"]), String(tp["label"])]
	d["hp"] = float(d["hp"]) * float(tp["hp"])
	if tp.has("shield"):
		d["shield"] = float(tp["shield"])
	d["dmg"] = float(d["dmg"]) * float(tp["dmg"])
	d["attack_dmg"] = float(d["attack_dmg"]) * float(tp["dmg"])
	d["size"] = float(d["size"]) * float(tp["size"])
	d["radius"] = float(d["radius"]) * float(tp["radius"])
	d["rank"] = int(tp["rank"])
	d["tint"] = tp["tint"]
	d["speed"] = float(d["speed"]) * (0.9 if int(tp["rank"]) >= 2 else 1.0)
	d["zone_shift"] = bool(tp.get("zone_shift", true))
	d["tier_tag"] = tier_name          # DIVERSITE : surcouche MK2 / INTER + palier d'avance
	if tier_name.begins_with("boss"):
		d["ogive"] = true
		d["final"] = (tier_name == "boss") and not GameState.endless
		d["behavior"] = "ranged"
		d["prefer_dist"] = 230.0
		d["garde"] = false
		d["esquive"] = false
	elif tier_name == "mini":
		d["garde"] = false
		d["esquive"] = false
		d["prefer_dist"] = 210.0
	_prof_defs[key] = d
	return d

func _spawn_tier(tier_name: String) -> Enemy:
	var d: Dictionary = _tier_def(tier_name)
	if d.is_empty() or player == null or not is_instance_valid(player) or game == null:
		return null
	var pool: Array = BIOME_POOL.get(current_biome, [])
	_sync_div()
	var e: Enemy = Enemy.new()
	var ang: float = randf() * TAU
	e.global_position = player.global_position + Vector2.from_angle(ang) * 700.0
	if arena_half > 0.0:
		e.global_position.x = clampf(e.global_position.x, arena.position.x, arena.end.x)
		e.global_position.y = clampf(e.global_position.y, arena.position.y, arena.end.y)
	game.enemy_layer.add_child(e)
	e.setup(String(pool[0]) + "_" + tier_name, d, player, game)
	_scale_enemy(e)
	var tp: Dictionary = TIERS[tier_name]
	if game.has_method("spawn_vfx"):
		game.spawn_vfx("shockwave", e.global_position, 0.0, 1.5 + float(tp["size"]), tp["tint"])
	_announce("", "!  %s  !" % String(tp["label"]), tp["tint"])
	Audio.sfx("boss", 0.1)
	if tier_name.begins_with("boss"):
		_boss_ref = e
		Audio.music("boss")
	return e

func _live_tier(rank_min: int) -> int:
	var n: int = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and (e as Enemy).alive and int((e as Enemy).rank) >= rank_min and (e as Enemy).kind.contains("_"):
			n += 1
	return n

func _boss_up() -> bool:
	return _boss_ref != null and is_instance_valid(_boss_ref) and _boss_ref.alive

## ORDRE D'APPARITION (22/10, patron : « l'ordre d'apparition » ; base de reference : docs/SURVIVOR_IO_PLAYBOOK.md §5, timeline
## d'evenements scriptee, boss 5/10/15 min, mini-boss/elite entre, la pietaille « devient blindee » apres un boss) :
##   0:00  ennemi de BASE (continu)            1:30  MARK 2 introduits (part croissante)      2:00  INTERMEDIAIRE (puis ~1 / 90 s, 2 max)
##   3:00  MINI-BOSS (puis 8:00, 12:00)        5:00  BOSS 1 (la base devient surtout MARK 2)  10:00 BOSS 2 (Mark 2 dominant)
##   15:00 BOSS FINAL (victoire) ; invocations d'escouade toutes les 22 s pendant un boss, apparitions x0,6.
const TIER_EVENTS: Array = [
	{"t": 180.0, "tier": "mini"}, {"t": 300.0, "tier": "boss1"}, {"t": 480.0, "tier": "mini"},
	{"t": 600.0, "tier": "boss2"}, {"t": 720.0, "tier": "mini"}, {"t": 900.0, "tier": "boss"},
]
## Echeancier de la hierarchie (appele par _squad_tick, apres les phases)
func _tier_tick(_delta: float) -> void:
	var t: float = GameState.run_time
	if t >= 120.0 and t - float(_tier_last["inter"]) >= 90.0 and not _boss_up() and _live_tier(1) < 2:
		_tier_last["inter"] = t
		_spawn_tier("inter")
	for ev in TIER_EVENTS:
		var et: float = float(ev["t"])
		if t >= et and not _tier_fired.has(et):
			if _boss_up():
				if String(ev["tier"]).begins_with("boss"):
					continue
				else:
					_tier_fired[et] = true
					continue
			_tier_fired[et] = true
			_spawn_tier(String(ev["tier"]))
			break
	if _boss_up() and t - float(_tier_last["summon"]) >= 22.0:
		_tier_last["summon"] = t
		_spawn_squad(true)


## MARK 2 : part des apparitions de base. Introduits des 1:30, puis « swap de base » apres le boss 1 (5:00) et le boss 2 (10:00).
func _mk2_share() -> float:
	var t: float = GameState.run_time
	if t >= 600.0:
		return 0.8
	if t >= 300.0:
		return 0.6
	return clampf((t - 90.0) / 210.0, 0.0, 1.0) * 0.35
## <<< PROFILS DE NIVEAU

func _spawn() -> void:
	if player == null or not is_instance_valid(player):
		return
	if get_tree().get_nodes_in_group("enemies").size() >= ENEMY_CAP:
		return
	var off: Vector2 = _pattern_offset()
	var ahead: bool = false
	if AK_ON and String((PROFILES.get(current_biome, {}) as Dictionary).get("pat", "")) != "ahead" and avg_vel.length() > _pbase() * AK_MOVE_RATIO and randf() < AK_AHEAD_SHARE:
		var a_h: float = avg_vel.angle() + randf_range(-AK_AHEAD_ARC, AK_AHEAD_ARC)
		off = Vector2.from_angle(a_h) * offscreen_dist(a_h)
		ahead = true
		ak_stats["ahead_spawns"] = int(ak_stats["ahead_spawns"]) + 1
	# 05/11 ZONE PUBG : une part des apparitions vient du cote de la zone sure -> la horde converge la ou le joueur DOIT aller.
	if not ahead and AK_ON and game != null and game.get("arena_wall") != null and game.arena_wall.active and randf() < AK_ZONE_SHARE:
		var zv: Vector2 = game.arena_wall.target_center() - player.global_position
		# v12.19 grande carte : seulement si le joueur est hors du cercle a atteindre ou pres de son bord (sinon exploration libre)
		if game.arena_wall.zone_live() and zv.length() > game.arena_wall.target_radius() * 0.8:
			var a_z: float = zv.angle() + randf_range(-0.6, 0.6)
			off = Vector2.from_angle(a_z) * offscreen_dist(a_z)
			ak_stats["zone_spawns"] = int(ak_stats.get("zone_spawns", 0)) + 1
	# CHASSEUR en filet continu (debloque selon la difficulte, plafond de vivants)
	if AK_ON and GameState.run_time >= float(CH_UNLOCK[_ak_diff()]) and _live_chasseurs() < _chasseur_cap() and randf() < CH_TRICKLE:
		if not ahead and avg_vel.length() > _pbase() * AK_MOVE_RATIO:
			var a_c: float = avg_vel.angle() + randf_range(-AK_AHEAD_ARC, AK_AHEAD_ARC)
			off = Vector2.from_angle(a_c) * offscreen_dist(a_c)
		spawn_chasseur(player.global_position + off)
		return
	var kind: String = _weighted_pick()
	if not _has_def(kind):
		return
	var e: Enemy = Enemy.new()
	var spos: Vector2 = player.global_position + off
	if arena_half > 0.0:
		# Keep spawns inside the walls. Fleeing toward a wall means the ahead-spawns land ON the
		# wall in front of you -> you get pinned, which is the whole point of the bounded arena.
		spos.x = clampf(spos.x, arena.position.x, arena.end.x)
		spos.y = clampf(spos.y, arena.position.y, arena.end.y)
	e.global_position = spos
	game.enemy_layer.add_child(e)
	e.setup(kind, _def_for(kind), player, game)
	_scale_enemy(e)
	_maybe_elite(e)

## Spawn one enemy at a fixed world point (beacon structures use this). Respects the enemy cap and
## the arena bounds, and scales the enemy like any normal spawn.
func spawn_at(pos: Vector2, kind: String) -> void:
	kind = _rigged_kind(kind)
	if player == null or not is_instance_valid(player):
		return
	if not _has_def(kind):
		return
	if get_tree().get_nodes_in_group("enemies").size() >= ENEMY_CAP:
		return
	var e: Enemy = Enemy.new()
	var p: Vector2 = _in_map(pos)
	if arena_half > 0.0:
		p.x = clampf(p.x, arena.position.x, arena.end.x)
		p.y = clampf(p.y, arena.position.y, arena.end.y)
	e.global_position = p
	game.enemy_layer.add_child(e)
	var def: Dictionary = _def_for(kind) if PHASE2_DEFS.has(kind) else DEFS[kind]
	e.setup(kind, def, player, game)
	_scale_enemy(e)

# Scale a fresh enemy, per stat (not uniformly):
#   HP     = run-time crescendo + per-zone bonus + difficulty (full stack)
#   damage = per-zone bonus + difficulty (contact AND ranged bolts)
#   speed  = biome modifier + difficulty only (intentionally NOT time/zone — enemy speed must
#            not creep upward over a run; cf. Game.next_map where difficulty_bonus feeds HP/dmg)
func _scale_enemy(e: Enemy) -> void:
	var d: Dictionary = GameState.diff()
	# Speed DOES scale now, capped at +40%. It used to be flat forever, which meant a player at
	# 512 px/s (agility + speed picks) simply outran every non-boss foe at 224 px/s for the whole
	# run — kiting was free and permanent, and ENEMY_CAP forbids raising pressure by numbers.
	# The cap keeps them beatable: even maxed they stay slower than an upgraded player.
	var spd_scale: float = minf(1.0 + difficulty_bonus * 0.10 + GameState.run_time * 0.00018, 1.25)   # 17/10 : plafond 1,40 -> 1,25
	e.speed *= speed_mult * float(d.get("speed", 1.0)) * spd_scale * clampf(Protocols.enemy_speed, 0.8, 1.2)
	# 17/10 (patron : « les ennemis sont trop rapides ») : un ennemi ne rattrape plus un mecha qui FUIT. Plafond = 80 % de la vitesse du
	# joueur : la poursuite reste menacante (on ne peut pas s'arreter), mais on peut toujours repositionner en courant. Les ruees
	# (dasher) et le coefficient individuel (+/-15 %) s'ajoutent par-dessus : brefs, pas permanents.
	if player != null and "base_speed" in player:
		e.speed = minf(e.speed, float(player.base_speed) * 0.80)
	# 22/10 (banc d'equilibre) : la difficulte doit MONTER avec le niveau (chapitre) : +4 % de PV par rang de niveau.
	# MONTEE EN CHARGE sur les 90 premieres secondes : adoucit les multiplicateurs extremes de tier et de protocole (ex: COLOSSES)
	# pour que le joueur de niveau 1-2 puisse faire ses premiers kills et lancer son build (supprime les 25% de morts precoces).
	var tier_n: float = float(int((PROFILES.get(current_biome, {}) as Dictionary).get("tier", 1)) - 1)
	var t0: float = GameState.run_time
	var tier_ease: float = clampf(t0 / 90.0, 0.35, 1.0)
	var proto_hp: float = lerpf(1.0, Protocols.enemy_hp, clampf(t0 / 75.0, 0.0, 1.0))
	var hp_scale: float = (1.0 + 0.04 * tier_n * tier_ease) * (1.0 + t0 * 0.0020) * (1.0 + difficulty_bonus) * float(d.get("hp", 1.0)) * proto_hp
	e.hp *= hp_scale
	e.hp_max = e.hp
	if e.shield_max > 0.0:               # shields scale with HP too, else late-game shields are trivial
		e.shield_max *= hp_scale
		e.shield = e.shield_max
	var proto_dmg: float = lerpf(1.0, Protocols.enemy_dmg, clampf(t0 / 75.0, 0.0, 1.0))
	var dmg_scale: float = (1.0 + GameState.run_time * 0.0008) * (1.0 + difficulty_bonus * 0.5) * float(d.get("dmg", 1.0)) * proto_dmg
	e.contact_dmg *= dmg_scale
	e.attack_dmg *= dmg_scale             # ranged bolts scale too (else late-game shooters are harmless)

# Scripted horde: a big ring of foes crashes in at once. Leans on one archetype for a
# coherent "swarm" read, mixes in a few others, and stays under the enemy cap for mobile.
func _spawn_wave() -> void:
	if player == null or not is_instance_valid(player):
		return
	var existing: int = get_tree().get_nodes_in_group("enemies").size()
	var want: int = 24 + int(GameState.run_time / 40.0) * 6 + int(difficulty_bonus * 24.0)
	var count: int = clampi(want, 0, maxi(0, ENEMY_CAP - existing))
	if count <= 0:
		return
	var lead: String = _weighted_pick(true)   # waves are pure weak swarm (fodder only)
	if lead == "":
		return   # aucun ennemi defini -> pas de vague (evite une banniere "VAGUE MASSIVE" pour rien)
	var base_ang: float = randf() * TAU
	# STAGGERED: building ~50 enemies (sprite + shadow + collider + shader material each) in ONE
	# frame was a ~200-node spike -> a visible hitch every wave, on any hardware. Queue them and
	# drain a few per frame instead: same ring, same instant, no freeze.
	# 🚨 « les ennemis arrivent en colonnes trop regulieres — des rangees presque parfaitement
	# alignees, des arcs de cercle nets. Ca se lit comme du spawn en ligne, pas comme une horde. »
	# En cause : un angle strictement regulier (i/count * TAU, +/- 0,06 rad) et une distance
	# quasi constante. On repartit maintenant la vague en 3 a 5 PAQUETS places au hasard sur le
	# tour, chacun avec sa propre dispersion angulaire et sa profondeur : on lit une meute.
	var packs: int = clampi(3 + randi() % 3, 3, 5)
	var pack_ang: Array = []
	for pi in packs:
		pack_ang.append(base_ang + float(pi) / float(packs) * TAU + randf_range(-0.45, 0.45))
	for i in count:
		var pk: int = i % packs
		_wave_queue.append({
			"ang": float(pack_ang[pk]) + randf_range(-0.42, 0.42),
			"dist": 700.0 + randf_range(-90.0, 260.0),
			"kind": lead if randf() < 0.82 else _weighted_pick(true),
		})
	if game != null:
		if game.has_method("show_horde_warning"):
			game.show_horde_warning("⚠️ ATTENTION : VAGUE IMMINENTE ⚠️", "Une horde massive encercle la zone !")
		elif game.has_method("show_banner"):
			game.show_banner(">>>  VAGUE MASSIVE  <<<", Color(1.0, 0.55, 0.3))
	Audio.sfx("boss", 0.1)

## ======================= ANTI-FUITE (31/10, plan B valide par le patron) =======================
## Probleme : « le mecha du joueur peut fuir indefiniment sans etre inquiete ». Quatre leviers ici :
##  1. vitesse MOYENNE du joueur sur ~2 s (avg_vel, EMA) : AK_AHEAD_SHARE (36 %) des apparitions normales tombent dans un arc
##     DEVANT son deplacement, juste HORS ECRAN (offscreen_dist lit le viewport reel + zoom camera -> marche en portrait mobile) ;
##  2. detection de fuite : s'il court (> 55 % de sa vitesse) en s'eloignant de la masse ennemie pendant AK_FLEE_T s,
##     une petite vague d'INTERCEPTION (chasseurs + essaim) surgit devant lui (recharge AK_INTERCEPT_CD) ;
##  3. CHASSEUR (role « chasseur ») : plus rapide que le mecha, vise un point de coupure DEVANT lui, ruee telegraphiee
##     (ligne au sol) ; planche RIGGEE de l'essaim du biome (aucun nouvel art), taille uniforme 124 px / rayon 40 ;
##  4. mesures de banc (ak_stats) : temps de fuite, temps « loin de tout », interceptions, apparitions devant.
static var AK_ON: bool = not OS.get_cmdline_user_args().has("--no-antikite")   # banc : -- --no-antikite = temoin v12.16
const AK_AHEAD_SHARE: float = 0.36
const AK_ZONE_SHARE: float = 0.30              # 05/11 zone PUBG : part des apparitions cote zone sure
const AK_AHEAD_ARC: float = 0.75
const AK_MOVE_RATIO: float = 0.45            # vitesse moyenne / vitesse de base au-dela de laquelle on « se deplace »
const AK_FLEE_RATIO: float = 0.55
const AK_FLEE_T: Array[float] = [5.5, 4.0, 3.2, 2.6]          # Facile / Normal / Difficile / Veteran
const AK_INTERCEPT_CD: Array[float] = [26.0, 18.0, 15.0, 12.0]
const AK_INTERCEPT_T0: float = 60.0          # jamais d'interception avant 1:00 (le joueur apprend)
const AK_FAR_PX: float = 380.0               # « loin de tout » : aucun ennemi a moins de 380 px
const CH_UNLOCK: Array[float] = [150.0, 90.0, 60.0, 45.0]
const CH_CAP: Array[int] = [1, 2, 3, 4]
const CH_TRICKLE: float = 0.06
const CH_SPEED: Array[float] = [1.03, 1.08, 1.13, 1.18]        # x vitesse de base du joueur (le plafond 80 % ne s'applique PAS)
const CH_TINT: Color = Color(0.8, 1.25, 1.6)
var avg_vel: Vector2 = Vector2.ZERO
var _flee_t: float = 0.0
var _intercept_cd: float = 0.0
var _ak_scan: float = 0.0
var ak_stats: Dictionary = {"flee_s": 0.0, "far_s": 0.0, "intercepts": 0, "ahead_spawns": 0, "chasseurs": 0}

func _ak_diff() -> int:
	return clampi(int(GameState.difficulty), 0, 3)

func _pbase() -> float:
	if player != null and "base_speed" in player:
		return float(player.base_speed) * (float(player.move_mult) if "move_mult" in player else 1.0)
	return 320.0

## Distance du joueur au bord de l'ecran dans la direction `ang` (+ marge) : l'apparition se fait juste hors champ.
## Lit la taille VISIBLE (stretch expand) et le zoom camera (Game._update_cam_zoom) -> correct en paysage, portrait, mobile.
func offscreen_dist(ang: float, margin: float = 90.0) -> float:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var z: Vector2 = Vector2.ONE
	if game != null and "cam" in game and game.cam != null:
		z = (game.cam as Camera2D).zoom
	var half: Vector2 = Vector2(vp.x / maxf(z.x, 0.01), vp.y / maxf(z.y, 0.01)) * 0.5
	var o: Vector2 = Vector2(0.0, 84.0)          # le joueur est sous le centre de vue (Game.CAM_OFFSET = (0, -84))
	var d: Vector2 = Vector2.from_angle(ang)
	var tx: float = 1.0e9
	var ty: float = 1.0e9
	if absf(d.x) > 0.0001:
		tx = ((half.x if d.x > 0.0 else -half.x) - o.x) / d.x
	if absf(d.y) > 0.0001:
		ty = ((half.y if d.y > 0.0 else -half.y) - o.y) / d.y
	return clampf(minf(tx, ty) + margin, 430.0, 980.0)

func _ak_tick(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var v: Vector2 = (player.velocity as Vector2) if "velocity" in player else Vector2.ZERO
	avg_vel = avg_vel.lerp(v, 1.0 - exp(-delta / 2.0))
	_intercept_cd -= delta
	_ak_scan -= delta
	if _ak_scan > 0.0:
		return
	var step: float = 0.25
	_ak_scan = step
	var pp: Vector2 = player.global_position
	var c: Vector2 = Vector2.ZERO
	var n: int = 0
	var near: float = 1.0e12
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or not (e as Enemy).alive:
			continue
		var d2: float = pp.distance_squared_to((e as Enemy).global_position)
		near = minf(near, d2)
		if d2 < 1100.0 * 1100.0:
			c += (e as Enemy).global_position
			n += 1
	if n > 0 and near > AK_FAR_PX * AK_FAR_PX:
		ak_stats["far_s"] = float(ak_stats["far_s"]) + step
	var fleeing: bool = false
	if n >= 3 and avg_vel.length() > _pbase() * AK_FLEE_RATIO:
		var away: Vector2 = pp - c / float(n)
		fleeing = away.length() > 1.0 and avg_vel.normalized().dot(away.normalized()) > 0.5
	if fleeing:
		_flee_t += step
		ak_stats["flee_s"] = float(ak_stats["flee_s"]) + step
	else:
		_flee_t = maxf(0.0, _flee_t - step * 2.0)
	var dk: int = _ak_diff()
	if AK_ON and _flee_t >= AK_FLEE_T[dk] and _intercept_cd <= 0.0 and GameState.run_time >= AK_INTERCEPT_T0:
		_flee_t = 0.0
		_intercept_cd = AK_INTERCEPT_CD[dk]
		_spawn_intercept()

## Vague d'INTERCEPTION : 3 a 6 ennemis en eventail serre devant la fuite, juste hors ecran (1-2 chasseurs + essaim).
func _spawn_intercept() -> void:
	var pool: Array = BIOME_POOL.get(current_biome, [])
	if pool.is_empty() or game == null:
		return
	var dk: int = _ak_diff()
	var n: int = 3 + dk + (1 if EnemyDiv.tier() >= 3 else 0)
	# 04/11 : un fuyard accumule la horde au plafond (220) -> l'interception etait TOUJOURS annulee (banc : interceptions=0).
	# On libere la place en retirant les trainards loin DERRIERE la fuite (ils ne rattraperont jamais).
	var over: int = get_tree().get_nodes_in_group("enemies").size() + n - ENEMY_CAP
	if over > 0 and _ak_make_room(over) < over:
		return
	var nch: int = 1 if dk == 0 else 2
	var a0: float = avg_vel.angle()
	var swarm: String = String(pool[1]) if pool.size() > 1 else String(pool[0])
	for i in n:
		var a: float = a0 + (float(i) - float(n - 1) * 0.5) * 0.26
		var pos: Vector2 = player.global_position + Vector2.from_angle(a) * offscreen_dist(a, 60.0)
		if i % 2 == 0 and nch > 0 and _live_chasseurs() < _chasseur_cap() + 2:
			nch -= 1
			spawn_chasseur(pos)
		else:
			spawn_kind_at(swarm, pos)
	ak_stats["intercepts"] = int(ak_stats["intercepts"]) + 1
	if game.has_method("show_banner") and _t - float(_banner_t.get("intercept", -99.0)) > 25.0:
		_banner_t["intercept"] = _t
		game.show_banner(">>  INTERCEPTION  <<", Color(0.55, 0.95, 1.0))

## Retire jusqu'a `need` ennemis ordinaires (rang 0, hors chasseurs) a plus de 1300 px et DERRIERE la fuite. Renvoie le nombre retire.
func _ak_make_room(need: int) -> int:
	var pp: Vector2 = player.global_position
	var fwd: Vector2 = avg_vel.normalized()
	var cand: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or not (e as Enemy).alive or (e as Enemy).rank != 0 or (e as Enemy).behavior == "chasseur":
			continue
		var off: Vector2 = (e as Enemy).global_position - pp
		if off.length_squared() > 1300.0 * 1300.0 and off.dot(fwd) < 0.0:
			cand.append([off.length_squared(), e])
	cand.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	var k: int = 0
	for c in cand:
		if k >= need:
			break
		var en: Enemy = c[1]
		en.alive = false
		en.remove_from_group("enemies")
		en.queue_free()
		k += 1
	ak_stats["recycled"] = int(ak_stats.get("recycled", 0)) + k
	return k

func _live_chasseurs() -> int:
	var k: int = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and (e as Enemy).alive and (e as Enemy).behavior == "chasseur":
			k += 1
	return k

func _chasseur_cap() -> int:
	return CH_CAP[_ak_diff()] + (EnemyDiv.tier() - 1) / 2

func _chasseur_def() -> Dictionary:
	var pool: Array = BIOME_POOL.get(current_biome, [])
	if pool.is_empty():
		pool = BIOME_POOL["tech"]
	var base_k: String = String(pool[1]) if pool.size() > 1 else String(pool[0])
	if not DEFS.has(base_k):
		return {}
	var d: Dictionary = (DEFS[base_k] as Dictionary).duplicate()
	var t: float = float(EnemyDiv.tier())
	d["name"] = "Chasseur"
	d["role"] = "chasseur"
	d["behavior"] = "chasseur"
	d["bull"] = false
	d["zigzag"] = 0.0
	d["rank"] = 0
	d["w"] = 0
	d["hp"] = float(d.get("hp", 14.0)) * (1.35 + 0.12 * (t - 1.0))
	d["attack_dmg"] = float(d.get("dmg", 4.0)) * (1.7 + 0.15 * (t - 1.0))   # la ruee frappe fort, le contact reste leger
	return d

## Un chasseur : planche riggee de l'essaim du biome, teinte cyan electrique, vitesse > joueur (hors plafond 80 %).
func spawn_chasseur(pos: Vector2) -> Enemy:
	if player == null or not is_instance_valid(player) or game == null:
		return null
	if get_tree().get_nodes_in_group("enemies").size() >= ENEMY_CAP:
		return null
	var d: Dictionary = _chasseur_def()
	if d.is_empty():
		return null
	_sync_div()
	var e: Enemy = Enemy.new()
	e.global_position = _in_map(pos)
	game.enemy_layer.add_child(e)
	e.setup(String((BIOME_POOL.get(current_biome, ["mech01"]) as Array)[0]) + "_chasseur", d, player, game)
	_scale_enemy(e)
	var tb: float = 0.01 * float(EnemyDiv.tier() - 1)
	e.speed = _pbase() * (CH_SPEED[_ak_diff()] + tb)
	e._speed_mult = 1.0
	if e._spr != null:
		e._spr.self_modulate = CH_TINT
	ak_stats["chasseurs"] = int(ak_stats["chasseurs"]) + 1
	return e
