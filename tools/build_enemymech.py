"""Recolorise les mechas Meshy en machines ENNEMIES (metal sombre + accent rouge),
avec re-cadrage auto (les sheets Meshy ont des echelles differentes), + catalogue."""
import base64, os, numpy as np
from PIL import Image
from scipy import ndimage
SP=r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad"
OUT="cine/_show/enemymech"; os.makedirs(OUT, exist_ok=True)
ROSTER=[("lourd","Lourd","B\u00c9LIER \u2014 chargeur lourd"),
        ("titan","Titan","BROYEUR \u2014 brute lourde"),
        ("valiant","Valiant","RAIDER \u2014 lames"),
        ("bluestrike","Bluestrike","R\u00d4DEUR \u2014 rusher"),
        ("vanguard","Vanguard-M","SENTINELLE \u2014 blind\u00e9"),
        ("mecha_joueur","Grunt","GRUNT \u2014 contact de base")]
RAMP=[(0,(12,12,16)),(.4,(46,48,56)),(.72,(112,116,128)),(1,(206,212,224))]
ACC=(232,48,42)
def lutf(r):
    xs=[p[0] for p in r]; c=np.array([p[1] for p in r],float)
    t=np.linspace(0,1,256); return np.stack([np.interp(t,xs,c[:,k]) for k in range(3)],1)
LUT=lutf(RAMP)
def autoframe(arr, pad=0.10):
    """Union bbox across 8 cells -> crop each cell to it -> paste centered square."""
    h=arr.shape[0]; fw=arr.shape[1]//8
    cells=[arr[:, i*fw:(i+1)*fw].copy() for i in range(8)]
    x0,y0,x1,y1=fw,h,0,0
    for c in cells:
        ys,xs=np.where(c[:,:,3]>40)
        if len(xs): x0=min(x0,xs.min());x1=max(x1,xs.max());y0=min(y0,ys.min());y1=max(y1,ys.max())
    if x1<=x0: return arr
    bw=x1-x0; bh=y1-y0; side=int(max(bw,bh)*(1+pad*2))
    out=np.zeros((side, side*8, 4), np.uint8)
    for i,c in enumerate(cells):
        sub=c[y0:y1+1, x0:x1+1]
        ox=(side-sub.shape[1])//2; oy=side-sub.shape[0]-int(side*pad)  # feet near bottom
        oy=max(0,min(oy, side-sub.shape[0]))
        out[oy:oy+sub.shape[0], i*side+ox:i*side+ox+sub.shape[1]]=sub
    return out
def recolor(arr):
    rgb=arr[:,:,:3].astype(float); a=arr[:,:,3]
    R,G,B=rgb[...,0],rgb[...,1],rgb[...,2]
    L=0.299*R+0.587*G+0.114*B; L=ndimage.median_filter(L,4); L=ndimage.gaussian_filter(L,0.7)
    L=np.clip((L-10)*1.2,0,255).astype(int)
    body=LUT[L]
    mx=np.maximum(np.maximum(R,G),B); mn=np.minimum(np.minimum(R,G),B)
    glow=(np.clip(((mx-mn)/255-0.25)*2,0,1)*np.clip((mx/255-0.35)*1.6,0,1))[...,None]*0.55
    out=body*(1-glow)+np.array(ACC,float)*glow
    res=np.zeros_like(arr); res[...,:3]=np.clip(out,0,255).astype(np.uint8); res[...,3]=a
    return res
def gif(arr,out,sz=190):
    fw=arr.shape[1]//8; fr=[]
    for i in range(8):
        cell=Image.fromarray(arr[:,i*fw:(i+1)*fw],"RGBA"); b=Image.new("RGBA",cell.size,(26,28,34,255)); b.alpha_composite(cell)
        fr.append(b.convert("RGB").resize((sz,sz)).convert("P",palette=Image.ADAPTIVE))
    fr[0].save(out,save_all=True,append_images=fr[1:],duration=110,loop=0,disposal=2)
made=[]
for ch,name,role in ROSTER:
    p=f"game/assets/mecha/{ch}_walk_front.png"
    if not os.path.exists(p): print("miss",ch); continue
    arr=autoframe(np.array(Image.open(p).convert("RGBA")))
    gif(recolor(arr), f"{OUT}/en_{ch}.gif")
    made.append((ch,name,role)); print("done",ch)
def b64(f): return "data:image/gif;base64,"+base64.b64encode(open(f"{OUT}/en_{f}.gif","rb").read()).decode()
cards="".join('<figure class="card"><div class="thumb"><span class="live">\u25cf</span><img src="%s"></div><figcaption><b>%s</b><span class="role">%s</span></figcaption></figure>'%(b64(ch),name,role) for ch,name,role in made)
CSS=""":root{--bg:#0d0f14;--p1:#14161d;--bd:#262b36;--tx:#e7e9f0;--mut:#8b91a0;--crim:#e5384d;--ok:#2fbf71}
*{box-sizing:border-box}body{margin:0;background:radial-gradient(1200px 600px at 70% -10%,#171a22,#0d0f14 60%);color:var(--tx);font:15px/1.5 system-ui,Segoe UI,Roboto,sans-serif}
.wrap{max-width:1000px;margin:0 auto;padding:44px 22px 80px}
.eyebrow{font:600 12px/1 ui-monospace,Menlo,monospace;letter-spacing:.22em;color:var(--crim);text-transform:uppercase}
h1{font-size:32px;margin:.35em 0 .15em}.sub{color:var(--mut);max-width:64ch;margin:0}
.banner{background:linear-gradient(90deg,rgba(47,191,113,.13),transparent);border:1px solid var(--bd);border-left:3px solid var(--ok);border-radius:10px;padding:14px 18px;margin:24px 0 30px;color:#d7f0e0;font-size:14px}.banner b{color:#fff}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:15px}
.card{background:var(--p1);border:1px solid var(--bd);border-radius:14px;overflow:hidden;transition:.18s}.card:hover{border-color:#3a4453;transform:translateY(-3px)}
.thumb{position:relative;aspect-ratio:1;background:#1c1e25;display:grid;place-items:center}.thumb img{width:100%;height:100%;object-fit:contain}
.live{position:absolute;top:8px;right:9px;color:var(--ok);font-size:11px;filter:drop-shadow(0 0 4px #2fbf71);animation:pulse 1.4s infinite}@keyframes pulse{50%{opacity:.3}}
figcaption{padding:11px 13px}figcaption b{font-size:14.5px}.role{color:var(--mut);font-size:12px;display:block;margin-top:2px}
footer{color:var(--mut);font-size:13px;border-top:1px solid var(--bd);margin-top:38px;padding-top:18px}"""
BODY="""<div class="wrap"><div class="eyebrow">Ennemis \u00b7 vrais mechas</div>
<h1>Ennemis mecha \u2014 base Meshy recolor</h1>
<p class="sub">Mixamo = soldats humains, pas des mechas. Voici la vraie r\u00e9ponse : nos <b>mechas Meshy</b> (d\u00e9j\u00e0 anim\u00e9s 4-dir, rigs propres) recoloris\u00e9s en <b>machines ennemies</b> (m\u00e9tal sombre + \u00e9nergie rouge). Ce sont de VRAIS robots, coh\u00e9rents avec ton mecha joueur. Vignettes en direct.</p>
<div class="banner"><b>Ma proposition :</b> ce roster de mechas ennemis (r\u00f4les indiqu\u00e9s). Tous d\u00e9j\u00e0 anim\u00e9s, z\u00e9ro tige, teinte ajustable. Dis-moi lesquels tu gardes \u2192 je les c\u00e2ble comme le Vanguard test.</div>
<div class="grid">%s</div>
<footer>Palette \u00ab machine corrompue \u00bb (gunmetal + rouge) ajustable par r\u00f4le. Re-cadrage auto appliqu\u00e9 pour une \u00e9chelle homog\u00e8ne.</footer></div>"""
open(os.path.join(SP,"enemy_mechs.html"),"w",encoding="utf-8").write("<title>Ennemis mecha \u2014 Meshy</title>\n<style>%s</style>\n%s"%(CSS,BODY%cards))
print("catalog", len(made))
