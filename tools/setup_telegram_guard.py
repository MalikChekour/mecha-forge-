# -*- coding: utf-8 -*-
"""Configure Telegram alert in DemoGuard.gd securely using openclaw.json."""
import json
import base64
import os

CFG = r"C:\Users\Administrator\.openclaw\openclaw.json"
cfg = json.load(open(CFG, encoding="utf-8-sig"))

def find_token(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k.lower() in ("bottoken", "token") and isinstance(v, str) and ":" in v and v.split(":")[0].isdigit():
                return v
            r = find_token(v)
            if r: return r
    elif isinstance(o, list):
        for v in o:
            r = find_token(v)
            if r: return r
    return None

token = find_token(cfg)
if not token:
    print("Error: token not found")
    exit(1)

b64_token = base64.b64encode(token.encode("utf-8")).decode("utf-8")
chat_id = "7698730603"

path = r"game/autoload/DemoGuard.gd"
code = open(path, "r", encoding="utf-8").read()

tg_decl = f'''# TELEGRAM DIRECT : Alerte instantanée sur Telegram (Agent MK / Bot)
const TELEGRAM_ALERT_ACTIVE: bool = true
const TELEGRAM_CHAT_ID: String = "{chat_id}"
const TELEGRAM_BOT_TOKEN_B64: String = "{b64_token}"
'''

if "const TELEGRAM_BOT_TOKEN_B64" not in code:
    code = code.replace('const TELEMETRY_WEBHOOK_URL: String = ""', 'const TELEMETRY_WEBHOOK_URL: String = ""\n' + tg_decl)

tg_send_func = '''
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
		msg = "🛡️ *[MECHA-FORGE] TEST TELEGRAM DU MOUCHARD REÇU !*\\n\\n"
		msg += "✅ Votre jeu est correctement relié à votre bot Telegram.\\n"
		msg += "📦 Version : `" + DEMO_VERSION + "`"
	else:
		msg = "🚨 *[MECHA-FORGE] ALERTE COPIE NON AUTORISÉE DÉTECTÉE !* 🚨\\n\\n"
		msg += "🌐 *Domaine voleur :* `" + detected_domain + "`\\n"
		if detected_url != "":
			msg += "🔗 *URL complète :* " + detected_url + "\\n"
		if detected_referrer != "":
			msg += "📍 *Référent :* " + detected_referrer + "\\n"
		msg += "🕒 *Date/Heure :* " + Time.get_datetime_string_from_system() + "\\n"
		msg += "📦 *Version :* `" + DEMO_VERSION + "`\\n\\n"
		msg += "⚠️ _Le filigrane anti-vol rouge clignotant a été déployé sur la partie du voleur._"
	
	var payload: Dictionary = {
		"chat_id": TELEGRAM_CHAT_ID,
		"text": msg,
		"parse_mode": "Markdown"
	}
	var json_body: String = JSON.stringify(payload)
	var headers: PackedStringArray = ["Content-Type: application/json"]
	http.request(url, headers, HTTPClient.METHOD_POST, json_body)
'''

if "func _send_telegram_alert" not in code:
    code = code.replace("func _send_canary_beacon() -> void:", tg_send_func + "\nfunc _send_canary_beacon() -> void:")

# Connect in _ready()
if "_send_telegram_alert()" not in code:
    code = code.replace("if is_pirated:\n\t\t_setup_tamper_warning()", "if is_pirated:\n\t\t_send_telegram_alert()\n\t\t_setup_tamper_warning()")

open(path, "w", encoding="utf-8").write(code)
print("SUCCESS: DemoGuard.gd updated with Telegram alert capability.")
