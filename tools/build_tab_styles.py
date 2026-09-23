# Builds cine/_show/tab_styles.html : 6 REALLY different nav-tab styles for the
# epure menu, shown in context (the real menu) + zoomed so the detail is visible,
# in landscape and portrait. Everything is drawable in Godot (polygons, gradients,
# scanlines) -- no rounded-pill defaults.
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AS = json.load(open(os.path.join(ROOT, "cine", "_show", "_menu_assets.json")))
ASSETS_JSON = json.dumps(AS, separators=(",", ":"))

HTML = r"""<div id="app">
<header>
  <h1>MECHA-FORGE <span>&middot; Atelier d'onglets</span></h1>
  <p class="sub">Six styles d'onglets, dessin&eacute;s pour un jeu de mechas et pas pour une page web. Chacun est <b>vu en contexte</b> dans le menu, puis <b>agrandi</b> pour juger le d&eacute;tail. Clique un onglet pour sentir l'appui.</p>
</header>

<div class="bar">
  <div class="segs" id="orient"></div>
  <div class="spacer"></div>
  <div class="hint">Clique les onglets &middot; bascule portrait / paysage</div>
</div>

<main>
  <section class="stagewrap">
    <div class="scaler" id="scaler"><div class="stage" id="stage"></div></div>
    <div class="zoomwrap">
      <div class="zlabel">Agrandi &times;2 &mdash; le d&eacute;tail</div>
      <div class="zoom" id="zoom"></div>
    </div>
  </section>

  <aside class="side">
    <div class="grp"><h3>Style d'onglet</h3><div class="opts" id="opts"></div></div>
    <div class="grp note" id="note"></div>
  </aside>
</main>
</div>

<style>
:root{--bg:#080c14;--panel:#0f1522;--line:#1d2939;--line2:#27374d;--ink:#e8eefb;--dim:#8ba1c0;--accent:#4fd8e8}
*{box-sizing:border-box}
#app{max-width:1200px;margin:0 auto;padding:20px 18px 44px;color:var(--ink);
  font:14px/1.55 ui-sans-serif,system-ui,"Segoe UI",Roboto,sans-serif}
body{background:radial-gradient(1100px 560px at 12% -12%,#132238 0,transparent 62%),
  radial-gradient(900px 520px at 108% 4%,#1a1430 0,transparent 58%),var(--bg)}
header h1{margin:0;font-weight:800;font-size:22px}
header h1 span{color:var(--accent);font-weight:600;font-size:15px}
.sub{margin:.4em 0 0;color:var(--dim);max-width:80ch}
.bar{display:flex;align-items:center;gap:12px;margin:16px 0 12px;flex-wrap:wrap}
.segs{display:flex;gap:6px}
.segs button{background:#111a28;border:1px solid var(--line2);color:var(--dim);padding:8px 14px;
  cursor:pointer;font-size:12px;font-weight:600;border-radius:0}
.segs button.on{border-color:var(--accent);background:#122a34;color:#fff}
.spacer{flex:1}
.bar .hint{color:var(--dim);font-size:12px}
main{display:grid;grid-template-columns:1fr 320px;gap:16px;align-items:start}
@media(max-width:940px){main{grid-template-columns:1fr}}
.stagewrap{background:var(--panel);border:1px solid var(--line);padding:12px;position:sticky;top:12px}
@media(max-width:940px){.stagewrap{position:relative}}
.scaler{overflow:hidden;border:1px solid var(--line2);background:#04060a}
.stage{position:relative;transform-origin:top left;overflow:hidden;user-select:none}
.zoomwrap{margin-top:12px;border:1px solid var(--line2);background:#04060a;padding:14px 12px}
.zlabel{color:var(--dim);font-size:11px;letter-spacing:.6px;text-transform:uppercase;margin-bottom:10px}
.zoom{display:flex;align-items:center;justify-content:center;min-height:210px;overflow:hidden}
.zrow{display:flex;gap:16px;align-items:center;transform:scale(2)}
.side{display:flex;flex-direction:column;gap:12px}
.grp{background:var(--panel);border:1px solid var(--line);padding:12px}
.grp h3{margin:0 0 9px;font-size:12px;text-transform:uppercase;letter-spacing:.5px;color:var(--accent)}
.opts{display:flex;flex-direction:column;gap:7px}
.opt{border:1px solid transparent;padding:9px 11px;cursor:pointer;background:#0d1728}
.opt:hover{border-color:var(--line2)}
.opt.on{border-color:var(--accent);background:#122436}
.opt .t{font-weight:700;font-size:13px}
.opt .d{color:var(--dim);font-size:11.5px;line-height:1.4;margin-top:2px}
.note{color:var(--dim);font-size:12.5px}
.note b{color:var(--ink)}
.note code{color:#8fe6ff;font-family:ui-monospace,Consolas,monospace;font-size:11.5px}

/* ---------- menu (contexte) ---------- */
.stage .bg{position:absolute;inset:0;background-size:cover;background-position:center}
.stage .veil{position:absolute;inset:0;background:rgba(8,13,20,.32)}
.stage .band{position:absolute;left:0;right:0;bottom:0;height:38%;
  background:linear-gradient(to bottom,rgba(5,8,13,0),rgba(5,8,13,.96))}
.g-title{color:#bcecff;text-shadow:0 0 10px rgba(10,60,90,.9),0 3px 0 #0a2c3e;white-space:nowrap;
  font-weight:900;letter-spacing:3px}
.g-tag{color:#5fe0ff;letter-spacing:6px;font-weight:700}
.play{display:flex;align-items:center;justify-content:center;color:#fff;background:#29a866;
  border:3px solid #66e2a0;box-shadow:0 0 26px rgba(41,168,102,.55);border-radius:14px;
  font-weight:800;letter-spacing:1px}
.cap{color:#cfe0f2;text-align:center;letter-spacing:1px}
.railrow{position:absolute;left:0;right:0;display:flex;gap:10px;justify-content:center;align-items:flex-end;flex-wrap:wrap}

/* ================= LES 6 STYLES D'ONGLET ================= */
.tab{position:relative;cursor:pointer;user-select:none;color:#dfe9f5;font-weight:700;
  display:flex;align-items:center;justify-content:center;transition:transform .07s}
.tab:active{transform:translateY(2px) scale(.985)}
.tab .lbl{position:relative;z-index:2;white-space:nowrap}

/* 1 — PLAQUE RIVETEE : tole d'atelier, coins vifs, 4 rivets, texte grave */
.s-plaque{padding:0 20px;height:52px;letter-spacing:2px;font-size:15px;
  background:linear-gradient(180deg,#464e58 0%,#2c333c 46%,#232931 47%,#181d24 100%);
  border:1px solid #0c1015;box-shadow:inset 0 1px 0 rgba(255,255,255,.22),inset 0 -2px 5px rgba(0,0,0,.55),0 2px 0 #0a0d12;
  color:#e6edf6;text-shadow:0 1px 0 rgba(0,0,0,.75)}
.s-plaque::before{content:"";position:absolute;inset:5px;pointer-events:none;
  background:radial-gradient(circle 2px at 0 0,#8e99a6 60%,transparent 61%),
             radial-gradient(circle 2px at 100% 0,#8e99a6 60%,transparent 61%),
             radial-gradient(circle 2px at 0 100%,#8e99a6 60%,transparent 61%),
             radial-gradient(circle 2px at 100% 100%,#8e99a6 60%,transparent 61%)}
.s-plaque::after{content:"";position:absolute;left:0;top:0;bottom:0;width:4px;background:var(--acc)}

/* 2 — HUD BISEAUTE : coins coupes, filet fin, marques d'angle */
.s-hud{padding:0 22px;height:50px;letter-spacing:2.5px;font-size:14px;background:transparent;color:#dff3ff}
.s-hud .cut{position:absolute;inset:0;background:var(--acc);
  clip-path:polygon(10px 0,100% 0,100% calc(100% - 10px),calc(100% - 10px) 100%,0 100%,0 10px)}
.s-hud .cut2{position:absolute;inset:1.5px;background:rgba(6,14,20,.86);
  clip-path:polygon(9px 0,100% 0,100% calc(100% - 9px),calc(100% - 9px) 100%,0 100%,0 9px)}
.s-hud .tick{position:absolute;width:7px;height:7px;border:1px solid var(--acc);opacity:.9}
.s-hud .t1{left:5px;top:5px;border-right:0;border-bottom:0}
.s-hud .t2{right:5px;bottom:5px;border-left:0;border-top:0}

/* 3 — CHEVRON : onglet incline qui s'emboite, arete coloree en tete */
.s-chevron{padding:0 26px 0 20px;height:52px;letter-spacing:1.6px;font-size:14.5px;background:transparent}
.s-chevron .body{position:absolute;inset:0;background:linear-gradient(180deg,#1b2530,#101720);
  border-top:1px solid rgba(150,190,220,.22);
  clip-path:polygon(12px 0,100% 0,calc(100% - 12px) 100%,0 100%)}
.s-chevron .edge{position:absolute;left:0;top:0;bottom:0;width:16px;background:var(--acc);
  clip-path:polygon(12px 0,100% 0,calc(100% - 12px) 100%,0 100%)}

/* 4 — BANDEAU GRAVE : pas de boite du tout, un seul bandeau + soulignement */
.s-bandeau{padding:0 20px;height:46px;letter-spacing:3px;font-size:13.5px;background:transparent;
  color:#cfe0f2;text-shadow:0 1px 0 rgba(0,0,0,.6)}
.s-bandeau::after{content:"";position:absolute;left:16px;right:16px;bottom:8px;height:2px;background:var(--acc);opacity:.85}
.s-bandeau::before{content:"";position:absolute;right:-6px;top:12px;bottom:12px;width:1px;
  background:linear-gradient(180deg,transparent,rgba(160,200,230,.35),transparent)}

/* 5 — ECUSSON HEXA : tuile hexagonale, icone au-dessus du mot */
.s-hexa{width:104px;height:88px;flex-direction:column;gap:4px;font-size:11.5px;letter-spacing:1.4px;background:transparent}
.s-hexa .hx{position:absolute;inset:0;background:var(--acc);
  clip-path:polygon(50% 0,100% 26%,100% 74%,50% 100%,0 74%,0 26%)}
.s-hexa .hx2{position:absolute;inset:2px;background:linear-gradient(180deg,#16202b,#0b1119);
  clip-path:polygon(50% 0,100% 26%,100% 74%,50% 100%,0 74%,0 26%)}
.s-hexa .ic{position:relative;z-index:2;font-size:20px;line-height:1}

/* 6 — TERMINAL : petit ecran encastre, lignes de balayage, texte phosphore */
.s-terminal{padding:0 18px;height:50px;letter-spacing:2px;font-size:13px;
  font-family:ui-monospace,Consolas,monospace;color:var(--acc);
  background:#060b10;border:1px solid #1b2b38;
  box-shadow:inset 0 0 14px rgba(0,0,0,.9),inset 0 0 0 1px rgba(255,255,255,.03)}
.s-terminal::before{content:"";position:absolute;inset:0;pointer-events:none;opacity:.5;
  background:repeating-linear-gradient(180deg,rgba(255,255,255,.07) 0 1px,transparent 1px 3px)}
.s-terminal::after{content:"";position:absolute;right:8px;top:50%;width:6px;height:12px;
  transform:translateY(-50%);background:var(--acc);opacity:.85}
</style>

<script>
const A=__ASSETS__;
const NAV=[{t:"ARSENAL",i:"⚙",c:"#d09a3e"},{t:"ÉQUIPEMENT",i:"🛡",c:"#9b7bd4"},{t:"GARAGE",i:"🔧",c:"#5793d8"},
           {t:"QUOTIDIEN",i:"🎁",c:"#4fc98a"},{t:"HISTOIRE",i:"📖",c:"#e0725c"}];

const STYLES=[
 {k:"plaque",n:"1 · PLAQUE RIVETÉE",
  d:"Tôle d'atelier : coins vifs, dégradé métal, 4 rivets, texte gravé, arête de couleur sur la tranche.",
  godot:"StyleBoxFlat coins a 0 + degrade via StyleBoxTexture, rivets dessines en _draw() (4 cercles)"},
 {k:"hud",n:"2 · HUD BISEAUTÉ",
  d:"Coins coupés en diagonale, filet fin de couleur, marques d'angle. Le cockpit, pas le web.",
  godot:"_draw() : draw_colored_polygon (octogone) + draw_polyline pour le filet et les marques"},
 {k:"chevron",n:"3 · CHEVRON",
  d:"Onglets inclinés qui s'emboîtent, arête colorée en tête. Une vraie rangée d'onglets, pas des pastilles.",
  godot:"_draw() : parallelogramme (4 points) + bande coloree en tete"},
 {k:"bandeau",n:"4 · BANDEAU GRAVÉ",
  d:"Aucune boîte : un seul bandeau, mots espacés, soulignement de couleur et fins séparateurs. Le plus sobre.",
  godot:"Labels simples + draw_line pour le soulignement et les separateurs — le plus leger"},
 {k:"hexa",n:"5 · ÉCUSSON HEXA",
  d:"Tuiles hexagonales, icône au-dessus du mot. Le plus « jeu », le plus lisible au pouce.",
  godot:"_draw() : hexagone (6 points) + un 2e hexagone interieur pour le liseré"},
 {k:"terminal",n:"6 · TERMINAL",
  d:"Petits écrans encastrés : lignes de balayage, texte phosphore, curseur. Très machine.",
  godot:"StyleBoxFlat sombre + overlay de lignes (TextureRect en repetition) + police mono"}];

let si=1, portrait=false;

function tabHTML(n, s, zoom){
  const acc=`--acc:${n.c}`;
  const sc = "";
  if(s==="hud")      return `<div class="tab s-hud" style="${acc};${sc}"><span class="cut"></span><span class="cut2"></span><span class="tick t1"></span><span class="tick t2"></span><span class="lbl">${n.t}</span></div>`;
  if(s==="chevron")  return `<div class="tab s-chevron" style="${acc};${sc}"><span class="body"></span><span class="edge"></span><span class="lbl">${n.t}</span></div>`;
  if(s==="hexa")     return `<div class="tab s-hexa" style="${acc};${sc}"><span class="hx"></span><span class="hx2"></span><span class="ic">${n.i}</span><span class="lbl">${n.t}</span></div>`;
  return `<div class="tab s-${s}" style="${acc};${sc}"><span class="lbl">${n.t}</span></div>`;
}

const stage=document.getElementById("stage"), scaler=document.getElementById("scaler");
function draw(){
  const W = portrait ? 720 : 1280, H = portrait ? 1280 : 720;
  const k = Math.min(W,H)/720;
  const s = STYLES[si].k;
  stage.style.width=W+"px"; stage.style.height=H+"px";
  const titleFs = portrait ? 46*k : 66*k;
  stage.innerHTML=`
    <div class="bg" style="background-image:url(${A.hero})"></div><div class="veil"></div><div class="band"></div>
    <div style="position:absolute;left:50%;transform:translateX(-50%);top:${(portrait?76:30)*k}px;text-align:center;width:max-content">
      <img src="${A.emblem}" style="width:${(portrait?100:92)*k}px;height:${(portrait?100:92)*k}px;object-fit:contain">
      <div class="g-title" style="font-size:${titleFs}px;line-height:1.05">MECHA-FORGE</div>
      <div class="g-tag" style="font-size:${17*k}px;margin-top:6px">SURVIVE THE HORDE</div>
    </div>
    <div style="position:absolute;left:50%;transform:translateX(-50%);top:${H*0.5+12*k}px;width:${Math.min(420*k,W-44*k)}px">
      <div class="cap" style="font-size:${14*k}px;margin-bottom:${7*k}px">CAMPAGNE · NORMAL</div>
      <div class="play" style="height:${94*k}px;font-size:${40*k}px">JOUER</div>
    </div>
    <div class="railrow" style="bottom:${46*k}px;padding:0 ${22*k}px">
      ${NAV.map(n=>tabHTML(n,s,false)).join("")}
    </div>`;
  const av=scaler.clientWidth||860, f=Math.min(1, av/W);
  stage.style.transform=`scale(${f})`; scaler.style.height=(H*f)+"px";
  document.getElementById("zoom").innerHTML=`<div class="zrow">${NAV.slice(0,3).map(n=>tabHTML(n,s,true)).join("")}</div>`;
  document.getElementById("note").innerHTML=
    `<h3>Comment je le ferai dans Godot</h3><b>${STYLES[si].n}</b><br><br><code>${STYLES[si].godot}</code>`
    +`<br><br>Tout est <b>dessiné</b> (polygones + dégradés), donc ça reste net à n'importe quelle taille et ça suit le responsive déjà en place.`;
}
window.addEventListener("resize",draw);

const opts=document.getElementById("opts");
STYLES.forEach((s,i)=>{const d=document.createElement("div");d.className="opt"+(i===si?" on":"");
  d.innerHTML=`<div class="t">${s.n}</div><div class="d">${s.d}</div>`;
  d.addEventListener("click",()=>{si=i;document.querySelectorAll(".opt").forEach((x,j)=>x.classList.toggle("on",j===i));draw();});
  opts.append(d);});
const orient=document.getElementById("orient");
[["Paysage",false],["Portrait",true]].forEach(([lbl,v])=>{const b=document.createElement("button");
  b.textContent=lbl; b.className=(v===portrait?"on":"");
  b.addEventListener("click",()=>{portrait=v;
    document.querySelectorAll("#orient button").forEach(x=>x.classList.toggle("on",x.textContent===lbl));draw();});
  orient.append(b);});
draw();
</script>
"""

HTML = HTML.replace("__ASSETS__", ASSETS_JSON)
dst = os.path.join(ROOT, "cine", "_show", "tab_styles.html")
open(dst, "w", encoding="utf-8").write(HTML)
print("wrote", dst, "%.0f KB" % (os.path.getsize(dst) / 1024))
