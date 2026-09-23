import base64, os
SP=r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad"
def b64(f): return "data:image/png;base64,"+base64.b64encode(open("cine/pixel/%s.png"%f,"rb").read()).decode()
CARDS=[("cm_juggernaut","Juggernaut","B\u00c9LIER / BROYEUR \u2014 tank lourd"),
 ("cm_striker","Striker","R\u00d4DEUR \u2014 rusher agile"),
 ("cm_bruiser","Bruiser","RAIDER \u2014 assaut agressif"),
 ("cm_sentinel","Sentinel","SENTINELLE \u2014 blind\u00e9 d\u00e9fensif")]
cards="".join('<figure class="card"><div class="thumb"><img src="%s"></div><figcaption><b>%s</b><span class="role">%s</span></figcaption></figure>'%(b64(s),n,r) for s,n,r in CARDS)
CSS=""":root{--bg:#0d0f14;--p1:#14161d;--bd:#262b36;--tx:#e7e9f0;--mut:#8b91a0;--crim:#e5384d;--ok:#2fbf71}
*{box-sizing:border-box}body{margin:0;background:radial-gradient(1200px 600px at 70% -10%,#171a22,#0d0f14 60%);color:var(--tx);font:15px/1.5 system-ui,Segoe UI,Roboto,sans-serif}
.wrap{max-width:1000px;margin:0 auto;padding:44px 22px 80px}
.eyebrow{font:600 12px/1 ui-monospace,Menlo,monospace;letter-spacing:.22em;color:var(--crim);text-transform:uppercase}
h1{font-size:32px;margin:.35em 0 .15em}.sub{color:var(--mut);max-width:64ch;margin:0}
.rule{background:linear-gradient(90deg,rgba(47,191,113,.13),transparent);border:1px solid var(--bd);border-left:3px solid var(--ok);border-radius:10px;padding:14px 18px;margin:24px 0 30px;color:#d7f0e0;font-size:14px}.rule b{color:#fff}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:16px}
.card{background:var(--p1);border:1px solid var(--bd);border-radius:14px;overflow:hidden;transition:.18s}.card:hover{border-color:#3a4453;transform:translateY(-3px)}
.thumb{aspect-ratio:1;background:linear-gradient(180deg,#d7d9dd,#c4c7cc);display:grid;place-items:center}.thumb img{width:100%;height:100%;object-fit:contain}
figcaption{padding:12px 14px}figcaption b{font-size:15px}.role{color:var(--mut);font-size:12.5px;display:block;margin-top:2px}
footer{color:var(--mut);font-size:13px;border-top:1px solid var(--bd);margin-top:38px;padding-top:18px}"""
BODY="""<div class="wrap"><div class="eyebrow">Nouveaux mechs \u00b7 pour rig Mixamo</div>
<h1>Mechs \u00ab sans excroissance \u00bb</h1>
<p class="sub">4 nouveaux mechs g\u00e9n\u00e9r\u00e9s sous contrainte anti-tige : compacts, blindage coll\u00e9 au corps, aucun c\u00e2ble/lame/cape/antenne qui pend. Silhouette serr\u00e9e = rien que le rig Mixamo puisse \u00e9tirer.</p>
<div class="rule"><b>R\u00e8gle appliqu\u00e9e :</b> z\u00e9ro c\u00e2ble/tuyau/fil, z\u00e9ro lame ou arme pendante, z\u00e9ro tissu, mains ferm\u00e9es, pieds plats, tout coll\u00e9 au corps. C'est ce qui manquait au Prototype crimson (qui avait un appendice aux jambes).</div>
<div class="grid">%s</div>
<footer>Dis-moi le(s)quel(s) tu veux qu'on rigue. Pipeline : TRELLIS (3D) \u2192 Mixamo (rig auto, sans marqueurs \u00e0 placer si possible) \u2192 v\u00e9rif z\u00e9ro tige \u2192 bake anim \u2192 en jeu. On en fait 1 d'abord pour valider l'absence de tige.</footer></div>"""
open(os.path.join(SP,"clean_mechs.html"),"w",encoding="utf-8").write("<title>Mechs sans excroissance</title>\n<style>%s</style>\n%s"%(CSS,BODY%cards))
print("ok")
