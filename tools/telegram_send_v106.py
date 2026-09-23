# -*- coding: utf-8 -*-
"""Envoie la version 10.6 de MECHA-FORGE (correctifs testeurs) sur le Telegram du patron.

Meme schema que telegram_send_menus.py : le jeton est LU dans la config OpenClaw et
n'est jamais affiche ni ecrit nulle part.

Usage: python tools/telegram_send_v106.py <dossier_des_captures>
"""
import os, sys, json, time
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
import httpx

CFG = r"C:\Users\Administrator\.openclaw\openclaw.json"
cfg = json.load(open(CFG, encoding="utf-8-sig"))


def find_token(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k.lower() in ("bottoken", "token") and isinstance(v, str) and ":" in v \
                    and v.split(":")[0].isdigit():
                return v
            r = find_token(v)
            if r:
                return r
    elif isinstance(o, list):
        for v in o:
            r = find_token(v)
            if r:
                return r
    return None


TOKEN = find_token(cfg)          # jamais affiche
CHAT = "7698730603"
SHOTS = sys.argv[1]
JEU = "https://whimora.itch.io/mecha-forge"

INTRO = (
    "🤖 MECHA-FORGE v10.6 — EN LIGNE\n\n"
    "Les 4 testeurs avaient sorti 22 defauts. Tous corriges, et verifies EN JEU dans "
    "4 formats d'ecran (16:9, portrait, 4:3, 21:9) : zero erreur.\n\n"
    "LES 4 GROS :\n"
    "• La cinematique AVANCE TOUTE SEULE. Avant, si tu ne touchais pas l'ecran, tu "
    "restais bloque a vie sur la 1re image.\n"
    "• Ton mecha est enfin TROUVABLE dans la foule (anneau ambre au sol + chassis plus clair).\n"
    "• On VOIT qu'on encaisse : vignette rouge au coup recu, pulsation sous 30 % de vie.\n"
    "• L'arme de depart claque enfin (projectile +45 %, vraie trainee, impact avec coeur "
    "blanc et anneau).\n\n"
    "Les images qui suivent : la planche de controle, puis le detail."
)

SEQ = [
    ("00_planche.png",          "0/8 — LA PLANCHE : les 9 controles d'un coup d'oeil."),
    ("01_portrait_menu.png",    "1/8 — PORTRAIT. Avant : tout le HUD ecrase en haut a gauche, texte a 7 px. Le menu tient maintenant en entier, REGLAGES compris (nouveau : la musique se coupe sans lancer de partie)."),
    ("02_4_3_menu.png",         "2/8 — 4:3 (tablette). Avant : HISTOIRE entierement hors ecran et le pied de page par-dessus QUOTIDIEN. Les 6 sections tiennent sans defiler."),
    ("03_21_9_draft.png",       "3/8 — 21:9. Avant : 400 px de barre du haut manquants et la carte d'amelioration decalee de 200 px. Barre pleine largeur, panneau centre."),
    ("04_vignette_degats.png",  "4/8 — LA VIGNETTE ROUGE. Avant, 8 % de vie ressemblait a 100 % : aucune image ne disait qu'on encaissait."),
    ("05_marqueur.png",         "5/8 — LE MARQUEUR. Le testeur n'arrivait plus a trouver son propre mecha parmi 22 ennemis. L'anneau ambre est permanent (avant, il fallait une carte optionnelle)."),
    ("06_impact.png",           "6/8 — L'IMPACT. Avant : un dessin au trait dore et le chiffre de degats blanc perdu dans la gerbe blanche. Maintenant coeur blanc + anneau, chiffre cyan a contour epais."),
    ("07_telegraphe_rouge.png", "7/8 — L'ENNEMI ROUGE a gauche : c'est une CHARGE imminente. Avant, l'alerte etait blanche, comme le flash de « j'ai touche » — on ne la distinguait pas."),
    ("08_ecran_mort.png",       "8/8 — ECRAN DE MORT PROPRE. Avant, le HUD et la carte d'amelioration restaient affiches par-dessus."),
]

OUTRO = (
    "AUSSI CORRIGE : REJOUER remonte en tete (il fallait 3 crans de molette), l'accueil "
    "n'annonce plus « NORMAL » quand le chapitre lance FACILE, l'auto-visee etait forcee "
    "par une ligne de test oubliee, les carres vides ★ et ◈ ont disparu, les cinematiques "
    "de secteur n'affichent plus le fond d'ecran du menu, ZQSD marche, le stick tactile est "
    "dessine, et il y a enfin de la musique dans les menus.\n\n"
    "EQUILIBRAGE : l'aimant a XP passe de 50 a 165 px — avant, fuir (la seule strategie "
    "viable) t'empechait de ramasser : le testeur est mort avec 51 ennemis tues et TOUJOURS "
    "niveau 1. Et fini les 65 % d'ecrans vides entre deux vagues.\n\n"
    "GARAGE : 2 mechas au lieu d'1 (BLUESTRIKE). J'ai regarde les planches des autres "
    "chassis image par image : george, darkstar et new_mecha ont des bakes rates, je ne "
    "les ai pas mis.\n\n"
    "⚠️ L'APK n'est PAS reconstruit (web seulement, comme toujours). Attention : itch "
    "affiche quand meme « 10.6 » sur le canal Android alors que c'est l'ancien fichier.\n\n"
    "🎮 A tester : " + JEU + "\n"
    "(la page du jeu est en BROUILLON sur itch : elle s'ouvre quand tu es connecte a ton "
    "compte, mais elle renvoie 404 pour tout le monde d'autre — verifie a l'instant. Si tu "
    "veux la rendre publique, c'est dans les reglages du projet cote itch.)"
)


def main():
    if not TOKEN:
        print("ERREUR: token Telegram introuvable dans la config.")
        return 1
    print("token OK (masque) | chat", CHAT)
    envoyes = 0
    with httpx.Client(timeout=180) as c:
        r = c.post("https://api.telegram.org/bot%s/sendMessage" % TOKEN,
                   data={"chat_id": CHAT, "text": INTRO})
        print("intro:", r.json().get("ok"))
        for fn, cap in SEQ:
            p = os.path.join(SHOTS, fn)
            if not os.path.exists(p):
                print("  MANQUANT:", fn)
                continue
            with open(p, "rb") as fh:
                # sendPhoto recompresse : pour des captures d'interface on veut le detail,
                # donc on envoie en DOCUMENT (le patron lit les petits textes du HUD dessus).
                r = c.post("https://api.telegram.org/bot%s/sendDocument" % TOKEN,
                           data={"chat_id": CHAT, "caption": cap[:1020]},
                           files={"document": (fn, fh, "image/png")})
            ok = r.json().get("ok")
            print("  %-26s %s" % (fn, ok))
            if ok:
                envoyes += 1
            time.sleep(1.2)          # anti-limitation de debit Telegram
        r = c.post("https://api.telegram.org/bot%s/sendMessage" % TOKEN,
                   data={"chat_id": CHAT, "text": OUTRO, "disable_web_page_preview": False})
        print("outro:", r.json().get("ok"))
    print("=> %d/%d images envoyees" % (envoyes, len(SEQ)))
    return 0 if envoyes == len(SEQ) else 1


sys.exit(main())
