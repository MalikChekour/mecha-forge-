import base64, os, io
from PIL import Image
SP=os.path.abspath("cine/_show")
OUTHTML=r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad\arms_compare.html"

def frame0(path, sz=230):
    im=Image.open(path).convert("RGBA"); fw=im.height  # square frames
    c=im.crop((0,0,fw,im.height))
    bg=Image.new("RGBA",c.size,(20,22,28,255)); bg.alpha_composite(c)
    return bg.convert("RGB").resize((sz,sz))

def b64(im):
    b=io.BytesIO(); im.save(b,"PNG"); return "data:image/png;base64,"+base64.b64encode(b.getvalue()).decode()

def b64file(path,maxw=900):
    im=Image.open(path).convert("RGB")
    if im.width>maxw: im=im.resize((maxw,int(im.height*maxw/im.width)))
    return b64(im)

before_f=b64(frame0("game/assets/mecha/bluestrike_walk_front.png"))
before_s=b64(frame0("game/assets/mecha/bluestrike_walk_left.png"))
after_f =b64(frame0("game/assets/enemies/bluestrike_walk_front.png"))
after_s =b64(frame0("game/assets/enemies/bluestrike_walk_left.png"))
ingame  =b64file(f"{SP}/enemyshot_02.png")

CSS="""
:root{--bg:#0c0e13;--card:#14171f;--bd:#242a35;--tx:#e8ebf2;--mut:#8d94a3;--bad:#e5556a;--ok:#3ecf8e;--accent:#f0913c}
@media(prefers-color-scheme:light){:root{--bg:#f4f5f8;--card:#fff;--bd:#dfe3ea;--tx:#1a1d24;--mut:#5b6270}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--tx);font:15px/1.55 system-ui,Segoe UI,Roboto,sans-serif}
.wrap{max-width:960px;margin:0 auto;padding:40px 22px 70px}
.eyebrow{font:600 12px/1 ui-monospace,monospace;letter-spacing:.22em;color:var(--accent);text-transform:uppercase}
h1{font-size:30px;margin:.35em 0 .1em;letter-spacing:-.01em}.sub{color:var(--mut);max-width:64ch;margin:0}
.cols{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin:28px 0}
@media(max-width:640px){.cols{grid-template-columns:1fr}}
.panel{background:var(--card);border:1px solid var(--bd);border-radius:14px;padding:16px 16px 18px}
.panel.bad{border-color:rgba(229,85,106,.4)}.panel.ok{border-color:rgba(62,207,142,.4)}
.tag{display:inline-flex;align-items:center;gap:7px;font:600 11px/1 ui-monospace,monospace;letter-spacing:.08em;padding:5px 9px;border-radius:6px;text-transform:uppercase}
.tag.bad{background:rgba(229,85,106,.14);color:var(--bad)}.tag.ok{background:rgba(62,207,142,.14);color:var(--ok)}
.imgs{display:flex;gap:10px;margin-top:13px}.imgs img{width:50%;border-radius:9px;background:#15171d}
.lab{display:flex;gap:10px;margin-top:7px}.lab span{width:50%;text-align:center;color:var(--mut);font-size:12px}
.desc{color:var(--mut);font-size:13.5px;margin:12px 0 0}
.big{background:var(--card);border:1px solid var(--bd);border-radius:14px;overflow:hidden;margin-top:10px}
.big img{width:100%;display:block}.big .cap{padding:12px 16px;color:var(--mut);font-size:13px}
.note{background:linear-gradient(90deg,rgba(240,145,60,.12),transparent);border:1px solid var(--bd);border-left:3px solid var(--accent);border-radius:10px;padding:14px 18px;margin:26px 0 0;font-size:14px}
.note b{color:var(--tx)}
h2{font-size:15px;text-transform:uppercase;letter-spacing:.12em;color:var(--mut);margin:34px 0 4px}
footer{color:var(--mut);font-size:13px;border-top:1px solid var(--bd);margin-top:34px;padding-top:16px}
"""
BODY=f"""<div class="wrap">
<div class="eyebrow">Blue Strike · ennemi</div>
<h1>Bras corrigés — Blue Strike passe ennemi</h1>
<p class="sub">Le Juggernaut est retiré. Blue Strike devient le seul ennemi du test, avec ses bras remis en place : ils tombent le long du corps (posture de charge) au lieu de partir vers l'arrière.</p>

<div class="cols">
  <div class="panel bad">
    <span class="tag bad">● Avant</span>
    <div class="imgs"><img src="{before_f}"><img src="{before_s}"></div>
    <div class="lab"><span>face</span><span>profil</span></div>
    <p class="desc">Les coudes remontaient <b>vers l'arrière/le haut</b> (fausse posture « garde »). De profil, les bras traînaient derrière le dos.</p>
  </div>
  <div class="panel ok">
    <span class="tag ok">● Après</span>
    <div class="imgs"><img src="{after_f}"><img src="{after_s}"></div>
    <div class="lab"><span>face</span><span>profil</span></div>
    <p class="desc">Bras <b>vers le bas et légèrement en avant</b> — allure de mecha qui charge. Plus aucun coude en arrière, silhouette nette.</p>
  </div>
</div>

<h2>En jeu (v7.4, biome jungle)</h2>
<div class="big"><img src="{ingame}"><div class="cap">Plusieurs Blue Strike autour du joueur — bras corrigés, contour de lisibilité actif. Confirmé en jeu, 4 directions.</div></div>

<div class="note"><b>Un point à trancher :</b> le joueur et l'ennemi Blue Strike ont quasi la même livrée (bleu-gris + orange) → dur de les distinguer d'un coup d'œil. Je peux recolorer l'ennemi en teinte « hostile » (rouge sombre ou vert corrompu) pour qu'il se lise instantanément comme adversaire. Tu me dis si tu veux ça, ou si on garde le bleu.</div>

<footer>v7.4 en ligne · <b>whimora.itch.io/mecha-forge</b> · teste en navigation privée. Juggernaut retiré du spawn, sheets conservés au cas où.</footer>
</div>"""
open(OUTHTML,"w",encoding="utf-8").write("<title>Blue Strike — bras corrigés</title>\n<style>%s</style>\n%s"%(CSS,BODY))
print("OK",OUTHTML)
