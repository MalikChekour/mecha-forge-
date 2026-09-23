# -*- coding: utf-8 -*-
"""Envoie les captures des styles de menu MECHA-FORGE sur le Telegram du patron."""
import os, sys, json
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
import httpx

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

TOKEN = find_token(cfg)          # jamais affiche
CHAT = "7698730603"
SHOTS = sys.argv[1]
LINK = "https://claude.ai/code/artifact/d972a226-af42-403a-9973-d485e47c6db9"

INTRO = ("🎛️ MECHA-FORGE — le menu : diagnostic + 5 styles\n\n"
         "Le menu d'accueil est pose en PIXELS ABSOLUS sur 1280x720, alors que le jeu s'etire "
         "selon l'ecran (aspect=expand). C'est pour ca qu'il est mal calibre. Les 3 premieres "
         "images le montrent, les 5 suivantes sont les styles proposes.")

SEQ = [
 ("menu_0_actuel.png",            "1/8 — ACTUEL en 16:9 : la SEULE taille ou il tombe juste."),
 ("menu_x_probleme_4_3.png",      "2/8 — ACTUEL en 4:3 (tablette) : chips '340' et '12 cristaux' COUPEES, HISTOIRE a disparu, QUOTIDIEN tronque."),
 ("menu_x_probleme_21_9.png",     "3/8 — ACTUEL en 21:9 : tout reste colle a gauche, ~400px de vide a droite, JOUER n'est plus centre."),
 ("menu_1_cinema.png",            "4/8 — STYLE 1 · CINEMA : ton menu actuel, juste recalibre. Meme identite, zero depaysement, le moins de travail."),
 ("menu_2_dock_lateral.png",      "5/8 — STYLE 2 · DOCK LATERAL : nav verticale a gauche, mecha en vedette, JOUER en bas-droite. La meilleure ergonomie en paysage (les 2 pouces)."),
 ("menu_3_carte_chapitre.png",    "6/8 — STYLE 3 · CARTE CHAPITRE : facon Survivor.io. La progression (chapitre, %, prochaine recompense) devient le coeur + barre de nav en bas."),
 ("menu_4_panneaux_tactiques.png","7/8 — STYLE 4 · PANNEAUX TACTIQUES : grille 2x2 de panneaux informatifs ('3 ameliorations dispo'), JOUER en barre pleine."),
 ("menu_5_epure.png",             "8/8 — STYLE 5 · EPURE : l'art domine, un seul geste evident, le reste dans un rail discret."),
]

OUTRO = ("Dis-moi lequel te plait (ou un melange, ex. « le 2 avec la carte de chapitre du 3 ») "
         "et je l'implemente avec de vraies ancres, puis je push.\n\n"
         "Module interactif (tu peux changer le ratio 4:3 -> 21:9 toi-meme) :\n" + LINK)

def main():
    if not TOKEN:
        print("ERREUR: token Telegram introuvable dans la config."); return 1
    print("token OK (masque) | chat", CHAT)
    ok = 0
    with httpx.Client(timeout=120) as c:
        r = c.post("https://api.telegram.org/bot%s/sendMessage" % TOKEN,
                   data={"chat_id": CHAT, "text": INTRO})
        print("intro:", r.json().get("ok"))
        for fn, cap in SEQ:
            p = os.path.join(SHOTS, fn)
            if not os.path.exists(p):
                print("  MANQUANT:", fn); continue
            sent = False
            for _ in range(3):
                with open(p, "rb") as fh:
                    r = c.post("https://api.telegram.org/bot%s/sendPhoto" % TOKEN,
                               data={"chat_id": CHAT, "caption": cap},
                               files={"photo": (fn, fh, "image/png")})
                j = r.json()
                if j.get("ok"):
                    print("  envoye:", fn); ok += 1; sent = True; break
                print("  retry:", fn, str(j)[:120])
            if not sent:
                print("  ECHEC:", fn)
        r = c.post("https://api.telegram.org/bot%s/sendMessage" % TOKEN,
                   data={"chat_id": CHAT, "text": OUTRO, "disable_web_page_preview": "true"})
        print("outro:", r.json().get("ok"))
    print("photos envoyees: %d/%d" % (ok, len(SEQ)))
    return 0 if ok == len(SEQ) else 2

if __name__ == "__main__":
    sys.exit(main())
