extends Node

## Haptics Manager (Game Feel & immersion tactile mobile)
## Centralise toutes les micro-vibrations haptiques pour Android & plateformes mobiles.
## Respecte SaveManager.setting("vibrations", true).

func tap() -> void:
	# Clic subtil : validation draft, bouton tactile UI
	_vibrate(18)

func hurt() -> void:
	# Impact mecha lors de la prise de dégâts
	_vibrate(50)

func heavy() -> void:
	# Détonation d'arme lourde (canon à plasma, salve de missiles)
	_vibrate(30)

func victory() -> void:
	# Victoire de run ou récompense majeure
	_vibrate(40)
	var t: SceneTree = get_tree()
	if t != null:
		t.create_timer(0.10).timeout.connect(func() -> void: _vibrate(85))

func boss_kill() -> void:
	# Écroulement de boss majeur (rank >= 3)
	_vibrate(115)

func overdrive() -> void:
	# Déclenchement de la Surcharge / Overdrive (double impulsion puissante)
	_vibrate(35)
	var t: SceneTree = get_tree()
	if t != null:
		t.create_timer(0.08).timeout.connect(func() -> void: _vibrate(75))

func _vibrate(duration_ms: int) -> void:
	if not bool(SaveManager.setting("vibrations", true)):
		return
	if Input.has_method("vibrate_handheld"):
		Input.vibrate_handheld(duration_ms)
