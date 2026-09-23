import base64, os
SP=r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad"
D="cine/_show/mixchars"
def b64(slug):
    return "data:image/png;base64,"+base64.b64encode(open(os.path.join(D,"thumb_%s.png"%slug),"rb").read()).decode()
GROUPS=[
 ("Machines &amp; soldats blind\u00e9s","reco","Recolor\u00e9s en m\u00e9tal = \u00ab machines corrompues \u00bb. Base id\u00e9ale pour les ennemis de contact. Rig Adobe propre.",[
   ("vanguard","Vanguard","B\u00c9LIER \u2014 chargeur lourd","reco"),
   ("exo_gray","Exo Gray","R\u00d4DEUR \u2014 rusher rapide","reco"),
   ("ely","Ely","RAIDER \u2014 \u00e9lite \u00e0 lames","reco"),
   ("paladin","Paladin","SENTINELLE \u2014 bouclier blind\u00e9","reco"),
   ("crypto","Crypto","FANT\u00d4ME \u2014 infiltrateur fin","opt"),
   ("alien_soldier","Alien Soldier","TRAQUEUR \u2014 silhouette organique","opt"),
   ("akai","Akai","ASSASSIN \u2014 agile / dasher","opt"),
 ]),
 ("Monstres &amp; b\u00eates (vari\u00e9t\u00e9)","mon","Si tu veux de la corruption organique en plus des machines. M\u00eame rig propre.",[
   ("mutant","Mutant","BROYEUR \u2014 brute \u00e0 lames d'\u00e9nergie (colle au th\u00e8me)","reco"),
   ("warrok","Warrok","OGRE \u2014 brute lourde","opt"),
   ("maw","Maw","B\u00caTE \u2014 quadrup\u00e8de cornu","opt"),
   ("pumpkinhulk","Pumpkin Hulk","COLOSSE \u2014 mini-boss","opt"),
   ("demon","Demon","INVOCATEUR \u2014 caster distance","opt"),
 ]),
]
def cards(items):
    out=[]
    for slug,name,role,tag in items:
        chip='<span class="chip reco">RECOMMAND\u00c9</span>' if tag=="reco" else '<span class="chip opt">OPTION</span>'
        out.append('<figure class="card"><div class="thumb"><img src="%s" alt="%s"></div><figcaption><b>%s</b><span class="role">%s</span>%s</figcaption></figure>'%(b64(slug),name,name,role,chip))
    return "".join(out)
sections="".join('<section><div class="shead"><h2>%s</h2><p>%s</p><span class="count">%d</span></div><div class="grid">%s</div></section>'%(t,d,len(it),cards(it)) for t,k,d,it in GROUPS)
CSS=""":root{--bg:#0d0f14;--p1:#14161d;--bd:#262b36;--tx:#e7e9f0;--mut:#8b91a0;--crim:#e5384d;--reco:#2fbf71;--opt:#6b7280}
*{box-sizing:border-box}
body{margin:0;background:radial-gradient(1200px 600px at 70% -10%,#171a22,#0d0f14 60%);color:var(--tx);font:15px/1.5 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;-webkit-font-smoothing:antialiased}
.wrap{max-width:1040px;margin:0 auto;padding:44px 22px 80px}
.eyebrow{font:600 12px/1 ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.22em;color:var(--crim);text-transform:uppercase}
h1{font-size:33px;margin:.35em 0 .15em;letter-spacing:-.02em}
.sub{color:var(--mut);max-width:66ch;margin:0}
.banner{background:linear-gradient(90deg,rgba(47,191,113,.13),transparent);border:1px solid var(--bd);border-left:3px solid var(--reco);border-radius:10px;padding:14px 18px;margin:24px 0 30px;color:#d7f0e0;font-size:14px}
.banner b{color:#fff}
.shead{display:flex;align-items:baseline;gap:12px;border-bottom:1px solid var(--bd);padding-bottom:9px;margin:32px 0 16px;flex-wrap:wrap}
.shead h2{font-size:17px;margin:0}.shead p{color:var(--mut);font-size:12.5px;margin:0;flex:1;min-width:220px}
.shead .count{font:700 13px/1 ui-monospace,monospace;color:var(--mut);border:1px solid var(--bd);border-radius:20px;padding:5px 10px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:15px}
.card{margin:0;background:var(--p1);border:1px solid var(--bd);border-radius:14px;overflow:hidden;transition:.18s}
.card:hover{border-color:#3a4453;transform:translateY(-3px)}
.thumb{aspect-ratio:.92;background:linear-gradient(180deg,#2a2d35,#191b21);display:grid;place-items:center}
.thumb img{width:100%;height:100%;object-fit:contain}
figcaption{padding:11px 13px;display:flex;flex-direction:column;gap:3px}
figcaption b{font-size:14.5px}
.role{color:var(--mut);font-size:12px}
.chip{align-self:flex-start;margin-top:6px;font:600 9.5px/1 ui-monospace,monospace;letter-spacing:.07em;padding:4px 8px;border-radius:6px}
.chip.reco{background:rgba(47,191,113,.16);color:#7ee0a8;border:1px solid rgba(47,191,113,.35)}
.chip.opt{background:rgba(107,114,128,.16);color:#a3a9b5;border:1px solid rgba(107,114,128,.35)}
footer{color:var(--mut);font-size:13px;border-top:1px solid var(--bd);margin-top:38px;padding-top:18px}"""
BODY="""<div class="wrap">
 <div class="eyebrow">Ennemis \u00b7 proposition de design</div>
 <h1>Designs d'ennemis \u2014 biblioth\u00e8que Mixamo</h1>
 <p class="sub">R\u00e9ponse \u00e0 ta question : oui, Mixamo a une biblioth\u00e8que gratuite (~50 persos), tous <b>rigg\u00e9s proprement par Adobe</b> \u2014 donc <b>z\u00e9ro tige/fonte</b> comme sur nos meshes IA. Voici les candidats ennemis, avec le r\u00f4le que je propose pour chacun.</p>
 <div class="banner"><b>Ma proposition :</b> partir sur 4-5 <b>machines</b> (Vanguard, Exo Gray, Ely, Paladin) recoloris\u00e9es en m\u00e9tal pour une identit\u00e9 \u00ab robots corrompus \u00bb coh\u00e9rente + 1 brute monstre (Mutant, il a d\u00e9j\u00e0 des lames d'\u00e9nergie). Tout est gratuit, propre, et j'applique la m\u00eame recette de finition qu'on a valid\u00e9e.</div>
 %s
 <footer>Dis-moi lesquels tu gardes (et pour quels r\u00f4les). Je lance alors le pipeline sur chacun : anim course/attaque \u2192 bake 4-dir \u2192 recolor m\u00e9tal \u2192 en jeu. Rigs propres = plus de tige aux jambes.</footer>
</div>"""
html="<title>Designs d'ennemis \u2014 Mixamo</title>\n<style>%s</style>\n%s"%(CSS, BODY%sections)
open(os.path.join(SP,"mixamo_designs.html"),"w",encoding="utf-8").write(html)
print("mixamo catalog bytes:", len(html))
