# Builds cine/_show/menu_style_lab.html : the chosen EPURE menu, with
# 5 typography styles x 6 click effects to combine and actually click.
# Every font is OFL (shippable as a .ttf inside the Godot project) and every
# effect is written to be reproducible with a Godot Tween / CPUParticles2D.
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AS = json.load(open(os.path.join(ROOT, "cine", "_show", "_menu_assets.json")))
ASSETS_JSON = json.dumps(AS, separators=(",", ":"))

HTML = r"""<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Orbitron:wght@700;900&family=Rajdhani:wght@500;600;700&family=Black+Ops+One&family=Barlow+Condensed:wght@500;600;700&family=Anton&family=Roboto+Condensed:wght@400;700&family=Oswald:wght@500;700&family=Chakra+Petch:wght@600;700&family=Share+Tech+Mono&display=swap" rel="stylesheet">

<div id="app">
<header>
  <h1>MECHA-FORGE <span>&middot; Style &amp; r&eacute;action du menu</span></h1>
  <p class="sub">Menu <b>&Eacute;PUR&Eacute;</b> retenu. Choisis un <b>style de caract&egrave;res</b> et un <b>effet au clic</b> &mdash; puis <b>clique les boutons dans la maquette</b> pour sentir l'effet. Les deux se combinent librement.</p>
</header>

<main>
  <section class="stagewrap">
    <div class="scaler" id="scaler"><div class="stage" id="stage"></div></div>
    <div class="tip">Clique <b>JOUER</b> ou une pastille du bas &mdash; l'effet choisi se joue vraiment.</div>
  </section>

  <aside class="side">
    <div class="grp">
      <h3>Style de caract&egrave;res</h3>
      <div class="opts" id="typos"></div>
    </div>
    <div class="grp">
      <h3>Effet au clic</h3>
      <div class="opts" id="fx"></div>
    </div>
    <div class="grp note" id="note"></div>
  </aside>
</main>
</div>

<style>
:root{--bg:#080c14;--panel:#0f1522;--line:#1d2939;--line2:#27374d;--ink:#e8eefb;--dim:#8ba1c0;
  --accent:#4fd8e8;--accent2:#7c5cff;--good:#2fbf74}
*{box-sizing:border-box}
#app{max-width:1200px;margin:0 auto;padding:20px 18px 44px;color:var(--ink);
  font:14px/1.55 ui-sans-serif,system-ui,"Segoe UI",Roboto,sans-serif}
body{background:radial-gradient(1100px 560px at 12% -12%,#132238 0,transparent 62%),
  radial-gradient(900px 520px at 108% 4%,#1a1430 0,transparent 58%),var(--bg)}
header h1{margin:0;font-weight:800;font-size:22px}
header h1 span{color:var(--accent);font-weight:600;font-size:15px}
.sub{margin:.4em 0 0;color:var(--dim);max-width:78ch}
main{display:grid;grid-template-columns:1fr 330px;gap:16px;align-items:start;margin-top:16px}
@media(max-width:940px){main{grid-template-columns:1fr}}
.stagewrap{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:12px;position:sticky;top:12px}
@media(max-width:940px){.stagewrap{position:relative}}
.scaler{overflow:hidden;border-radius:10px;border:1px solid var(--line2);background:#04060a}
.stage{position:relative;width:1280px;height:720px;transform-origin:top left;overflow:hidden;user-select:none}
.tip{margin-top:9px;color:var(--dim);font-size:12px}
.side{display:flex;flex-direction:column;gap:12px}
.grp{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:12px}
.grp h3{margin:0 0 9px;font-size:12px;text-transform:uppercase;letter-spacing:.5px;color:var(--accent)}
.opts{display:flex;flex-direction:column;gap:7px}
.opt{border:1px solid transparent;border-radius:10px;padding:9px 11px;cursor:pointer;background:#0d1728}
.opt:hover{border-color:var(--line2)}
.opt.on{border-color:var(--accent);background:#122436}
.opt .t{font-weight:700;font-size:13px}
.opt .d{color:var(--dim);font-size:11.5px;line-height:1.4;margin-top:2px}
.opt .spec{color:#6fe3ff;font-size:11px;margin-top:3px;font-family:ui-monospace,Consolas,monospace}
.note{color:var(--dim);font-size:12.5px}
.note b{color:var(--ink)}
.note code{color:#8fe6ff;font-family:ui-monospace,Consolas,monospace;font-size:11.5px}

/* ---------- stage ---------- */
.stage .bg{position:absolute;inset:0;background-size:cover;background-position:center}
.stage .veil{position:absolute;inset:0;background:rgba(8,13,20,.30)}
.stage .band{position:absolute;left:0;right:0;bottom:0;height:260px;
  background:linear-gradient(to bottom,rgba(5,8,13,0),rgba(5,8,13,.96))}
.g-title{color:#bcecff;text-shadow:0 0 10px rgba(10,60,90,.9),0 3px 0 #0a2c3e;line-height:1.04;white-space:nowrap}
.g-tag{white-space:nowrap}
.g-tag{color:#5fe0ff}
.chip{display:flex;align-items:center;gap:8px;height:38px;padding:0 12px;border-radius:10px;
  background:rgba(12,20,30,.9);border:2px solid #2c4a58;color:#e9f4ff;font-size:16px;white-space:nowrap}
.chip i{width:14px;height:14px;border-radius:50%;display:block;flex:none}
.chip .plus{color:#5cff8f;font-weight:700;margin-left:2px}
.cap{color:#cfe0f2;text-align:center}
.foot{position:absolute;left:20px;bottom:10px;color:#7f8b9c;font-size:12px}
.play{position:relative;display:flex;align-items:center;justify-content:center;height:98px;border-radius:14px;
  color:#fff;background:#29a866;border:3px solid #66e2a0;box-shadow:0 0 26px rgba(41,168,102,.55);
  cursor:pointer;overflow:hidden;will-change:transform,filter}
.rail{position:absolute;left:50%;transform:translateX(-50%);bottom:34px;display:flex;gap:10px;
  background:rgba(8,13,20,.72);border:1px solid #24384c;border-radius:14px;padding:9px 12px}
.pill{position:relative;display:flex;align-items:center;gap:8px;height:44px;padding:0 15px;border-radius:10px;
  background:rgba(255,255,255,.05);color:#dceaf7;cursor:pointer;overflow:hidden;will-change:transform,filter}
.pill .ic{font-size:16px}

/* ---------- click effects ---------- */
.fx-press{transform:scale(.955)}
.fx-punch{animation:punch .28s cubic-bezier(.2,.9,.25,1.2)}
@keyframes punch{0%{transform:scale(.93)}55%{transform:scale(1.055)}100%{transform:scale(1)}}
.fx-flash{animation:flash .3s ease-out}
@keyframes flash{0%{filter:brightness(2.1) saturate(1.3);box-shadow:0 0 46px rgba(255,255,255,.85)}
  100%{filter:brightness(1);box-shadow:0 0 26px rgba(41,168,102,.55)}}
.ripple{position:absolute;border-radius:50%;pointer-events:none;transform:translate(-50%,-50%);
  background:radial-gradient(circle,rgba(255,255,255,.55),rgba(255,255,255,0) 70%);animation:rip .5s ease-out forwards}
@keyframes rip{from{width:0;height:0;opacity:.9}to{width:340px;height:340px;opacity:0}}
.ring{position:absolute;border-radius:50%;pointer-events:none;transform:translate(-50%,-50%);
  border:3px solid rgba(255,255,255,.85);animation:ring .45s ease-out forwards}
@keyframes ring{from{width:10px;height:10px;opacity:1}to{width:300px;height:300px;opacity:0;border-width:1px}}
.spark{position:absolute;width:6px;height:6px;border-radius:50%;pointer-events:none;
  transform:translate(-50%,-50%);background:#fff;animation:spk .5s ease-out forwards}
@keyframes spk{to{opacity:0;transform:translate(calc(-50% + var(--dx)),calc(-50% + var(--dy))) scale(.3)}}
.sweep{position:absolute;top:0;bottom:0;width:38%;pointer-events:none;
  background:linear-gradient(100deg,rgba(255,255,255,0),rgba(255,255,255,.55),rgba(255,255,255,0));
  animation:swp .45s ease-out forwards}
@keyframes swp{from{left:-40%}to{left:110%}}
</style>

<script>
const A=__ASSETS__;

/* ---------- typography styles (all OFL -> shippable as .ttf in Godot) ---------- */
const TYPOS=[
 {k:"actuel",n:"0 · ACTUEL (défaut Godot)",
  d:"Ce que tu as aujourd'hui : aucune police n'est fournie, Godot met sa police système. C'est la référence pour comparer.",
  spec:"aucune police fournie",
  title:{ff:"ui-sans-serif,system-ui,'Segoe UI',Roboto,sans-serif",fw:900,ls:"2px",size:80,up:true},
  tag:{ff:'ui-sans-serif,system-ui,sans-serif',fw:700,ls:"3px",size:24},
  ui:{ff:'ui-sans-serif,system-ui,sans-serif',fw:800,ls:"1px"},play:44},
 {k:"techno",n:"1 · TECHNO HUD",
  d:"Géométrique, cockpit de mecha. La plus « science-fiction » : lettres larges, très lisibles de loin.",
  spec:"Orbitron 900 + Rajdhani 600",
  title:{ff:"'Orbitron',ui-sans-serif,sans-serif",fw:900,ls:"7px",size:72,up:true},
  tag:{ff:"'Rajdhani',ui-sans-serif,sans-serif",fw:600,ls:"6px",size:25},
  ui:{ff:"'Rajdhani',ui-sans-serif,sans-serif",fw:700,ls:"2px"},play:42},
 {k:"militaire",n:"2 · MILITAIRE",
  d:"Pochoir d'armée, brut et martial. Colle au thème guerre de robots ; à réserver aux titres (peu lisible en petit).",
  spec:"Black Ops One + Barlow Condensed 600",
  title:{ff:"'Black Ops One',Impact,ui-sans-serif",fw:400,ls:"3px",size:88,up:true},
  tag:{ff:"'Barlow Condensed',ui-sans-serif,sans-serif",fw:600,ls:"5px",size:27},
  ui:{ff:"'Barlow Condensed',ui-sans-serif,sans-serif",fw:700,ls:"1.5px"},play:46},
 {k:"affiche",n:"3 · AFFICHE INDUSTRIELLE",
  d:"Massif, façon affiche de film. Le plus « gros impact » sur mobile : le titre écrase l'écran.",
  spec:"Anton + Roboto Condensed 700",
  title:{ff:"'Anton',Impact,ui-sans-serif",fw:400,ls:"0px",size:96,up:true},
  tag:{ff:"'Roboto Condensed',ui-sans-serif,sans-serif",fw:700,ls:"5px",size:25},
  ui:{ff:"'Roboto Condensed',ui-sans-serif,sans-serif",fw:700,ls:"1.5px"},play:46},
 {k:"condense",n:"4 · CONDENSÉ NET",
  d:"Sobre et compact. Le meilleur compromis lisibilité/caractère, et le plus sûr sur petits écrans.",
  spec:"Oswald 700 + Barlow Condensed 600",
  title:{ff:"'Oswald',ui-sans-serif,sans-serif",fw:700,ls:"4px",size:90,up:true},
  tag:{ff:"'Barlow Condensed',ui-sans-serif,sans-serif",fw:600,ls:"5px",size:26},
  ui:{ff:"'Barlow Condensed',ui-sans-serif,sans-serif",fw:600,ls:"1.5px"},play:44},
 {k:"technique",n:"5 · TECHNIQUE",
  d:"Fiche d'atelier / terminal. Donne un ton « machine » ; le mono en petit fait très ingénieur.",
  spec:"Chakra Petch 700 + Share Tech Mono",
  title:{ff:"'Chakra Petch',ui-sans-serif,sans-serif",fw:700,ls:"6px",size:78,up:true},
  tag:{ff:"'Share Tech Mono',ui-monospace,monospace",fw:400,ls:"6px",size:25},
  ui:{ff:"'Chakra Petch',ui-sans-serif,sans-serif",fw:700,ls:"1.5px"},play:42}];

/* ---------- click effects (each maps to a Godot Tween / CPUParticles2D) ---------- */
const FX=[
 {k:"press",n:"A · Enfoncement",d:"Le bouton s'enfonce net puis revient. Sobre, jamais fatigant.",
  godot:"Tween sur scale 1 → 0.955 → 1 (0.09s, TRANS_QUAD)"},
 {k:"punch",n:"B · Punch élastique",d:"Il s'écrase puis dépasse légèrement avant de se caler. Le plus « juteux ».",
  godot:"Tween scale 0.93 → 1.055 → 1, TRANS_BACK / EASE_OUT"},
 {k:"ripple",n:"C · Onde au doigt",d:"Une onde claire part du point touché. Lisible même sans regarder le bouton.",
  godot:"Sprite2D additif au point du clic, tween scale + modulate:a → 0"},
 {k:"ring",n:"D · Anneau de choc",d:"Un cercle net se propage et s'efface. Très sci-fi, discret.",
  godot:"Line2D/Sprite anneau, tween scale 0.1 → 3, alpha → 0 (0.45s)"},
 {k:"sparks",n:"E · Éclats",d:"Une petite gerbe d'étincelles. Le plus démonstratif — à garder pour JOUER.",
  godot:"CPUParticles2D one_shot au point du clic (8-12 particules)"},
 {k:"sweep",n:"F · Balayage lumineux",d:"Un reflet traverse le bouton. Élégant, très « premium ».",
  godot:"ShaderMaterial (bande translatée) ou Sprite en clip + tween position"}];

let ti=4, fi=1;   // défauts : CONDENSÉ NET + Punch

const C={title:"MECHA-FORGE",tag:"SURVIVE THE HORDE",
  chips:[{t:"1 250 points",c:"#66ebff",plus:true},{t:"340",c:"#ffcc59"},{t:"12 cristaux",c:"#99c6ff"}],
  play:"JOUER",cap:"CAMPAGNE · NORMAL",
  nav:[{t:"ARSENAL",i:"⚙",c:"#8c6636"},{t:"ÉQUIPEMENT",i:"🛡",c:"#6b5699"},{t:"GARAGE",i:"🔧",c:"#3d6b9e"},
       {t:"QUOTIDIEN",i:"🎁",c:"#3d805e"},{t:"HISTOIRE",i:"📖",c:"#994d3d"}],
  foot:"v9.7 · Musique K. MacLeod (incompetech) CC-BY 4.0 · SFX Kenney CC0"};

const stage=document.getElementById("stage"),scaler=document.getElementById("scaler");

function drawStage(){
  const T=TYPOS[ti];
  const up=T.title.up?"text-transform:uppercase;":"";
  stage.innerHTML=`
  <div class="bg" style="background-image:url(${A.hero})"></div><div class="veil"></div>
  <div class="band"></div>
  <div style="position:absolute;left:50%;transform:translateX(-50%);top:44px;text-align:center;width:max-content">
    <img src="${A.emblem}" style="width:100px;height:100px;object-fit:contain">
    <div class="g-title" style="font-family:${T.title.ff};font-weight:${T.title.fw};letter-spacing:${T.title.ls};font-size:${T.title.size}px;${up}margin-top:4px">${C.title}</div>
    <div class="g-tag" style="font-family:${T.tag.ff};font-weight:${T.tag.fw};letter-spacing:${T.tag.ls};font-size:${T.tag.size}px;margin-top:7px">${C.tag}</div>
  </div>
  <div style="position:absolute;right:26px;top:20px;display:flex;gap:10px;font-family:${T.ui.ff}">
    ${C.chips.map(c=>`<div class="chip"><i style="background:${c.c}"></i>${c.t}${c.plus?'<span class="plus">+</span>':''}</div>`).join("")}
  </div>
  <div style="position:absolute;left:50%;transform:translateX(-50%);top:398px;width:400px">
    <div class="cap" style="font-family:${T.ui.ff};font-weight:${T.ui.fw};letter-spacing:${T.ui.ls};font-size:14px;margin-bottom:8px">${C.cap}</div>
    <div class="play" id="playbtn" style="font-family:${T.ui.ff};font-weight:${T.ui.fw};letter-spacing:${T.ui.ls};font-size:${T.play}px">${C.play}</div>
  </div>
  <div class="rail" style="font-family:${T.ui.ff}">
    ${C.nav.map(n=>`<div class="pill" style="border:1px solid ${n.c};font-weight:${T.ui.fw};letter-spacing:${T.ui.ls};font-size:13.5px"><span class="ic">${n.i}</span>${n.t}</div>`).join("")}
  </div>
  <div class="foot" style="font-family:${T.ui.ff}">${C.foot}</div>`;
  stage.querySelectorAll(".play,.pill").forEach(el=>el.addEventListener("pointerdown",e=>play(el,e)));
  fit();
}
function fit(){const k=Math.min(1,(scaler.clientWidth||860)/1280);
  stage.style.transform=`scale(${k})`;scaler.style.height=(720*k)+"px";}
window.addEventListener("resize",fit);

/* play the selected click effect on the element that was pressed */
function play(el,ev){
  const kind=FX[fi].k, r=el.getBoundingClientRect();
  const x=(ev.clientX-r.left)/(r.width/el.offsetWidth), y=(ev.clientY-r.top)/(r.height/el.offsetHeight);
  el.classList.remove("fx-punch","fx-flash");void el.offsetWidth;
  if(kind==="press"){el.classList.add("fx-press");setTimeout(()=>el.classList.remove("fx-press"),110);}
  else if(kind==="punch"){el.classList.add("fx-punch");setTimeout(()=>el.classList.remove("fx-punch"),300);}
  else if(kind==="ripple"){spawn(el,"ripple",x,y,500);}
  else if(kind==="ring"){spawn(el,"ring",x,y,470);el.classList.add("fx-flash");setTimeout(()=>el.classList.remove("fx-flash"),320);}
  else if(kind==="sparks"){for(let i=0;i<10;i++){const a=Math.PI*2*i/10+Math.random()*.5,d=34+Math.random()*30;
      const s=spawn(el,"spark",x,y,520);s.style.setProperty("--dx",(Math.cos(a)*d)+"px");s.style.setProperty("--dy",(Math.sin(a)*d)+"px");}
      el.classList.add("fx-punch");setTimeout(()=>el.classList.remove("fx-punch"),300);}
  else if(kind==="sweep"){const s=document.createElement("div");s.className="sweep";el.append(s);setTimeout(()=>s.remove(),470);}
}
function spawn(el,cls,x,y,ms){const d=document.createElement("div");d.className=cls;
  d.style.left=x+"px";d.style.top=y+"px";el.append(d);setTimeout(()=>d.remove(),ms);return d;}

/* ---------- option lists ---------- */
function buildOpts(){
  const tw=document.getElementById("typos");tw.innerHTML="";
  TYPOS.forEach((t,i)=>{const d=document.createElement("div");d.className="opt"+(i===ti?" on":"");
    d.innerHTML=`<div class="t" style="font-family:${t.title.ff}">${t.n}</div><div class="d">${t.d}</div><div class="spec">${t.spec}</div>`;
    d.addEventListener("click",()=>{ti=i;buildOpts();drawStage();note();});tw.append(d);});
  const fw=document.getElementById("fx");fw.innerHTML="";
  FX.forEach((f,i)=>{const d=document.createElement("div");d.className="opt"+(i===fi?" on":"");
    d.innerHTML=`<div class="t">${f.n}</div><div class="d">${f.d}</div>`;
    d.addEventListener("click",()=>{fi=i;buildOpts();note();});fw.append(d);});
}
function note(){document.getElementById("note").innerHTML=
  `<h3>Ce que j'implémenterai</h3><b>Police :</b> ${TYPOS[ti].spec}`
  +(TYPOS[ti].k==="actuel"?" — soit aucune police ajoutée (état actuel)."
    :` — polices OFL, j'ajoute le <code>.ttf</code> dans <code>game/assets/fonts/</code> et je le pose en police par défaut du thème.`)
  +`<br><br><b>Effet :</b> ${FX[fi].n} — <code>${FX[fi].godot}</code>, appliqué à JOUER et aux pastilles, en gardant le son <code>Audio.sfx("click")</code> déjà en place.`;}

buildOpts();drawStage();note();
</script>
"""

HTML = HTML.replace("__ASSETS__", ASSETS_JSON)
dst = os.path.join(ROOT, "cine", "_show", "menu_style_lab.html")
open(dst, "w", encoding="utf-8").write(HTML)
print("wrote", dst, "%.0f KB" % (os.path.getsize(dst) / 1024))
