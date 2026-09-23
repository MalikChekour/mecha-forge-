# -*- coding: utf-8 -*-
import base64, os
SP=r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad"
J="cine/_show/jug"
def d64(path, mime):
    return "data:%s;base64,%s"%(mime, base64.b64encode(open(path,"rb").read()).decode())
def gif(f): return d64(f"{J}/{f}.gif","image/gif")
def png(f): return d64(f"{J}/{f}.png","image/png")

STAGES=[
 ("stage_concept","1 \u00b7 Concept IA","Image g\u00e9n\u00e9r\u00e9e (FLUX) sous contrainte anti-tige : mecha compact, rien qui pend."),
 ("stage_3d","2 \u00b7 Mod\u00e8le 3D","Reconstruit en volume (TRELLIS). Silhouette pleine, pas d'appendice."),
 ("stage_sprite","3 \u00b7 Sprite bak\u00e9","Rig Mixamo + anim course, rendu en image 2D (8 frames \u00d7 4 directions)."),
 ("stage_ingame","4 \u00b7 En jeu","Ce que le joueur voit : un mecha lourd qui charge, avec liser\u00e9."),
]
stagecards="".join('<div class="stage"><div class="simg"><img src="%s"></div><b>%s</b><p>%s</p></div>'%(png(s),t,d) for s,t,d in STAGES)
DIRS=[("jug_front","Face"),("jug_left","Gauche"),("jug_back","Dos"),("jug_right","Droite")]
dcards="".join('<figure class="dcard"><div class="thumb"><span class="live">\u25cf</span><img src="%s"></div><figcaption>%s</figcaption></figure>'%(gif(f),n) for f,n in DIRS)

CSS=""":root{--bg:#0d0f14;--p1:#14161d;--p2:#1a1d25;--bd:#262b36;--tx:#e7e9f0;--mut:#8b91a0;--crim:#e5384d;--ok:#2fbf71;--warn:#e6a93a}
*{box-sizing:border-box}body{margin:0;background:radial-gradient(1200px 600px at 70% -10%,#171a22,#0d0f14 60%);color:var(--tx);font:15px/1.55 system-ui,Segoe UI,Roboto,sans-serif;-webkit-font-smoothing:antialiased}
.wrap{max-width:1000px;margin:0 auto;padding:44px 22px 80px}
.eyebrow{font:600 12px/1 ui-monospace,Menlo,monospace;letter-spacing:.22em;color:var(--crim);text-transform:uppercase}
h1{font-size:33px;margin:.35em 0 .12em;letter-spacing:-.02em}
.sub{color:var(--mut);max-width:66ch;margin:0}
.tldr{display:flex;gap:8px;flex-wrap:wrap;margin:22px 0 6px}
.badge{font:600 10px/1 ui-monospace,monospace;letter-spacing:.05em;padding:6px 10px;border-radius:6px}
.b-ok{background:rgba(47,191,113,.16);color:#7ee0a8;border:1px solid rgba(47,191,113,.35)}
.b-warn{background:rgba(230,169,58,.14);color:#e6c377;border:1px solid rgba(230,169,58,.3)}
h2{font-size:18px;margin:40px 0 4px}.lead{color:var(--mut);font-size:13.5px;margin:0 0 16px}
.pipe{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;position:relative}
.stage{background:var(--p1);border:1px solid var(--bd);border-radius:13px;padding:12px}
.simg{aspect-ratio:1;border-radius:9px;overflow:hidden;background:#20232c;margin-bottom:9px}
.simg img{width:100%;height:100%;object-fit:contain}
.stage b{font-size:13px;color:#dfe3ea}.stage p{color:var(--mut);font-size:11.5px;margin:4px 0 0}
.heroanim{display:flex;gap:22px;align-items:center;flex-wrap:wrap;background:var(--p1);border:1px solid var(--bd);border-radius:16px;padding:18px}
.heroanim .big{width:300px;height:300px;background:#1c1e25;border-radius:12px;flex:none}
.heroanim .big img{width:100%;height:100%;object-fit:contain}
.dgrid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;flex:1;min-width:280px}
.dcard{margin:0}.dcard .thumb{position:relative;aspect-ratio:1;background:#1c1e25;border:1px solid var(--bd);border-radius:11px;overflow:hidden}
.dcard .thumb img{width:100%;height:100%;object-fit:contain}
.dcard figcaption{color:var(--mut);font-size:11.5px;text-align:center;margin-top:4px}
.live{position:absolute;top:7px;right:8px;color:var(--ok);font-size:10px;filter:drop-shadow(0 0 4px #2fbf71);animation:pulse 1.4s infinite}@keyframes pulse{50%{opacity:.3}}
.melt{display:flex;gap:20px;align-items:center;flex-wrap:wrap;background:var(--p2);border:1px solid var(--bd);border-radius:16px;padding:18px}
.melt img{max-width:340px;width:100%;border-radius:10px}
.melt .txt{flex:1;min-width:260px;font-size:14px;color:#c9cdd6}
.opts{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-top:16px}
.opt{background:var(--p1);border:1px solid var(--bd);border-radius:13px;padding:16px}
.opt.pick{border-color:rgba(47,191,113,.4)}
.opt h3{margin:0 0 6px;font-size:15px}.opt p{color:var(--mut);font-size:13px;margin:0}
.opt .tag{font:600 10px/1 ui-monospace,monospace;padding:4px 8px;border-radius:5px;margin-bottom:8px;display:inline-block}
.t-fast{background:rgba(47,191,113,.16);color:#7ee0a8}.t-clean{background:rgba(230,169,58,.14);color:#e6c377}
footer{color:var(--mut);font-size:13px;border-top:1px solid var(--bd);margin-top:40px;padding-top:18px}
@media(max-width:640px){.pipe,.dgrid,.opts{grid-template-columns:1fr 1fr}}"""

BODY="""<div class="wrap">
<div class="eyebrow">Ennemi mecha \u00b7 comprendre le r\u00e9sultat</div>
<h1>Juggernaut \u2014 du concept au jeu</h1>
<p class="sub">De quoi on parle exactement : le chemin complet d'un ennemi (image \u2192 3D \u2192 rig \u2192 jeu), le rendu anim\u00e9 r\u00e9el, et le seul d\u00e9faut (la fonte) montr\u00e9 sans filtre.</p>
<div class="tldr"><span class="badge b-ok">\u2713 Z\u00c9RO TIGE aux jambes</span><span class="badge b-ok">\u2713 VRAI MECHA (pas un soldat)</span><span class="badge b-ok">\u2713 anim\u00e9 4 directions</span><span class="badge b-warn">\u26a0 l\u00e9g\u00e8re fonte \u00e9paules (gros plan)</span></div>

<h2>1. Le pipeline \u2014 comment on fabrique un ennemi</h2>
<p class="lead">4 \u00e9tapes, ~10 min par mecha. La seule qui te demande 5 clics : placer les marqueurs de rig sur Mixamo.</p>
<div class="pipe">%s</div>

<h2>2. En mouvement \u2014 le rendu r\u00e9el en jeu</h2>
<p class="lead">La course anim\u00e9e, telle qu'elle tourne. Grande vue de face + les 4 directions (l'ennemi te fait face selon d'o\u00f9 il arrive).</p>
<div class="heroanim">
  <div class="big"><img src="%s"></div>
  <div class="dgrid">%s</div>
</div>

<h2>3. La fonte, sans filtre</h2>
<div class="melt">
  <img src="%s">
  <div class="txt"><b>C'est quoi ?</b> Les bras du concept sont le long du corps (pas un vrai T), donc au rig le blindage des \u00e9paules \u00ab bave \u00bb un peu quand les bras bougent. <br><br><b>\u00c0 gauche (gros plan) :</b> on voit la fonte. <b>\u00c0 droite (taille r\u00e9elle en jeu) :</b> elle dispara\u00eet dans la masse \u2014 \u00e7a lit comme un gros mecha lourd. C'est le principe du top-down : les d\u00e9fauts d'articulation sont noy\u00e9s \u00e0 petite \u00e9chelle.</div>
</div>

<h2>4. Les 2 voies</h2>
<div class="opts">
  <div class="opt pick"><span class="tag t-fast">RAPIDE</span><h3>On garde le Juggernaut</h3><p>Je rigue Striker, Bruiser, Sentinel avec la m\u00eame m\u00e9thode \u2192 roster de 4 vrais mechas anim\u00e9s. La fonte reste (invisible en jeu). Rien \u00e0 refaire de ton c\u00f4t\u00e9 sauf les marqueurs par mecha.</p></div>
  <div class="opt"><span class="tag t-clean">PRISTINE</span><h3>Vrai T-pose \u2014 z\u00e9ro fonte</h3><p>Je r\u00e9g\u00e9n\u00e8re chaque mecha bras bien horizontaux (\u00e9cart\u00e9s du corps) \u2192 le rig ne bave plus du tout. Plus propre en gros plan, mais tu replaces les marqueurs sur les nouveaux mod\u00e8les.</p></div>
</div>
<footer>Dis-moi la voie et j'encha\u00eene. Anims possibles ensuite par ennemi : course + attaque + mort.</footer>
</div>"""

html="<title>Juggernaut \u2014 du concept au jeu</title>\n<style>%s</style>\n%s"%(CSS, BODY%(stagecards, gif("jug_front_big"), dcards, png("melt_detail")))
open(os.path.join(SP,"juggernaut.html"),"w",encoding="utf-8").write(html)
print("detailed catalog bytes:", len(html))
