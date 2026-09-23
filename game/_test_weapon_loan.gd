extends Node
## Headless regression harness for l'EMPRUNT D'ARME "BUTIN DE GUERRE" (patron, 23/09).
## Teste directement WeaponSystem.borrow_weapon()/return_borrowed_weapon() — sans passer par
## un vrai combat de boss, dont le bot headless n'a pas le DPS pour venir a bout en temps
## raisonnable (mesure : 950 PV + 240 de bouclier, bot jamais vu en tuer un en ~100s testees).
##   godot --headless --path game res://_test_weapon_loan.tscn

var _fail: int = 0

func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", label, ("   " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, "   ", detail)

func _ready() -> void:
	print("=== TEST EMPRUNT D'ARME ===")
	var dummy: Node2D = Node2D.new()
	add_child(dummy)
	var ws: WeaponSystem = WeaponSystem.new()
	add_child(ws)
	ws.setup(dummy, ["autocannon"])

	# --- 1. etat de depart ---
	_ok(ws.owned_weapons() == ["autocannon"], "loadout de depart = [autocannon]",
		"obtenu=%s" % str(ws.owned_weapons()))
	_ok(not ws.is_borrowing(), "pas d'emprunt actif au depart")

	# --- 2. emprunter une arme valide, absente du loadout ---
	var ok1: bool = ws.borrow_weapon("railgun")
	_ok(ok1, "emprunt de railgun reussi")
	_ok(ws.is_borrowing(), "is_borrowing() vrai pendant l'emprunt")
	_ok(ws.owned_weapons() == ["railgun"], "le slot 0 porte maintenant railgun",
		"obtenu=%s" % str(ws.owned_weapons()))
	_ok(int(ws._weapons.get("railgun", {}).get("level", 0)) == ws.MAX_LEVEL,
		"l'arme empruntee est a pleine puissance")

	# --- 3. un 2e emprunt pendant que le 1er est actif doit echouer (pas d'empilement) ---
	var ok2: bool = ws.borrow_weapon("plasma")
	_ok(not ok2, "un 2e emprunt pendant le 1er est refuse")
	_ok(ws.owned_weapons() == ["railgun"], "le loadout n'a pas bouge apres le refus")

	# --- 4. emprunter une arme DEJA possedee doit echouer (pas de doublon dans le dict) ---
	ws.return_borrowed_weapon()
	var ok3: bool = ws.borrow_weapon("autocannon")   # deja l'arme d'origine
	_ok(not ok3, "emprunter l'arme deja possedee est refuse")

	# --- 5. cycle complet : emprunt puis retour EXACT (meme id, meme niveau) ---
	ws.add_weapon("autocannon")   # remonte au niveau 2 (l'arme d'origine, pour tester la restauration du niveau)
	ws.add_weapon("autocannon")   # niveau 3
	var niveau_avant: int = int(ws._weapons["autocannon"]["level"])
	_ok(niveau_avant == 3, "arme d'origine montee au niveau 3 avant l'emprunt")
	var ok4: bool = ws.borrow_weapon("faisceau")
	_ok(ok4, "emprunt de faisceau reussi")
	ws.return_borrowed_weapon()
	_ok(not ws.is_borrowing(), "is_borrowing() faux apres le retour")
	_ok(ws.owned_weapons() == ["autocannon"], "l'arme d'origine (autocannon) est restauree",
		"obtenu=%s" % str(ws.owned_weapons()))
	_ok(int(ws._weapons.get("autocannon", {}).get("level", -1)) == niveau_avant,
		"le NIVEAU d'origine (3) est restaure, pas remis a 1",
		"obtenu=%d attendu=%d" % [int(ws._weapons.get("autocannon", {}).get("level", -1)), niveau_avant])

	# --- 6. retourner un emprunt deja inactif ne doit rien casser (idempotent) ---
	ws.return_borrowed_weapon()
	_ok(ws.owned_weapons() == ["autocannon"], "un 2e retour sans emprunt actif ne change rien")

	print("=== %s (%d echec(s)) ===" % ["SMOKE PASS" if _fail == 0 else "SMOKE FAIL", _fail])
	get_tree().quit(1 if _fail > 0 else 0)
