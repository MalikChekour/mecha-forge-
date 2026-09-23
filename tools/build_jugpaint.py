import base64, os
SP=r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad"
D="cine/_show/jugpaint"
def gif(f): return "data:image/gif;base64,"+base64.b64encode(open(f"{D}/{f}.gif","rb").read()).decode()
PAINTS=[("crimson_war","Crimson de guerre","rouge sombre \u00b7 agressif","reco"),
 ("corrosion","Corrosion verte","toxique \u00b7 machine corrompue","reco","toxic"),
 ("gunmetal_orange","Gunmetal orange","acier sombre \u00b7 accent chaud","",""),
 ("steel_cyan","Acier cyan","m\u00e9tal clair \u00b7 sci-fi","",""),
 ("cobalt","Cobalt","m\u00e9tal bleu","",""),
 ("obsidian_gold","Obsidienne or","noir \u00b7 dor\u00e9","","obsidian_gold")]
# normalize file keys
KEYS={"crimson_war":"crimson_war","corrosion":"toxic","gunmetal_orange":"gunmetal_orange","steel_cyan":"steel_cyan","cobalt":"cobalt","obsidian_gold":"obsidian_gold"}
def card(key,name,role,reco):
    f=KEYS[key]; badge='<span class="chip reco">RECOMMAND\u00c9</span>' if reco=="reco" else ''
    return '<figure class="card"><div class="thumb"><span class="live">\u25cf</span><img src="%s">%s</div><figcaption><b>%s</b><span class="role">%s</span></figcaption></figure>'%(gif(f),badge,name,role)
cards=card("crimson_war","Crimson de guerre","rouge sombre \u00b7 agressif","reco")
cards+=card("corrosion","Corrosion verte","toxique \u00b7 corrompue","reco")
cards+=card("gunmetal_orange","Gunmetal orange","acier sombre \u00b7 accent chaud","")
cards+=card("steel_cyan","Acier cyan","m\u00e9tal clair \u00b7 sci-fi","")
cards+=card("cobalt","Cobalt","m\u00e9tal bleu","")
cards+=card("obsidian_gold","Obsidienne or","noir \u00b7 dor\u00e9","")
CSS=""":root{--bg:#0d0f14;--p1:#14161d;--bd:#262b36;--tx:#e7e9f0;--mut:#8b91a0;--crim:#e5384d;--ok:#2fbf71}
*{box-sizing:border-box}body{margin:0;background:radial-gradient(1200px 600px at 70% -10%,#171a22,#0d0f14 60%);color:var(--tx);font:15px/1.5 system-ui,Segoe UI,Roboto,sans-serif}
.wrap{max-width:940px;margin:0 auto;padding:44px 22px 80px}
.eyebrow{font:600 12px/1 ui-monospace,Menlo,monospace;letter-spacing:.22em;color:var(--crim);text-transform:uppercase}
h1{font-size:32px;margin:.35em 0 .15em}.sub{color:var(--mut);max-width:62ch;margin:0}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:16px;margin-top:26px}
.card{background:var(--p1);border:1px solid var(--bd);border-radius:14px;overflow:hidden;transition:.18s}.card:hover{border-color:#3a4453;transform:translateY(-3px)}
.thumb{position:relative;aspect-ratio:1;background:#1c1e25;display:grid;place-items:center}.thumb img{width:100%;height:100%;object-fit:contain}
.live{position:absolute;top:9px;right:10px;color:var(--ok);font-size:11px;filter:drop-shadow(0 0 4px #2fbf71);animation:pulse 1.4s infinite}@keyframes pulse{50%{opacity:.3}}
.chip{position:absolute;top:9px;left:10px;font:600 9px/1 ui-monospace,monospace;letter-spacing:.06em;padding:4px 7px;border-radius:5px;background:rgba(47,191,113,.2);color:#7ee0a8;border:1px solid rgba(47,191,113,.4)}
figcaption{padding:11px 13px}figcaption b{font-size:14.5px}.role{color:var(--mut);font-size:12px;display:block;margin-top:2px}
footer{color:var(--mut);font-size:13px;border-top:1px solid var(--bd);margin-top:36px;padding-top:18px}"""
BODY="""<div class="wrap"><div class="eyebrow">Juggernaut \u00b7 peinture</div>
<h1>Juggernaut \u2014 finitions de peinture</h1>
<p class="sub">Le m\u00eame Juggernaut anim\u00e9, peint proprement : m\u00e9tal contrast\u00e9 + accents d'\u00e9nergie. Dis-moi laquelle et je l'applique en jeu pour le test. Vignettes en direct.</p>
<div class="grid">%s</div>
<footer>Pour un ennemi, le rouge ou le vert \u00ab corrompu \u00bb ressortent le mieux. Une fois choisi, m\u00eame recette applicable \u00e0 tout le roster.</footer></div>"""
open(os.path.join(SP,"jugpaint.html"),"w",encoding="utf-8").write("<title>Juggernaut \u2014 peinture</title>\n<style>%s</style>\n%s"%(CSS,BODY%cards))
print("ok")
