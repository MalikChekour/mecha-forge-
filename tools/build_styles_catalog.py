import base64, os
SP=r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad"
D="cine/_show/styles"
def b64(f):
    return "data:image/gif;base64,"+base64.b64encode(open(os.path.join(D,f),"rb").read()).decode()
PROTO=[
 ("style_acier.gif","Acier \u00b7 cyan"),("style_chrome_rouge.gif","Chrome \u00b7 rouge"),
 ("style_cobalt.gif","Cobalt"),("style_or_noir.gif","Or & noir"),
 ("style_olive_mil.gif","Militaire olive"),("style_orange_indus.gif","Industriel"),
 ("style_toxic_vert.gif","Toxique vert"),("style_violet_void.gif","Void violet"),
 ("style_crimson_clean.gif","Crimson (nettoy\u00e9)"),
]
LOURD=[("lourd_acier.gif","Acier"),("lourd_cobalt.gif","Cobalt"),("lourd_or_noir.gif","Or & noir"),("lourd_toxic_vert.gif","Toxique vert")]
def cards(items,live=True):
    L='<span class="live">\u25cf</span>' if live else ''
    return "".join('<figure class="card"><div class="thumb">%s<img src="%s" alt="%s"></div><figcaption><b>%s</b></figcaption></figure>'%(L,b64(f),n,n) for f,n in items)
CSS=""":root{--bg:#0d0f14;--p1:#14161d;--bd:#262b36;--tx:#e7e9f0;--mut:#8b91a0;--crim:#e5384d;--ok:#2fbf71;--warn:#e6a93a}
*{box-sizing:border-box}
body{margin:0;background:radial-gradient(1200px 600px at 70% -10%,#171a22,#0d0f14 60%);color:var(--tx);font:15px/1.5 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;-webkit-font-smoothing:antialiased}
.wrap{max-width:980px;margin:0 auto;padding:44px 22px 80px}
.eyebrow{font:600 12px/1 ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.22em;color:var(--crim);text-transform:uppercase}
h1{font-size:33px;margin:.35em 0 .15em;letter-spacing:-.02em}
.sub{color:var(--mut);max-width:64ch;margin:0}
.note{border:1px solid var(--bd);border-radius:10px;padding:13px 17px;margin:22px 0;font-size:14px}
.note.warn{background:linear-gradient(90deg,rgba(230,169,58,.13),transparent);border-left:3px solid var(--warn);color:#f0e2c6}
.note.ok{background:linear-gradient(90deg,rgba(47,191,113,.13),transparent);border-left:3px solid var(--ok);color:#d7f0e0}
.note b{color:#fff}
.shead{display:flex;align-items:baseline;gap:12px;border-bottom:1px solid var(--bd);padding-bottom:9px;margin:34px 0 16px;flex-wrap:wrap}
.shead h2{font-size:17px;margin:0}.shead p{color:var(--mut);font-size:12.5px;margin:0;flex:1;min-width:200px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:15px}
.card{margin:0;background:var(--p1);border:1px solid var(--bd);border-radius:14px;overflow:hidden;transition:.18s}
.card:hover{border-color:#3a4453;transform:translateY(-3px)}
.thumb{position:relative;aspect-ratio:1;background:#1e2129;display:grid;place-items:center}
.thumb img{width:100%;height:100%;object-fit:contain}
.live{position:absolute;top:9px;right:10px;color:var(--ok);font-size:11px;filter:drop-shadow(0 0 4px #2fbf71);animation:pulse 1.4s infinite}
@keyframes pulse{50%{opacity:.3}}
figcaption{padding:11px 13px}figcaption b{font-size:14px}
footer{color:var(--mut);font-size:13px;border-top:1px solid var(--bd);margin-top:38px;padding-top:18px}</style>"""
BODY="""<div class="wrap">
 <div class="eyebrow">Prototype \u00b7 exploration + finitions</div>
 <h1>Prototype \u2014 styles robot</h1>
 <p class="sub">M\u00eame mecha (course anim\u00e9e), red\u00e9taour\u00e9 puis recoloris\u00e9 en finitions robot : corps m\u00e9tal + lignes d'\u00e9nergie subtiles. Vignettes en direct.</p>
 <div class="note warn"><b>\u26a0 D\u00e9faut du Prototype :</b> une <b>tige qui pend aux jambes</b> (un appendice du mesh TRELLIS que le rig Mixamo \u00e9tire, diff\u00e9rent \u00e0 chaque frame). Le nettoyage 2D ne l'enl\u00e8ve pas proprement. Le d\u00e9tourage (halo/specks) est corrig\u00e9, mais cette tige vient de la 3D.</div>
 <div class="shead"><h2>Finitions du Prototype</h2><p>9 palettes appliqu\u00e9es en 1 clic (la tige reste tant qu'on garde ce mesh).</p></div>
 <div class="grid">%s</div>
 <div class="note ok"><b>\u2713 L'alternative propre :</b> nos <b>12 mechs Meshy</b> ont des rigs corrects \u2014 <b>z\u00e9ro tige</b>, jambes nettes, d\u00e9j\u00e0 anim\u00e9s. Exemple : <b>\u00ab lourd \u00bb</b> recoloris\u00e9 ci-dessous. M\u00eame recette de finition, base saine. C'est le chemin recommand\u00e9 pour un ennemi propre.</div>
 <div class="shead"><h2>Alternative propre \u2014 base Meshy \u00ab lourd \u00bb</h2><p>Rig sain, aucune tige. Recolorisable \u00e0 l'identique.</p></div>
 <div class="grid">%s</div>
 <footer>Dis-moi : (a) on garde le Prototype avec un style (je tente un trim du mesh dans Blender, incertain), ou (b) on bascule l'ennemi sur une base Meshy propre + le style choisi. Je penche (b).</footer>
</div>"""
html="<title>Prototype \u2014 styles robot</title>\n<style>%s\n%s"%(CSS, BODY%(cards(PROTO), cards(LOURD)))
open(os.path.join(SP,"proto_styles.html"),"w",encoding="utf-8").write(html)
print("styles catalog v2 bytes:", len(html))
