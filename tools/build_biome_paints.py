"""Catalogue v3 : Blue Strike repeint par biome, recolor multi-materiau
+ YEUX ROUGES (signature) + armure detaillee/sharpen. GIF anime par biome."""
import base64, os, io, sys, numpy as np
from PIL import Image
sys.path.insert(0, os.path.abspath("tools"))
from biome_paint3 import recolor
from biome_paint2 import BIOMES

SRC = "meshy_in/bluestrike_eyebase/walk_front.png"
OUTHTML = r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad\biome_paints.html"

def gif_b64(sheet, ramp, trim, energy, glow, sz=190):
    fw=sheet.shape[1]//8; fr=[]
    for i in range(8):
        cell=recolor(sheet[:,i*fw:(i+1)*fw], ramp, trim, energy, glow)
        im=Image.fromarray(cell,"RGBA"); b=Image.new("RGBA",im.size,(22,24,30,255)); b.alpha_composite(im)
        fr.append(b.convert("RGB").resize((sz,sz)).convert("P",palette=Image.ADAPTIVE))
    buf=io.BytesIO(); fr[0].save(buf,"GIF",save_all=True,append_images=fr[1:],duration=110,loop=0,disposal=2)
    return "data:image/gif;base64,"+base64.b64encode(buf.getvalue()).decode()

sheet=np.array(Image.open(SRC).convert("RGBA"))
cards=""
for key,bname,pname,ramp,trim,energy,glow,spec in BIOMES:
    g=gif_b64(sheet,ramp,trim,energy,glow)
    cards+=f'''<figure class="card"><div class="thumb"><span class="live">\u25cf</span><img src="{g}"></div>
    <figcaption><div class="bhead"><b>{bname}</b><span class="pn">{pname}</span></div><p class="spec">{spec}</p></figcaption></figure>'''

CSS="""
:root{--bg:#0c0e13;--card:#14171f;--bd:#242a35;--tx:#e8ebf2;--mut:#8d94a3;--accent:#e5556a;--ok:#3ecf8e}
@media(prefers-color-scheme:light){:root{--bg:#f4f5f8;--card:#fff;--bd:#dfe3ea;--tx:#1a1d24;--mut:#5b6270}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--tx);font:15px/1.55 system-ui,Segoe UI,Roboto,sans-serif}
.wrap{max-width:1040px;margin:0 auto;padding:40px 22px 70px}
.eyebrow{font:600 12px/1 ui-monospace,monospace;letter-spacing:.22em;color:var(--accent);text-transform:uppercase}
h1{font-size:30px;margin:.35em 0 .1em}.sub{color:var(--mut);max-width:70ch;margin:0}
.banner{background:linear-gradient(90deg,rgba(229,85,106,.12),transparent);border:1px solid var(--bd);border-left:3px solid var(--accent);border-radius:10px;padding:13px 18px;margin:22px 0 26px;font-size:14px}.banner b{color:var(--tx)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:16px}
.card{background:var(--card);border:1px solid var(--bd);border-radius:14px;overflow:hidden}
.thumb{position:relative;aspect-ratio:1;background:radial-gradient(circle at 50% 40%,#1e2129,#0e1015);display:grid;place-items:center}
.thumb img{width:90%;height:90%;object-fit:contain}
.live{position:absolute;top:9px;right:10px;color:var(--ok);font-size:11px;filter:drop-shadow(0 0 4px #3ecf8e);animation:pulse 1.4s infinite}@keyframes pulse{50%{opacity:.3}}
figcaption{padding:12px 14px 15px}.bhead{display:flex;flex-direction:column;gap:1px}.bhead b{font-size:15px}
.pn{color:#f0913c;font:600 12px/1.2 ui-monospace,monospace;letter-spacing:.03em}
.spec{color:var(--mut);font-size:12.5px;margin:9px 0 0}
footer{color:var(--mut);font-size:13px;border-top:1px solid var(--bd);margin-top:34px;padding-top:16px}
"""
BODY=f"""<div class="wrap">
<div class="eyebrow">Blue Strike \u00b7 ennemi de base \u00b7 yeux rouges + peinture biome</div>
<h1>Les machines \u2014 neuf corruptions</h1>
<p class="sub">M\u00eame ch\u00e2ssis, <b style="color:#e5556a">yeux rouges signature</b> sur tous (les machines), puis armure + c\u0153ur d'\u00e9nergie repeints par biome. Zones peintes s\u00e9par\u00e9ment + d\u00e9tail accentu\u00e9 \u2014 fini l'aplat uni. Vignettes anim\u00e9es.</p>
<div class="banner"><b>\u00c0 valider :</b> le niveau de d\u00e9tail + les <b>yeux rouges</b> (je peux les agrandir/att\u00e9nuer), et la peinture de chaque biome. Une fois cal\u00e9 \u2192 bake 4 directions \u00d7 9 biomes + c\u00e2blage.</div>
<div class="grid">{cards}</div>
<footer>Yeux = \u00e9l\u00e9ment \u00e9missif bak\u00e9 sur la t\u00eate (correct dans toutes les directions), keyé puis forc\u00e9 rouge. Recolor multi-mat\u00e9riau + sharpen. Mecha joueur non touch\u00e9.</footer>
</div>"""
open(OUTHTML,"w",encoding="utf-8").write("<title>Blue Strike \u2014 9 biomes</title>\n<style>%s</style>\n%s"%(CSS,BODY))
print("OK",OUTHTML)
