"""Recolorise les 5 ennemis Mixamo en metal (par role) + GIF original & metal, puis catalogue HTML."""
import base64, os, numpy as np
from PIL import Image
from scipy import ndimage
SP=r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad"
SRC="cine/_show/roster"; OUT="cine/_show/roster_gif"; os.makedirs(OUT, exist_ok=True)
ROSTER=[
 ("vanguard","Vanguard","B\u00c9LIER \u2014 chargeur lourd",
    [(0,(20,19,17)),(.4,(74,70,64)),(.72,(152,148,140)),(1,(242,238,230))],(255,140,28)),
 ("exo_gray","Exo Gray","R\u00d4DEUR \u2014 rusher rapide",
    [(0,(18,20,26)),(.4,(72,80,92)),(.72,(150,160,176)),(1,(236,243,252))],(70,205,255)),
 ("ely","Ely","RAIDER \u2014 \u00e9lite \u00e0 lames",
    [(0,(20,18,20)),(.4,(74,64,66)),(.72,(152,140,142)),(1,(242,232,234))],(232,46,56)),
 ("paladin","Paladin","SENTINELLE \u2014 bouclier",
    [(0,(14,17,26)),(.4,(48,60,90)),(.72,(122,142,182)),(1,(222,232,250))],(95,165,255)),
 ("mutant","Mutant","BROYEUR \u2014 brute \u00e0 lames",
    [(0,(16,20,16)),(.4,(56,66,54)),(.72,(120,142,118)),(1,(220,236,220))],(126,255,120)),
]
def lut(ramp):
    xs=[p[0] for p in ramp]; c=np.array([p[1] for p in ramp],float)
    t=np.linspace(0,1,256); return np.stack([np.interp(t,xs,c[:,k]) for k in range(3)],1)
def recolor(arr, ramp, accent, astr=.6):
    rgb=arr[:,:,:3].astype(float); a=arr[:,:,3]
    R,G,B=rgb[...,0],rgb[...,1],rgb[...,2]
    L=0.299*R+0.587*G+0.114*B; L=ndimage.median_filter(L,4); L=ndimage.gaussian_filter(L,0.7)
    L=np.clip((L-12)*1.18,0,255).astype(int)
    body=lut(ramp)[L]
    mx=np.maximum(np.maximum(R,G),B); mn=np.minimum(np.minimum(R,G),B)
    sat=(mx-mn)/255.0; bright=mx/255.0
    glow=np.clip((sat-0.28)*2.0,0,1)*np.clip((bright-0.35)*1.6,0,1)
    glow=(glow[...,None])*astr
    out=body*(1-glow)+np.array(accent,float)*glow
    res=np.zeros_like(arr); res[...,:3]=np.clip(out,0,255).astype(np.uint8); res[...,3]=a
    return res
def gifify(arr, out, sz=190, bg=(30,32,38)):
    fw=arr.shape[1]//8; frames=[]
    for i in range(8):
        cell=Image.fromarray(arr[:,i*fw:(i+1)*fw],"RGBA"); b=Image.new("RGBA",cell.size,bg+(255,)); b.alpha_composite(cell)
        frames.append(b.convert("RGB").resize((sz,sz)).convert("P",palette=Image.ADAPTIVE))
    frames[0].save(out,save_all=True,append_images=frames[1:],duration=110,loop=0,disposal=2)
made=[]
for slug,name,role,ramp,acc in ROSTER:
    p=f"{SRC}/{slug}_front.png"
    if not os.path.exists(p): print("MISS",slug); continue
    arr=np.array(Image.open(p).convert("RGBA"))
    gifify(arr, f"{OUT}/orig_{slug}.gif")
    gifify(recolor(arr,ramp,acc), f"{OUT}/metal_{slug}.gif")
    made.append((slug,name,role)); print("done",slug)
# catalog
def b64(f): return "data:image/gif;base64,"+base64.b64encode(open(f"{OUT}/{f}","rb").read()).decode()
cards="".join('<figure class="card"><div class="pair"><div class="t"><span class="tag">MIXAMO</span><img src="%s"></div><div class="t"><span class="tag m">M\u00c9TAL</span><img src="%s"></div></div><figcaption><b>%s</b><span class="role">%s</span></figcaption></figure>'%(b64("orig_%s.gif"%s),b64("metal_%s.gif"%s),n,r) for s,n,r in made)
CSS=""":root{--bg:#0d0f14;--p1:#14161d;--bd:#262b36;--tx:#e7e9f0;--mut:#8b91a0;--crim:#e5384d;--ok:#2fbf71}
*{box-sizing:border-box}body{margin:0;background:radial-gradient(1200px 600px at 70% -10%,#171a22,#0d0f14 60%);color:var(--tx);font:15px/1.5 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
.wrap{max-width:1000px;margin:0 auto;padding:44px 22px 80px}
.eyebrow{font:600 12px/1 ui-monospace,Menlo,monospace;letter-spacing:.22em;color:var(--crim);text-transform:uppercase}
h1{font-size:32px;margin:.35em 0 .15em}.sub{color:var(--mut);max-width:64ch;margin:0}
.banner{background:linear-gradient(90deg,rgba(47,191,113,.13),transparent);border:1px solid var(--bd);border-left:3px solid var(--ok);border-radius:10px;padding:14px 18px;margin:24px 0 30px;color:#d7f0e0;font-size:14px}.banner b{color:#fff}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:16px}
.card{background:var(--p1);border:1px solid var(--bd);border-radius:14px;overflow:hidden}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:2px;background:var(--bd)}
.t{position:relative;aspect-ratio:1;background:#1e2129;display:grid;place-items:center}
.t img{width:100%;height:100%;object-fit:contain}
.tag{position:absolute;top:7px;left:8px;font:600 9px/1 ui-monospace,monospace;letter-spacing:.08em;color:var(--mut);background:rgba(0,0,0,.5);padding:3px 6px;border-radius:5px}
.tag.m{color:#7ee0a8}
figcaption{padding:12px 14px}figcaption b{font-size:15px}.role{color:var(--mut);font-size:12.5px;display:block;margin-top:2px}
footer{color:var(--mut);font-size:13px;border-top:1px solid var(--bd);margin-top:38px;padding-top:18px}"""
BODY="""<div class="wrap"><div class="eyebrow">Ennemis \u00b7 avant validation</div>
<h1>Roster Mixamo \u2014 anim\u00e9 + recolor m\u00e9tal</h1>
<p class="sub">Les 5 persos valid\u00e9s, pass\u00e9s au pipeline : course anim\u00e9e (rig Adobe propre, z\u00e9ro tige) + finition m\u00e9tal par r\u00f4le. Gauche = Mixamo brut, droite = recolor m\u00e9tal. Tout joue en direct.</p>
<div class="banner"><b>\u00c0 valider :</b> le rendu te va ? Je peux ajuster la teinte/finition de chacun. Une fois OK, je les c\u00e2ble en jeu (spawner + teinte biome + \u00e9chelle) \u2014 on peut commencer par 1 pour tester en jeu.</div>
<div class="grid">%s</div>
<footer>Anims: course (In Place). Prochaines: attaque/mort par ennemi si besoin. Recolor 100%% ajustable.</footer></div>"""
open(os.path.join(SP,"roster_validation.html"),"w",encoding="utf-8").write("<title>Roster Mixamo \u2014 validation</title>\n<style>%s</style>\n%s"%(CSS,BODY%cards))
print("catalog written, enemies:", len(made))
