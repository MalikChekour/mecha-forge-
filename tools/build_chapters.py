# -*- coding: utf-8 -*-
"""Doc de progression : 5 chapitres facon Survivor.io (deblocage en chaine)."""
import base64, io, os
from PIL import Image
OUT = r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad\chapters.html"

def thumb(biome):
    im = Image.open(f"game/assets/enemies/bs_{biome}_walk_front.png").convert("RGBA")
    fw = im.height
    c = im.crop((0, 0, fw, im.height))
    b = Image.new("RGBA", c.size, (0, 0, 0, 0)); b.alpha_composite(c)
    o = io.BytesIO(); b.resize((180, 180)).save(o, "PNG")
    return "data:image/png;base64," + base64.b64encode(o.getvalue()).decode()

CH = [
 (1, "tech", "L'Usine", "Le Reveil", "#a55fff", "La ou les machines s'eveillent. Ton entrainement.",
   ["Machine Tech", "Artilleur lourd"], "Colosse", 1, "Piece RARE + 200 ferraille + 15 cristaux", "~1 000"),
 (2, "desert", "Les Terres Calcinees", "La Traversee", "#ffcd37", "Le desert que les machines ont conquis.",
   ["Raider (rapide)", "Artilleur", "Kamikaze"], "Colosse renforce", 2, "Piece Rare/EPIQUE + materiaux", "~2 500"),
 (3, "jungle", "La Ruine Verte", "L'Enlisement", "#8cff41", "La nature submergee, grouillante.",
   ["Rodeur (essaim)", "Invocateur", "Artilleur"], "Broyeur", 3, "Piece EPIQUE", "~5 000"),
 (4, "volcanic", "La Forge", "Le Coeur Ardent", "#ff4e12", "Le coeur brulant + coulees de lave (hazard).",
   ["Fondeur (agressif)", "Kamikaze", "Artilleur"], "Colosse de lave", 4, "Piece Epique/LEGENDAIRE", "~9 000"),
 (5, "ruines", "La Cite Dechue", "Le Souverain", "#ffa54b", "Le repaire du maitre. Confrontation finale.",
   ["Tout melange + elites"], "SOUVERAIN (boss final)", 5, "Piece LEGENDAIRE garantie", "~15 000"),
]

def stars(n):
    return "".join('<span class="s on">&#9733;</span>' for _ in range(n)) + \
           "".join('<span class="s">&#9733;</span>' for _ in range(5 - n))

cards = ""
for num, biome, name, sub, acc, desc, foes, boss, diff, rew, gate in CH:
    foeli = "".join("<li>%s</li>" % f for f in foes)
    cards += '''<div class="ch" style="--a:%s">
      <div class="num">%d</div>
      <div class="thumb"><img src="%s"></div>
      <div class="body">
        <div class="head"><h3>%s</h3><span class="sub">&laquo; %s &raquo;</span></div>
        <p class="desc">%s</p>
        <div class="meta">
          <div class="m"><span class="lab">Ennemis vedettes</span><ul class="foes">%s</ul></div>
          <div class="m"><span class="lab">Boss de fin</span><b class="boss">%s</b></div>
        </div>
        <div class="foot"><div class="diff">%s</div><div class="gate"><span class="lab">Palier requis</span><b>%s</b></div></div>
        <div class="rew"><span class="rlab">1er clear</span>%s</div>
      </div>
    </div>''' % (acc, num, thumb(biome), name, sub, desc, foeli, boss, stars(diff), gate, rew)

CSS = '''
:root{--bg:#0b0d11;--card:#14171e;--card2:#181c24;--bd:#242a34;--tx:#e8ebf2;--mut:#8b92a0;--acc:#f0a03c;--ok:#37c98a;--gold:#ffcf6a}
@media(prefers-color-scheme:light){:root{--bg:#f4f5f8;--card:#fff;--card2:#f0f2f6;--bd:#dfe3ea;--tx:#181b21;--mut:#5c6472}}
:root[data-theme=light]{--bg:#f4f5f8;--card:#fff;--card2:#f0f2f6;--bd:#dfe3ea;--tx:#181b21;--mut:#5c6472}
:root[data-theme=dark]{--bg:#0b0d11;--card:#14171e;--card2:#181c24;--bd:#242a34;--tx:#e8ebf2;--mut:#8b92a0}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--tx);font:15px/1.55 system-ui,Segoe UI,Roboto,sans-serif}
.wrap{max-width:880px;margin:0 auto;padding:46px 22px 80px}
.eyebrow{font:600 12px/1 ui-monospace,monospace;letter-spacing:.22em;color:var(--acc);text-transform:uppercase}
h1{font-size:32px;margin:.32em 0 .12em;letter-spacing:-.015em;text-wrap:balance}
.lead{color:var(--mut);max-width:66ch;margin:0}
.model{background:var(--card);border:1px solid var(--bd);border-radius:12px;padding:14px 18px;margin:22px 0 8px;font-size:14px;color:var(--mut)}
.model b{color:var(--tx)}
.flow{display:flex;flex-direction:column;gap:10px;margin-top:22px}
.ch{position:relative;display:grid;grid-template-columns:52px 150px 1fr;gap:16px;background:var(--card);border:1px solid var(--bd);border-left:4px solid var(--a);border-radius:14px;padding:16px 18px;align-items:center}
.num{font:800 30px/1 system-ui;color:var(--a);text-align:center}
.thumb{aspect-ratio:1;background:radial-gradient(circle at 50% 42%,#20242c,#0e1015);border-radius:10px;display:grid;place-items:center;overflow:hidden}
.thumb img{width:92%}
.head{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap}
.head h3{margin:0;font-size:19px}.sub{color:var(--a);font:600 13px/1 ui-monospace,monospace}
.desc{color:var(--mut);font-size:13.5px;margin:4px 0 10px}
.meta{display:flex;gap:22px;flex-wrap:wrap;margin-bottom:10px}
.lab{display:block;font:600 10px/1 ui-monospace,monospace;letter-spacing:.1em;color:var(--mut);text-transform:uppercase;margin-bottom:5px}
.foes{margin:0;padding-left:16px;font-size:13px}.foes li{margin:1px 0}
.boss{color:var(--tx);font-size:14.5px}
.foot{display:flex;align-items:center;justify-content:space-between;gap:14px;border-top:1px solid var(--bd);padding-top:10px}
.diff .s{color:var(--bd);font-size:17px;letter-spacing:2px}.diff .s.on{color:var(--a)}
.gate{text-align:right}.gate b{color:var(--tx);font-variant-numeric:tabular-nums}
.rew{margin-top:9px;background:linear-gradient(90deg,rgba(255,207,106,.14),transparent 70%);border:1px solid var(--bd);border-radius:8px;padding:7px 11px;font-size:13px}
.rlab{font:700 10px/1 ui-monospace,monospace;letter-spacing:.08em;color:var(--gold);text-transform:uppercase;margin-right:8px}
.after{background:var(--card2);border:1px solid var(--bd);border-radius:12px;padding:16px 18px;margin-top:24px}
.after h4{margin:0 0 8px;font-size:15px}.after p{margin:6px 0;font-size:14px;color:var(--mut)}.after b{color:var(--tx)}
.funnel{background:linear-gradient(100deg,rgba(55,201,138,.12),transparent 70%);border:1px solid var(--bd);border-left:3px solid var(--ok);border-radius:11px;padding:14px 18px;margin-top:16px;font-size:14px}.funnel b{color:var(--tx)}
footer{color:var(--mut);font-size:13px;border-top:1px solid var(--bd);margin-top:30px;padding-top:16px}
@media(max-width:620px){.ch{grid-template-columns:44px 1fr}.thumb{display:none}}
'''

BODY = '''<div class="wrap">
<div class="eyebrow">Progression &middot; facon Survivor.io</div>
<h1>5 chapitres qui se debloquent en chaine</h1>
<p class="lead">Pas de choix de difficulte : tu bats le boss d'un chapitre &rarr; le suivant s'ouvre. La difficulte monte toute seule avec le numero. Tu rejoues les chapitres debloques pour farmer le gear.</p>
<div class="model"><b>Le moteur de monetisation :</b> chaque chapitre a un <b>palier de puissance requis</b>. Trop faible &rarr; tu bloques sur le boss &rarr; tu farmes / ameliores ton gear (gacha) pour passer. C'est exactement l'entonnoir de Survivor.io.</div>
<div class="flow">%s</div>
<div class="after"><h4>Apres le chapitre 5</h4>
<p><b>Mode Sans-fin (Assaut infini)</b> &mdash; vagues sans limite qui montent en puissance + classement. Le end-game qui retient les gros joueurs.</p>
<p><b>Farm</b> &mdash; rejoue n'importe quel chapitre debloque pour du materiel (moins qu'au 1er clear, mais infini).</p></div>
<div class="funnel"><b>Retention post-lancement :</b> les <b>4 biomes restants</b> (Terre, Vaisseau, Glace, Marais) sortent en <b>&laquo; nouveau chapitre &raquo;</b> apres le lancement &mdash; evenements limites avec gear exclusif &rarr; ca fait revenir les joueurs sans reproduire d'assets a la sortie.</div>
<footer>Chiffres de palier / recompense = indicatifs, a equilibrer en jeu. Vignettes = tes ennemis reels par biome. Bosses : Colosse (midboss) + Souverain (endboss) existent deja ; les variantes = re-stat + teinte.</footer>
</div>''' % cards

open(OUT, "w", encoding="utf-8").write("<title>Progression 5 chapitres</title>\n<style>%s</style>\n%s" % (CSS, BODY))
print("OK", OUT)
