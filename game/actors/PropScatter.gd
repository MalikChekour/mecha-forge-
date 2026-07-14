extends Node2D
class_name PropScatter
## Scatters the Gemini decor sprites across the arena, coherently per biome. Every prop is a
## StaticBody2D (blocks the player; enemies steer around it via Game.cover_list). Some crates are
## DESTRUCTIBLE and drop a skill bonus; the rest are indestructible obstacles.

var game: Node
var biome: String = "tech"

# kind -> f(ile g<n>), hp, sz(on-screen height px), destruct, skill(chance a broken crate holds a
# competence), glow(optional accent colour for emissive props)
const DECOR: Dictionary = {
	"baril":      {"f": "g20", "hp": 30.0,  "sz": 88.0,  "destruct": true,  "skill": 0.35},
	"caisses":    {"f": "g21", "hp": 26.0,  "sz": 96.0,  "destruct": true,  "skill": 0.50},
	"generateur": {"f": "g22", "hp": 130.0, "sz": 124.0, "glow": "cyan"},
	"antenne":    {"f": "g23", "hp": 80.0,  "sz": 132.0},
	"conduit":    {"f": "g24", "hp": 90.0,  "sz": 112.0, "glow": "cyan"},
	"emetteur":   {"f": "g25", "hp": 100.0, "sz": 118.0, "glow": "cyan"},
	"epave":      {"f": "g26", "hp": 240.0, "sz": 150.0},
	"tourelle":   {"f": "g27", "hp": 140.0, "sz": 130.0},
	"container":  {"f": "g28", "hp": 34.0,  "sz": 140.0, "destruct": true,  "skill": 0.55},
	"rocher":     {"f": "g29", "hp": 170.0, "sz": 120.0},
	"cristaux":   {"f": "g30", "hp": 48.0,  "sz": 110.0, "destruct": true,  "skill": 0.25, "glow": "cyan"},
	"arbre":      {"f": "g31", "hp": 70.0,  "sz": 142.0},
	"plante":     {"f": "g32", "hp": 40.0,  "sz": 100.0, "destruct": true,  "glow": "green"},
	"glace":      {"f": "g33", "hp": 58.0,  "sz": 122.0, "destruct": true},
	"arche":      {"f": "g34", "hp": 190.0, "sz": 152.0},
	"lave":       {"f": "g35", "hp": 150.0, "sz": 112.0, "glow": "orange"},
	"racines":    {"f": "g36", "hp": 95.0,  "sz": 132.0, "glow": "green"},
	# --- ruined-city map (guerre des robots) ---
	"immeuble":   {"f": "g37",  "hp": 400.0, "sz": 224.0, "glow": "cyan"},   # ruined tower — big obstacle
	"immeuble2":  {"f": "g37b", "hp": 400.0, "sz": 212.0},
	"vaisseau":   {"f": "g39",  "hp": 350.0, "sz": 202.0},                   # crashed dropship
	"vaisseau2":  {"f": "g39b", "hp": 350.0, "sz": 196.0},
	"voiture":    {"f": "g40",  "hp": 45.0,  "sz": 120.0, "destruct": true, "skill": 0.30},
	"gravats":    {"f": "g41",  "hp": 30.0,  "sz": 102.0, "destruct": true},
	"gravats2":   {"f": "g41b", "hp": 30.0,  "sz": 110.0, "destruct": true},
	"pylone":     {"f": "g42",  "hp": 90.0,  "sz": 150.0},
	"panneau":    {"f": "g43",  "hp": 70.0,  "sz": 150.0, "glow": "cyan"},
	"barricade":  {"f": "g44",  "hp": 40.0,  "sz": 130.0, "destruct": true, "skill": 0.40},
	"carcasse":   {"f": "g45",  "hp": 300.0, "sz": 172.0},
	# --- biome enrichers ---
	"lave_geyser":{"f": "g47",  "hp": 9999.0,"sz": 132.0, "glow": "orange"},
	"champignon": {"f": "g48",  "hp": 40.0,  "sz": 122.0, "destruct": true, "glow": "cyan"},
	"campement":  {"f": "g49",  "hp": 50.0,  "sz": 122.0, "destruct": true},
	"epave_gel":  {"f": "g50",  "hp": 120.0, "sz": 132.0},
	"serveurs":   {"f": "g51",  "hp": 60.0,  "sz": 122.0, "glow": "cyan"},
	"capsule":    {"f": "g52",  "hp": 80.0,  "sz": 116.0, "glow": "cyan"},
}
# Biome-coherent placement: climate/nature props ONLY in their biome (no ice in the spaceship);
# generic industrial (baril/caisses/container/epave) shows up as scattered wreckage most places.
const BIOME_DECOR: Dictionary = {
	"earth":     ["rocher", "arbre", "epave", "caisses", "baril", "rocher"],
	"volcanic":  ["lave", "lave", "lave_geyser", "epave", "rocher", "baril", "caisses"],
	"spaceship": ["generateur", "conduit", "emetteur", "container", "caisses", "baril", "cristaux", "tourelle", "antenne", "serveurs", "capsule"],
	"tech":      ["generateur", "conduit", "antenne", "baril", "caisses", "tourelle", "cristaux", "container", "serveurs"],
	"desert":    ["arche", "rocher", "arbre", "epave", "caisses", "baril", "campement"],
	"ice":       ["glace", "glace", "cristaux", "epave", "caisses", "rocher", "epave_gel"],
	"jungle":    ["plante", "racines", "rocher", "arbre", "plante", "champignon"],
	"swamp":     ["racines", "plante", "arbre", "rocher", "racines"],
	"ruines":    ["immeuble", "immeuble2", "vaisseau", "vaisseau2", "voiture", "gravats", "gravats2",
	              "pylone", "panneau", "barricade", "carcasse", "gravats"],
}

func populate(count: int = 28) -> void:
	var kinds: Array = BIOME_DECOR.get(biome, BIOME_DECOR["tech"])
	var placed: Array = []               # [{pos, gap}] — gap scales with prop size
	var tries: int = 0
	while placed.size() < count and tries < count * 6:
		tries += 1
		var pos: Vector2 = Vector2(randf_range(-2000.0, 2000.0), randf_range(-2000.0, 2000.0))
		if pos.length() < 340.0:
			continue                     # keep the spawn area clear
		var kind: String = String(kinds[randi() % kinds.size()])
		# footprint radius: big ruins props (immeuble/vaisseau) need far more room so their
		# enemy-repulsion bubbles never overlap (which would jitter/bottleneck the swarm).
		var gap: float = 55.0 + float((DECOR.get(kind, {}) as Dictionary).get("sz", 110.0)) * 0.45
		var ok: bool = true
		for e in placed:
			if pos.distance_to(e["pos"]) < gap + float(e["gap"]):
				ok = false; break
		if not ok:
			continue
		placed.append({"pos": pos, "gap": gap})
		_place(kind, pos)

func _place(kind: String, pos: Vector2) -> void:
	var prop: Prop = Prop.new()
	prop.game = game
	prop.kind = kind
	prop.def = DECOR.get(kind, {})
	prop.position = pos
	add_child(prop)

class Prop extends StaticBody2D:
	var game: Node
	var kind: String
	var def: Dictionary
	var hp: float
	var block_r: float = 40.0        # radius enemies steer around (read by Enemy)
	var _sprite: Sprite2D
	var _skill: bool = false

	func _ready() -> void:
		hp = float(def.get("hp", 60.0))
		var tex: Texture2D = load("res://assets/decor/%s.png" % String(def.get("f", "g20")))
		var th: float = maxf(1.0, float(tex.get_height()))
		var sc: float = randf_range(0.86, 1.16) * (float(def.get("sz", 110.0)) / th)
		var spanx: float = float(tex.get_width()) * sc
		var spany: float = th * sc

		# ground contact shadow -> the prop sits in the world instead of floating
		var shadow: Sprite2D = Sprite2D.new()
		shadow.texture = Tex.glow(Color(0, 0, 0, 1), 64)
		shadow.modulate = Color(0, 0, 0, 0.5)
		shadow.position = Vector2(0.0, spany * 0.36)
		shadow.scale = Vector2(spanx / 64.0 * 0.66, spany / 64.0 * 0.20)
		shadow.z_index = -2
		add_child(shadow)

		_sprite = Sprite2D.new()
		_sprite.texture = tex
		_sprite.scale = Vector2.ONE * sc
		add_child(_sprite)

		var glow: String = String(def.get("glow", ""))
		if glow != "":
			var gc: Color = Palette.CYAN
			if glow == "green": gc = Color(0.4, 1.0, 0.5)
			elif glow == "orange": gc = Color(1.0, 0.55, 0.2)
			var l: PointLight2D = PointLight2D.new()
			l.texture = Tex.glow(gc, 128); l.color = gc; l.energy = 0.7
			l.texture_scale = maxf(spanx, spany) / 128.0 * 1.8
			add_child(l)

		# a destructible crate MAY hold a competence -> warm gold tell so the player breaks it
		if bool(def.get("destruct", false)) and randf() < float(def.get("skill", 0.0)):
			_skill = true
			var bl: PointLight2D = PointLight2D.new()
			bl.texture = Tex.glow(Palette.BONUS, 128); bl.color = Palette.BONUS; bl.energy = 1.2
			bl.texture_scale = maxf(spanx, spany) / 128.0 * 2.2
			add_child(bl)

		# collision: blocks the player (mask 8) and bullets; enemies avoid via Game.cover_list
		block_r = maxf(spanx, spany) * 0.30
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = block_r
		var col: CollisionShape2D = CollisionShape2D.new()
		col.shape = shape
		col.position = Vector2(0.0, spany * 0.12)   # centre the collider on the base, not the top
		add_child(col)
		add_to_group("cover")
		collision_layer = 8
		collision_mask = 0
		if game != null and "cover_list" in game:
			game.cover_list.append(self)

	func take_damage(amount: float) -> void:
		if not bool(def.get("destruct", false)):
			return   # indestructible obstacle (bullets already stopped by the collider)
		hp -= amount
		if hp <= 0.0:
			if game != null:
				if game.has_method("death_fx"):
					game.death_fx(global_position, 0)
				if _skill and game.has_method("spawn_skill"):
					game.spawn_skill(global_position)          # the reward: a competence
				elif game.has_method("spawn_scrap"):
					game.spawn_scrap(global_position, 2 + randi() % 3)
				if "cover_list" in game:
					game.cover_list.erase(self)
			call_deferred("queue_free")
		else:
			var tw: Tween = create_tween()
			tw.tween_property(_sprite, "modulate", Color(2.2, 2.2, 2.4), 0.05)
			tw.tween_property(_sprite, "modulate", Color.WHITE, 0.15)
