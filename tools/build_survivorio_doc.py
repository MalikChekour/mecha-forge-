# -*- coding: utf-8 -*-
"""Design doc : cartographie Survivor.io -> Mecha Forge (systemes vs ce qu'on a),
gaps priorises. Sort un HTML autonome pour artifact."""
import os
OUT = r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad\survivorio_map.html"

# groupe -> [ (systeme, statut, idee) ]  ; statut in ok/warn/bad
GROUPS = [
 ("Boucle en run", "La colonne vertebrale du genre", [
   ("Auto-tir + deplacement seul + auto-visee", "ok", "—"),
   ("Gemmes XP -> montee de niveau", "ok", "—"),
   ("Draft : choisir 1 carte sur 3", "ok", "—"),
   ("Relancer / Bannir une carte", "ok", "—"),
   ("Armes multiples + passifs", "ok", "—"),
   ("EVOLUTIONS (arme max + passif -> forme ultime)", "ok", "—"),
   ("Survie chronometree + score", "ok", "—"),
 ]),
 ("Ennemis & boss", "La ou se joue la variete du combat", [
   ("Nuees / vagues croissantes", "ok", "—"),
   ("Fonceur / Tireur / Dasher", "ok", "—"),
   ("Blinde (bouclier qui englobe)", "ok", "—"),
   ("Kamikaze (fonce et EXPLOSE au contact)", "bad", "A AJOUTER — variete + tension"),
   ("Invocateur (crache une petite nuee)", "bad", "A AJOUTER — pression dynamique"),
   ("Elites / mini-boss (events)", "ok", "—"),
   ("Boss a ATTAQUES TELEGRAPHIEES (zones au sol, salves)", "warn", "A ENRICHIR — les boss foncent surtout"),
   ("Boss chronometres 5 / 10 / 15 min", "ok", "—"),
 ]),
 ("Pickups en run", "Les petits shots de dopamine", [
   ("Soin (poulet roti)", "ok", "—"),
   ("BOMBE = clear d'ecran (bouton panique)", "bad", "A AJOUTER — moment fort, rapide a coder"),
   ("AIMANT instantane (aspire TOUTES les gemmes)", "warn", "A AJOUTER — on n'a que le passif de portee"),
   ("Coffre d'elite (recompense garantie)", "warn", "A FORMALISER — le drop 'bonus' existe deja"),
   ("Overdrive / Fever (surpuissance temporaire)", "ok", "—"),
 ]),
 ("Meta & retention", "Ce qui fait REVENIR le joueur", [
   ("Connexion quotidienne (cycle 7 jours + streak)", "ok", "—"),
   ("Missions quotidiennes (3/jour, rotation)", "ok", "—"),
   ("Equipement : slots + raretes + niveaux", "ok", "4 slots (Survivor.io=6, extensible)"),
   ("Gacha : tirage de pieces (cristaux)", "ok", "—"),
   ("Amelioration + recyclage des pieces", "ok", "—"),
   ("Bonus de SET (pieces assorties)", "bad", "A AJOUTER — profondeur de build"),
   ("Talents / arbre de competences", "ok", "—"),
   ("Personnages / mechs a debloquer (garage)", "ok", "—"),
   ("Passifs PROPRES a chaque mech", "bad", "A AJOUTER — les mechs sont cosmetiques"),
   ("Chapitres / stages (maps + paliers)", "warn", "A ENRICHIR — on a difficulte + sans-fin"),
 ]),
 ("Economie F2P", "Le moteur de monetisation", [
   ("Monnaie douce (ferraille)", "ok", "—"),
   ("Monnaie premium (cristaux, gacha)", "ok", "—"),
   ("Monnaie d'up (noyaux, recyclage)", "ok", "—"),
   ("Pubs recompensees + plafond quotidien", "ok", "—"),
   ("Energie / stamina (gate de sessions)", "bad", "OPTIONNEL — a decider (retention vs friction)"),
 ]),
]

TIERS = [
 ("1", "Fun immediat", "Petit code, gros ressenti — testable tout de suite", "#3ecf8e", [
   "Bombe ramassable = clear d'ecran",
   "Aimant instantane = aspire toutes les gemmes",
   "Ennemi Kamikaze (fonce -> explose)",
   "Ennemi Invocateur (crache une nuee)",
   "Coffre d'elite formalise (recompense garantie)",
 ]),
 ("2", "Boss & lisibilite", "Le plus gros ecart de RESSENTI vs Survivor.io", "#f0a03c", [
   "Boss a attaques telegraphiees : anticipation -> zone au sol -> impact",
   "Salves / spirales de projectiles a esquiver",
   "Phases de boss (change de pattern sous X% PV)",
 ]),
 ("3", "Profondeur meta", "Retention & monetisation (deja solides, on approfondit)", "#7aa2ff", [
   "Bonus de SET sur l'equipement (2/4 pieces assorties)",
   "Passifs propres a chaque mech (choix reel au garage)",
   "Chapitres / stages avec maps + boss + recompenses dedies",
 ]),
]

PILL = {"ok": ("FAIT", "ok"), "warn": ("PARTIEL", "warn"), "bad": ("MANQUE", "bad")}

def rows(items):
    r = ""
    for name, st, idea in items:
        label, cls = PILL[st]
        idea_html = f'<span class="idea {cls}">{idea}</span>' if idea != "—" else '<span class="dash">—</span>'
        r += f'<tr><td class="sys">{name}</td><td><span class="pill {cls}">{label}</span></td><td>{idea_html}</td></tr>'
    return r

groups_html = ""
for title, sub, items in GROUPS:
    groups_html += f'''<section class="grp">
      <div class="ghead"><h2>{title}</h2><span class="gsub">{sub}</span></div>
      <div class="tbl-wrap"><table>
        <thead><tr><th>Systeme</th><th>Statut</th><th>Idee a piocher</th></tr></thead>
        <tbody>{rows(items)}</tbody>
      </table></div>
    </section>'''

tiers_html = ""
for n, name, sub, col, items in TIERS:
    lis = "".join(f"<li>{x}</li>" for x in items)
    tiers_html += f'''<div class="tier" style="--tc:{col}">
      <div class="tnum">{n}</div>
      <div class="tbody"><h3>{name}</h3><p class="tsub">{sub}</p><ul>{lis}</ul></div>
    </div>'''

# counts
allrows = [it for _,_,items in GROUPS for it in items]
n_ok = sum(1 for _,s,_ in allrows if s=="ok")
n_warn = sum(1 for _,s,_ in allrows if s=="warn")
n_bad = sum(1 for _,s,_ in allrows if s=="bad")
tot = len(allrows)
pct = round(100*n_ok/tot)

CSS = """
:root{
 --bg:#0c0e12; --panel:#14171e; --panel2:#191d25; --bd:#262b34; --tx:#e8ebf2; --mut:#8b92a0;
 --acc:#f0a03c; --ok:#37c98a; --warn:#e5b34a; --bad:#e5566e; --info:#7aa2ff;
}
@media(prefers-color-scheme:light){:root{--bg:#f5f6f9;--panel:#fff;--panel2:#f0f2f6;--bd:#e0e4ea;--tx:#181b21;--mut:#5c6472;}}
:root[data-theme=dark]{--bg:#0c0e12;--panel:#14171e;--panel2:#191d25;--bd:#262b34;--tx:#e8ebf2;--mut:#8b92a0;}
:root[data-theme=light]{--bg:#f5f6f9;--panel:#fff;--panel2:#f0f2f6;--bd:#e0e4ea;--tx:#181b21;--mut:#5c6472;}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--tx);font:15px/1.55 system-ui,'Segoe UI',Roboto,sans-serif}
.wrap{max-width:1000px;margin:0 auto;padding:46px 22px 90px}
.eyebrow{font:600 12px/1 ui-monospace,'SF Mono',Menlo,monospace;letter-spacing:.24em;color:var(--acc);text-transform:uppercase}
h1{font-size:34px;line-height:1.08;margin:.32em 0 .18em;letter-spacing:-.015em;text-wrap:balance}
.lead{color:var(--mut);max-width:66ch;margin:0;font-size:16px}
.hero-stat{display:flex;gap:26px;flex-wrap:wrap;margin:30px 0 6px;align-items:center}
.big{font:800 60px/1 system-ui;letter-spacing:-.03em;color:var(--ok)}
.big small{display:block;font:600 12px/1.4 ui-monospace,monospace;letter-spacing:.14em;color:var(--mut);text-transform:uppercase;margin-top:6px}
.legend{display:flex;gap:8px;flex-wrap:wrap}
.pill{display:inline-flex;align-items:center;gap:6px;font:700 10.5px/1 ui-monospace,monospace;letter-spacing:.07em;padding:5px 9px;border-radius:6px;white-space:nowrap}
.pill.ok{background:rgba(55,201,138,.15);color:var(--ok);border:1px solid rgba(55,201,138,.35)}
.pill.warn{background:rgba(229,179,74,.15);color:var(--warn);border:1px solid rgba(229,179,74,.35)}
.pill.bad{background:rgba(229,86,110,.15);color:var(--bad);border:1px solid rgba(229,86,110,.35)}
.banner{background:linear-gradient(100deg,rgba(55,201,138,.12),transparent 70%);border:1px solid var(--bd);border-left:3px solid var(--ok);border-radius:12px;padding:16px 20px;margin:26px 0 6px;font-size:14.5px}
.banner b{color:var(--tx)}
.grp{margin-top:34px}
.ghead{display:flex;align-items:baseline;gap:12px;flex-wrap:wrap;border-bottom:1px solid var(--bd);padding-bottom:9px;margin-bottom:2px}
.ghead h2{font-size:19px;margin:0;letter-spacing:-.01em}
.gsub{color:var(--mut);font-size:13px}
.tbl-wrap{overflow-x:auto}
table{width:100%;border-collapse:collapse;font-size:14px;min-width:520px}
thead th{text-align:left;font:600 11px/1 ui-monospace,monospace;letter-spacing:.1em;color:var(--mut);text-transform:uppercase;padding:12px 10px 8px}
tbody td{padding:10px 10px;border-top:1px solid var(--bd);vertical-align:middle}
td.sys{color:var(--tx)}
tbody tr:hover{background:var(--panel2)}
.idea{font-size:13px}
.idea.bad{color:var(--bad);font-weight:600}.idea.warn{color:var(--warn);font-weight:600}.idea.ok{color:var(--mut)}
.dash{color:var(--mut);opacity:.5}
h2.section{font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:var(--mut);margin:52px 0 14px;font-family:ui-monospace,monospace}
.tiers{display:flex;flex-direction:column;gap:14px}
.tier{display:flex;gap:16px;background:var(--panel);border:1px solid var(--bd);border-radius:14px;padding:18px 20px;border-left:4px solid var(--tc)}
.tnum{font:800 30px/1 system-ui;color:var(--tc);min-width:34px}
.tbody h3{margin:2px 0 2px;font-size:17px}
.tsub{color:var(--mut);font-size:13px;margin:0 0 10px}
.tbody ul{margin:0;padding-left:18px}
.tbody li{margin:4px 0;color:var(--tx);font-size:14px}
.reco{background:var(--panel);border:1px solid var(--bd);border-radius:12px;padding:18px 20px;margin-top:22px;font-size:14.5px}
.reco b{color:var(--acc)}
footer{color:var(--mut);font-size:13px;border-top:1px solid var(--bd);margin-top:40px;padding-top:18px}
"""

HTML = f"""<div class="wrap">
<div class="eyebrow">Analyse &middot; Survivor.io &rarr; Mecha Forge</div>
<h1>La carte des systemes<br>et les vraies idees a piocher</h1>
<p class="lead">Impossible de "jouer" a l'app native ici, mais pas besoin : voici le game design de Survivor.io mis face a ce que Mecha Forge implemente <b>deja</b>. La surprise, c'est a quel point on est avance.</p>

<div class="hero-stat">
  <div class="big">{pct}%<small>des systemes deja faits</small></div>
  <div class="legend">
    <span class="pill ok">FAIT &middot; {n_ok}</span>
    <span class="pill warn">PARTIEL &middot; {n_warn}</span>
    <span class="pill bad">MANQUE &middot; {n_bad}</span>
  </div>
</div>

<div class="banner"><b>Le constat :</b> Mecha Forge ne copie pas juste la boucle de jeu — il a deja <b>toute la meta F2P</b> de Survivor.io : connexion quotidienne, missions du jour, equipement (raretes + gacha + amelioration + recyclage) avec bonus appliques au perso, 4 monnaies, pubs recompensees plafonnees, talents, garage, paliers de difficulte. Les manques sont <b>peu nombreux et cibles</b>.</div>

{groups_html}

<h2 class="section">Roadmap des idees &mdash; par priorite</h2>
<div class="tiers">{tiers_html}</div>

<div class="reco"><b>Ma reco :</b> on attaque le <b>Niveau 1</b> (bombe, aimant, kamikaze, invocateur, coffre d'elite) — c'est rapide, ca se ressent tout de suite en jeu, et ca comble les manques les plus visibles. Ensuite le <b>Niveau 2 (boss telegraphies)</b>, qui est le plus gros ecart de ressenti : aujourd'hui nos boss foncent, ceux de Survivor.io se lisent et s'esquivent. La meta (Niveau 3) est deja forte — les bonus de set et les passifs de mech sont la cerise, pas l'urgence.</div>

<footer>Etabli en lisant le code reel (SaveManager, EnemySpawner, WeaponSystem, Pickup, Game). Statuts verifies, pas supposes. Les specifics exacts de Survivor.io (recettes d'evo, patterns de boss actuels) peuvent etre recherches sur le web pour caler l'equilibrage.</footer>
</div>"""

open(OUT, "w", encoding="utf-8").write(
  '<title>Survivor.io -> Mecha Forge</title>\n<style>%s</style>\n%s' % (CSS, HTML))
print("OK", OUT)
