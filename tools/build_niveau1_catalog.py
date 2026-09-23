# -*- coding: utf-8 -*-
"""Catalogue de validation NIVEAU 1 (idees Survivor.io) :
- 2 ennemis speciaux (Kamikaze / Invocateur) recolores depuis Blue Strike (GIF anime)
- 3 objets a ramasser (Bombe / Aimant / Coffre) dessines en PIL, style du jeu
Sort un HTML autonome pour artifact."""
import base64, io, os, sys, math, numpy as np
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.abspath("tools"))
from biome_paint3 import recolor
from biome_paint2 import GUNMETAL

OUT = r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad\niveau1.html"

def b64png(im):
    b=io.BytesIO(); im.save(b,"PNG"); return "data:image/png;base64,"+base64.b64encode(b.getvalue()).decode()
def b64gif(frames,dur=110):
    b=io.BytesIO(); frames[0].save(b,"GIF",save_all=True,append_images=frames[1:],duration=dur,loop=0,disposal=2)
    return "data:image/gif;base64,"+base64.b64encode(b.getvalue()).decode()

# ---------- ENEMIS speciaux (recolor Blue Strike, schema FIXE = reconnaissable partout) ----------
def b64file(path,w=560):
    im=Image.open(path).convert("RGB")
    if im.width>w: im=im.resize((w,int(im.height*w/im.width)))
    return b64png(im)
enemy_img={"kamikaze":b64file("cine/concepts/kamikaze.png"),
           "invocateur":b64file("cine/concepts/invocateur.png")}

# ---------- OBJETS a ramasser (PIL, glow style jeu) ----------
def glow(S,color,cx,cy,r,blur=16,a=200):
    g=Image.new("RGBA",(S,S),(0,0,0,0)); ImageDraw.Draw(g).ellipse([cx-r,cy-r,cx+r,cy+r],fill=color+(a,))
    return g.filter(ImageFilter.GaussianBlur(blur))
S=220
def sphere(S,cx,cy,r,base,hi):
    im=Image.new("RGBA",(S,S),(0,0,0,0)); d=ImageDraw.Draw(im)
    for i in range(r,0,-1):
        t=i/r; c=[int(base[k]+(hi[k]-base[k])*(1-t)**1.6) for k in range(3)]
        d.ellipse([cx-i,cy-i,cx+i,cy+i],fill=(c[0],c[1],c[2],255))
    return im

def draw_bomb():
    im=Image.new("RGBA",(S,S),(0,0,0,0))
    im=Image.alpha_composite(im, glow(S,(255,64,30),S//2,S//2+16,74,blur=28,a=120))
    cx,cy,r=S//2,S//2+22,56
    im=Image.alpha_composite(im, sphere(S,cx,cy,r,(14,15,20),(96,104,120)))
    im=Image.alpha_composite(im, glow(S,(150,170,205),cx-20,cy-22,16,blur=9,a=150))
    d=ImageDraw.Draw(im)
    d.line([(cx+16,cy-r+8),(cx+30,cy-r-16),(cx+44,cy-r-30)],fill=(92,82,70,255),width=6)
    im=Image.alpha_composite(im, glow(S,(255,140,50),cx+46,cy-r-32,28,blur=15,a=170))
    im=Image.alpha_composite(im, glow(S,(255,235,150),cx+46,cy-r-32,15,blur=7,a=245))
    return im

def draw_magnet():
    im=Image.new("RGBA",(S,S),(0,0,0,0)); d=ImageDraw.Draw(im)
    cx=S//2; top=56; bot=150; pw=30; off=54; midY=(top+bot)//2
    L=(cx-off-pw//2,cx-off+pw//2); R=(cx+off-pw//2,cx+off+pw//2)
    for (x0,x1) in (L,R):
        d.rectangle([x0,midY,x1,bot],fill=(158,166,182,255))            # silver bottom
        d.rectangle([x0,top,x1,midY],fill=(214,66,58,255))              # red top
    d.rectangle([L[0],bot-pw,R[1],bot],fill=(158,166,182,255))          # connector
    d.rounded_rectangle([L[0]-2,top-2,R[1]+2,bot+2],radius=6,outline=(26,28,34,255),width=3)
    for (x0,x1) in (L,R):
        im=Image.alpha_composite(im, glow(S,(120,225,255),(x0+x1)//2,top+4,20,blur=9,a=220))
    d=ImageDraw.Draw(im)
    for gx,gy in [(28,44),(190,62),(40,118),(196,116)]:
        d.line([(gx,gy),(cx,top+2)],fill=(120,235,150,55),width=3)
        d.polygon([(gx,gy-7),(gx+6,gy),(gx,gy+7),(gx-6,gy)],fill=(120,240,150,255))
    return im

def draw_chest():
    im=Image.new("RGBA",(S,S),(0,0,0,0))
    im=Image.alpha_composite(im, glow(S,(255,200,90),S//2,S//2+6,82,blur=28,a=115))
    d=ImageDraw.Draw(im); cx=S//2; w=132; x0=cx-w//2; x1=cx+w//2
    body_top=112; body_bot=172; lid_top=68
    d.rounded_rectangle([x0,body_top,x1,body_bot],radius=9,fill=(66,76,92,255))
    d.rounded_rectangle([x0,lid_top,x1,body_top+8],radius=11,fill=(90,102,122,255))
    for bx in (x0+24,x1-24):
        d.rectangle([bx-5,lid_top+2,bx+5,body_bot-2],fill=(150,160,176,255))
    d.rounded_rectangle([cx-11,body_top-14,cx+11,body_top+18],radius=4,fill=(236,192,92,255))
    d.line([(x0+6,body_top+4),(x1-6,body_top+4)],fill=(255,242,196,255),width=5)
    im=Image.alpha_composite(im, glow(S,(255,228,150),cx,body_top+4,54,blur=13,a=160))
    d=ImageDraw.Draw(im)
    for sx,sy,rr in [(x0+18,lid_top+2,3),(x1-16,body_top+30,2),(cx+30,lid_top-4,2)]:
        d.ellipse([sx-rr,sy-rr,sx+rr,sy+rr],fill=(255,255,235,255))
    return im

icons={"bombe":b64png(draw_bomb()),"aimant":b64png(draw_magnet()),"coffre":b64png(draw_chest())}

# ---------- data ----------
ENEMIES=[
 ("kamikaze","Surcharge","KAMIKAZE",enemy_img["kamikaze"],
  "Fonce droit sur toi et EXPLOSE au contact (ou a sa mort) — degats de ZONE. Avant-bras = ogives orange en surchauffe, PV faibles, tres rapide.",
  "Te force a bouger sans arret ; punit le camping. Les ogives qui crepitent = signal 'danger imminent'."),
 ("invocateur","Essaimeur","INVOCATEUR",enemy_img["invocateur"],
  "Garde ses distances et INVOQUE periodiquement des drones qui sortent de ses PODS. Ne fonce pas — il alimente la pression.",
  "Cible prioritaire : tant qu'il vit, la nuee se renouvelle. Baies violettes = signature 'a tuer en premier'."),
]
ITEMS=[
 ("bombe","Bombe","OBJET &middot; RARE",icons["bombe"],
  "Detruit (ou assomme) TOUS les ennemis a l'ecran. Le bouton panique quand la nuee deborde.",
  "Drop rare (elite / au sol). Moment fort garanti + respiration."),
 ("aimant","Aimant","OBJET &middot; OCCASIONNEL",icons["aimant"],
  "Aspire d'un coup TOUTES les gemmes XP de la carte. (On a deja le passif de portee — ca, c'est le drop instantane.)",
  "Petit pic de niveau + nettoie l'ecran des gemmes eparpillees."),
 ("coffre","Coffre d'elite","OBJET &middot; ELITE",icons["coffre"],
  "Lache par les elites. S'ouvre -> recompense GARANTIE : une arme/upgrade au choix, ou un paquet de scrap/soin.",
  "La carotte du mid-game : tuer un elite devient un evenement."),
]

def card(kind,name,tag,media,cls,caption,desc,why,tagcls):
    cap=f'<span class="cap">{caption}</span>' if caption else ''
    m=f'<div class="thumb {cls}"><img src="{media}">{cap}</div>'
    return f'''<figure class="card"><span class="tag {tagcls}">{tag}</span>{m}
      <figcaption><h3>{name} <span class="kind">&mdash; {kind}</span></h3>
      <p class="desc">{desc}</p><p class="why">{why}</p></figcaption></figure>'''

en_cards="".join(card(k,n,t,g,"en","Concept FLUX &middot; passage 3D anim\u00e9 apr\u00e8s validation",d,w,"en") for k,n,t,g,d,w in ENEMIES)
it_cards="".join(card(k,n,t,g,"it","",d,w,"it") for k,n,t,g,d,w in ITEMS)

CSS="""
:root{--bg:#0c0e12;--panel:#14171e;--bd:#262b34;--tx:#e8ebf2;--mut:#8b92a0;--acc:#f0a03c;--en:#e5566e;--it:#37c98a}
@media(prefers-color-scheme:light){:root{--bg:#f4f5f8;--panel:#fff;--bd:#dfe3ea;--tx:#181b21;--mut:#5c6472}}
:root[data-theme=light]{--bg:#f4f5f8;--panel:#fff;--bd:#dfe3ea;--tx:#181b21;--mut:#5c6472}
:root[data-theme=dark]{--bg:#0c0e12;--panel:#14171e;--bd:#262b34;--tx:#e8ebf2;--mut:#8b92a0}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--tx);font:15px/1.55 system-ui,'Segoe UI',Roboto,sans-serif}
.wrap{max-width:1000px;margin:0 auto;padding:44px 22px 80px}
.eyebrow{font:600 12px/1 ui-monospace,monospace;letter-spacing:.22em;color:var(--acc);text-transform:uppercase}
h1{font-size:31px;margin:.32em 0 .12em;letter-spacing:-.015em}
.lead{color:var(--mut);max-width:66ch;margin:0}
h2.sec{font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:var(--mut);font-family:ui-monospace,monospace;margin:38px 0 14px;display:flex;align-items:center;gap:10px}
h2.sec::after{content:"";flex:1;height:1px;background:var(--bd)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:16px}
.card{position:relative;background:var(--panel);border:1px solid var(--bd);border-radius:15px;overflow:hidden;display:flex;flex-direction:column}
.tag{position:absolute;top:11px;left:11px;z-index:2;font:700 9.5px/1 ui-monospace,monospace;letter-spacing:.08em;padding:5px 8px;border-radius:5px}
.tag.en{background:rgba(229,86,110,.16);color:var(--en);border:1px solid rgba(229,86,110,.4)}
.tag.it{background:rgba(55,201,138,.16);color:var(--it);border:1px solid rgba(55,201,138,.4)}
.thumb{position:relative;display:grid;place-items:center;overflow:hidden}
.thumb.en{aspect-ratio:1;background:#0e1015}
.thumb.en img{width:100%;height:100%;object-fit:cover}
.thumb.it{aspect-ratio:1.5;background:radial-gradient(circle at 50% 45%,#1b1f27,#0e1015)}
.thumb.it img{width:54%;height:88%;object-fit:contain}
.cap{position:absolute;left:0;right:0;bottom:0;padding:7px 10px;font:600 10px/1.3 ui-monospace,monospace;letter-spacing:.03em;color:#cdd3de;background:linear-gradient(0deg,rgba(8,9,12,.9),rgba(8,9,12,.5) 60%,transparent);text-align:center}
figcaption{padding:13px 15px 16px}
figcaption h3{margin:0 0 6px;font-size:16px}.kind{color:var(--mut);font-weight:500;font-size:14px}
.desc{margin:0 0 8px;font-size:13.5px;color:var(--tx)}
.why{margin:0;font-size:12.5px;color:var(--mut);border-top:1px solid var(--bd);padding-top:8px}
.note{background:linear-gradient(100deg,rgba(240,160,60,.12),transparent 70%);border:1px solid var(--bd);border-left:3px solid var(--acc);border-radius:11px;padding:14px 18px;margin:24px 0 4px;font-size:14px}.note b{color:var(--tx)}
footer{color:var(--mut);font-size:13px;border-top:1px solid var(--bd);margin-top:36px;padding-top:16px}
"""
BODY=f"""<div class="wrap">
<div class="eyebrow">Niveau 1 &middot; a valider avant integration</div>
<h1>5 nouveautes style Survivor.io</h1>
<p class="lead">Les ennemis speciaux sont des <b>concepts generes (FLUX)</b> pour valider le design ; les objets sont dessines dans le style du jeu. Rien n'est encore cable — tu valides d'abord.</p>

<div class="note"><b>Rendu genere :</b> mechs distincts, corps gunmetal + yeux rouges, couleur signature (orange=explose, violet=invoque) et surtout des <b>appendices de fonction lisibles</b>. Apres validation -> passage en <b>3D animable</b> (image&rarr;3D + bake 4 directions), comme les ennemis premium.</div>

<h2 class="sec">Ennemis speciaux</h2>
<div class="grid">{en_cards}</div>

<h2 class="sec">Objets a ramasser</h2>
<div class="grid">{it_cards}</div>

<div class="note"><b>Apres ta validation</b> je verifie chaque systeme dans le build (pour ne rien dupliquer), puis je cable : drop rates, effets, IA des 2 ennemis, ouverture du coffre. Tu pourras tout ajuster ensuite en jeu.</div>
<footer>Ennemis = concepts <b>flux-1.1-pro</b> (design a valider) &rarr; production 3D animee ensuite. Icones objets = rendu concept, implementation procedurale en jeu.</footer>
</div>"""
open(OUT,"w",encoding="utf-8").write("<title>Niveau 1 \u2014 Survivor.io ideas</title>\n<style>%s</style>\n%s"%(CSS,BODY))
print("OK",OUT)
