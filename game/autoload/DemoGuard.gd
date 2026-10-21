extends Node
## ==============================================================================
## DEMO GUARD - MOUCHARD & PROTECTION ANTI-VOL TEMPORAIRE (DEMO UNIQUEMENT)
## ==============================================================================
## Ce module protège la démo de MECHA-FORGE contre les copies et vols non autorisés :
##
##  [OPTION 1] BALISE TÉLÉMÉTRIQUE / CANARY PING :
##    - Interroge le navigateur (domaine, URL complète, référent, horodatage, version).
##    - Si TELEMETRY_WEBHOOK_URL est configuré (ex: Discord Webhook, Cloudflare Worker),
##      envoie un ping HTTP silencieux dès le lancement ou dès qu'un domaine suspect est détecté.
##
##  [OPTION 4] KILL-SWITCH À DISTANCE (INTERRUPTEUR D'URGENCE) :
##    - Interroge REMOTE_KILLSWITCH_URL (ex: Gist GitHub public contenant {"kill": false}).
##    - Si vous basculez {"kill": true} à distance, le jeu se verrouille immédiatement
##      avec un écran d'information élégant, rendant toute copie volée inutilisable.
##    - En cas d'absence de réseau ou d'URL vide, le jeu reste parfaitement jouable (fail-safe).
##
##  [DOMAIN LOCK & FILIGRANE] :
##    - Autorise uniquement les domaines officiels (itch.io, CDN itch, localhost).
##    - Si hébergé illégalement ailleurs, active le filigrane anti-vol permanent.
##
## POUR LE DÉPLOIEMENT FINAL :
##  - Mettre DEMO_GUARD_ACTIVE = false ci-dessous, OU
##  - Supprimer la ligne DemoGuard dans game/project.godot sous [autoload].
## ==============================================================================

const DEMO_GUARD_ACTIVE: bool = true
const DEMO_VERSION: String = "v11.90-DEMO"
const OFFICIAL_URL: String = "https://itch.io"

# ------------------------------------------------------------------------------
# CONFIGURATION DU MOUCHARD (OPTIONS 1 & 4)
# ------------------------------------------------------------------------------
# OPTION 1 : URL Webhook pour recevoir les alertes de lancement / vol en direct
# Exemple : "https://discord.com/api/webhooks/123456789/abcdef..."
const TELEMETRY_WEBHOOK_URL: String = ""
# TELEGRAM DIRECT : Alerte instantanée sur Telegram (Agent MK / Bot)
const TELEGRAM_ALERT_ACTIVE: bool = true
const TELEGRAM_CHAT_ID: String = "7698730603"
const TELEGRAM_BOT_TOKEN_B64: String = "Nzk1OTc2MTkyNTpBQUVwcUdzMXhySXp3MjBydmt2ZnZibjdjVE1kWmVISFl3RQ=="


# OPTION 4 : URL distante pour le Kill-Switch (Gist GitHub, Pastebin, JSON statique)
# Format attendu du JSON distant : {"kill": false, "message": "Démo terminée."}
# Si "kill": true, la démo se verrouille automatiquement.
const REMOTE_KILLSWITCH_URL: String = ""

# Domaines autorisés pour la démo
const ALLOWED_DOMAINS: Array[String] = [
	"localhost",
	"127.0.0.1",
	"0.0.0.0",
	"itch.io",
	"itch.zone",
	"hwcdn.net" # CDN officiel itch.io
]

var is_pirated: bool = false
var is_killed_remotely: bool = false
var detected_domain: String = "native"
var detected_url: String = ""
var detected_referrer: String = ""
var detected_tz: String = ""
var detected_lang: String = ""
var detected_res: String = ""
var detected_ua: String = ""
var detected_gpu: String = ""

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
	
	# Option 1 : Télémétrie / Canary Ping
	if is_pirated or TELEMETRY_WEBHOOK_URL != "":
		_send_canary_beacon()
	
	# Option 4 : Vérification du Kill-Switch à distance
	if REMOTE_KILLSWITCH_URL != "":
		_check_remote_killswitch()
	
	if is_pirated:
		_send_telegram_alert()
		_setup_tamper_warning()

func _inspect_environment() -> void:
	if not OS.has_feature("web"):
		detected_domain = "desktop_or_test"
		return
	
	var js_host: Variant = JavaScriptBridge.eval("window.location.hostname")
	var js_href: Variant = JavaScriptBridge.eval("window.location.href")
	var js_ref: Variant = JavaScriptBridge.eval("document.referrer")
	var js_tz: Variant = JavaScriptBridge.eval("try { Intl.DateTimeFormat().resolvedOptions().timeZone } catch(e) { '' }")
	var js_lang: Variant = JavaScriptBridge.eval("navigator.language || ''")
	var js_res: Variant = JavaScriptBridge.eval("window.screen ? (window.screen.width + 'x' + window.screen.height) : ''")
	var js_ua: Variant = JavaScriptBridge.eval("navigator.userAgent || ''")
	var js_gpu: Variant = JavaScriptBridge.eval("(function(){ try { var c = document.createElement('canvas'); var gl = c.getContext('webgl') || c.getContext('experimental-webgl'); if (!gl) return ''; var ext = gl.getExtension('WEBGL_debug_renderer_info'); return ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : ''; } catch(e){ return ''; } })()")
	
	if js_host != null:
		detected_domain = str(js_host).to_lower()
	if js_href != null:
		detected_url = str(js_href)
	if js_ref != null:
		detected_referrer = str(js_ref)
	if js_tz != null:
		detected_tz = str(js_tz)
	if js_lang != null:
		detected_lang = str(js_lang)
	if js_res != null:
		detected_res = str(js_res)
	if js_ua != null:
		detected_ua = str(js_ua)
	if js_gpu != null:
		detected_gpu = str(js_gpu)
	
	var authorized: bool = false
	for allowed in ALLOWED_DOMAINS:
		if detected_domain == allowed or detected_domain.ends_with("." + allowed):
			authorized = true
			break
	
	if not authorized and detected_domain != "":
		is_pirated = true

## ==============================================================================
## [OPTION 1] ENVOI DE LA BALISE TÉLÉMÉTRIQUE (CANARY PING)
## ==============================================================================

## ==============================================================================
## [TELEGRAM] ALERTE EN TEMPS RÉEL SUR TELEGRAM (AGENT MK)
## ==============================================================================
func _send_telegram_alert(is_test: bool = false) -> void:
	if not TELEGRAM_ALERT_ACTIVE or TELEGRAM_BOT_TOKEN_B64 == "" or TELEGRAM_CHAT_ID == "":
		return
	
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	http.timeout = 5.0
	http.request_completed.connect(func(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		http.queue_free()
	)
	
	var token: String = Marshalls.base64_to_utf8(TELEGRAM_BOT_TOKEN_B64)
	var url: String = "https://api.telegram.org/bot" + token + "/sendMessage"
	
	var msg: String = ""
	if is_test:
		msg = "🛡️ *[MECHA-FORGE] TEST TELEGRAM DU MOUCHARD REÇU !*\n\n"
		msg += "✅ Votre jeu est correctement relié à votre bot Telegram.\n"
		msg += "📦 Version : `" + DEMO_VERSION + "`"
	else:
		msg = "🚨 *[MECHA-FORGE] ALERTE COPIE NON AUTORISÉE DÉTECTÉE !* 🚨\n\n"
		msg += "🌐 *Domaine voleur :* `" + detected_domain + "`\n"
		if detected_url != "":
			msg += "🔗 *URL complète :* " + detected_url + "\n"
		if detected_referrer != "":
			msg += "📍 *Référent :* " + detected_referrer + "\n"
		if detected_tz != "" or detected_lang != "":
			msg += "🌍 *Localisation :* Fuseau `" + (detected_tz if detected_tz != "" else "Inconnu") + "` · Langue `" + (detected_lang if detected_lang != "" else "Inconnue") + "`\n"
		if detected_ua != "":
			msg += "💻 *Navigateur / OS :* `" + detected_ua + "`\n"
		if detected_gpu != "":
			msg += "🎮 *GPU :* `" + detected_gpu + "`\n"
		if detected_res != "":
			msg += "📐 *Résolution écran :* `" + detected_res + "`\n"
		msg += "🕒 *Date/Heure :* " + Time.get_datetime_string_from_system() + "\n"
		msg += "📦 *Version :* `" + DEMO_VERSION + "`\n\n"
		msg += "⚠️ _Le filigrane anti-vol rouge clignotant a été déployé sur la partie du voleur._"
	
	var payload: Dictionary = {
		"chat_id": TELEGRAM_CHAT_ID,
		"text": msg,
		"parse_mode": "Markdown"
	}
	var json_body: String = JSON.stringify(payload)
	var headers: PackedStringArray = ["Content-Type: application/json"]
	http.request(url, headers, HTTPClient.METHOD_POST, json_body)

func _send_canary_beacon() -> void:
	# Trace discrète dans la console navigateur
	if OS.has_feature("web"):
		var js_log: String = "console.info('[MECHA-FORGE] Build Security: " + DEMO_VERSION + " | Host: " + detected_domain.replace("'", "") + "');"
		JavaScriptBridge.eval(js_log)
	
	if TELEMETRY_WEBHOOK_URL == "":
		return
	
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	http.timeout = 5.0
	http.request_completed.connect(func(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		http.queue_free()
	)
	
	var payload: Dictionary = {
		"event": "unauthorized_copy_detected" if is_pirated else "demo_session_start",
		"domain": detected_domain,
		"url": detected_url,
		"referrer": detected_referrer,
		"version": DEMO_VERSION,
		"timestamp": Time.get_datetime_string_from_system()
	}
	var json_body: String = JSON.stringify(payload)
	var headers: PackedStringArray = ["Content-Type: application/json"]
	http.request(TELEMETRY_WEBHOOK_URL, headers, HTTPClient.METHOD_POST, json_body)

## ==============================================================================
## [OPTION 4] VÉRIFICATION DU KILL-SWITCH DISTANT
## ==============================================================================
func _check_remote_killswitch() -> void:
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	http.timeout = 4.0
	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			var text: String = body.get_string_from_utf8()
			var parse_res: Variant = JSON.parse_string(text)
			if parse_res is Dictionary:
				var data: Dictionary = parse_res as Dictionary
				var killed: bool = bool(data.get("kill", false)) or not bool(data.get("demo_enabled", true))
				if killed:
					var msg: String = String(data.get("message", "Cette version de démonstration a été désactivée."))
					_trigger_killswitch_lock(msg)
		http.queue_free()
	)
	http.request(REMOTE_KILLSWITCH_URL)

func _trigger_killswitch_lock(custom_msg: String) -> void:
	is_killed_remotely = true
	get_tree().paused = true
	
	var kill_layer: CanvasLayer = CanvasLayer.new()
	kill_layer.layer = 150 # Au-dessus de tout
	add_child(kill_layer)
	
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.08, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	kill_layer.add_child(bg)
	
	var vb: VBoxContainer = VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	kill_layer.add_child(vb)
	
	var title: Label = Label.new()
	title.text = "MECHA-FORGE  ·  DÉMONSTRATION FERMÉE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	vb.add_child(title)
	
	var desc: Label = Label.new()
	desc.text = "\n" + custom_msg + "\n\nRetrouvez la version officielle sur :\n" + OFFICIAL_URL
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 20)
	desc.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	vb.add_child(desc)

## ==============================================================================
## GESTION DU FILIGRANE ANTI-VOL (POUR SITES PIRATES)
## ==============================================================================
func _setup_tamper_warning() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 125
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
	if _timer >= 60.0 and not _trap_active:
		_trap_active = true
		if _banner_bg != null:
			_banner_bg.visible = true
		if _banner_label != null:
			_banner_label.visible = true
	
	if _trap_active and _banner_label != null:
		var pulse: float = 0.7 + 0.3 * sin(_timer * 3.0)
		_banner_label.modulate.a = pulse
