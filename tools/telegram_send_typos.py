# -*- coding: utf-8 -*-
"""Envoie les styles de caracteres du menu EPURE sur le Telegram du patron."""
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

TOKEN = find_token(cfg)
CHAT = "7698730603"
SHOTS = sys.argv[1]
LINK = "https://claude.ai/code/artifact/94b9542b-f2a7-4625-a535-69545ab0a3b1"

INTRO = ("🔤 MECHA-FORGE — menu EPURE retenu : les styles de caracteres\n\n"
         "Info importante : le jeu n'a AUCUNE police fournie aujourd'hui, tout est en police par "
         "defaut de Godot (image 1 = la reference). Les 5 suivantes sont des polices libres (OFL) "
         "que je peux livrer dans le jeu.")

SEQ = [
 ("specimen_polices.png",  "PLANCHE — les 6 polices en grand, meme texte et meme taille. C'est ici que la difference se voit le mieux."),
 ("typo_0_actuel.png",      "1/6 (menu) — ACTUEL (defaut Godot) : aucune police fournie. C'est la reference pour comparer."),
 ("typo_1_techno_hud.png",  "2/6 (menu) — TECHNO HUD : Orbitron + Rajdhani. Geometrique, cockpit de mecha, tres lisible de loin."),
 ("typo_2_militaire.png",   "3/6 (menu) — MILITAIRE : Black Ops One + Barlow Condensed. Pochoir d'armee, brut et martial."),
 ("typo_3_affiche.png",     "4/6 (menu) — AFFICHE INDUSTRIELLE : Anton + Roboto Condensed. Massif, facon affiche de film, gros impact mobile."),
 ("typo_4_condense.png",    "5/6 (menu) — CONDENSE NET : Oswald + Barlow Condensed. Sobre et compact, le meilleur compromis lisibilite/caractere."),
 ("typo_5_technique.png",   "6/6 (menu) — TECHNIQUE : Chakra Petch + Share Tech Mono. Fiche d'atelier / terminal, ton 'machine'."),
]

OUTRO = ("Pour l'EFFET AU CLIC il faut cliquer, ca ne se voit pas en photo — j'en ai prepare 6 :\n"
         "A Enfoncement · B Punch elastique · C Onde au doigt · D Anneau de choc · E Eclats · F Balayage lumineux\n\n"
         "Ouvre le module, choisis une police + un effet, et CLIQUE sur JOUER et les pastilles :\n" + LINK +
         "\n\nDis-moi la combinaison que tu veux (ex. « CONDENSE NET + Punch ») et je l'implemente dans le jeu.")

def main():
    if not TOKEN:
        print("ERREUR: token introuvable."); return 1
    print("token OK (masque) | chat", CHAT)
    ok = 0
    with httpx.Client(timeout=120) as c:
        print("intro:", c.post("https://api.telegram.org/bot%s/sendMessage" % TOKEN,
              data={"chat_id": CHAT, "text": INTRO}).json().get("ok"))
        for fn, cap in SEQ:
            p = os.path.join(SHOTS, fn)
            if not os.path.exists(p):
                print("  MANQUANT:", fn); continue
            for _ in range(3):
                with open(p, "rb") as fh:
                    j = c.post("https://api.telegram.org/bot%s/sendPhoto" % TOKEN,
                               data={"chat_id": CHAT, "caption": cap},
                               files={"photo": (fn, fh, "image/png")}).json()
                if j.get("ok"):
                    print("  envoye:", fn); ok += 1; break
                print("  retry:", fn, str(j)[:100])
        print("outro:", c.post("https://api.telegram.org/bot%s/sendMessage" % TOKEN,
              data={"chat_id": CHAT, "text": OUTRO, "disable_web_page_preview": "true"}).json().get("ok"))
    print("photos: %d/%d" % (ok, len(SEQ)))
    return 0 if ok == len(SEQ) else 2

if __name__ == "__main__":
    sys.exit(main())
