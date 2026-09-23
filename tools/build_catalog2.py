import base64, os
SP=r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad"
cat="cine/_show/catalog"
def b64(f):
    p=os.path.join(cat,f); mime="image/gif" if f.endswith(".gif") else "image/png"
    return "data:%s;base64,%s"%(mime, base64.b64encode(open(p,"rb").read()).decode())
GROUPS=[
 ("Ennemis \u2014 Premium ANIM\u00c9","anim","Qualit\u00e9 premium + vraie animation. Pipeline FLUX\u2192TRELLIS\u2192Mixamo prouv\u00e9.",[
    ("mixtest","Prototype","course \u00b7 test Mixamo valid\u00e9","gif")]),
 ("Mechs Meshy \u2014 d\u00e9j\u00e0 ANIM\u00c9S (r\u00e9utilisables comme ennemis)","mesh","Anciennes versions du joueur, faites sur Meshy/TRELLIS. D\u00e9j\u00e0 rigg\u00e9es + anim\u00e9es 4-dir \u2192 utilisables direct comme ennemis, sans re-rig.",[
    ("mech_vortex","VORTEX","joueur ACTUEL","gif"),
    ("mech_valiant","Valiant","proto joueur","gif"),
    ("mech_vanguard","Vanguard","proto joueur","gif"),
    ("mech_vanguard2","Vanguard-2","forme overdrive","gif"),
    ("mech_titan","Titan","ch\u00e2ssis lourd","gif"),
    ("mech_darkstar","Darkstar","proto","gif"),
    ("mech_bluestrike","Bluestrike","proto","gif"),
    ("mech_new_mecha","New-Mecha","proto","gif"),
    ("mech_mecha_joueur","Mecha v1","proto v1","gif"),
    ("mech_lourd","Lourd","ch\u00e2ssis lourd","gif"),
    ("mech_pilot","Pilote","perso \u00e0 pied","gif"),
    ("mech_george","George","joueur Quaternius","gif")]),
 ("Ennemis \u2014 Premium STATIQUE (\u00e0 animer)","static","Look premium mais fig\u00e9. \u00c0 passer par Mixamo (ou remplacer par un mech Meshy anim\u00e9 ci-dessus).",[
    ("u_rodeur","R\u00f4deur","r\u00f4deur m\u00eal\u00e9e \u00b7 universel","png"),
    ("u_guepe","Gu\u00eape","drone volant \u00b7 universel","png"),
    ("u_belier","B\u00e9lier","chargeur lourd \u00b7 universel","png"),
    ("shielded","Sentinelle","trooper \u00e0 bouclier","png"),
    ("warden","Artilleur","canonnier lourd","png"),
    ("eyedrone","Essaim","drone essaim","png")]),
 ("Boss \u2014 anim\u00e9 (ancien art)","boss","Anim\u00e9s, art \u00e0 repasser au niveau premium.",[
    ("midboss_quad","Colosse","mid-boss quadrup\u00e8de","gif"),
    ("endboss_boss","Souverain","boss final","gif")]),
 ("Ennemis \u2014 ancien roster anim\u00e9 (rejet\u00e9)","old","Anciennes anims (Meshy/Quaternius) \u00ab moche \u00bb, sur le disque, hors-jeu.",[
    ("brute","R\u00f4deur v0","ancien","gif"),
    ("elite","Raider v0","ancien","gif"),
    ("crusher","Broyeur v0","ancien","gif"),
    ("drone","Gu\u00eape v0","ancien","gif"),
    ("quadshell","Quad v0","ancien","gif")]),
]
CHIP={"anim":("ANIM\u00c9","c-anim"),"mesh":("ANIM\u00c9","c-mesh"),"static":("STATIQUE","c-static"),"boss":("ANIM\u00c9","c-boss"),"old":("ANIM\u00c9 \u00b7 REJET\u00c9","c-old")}
def cards(items,kind):
    lbl,cls=CHIP[kind]; out=[]
    for ch,name,role,ext in items:
        src=b64(ch+"."+ext); live='<span class="live">\u25cf</span>' if ext=="gif" else ''
        out.append('<figure class="card"><div class="thumb">%s<img src="%s" alt="%s" loading="lazy"></div><figcaption><b>%s</b><span class="role">%s</span><span class="chip %s">%s</span></figcaption></figure>'%(live,src,name,name,role,cls,lbl))
    return "\n".join(out)
sections="".join('<section><div class="shead"><h2>%s</h2><p>%s</p><span class="count">%d</span></div><div class="grid">%s</div></section>'%(t,d,len(it),cards(it,k)) for t,k,d,it in GROUPS)
CSS=""":root{--bg:#0d0f14;--p1:#14161d;--bd:#262b36;--tx:#e7e9f0;--mut:#8b91a0;--crim:#e5384d;--anim:#2fbf71;--mesh:#3aa0e6;--static:#e6a93a;--boss:#a479ff;--old:#6b7280;}
*{box-sizing:border-box}
body{margin:0;background:radial-gradient(1200px 600px at 70% -10%,#171a22,#0d0f14 60%);color:var(--tx);font:15px/1.5 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;-webkit-font-smoothing:antialiased}
.wrap{max-width:1100px;margin:0 auto;padding:40px 22px 80px}
.eyebrow{font:600 12px/1 ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.22em;color:var(--crim);text-transform:uppercase}
h1{font-size:34px;margin:.35em 0 .15em;letter-spacing:-.02em;text-wrap:balance}
.sub{color:var(--mut);max-width:64ch;margin:0}
.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:26px 0}
.tile{background:var(--p1);border:1px solid var(--bd);border-radius:12px;padding:14px 16px}
.tile .n{font:700 26px/1 ui-monospace,monospace;font-variant-numeric:tabular-nums}
.tile .k{color:var(--mut);font-size:12.5px;margin-top:4px}
.tile.anim .n{color:var(--anim)} .tile.mesh .n{color:var(--mesh)} .tile.static .n{color:var(--static)} .tile.old .n{color:var(--old)}
.banner{background:linear-gradient(90deg,rgba(58,160,230,.14),transparent);border:1px solid var(--bd);border-left:3px solid var(--mesh);border-radius:10px;padding:14px 18px;margin:6px 0 34px;color:#dbe7f2}
.banner b{color:#fff}
section{margin:34px 0}
.shead{display:flex;align-items:baseline;gap:12px;border-bottom:1px solid var(--bd);padding-bottom:10px;margin-bottom:18px;flex-wrap:wrap}
.shead h2{font-size:16px;margin:0}
.shead p{color:var(--mut);font-size:12.5px;margin:0;flex:1;min-width:220px}
.shead .count{font:700 13px/1 ui-monospace,monospace;color:var(--mut);border:1px solid var(--bd);border-radius:20px;padding:5px 10px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:13px}
.card{margin:0;background:var(--p1);border:1px solid var(--bd);border-radius:13px;overflow:hidden;transition:.18s}
.card:hover{border-color:#374052;transform:translateY(-2px)}
.thumb{position:relative;aspect-ratio:1;background:#20232c;display:grid;place-items:center}
.thumb img{width:100%;height:100%;object-fit:contain}
.live{position:absolute;top:8px;right:9px;color:var(--anim);font-size:11px;filter:drop-shadow(0 0 4px #2fbf71);animation:pulse 1.4s infinite}
@keyframes pulse{50%{opacity:.3}}
figcaption{padding:10px 12px;display:flex;flex-direction:column;gap:2px}
figcaption b{font-size:13.5px}
.role{color:var(--mut);font-size:11.5px}
.chip{align-self:flex-start;margin-top:6px;font:600 9.5px/1 ui-monospace,monospace;letter-spacing:.07em;padding:4px 7px;border-radius:6px;text-transform:uppercase}
.c-anim{background:rgba(47,191,113,.16);color:#7ee0a8;border:1px solid rgba(47,191,113,.35)}
.c-mesh{background:rgba(58,160,230,.16);color:#8fccf3;border:1px solid rgba(58,160,230,.35)}
.c-static{background:rgba(230,169,58,.14);color:#e6c377;border:1px solid rgba(230,169,58,.3)}
.c-boss{background:rgba(164,121,255,.15);color:#c3a7ff;border:1px solid rgba(164,121,255,.32)}
.c-old{background:rgba(107,114,128,.16);color:#a3a9b5;border:1px solid rgba(107,114,128,.35)}
footer{color:var(--mut);font-size:13px;border-top:1px solid var(--bd);margin-top:40px;padding-top:18px}
@media(max-width:560px){.stats{grid-template-columns:repeat(2,1fr)}h1{font-size:27px}}"""
BODY="""<div class="wrap">
 <div class="eyebrow">Mecha-Forge \u00b7 inventaire complet</div>
 <h1>Catalogue \u2014 ennemis &amp; mechs</h1>
 <p class="sub">Tout ce qu'on a sur le disque (ennemis + tous les mechs Meshy), class\u00e9 par \u00e9tat. Les vignettes anim\u00e9es jouent en direct (\u25cf).</p>
 <div class="stats">
   <div class="tile anim"><div class="n">1</div><div class="k">Ennemi premium \u00b7 anim\u00e9</div></div>
   <div class="tile mesh"><div class="n">12</div><div class="k">Mechs Meshy \u00b7 anim\u00e9s</div></div>
   <div class="tile static"><div class="n">6</div><div class="k">Ennemi premium \u00b7 statique</div></div>
   <div class="tile old"><div class="n">7</div><div class="k">Boss &amp; anciens \u00b7 anim\u00e9s</div></div>
 </div>
 <div class="banner"><b>La grosse r\u00e9serve : 12 mechs Meshy D\u00c9J\u00c0 ANIM\u00c9S</b> (anciennes versions du joueur, rigg\u00e9es 4-dir). R\u00e9utilisables <b>directement comme ennemis anim\u00e9s</b>, sans repasser par Mixamo. C\u00f4t\u00e9 ennemis, un seul est premium+anim\u00e9 (le Prototype) ; le roster premium actuel est statique.</div>
 %s
 <footer>G\u00e9n\u00e9r\u00e9 depuis <code>game/assets/enemies</code> et <code>game/assets/mecha</code>. Piste rapide pour un roster anim\u00e9 : recycler les mechs Meshy en ennemis (teinte + \u00e9chelle), plut\u00f4t que tout re-rigger.</footer>
</div>"""
html="<title>Catalogue ennemis & mechs \u2014 MECHA-FORGE</title>\n<style>%s</style>\n%s"%(CSS, BODY%sections)
open(os.path.join(SP,"enemy_catalog.html"),"w",encoding="utf-8").write(html)
print("catalog v2 bytes:", len(html))
