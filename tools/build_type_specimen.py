# -*- coding: utf-8 -*-
"""Planche de comparaison des polices : meme texte, meme taille -> seules les
formes de lettres changent. Une seule image, lisible d'un coup d'oeil."""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

ROWS = [
 ("0 · ACTUEL", "défaut Godot — aucune police fournie",
  "ui-sans-serif,system-ui,sans-serif", 900, "1px",
  "ui-sans-serif,system-ui,sans-serif", 800),
 ("1 · TECHNO HUD", "Orbitron + Rajdhani",
  "'Orbitron',sans-serif", 900, "4px", "'Rajdhani',sans-serif", 700),
 ("2 · MILITAIRE", "Black Ops One + Barlow Condensed",
  "'Black Ops One',Impact,sans-serif", 400, "2px", "'Barlow Condensed',sans-serif", 700),
 ("3 · AFFICHE", "Anton + Roboto Condensed",
  "'Anton',Impact,sans-serif", 400, "0px", "'Roboto Condensed',sans-serif", 700),
 ("4 · CONDENSÉ NET", "Oswald + Barlow Condensed",
  "'Oswald',sans-serif", 700, "2px", "'Barlow Condensed',sans-serif", 600),
 ("5 · TECHNIQUE", "Chakra Petch + Share Tech Mono",
  "'Chakra Petch',sans-serif", 700, "3px", "'Share Tech Mono',monospace", 400),
]

rows = "\n".join("""
<div class="row">
  <div class="lab"><div class="n">%s</div><div class="f">%s</div></div>
  <div class="samp">
    <div class="big" style="font-family:%s;font-weight:%d;letter-spacing:%s">MECHA-FORGE</div>
    <div class="ui" style="font-family:%s;font-weight:%d">JOUER &nbsp;·&nbsp; ARSENAL &nbsp;·&nbsp; ÉQUIPEMENT &nbsp;·&nbsp; 1 250 points</div>
  </div>
</div>""" % r for r in ROWS)

HTML = """<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Orbitron:wght@900&family=Rajdhani:wght@700&family=Black+Ops+One&family=Barlow+Condensed:wght@600;700&family=Anton&family=Roboto+Condensed:wght@700&family=Oswald:wght@700&family=Chakra+Petch:wght@700&family=Share+Tech+Mono&display=swap" rel="stylesheet">
<div id="sheet">
<div class="head"><b>MECHA-FORGE</b> — les 6 polices, même texte et même taille</div>
%s
<div class="foot">Seules les <b>formes de lettres</b> changent ici. Dans le menu, chaque style a aussi sa taille et son espacement.</div>
</div>
<style>
#sheet{width:1280px;background:#070b12;color:#e8eefb;padding:22px 26px 20px;
  font:14px ui-sans-serif,system-ui,sans-serif;box-sizing:border-box}
.head{font-size:16px;color:#8ba1c0;margin-bottom:14px}
.head b{color:#4fd8e8}
.row{display:grid;grid-template-columns:250px 1fr;gap:20px;align-items:center;
  padding:15px 0;border-top:1px solid #1d2939}
.lab .n{font-weight:800;font-size:15px;color:#fff}
.lab .f{color:#6fe3ff;font-size:12.5px;font-family:ui-monospace,Consolas,monospace;margin-top:3px}
.big{font-size:64px;line-height:1.06;color:#bcecff;text-shadow:0 0 10px rgba(10,60,90,.9),0 3px 0 #0a2c3e;
  text-transform:uppercase;white-space:nowrap}
.ui{font-size:23px;color:#cfe0f2;margin-top:7px;letter-spacing:1px}
.foot{color:#8ba1c0;font-size:12.5px;margin-top:14px;border-top:1px solid #1d2939;padding-top:11px}
.foot b{color:#e8eefb}
</style>""" % rows

dst = os.path.join(ROOT, "cine", "_show", "type_specimen.html")
open(dst, "w", encoding="utf-8").write(HTML)
print("wrote", dst)
