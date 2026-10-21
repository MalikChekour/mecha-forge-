extends Node
## ==============================================================================
## DEMO GUARD - MOUCHARD & PROTECTION ANTI-VOL TEMPORAIRE (DEMO UNIQUEMENT)
## ==============================================================================
## Ce module protège la démo de MECHA-FORGE contre les copies et vols non autorisés :
## 1. Mouchard / Balise : détecte le domaine web où tourne le jeu et l'URL source.
## 2. Domain-Lock : autorise uniquement les domaines officiels (itch.io, CDN itch, localhost).
## 3. Filigrane & Dégradation : si le jeu est hébergé illégalement sur un autre site,
##    un filigrane anti-vol permanent apparaît et avertit les joueurs de la contrefaçon.
##
## POUR LE DÉPLOIEMENT FINAL :
## - Passer DEMO_GUARD_ACTIVE à false ci-dessous, OU
## - Supprimer la ligne DemoGuard dans game/project.godot sous [autoload].
## ==============================================================================

const DEMO_GUARD_ACTIVE: bool = true
const DEMO_VERSION: String = "v11.90-DEMO"
const OFFICIAL_URL: String = "https://itch.io"

# Domaines autorisés pour la démo
const ALLOWED_DOMAINS: Array[String] = [
	"localhost",
	"127.0.0.1",
	"0.0.0.0",
	"itch.io",
	"itch.zone",
	"hwcdn.net" # CDN officiel itch.io
]

# URL optionnelle de webhook / balise de signalement (ex: Discord Webhook, Cloudflare worker, etc.)
# Si laissée vide, la balise enregistre la trace en console JS et applique la protection locale.
const TELEMETRY_WEBHOOK_URL: String = ""

var is_pirated: bool = false
var detected_domain: String = "native"
var detected_url: String = ""
var detected_referrer: String = ""

var _timer: float = 0.0
var _trap_active: bool = false
var _banner_label: Label = null
var _banner_bg: ColorRect = null
var _canvas_layer: CanvasLayer = null

func _ready() -> void:
	if not DEMO_GUARD_ACTIVE:
		return
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	_inspect_environment()
	
	if is_pirated:
		_setup_tamper_warning()

func _inspect_environment() -> void:
	if not OS.has_feature("web"):
		detected_domain = "desktop_or_test"
		return
	
	# Récupération sécurisée du domaine dans l'environnement Web
	var js_host: Variant = JavaScriptBridge.eval("window.location.hostname")
	var js_href: Variant = JavaScriptBridge.eval("window.location.href")
	var js_ref: Variant = JavaScriptBridge.eval("document.referrer")
	
	if js_host != null:
		detected_domain = str(js_host).to_lower()
	if js_href != null:
		detected_url = str(js_href)
	if js_ref != null:
		detected_referrer = str(js_ref)
	
	# Vérification du domaine
	var authorized: bool = false
	for allowed in ALLOWED_DOMAINS:
		if detected_domain == allowed or detected_domain.ends_with("." + allowed):
			authorized = true
			break
	
	if not authorized and detected_domain != "":
		is_pirated = true
		_send_canary_beacon()

func _send_canary_beacon() -> void:
	# Trace discrète dans la console du navigateur
	var js_log: String = "console.warn('[MECHA-FORGE] Version Démo Protégée. Hôte: " + detected_domain.replace("'", "") + "');"
	JavaScriptBridge.eval(js_log)
	
	# Envoi balise HTTP silencieuse si une URL de télémétrie est configurée
	if TELEMETRY_WEBHOOK_URL != "":
		var http: HTTPRequest = HTTPRequest.new()
		add_child(http)
		var payload: Dictionary = {
			"event": "unauthorized_demo_hosted",
			"domain": detected_domain,
			"url": detected_url,
			"referrer": detected_referrer,
			"version": DEMO_VERSION,
			"timestamp": Time.get_datetime_string_from_system()
		}
		var json_body: String = JSON.stringify(payload)
		var headers: PackedStringArray = ["Content-Type: application/json"]
		http.request(TELEMETRY_WEBHOOK_URL, headers, HTTPClient.METHOD_POST, json_body)

func _setup_tamper_warning() -> void:
	# Couche UI invisible au départ, qui s'active après un délai de 60s de jeu
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 125 # Au-dessus de tout le jeu
	add_child(_canvas_layer)
	
	_banner_bg = ColorRect.new()
	_banner_bg.color = Color(0.12, 0.02, 0.02, 0.88)
	_banner_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner_bg.size = Vector2(1280, 54)
	_banner_bg.visible = false
	_canvas_layer.add_child(_banner_bg)
	
	_banner_label = Label.new()
	_banner_label.text = "⚠️ COPIE NON AUTORISÉE DÉTECTÉE SUR " + detected_domain.to_upper() + " — MECHA-FORGE EST UNE DÉMO OFFICIELLE ITCH.IO"
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner_label.size = Vector2(1280, 54)
	_banner_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	_banner_label.visible = false
	_canvas_layer.add_child(_banner_label)

func _process(delta: float) -> void:
	if not DEMO_GUARD_ACTIVE or not is_pirated:
		return
	
	_timer += delta
	# Après 60 secondes de jeu pirate : affichage du filigrane anti-vol
	if _timer >= 60.0 and not _trap_active:
		_trap_active = true
		if _banner_bg != null:
			_banner_bg.visible = true
		if _banner_label != null:
			_banner_label.visible = true
	
	# Effet de clignotement subtil du filigrane
	if _trap_active and _banner_label != null:
		var pulse: float = 0.7 + 0.3 * sin(_timer * 3.0)
		_banner_label.modulate.a = pulse
