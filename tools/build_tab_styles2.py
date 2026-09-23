# Builds cine/_show/tab_styles2.html : a SECOND wave of nav-tab styles (new design
# territories, not variations of the first six) + live ANIMATIONS for both the game
# title and the tabs. Everything is reproducible in Godot (Tween, shader sweep,
# staggered delays, per-letter labels).
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AS = json.load(open(os.path.join(ROOT, "cine", "_show", "_menu_assets.json")))
ASSETS_JSON = json.dumps(AS, separators=(",", ":"))

HTML = r"""<div id="app">
<header>
  <h1>MECHA-FORGE <span>&middot; Onglets &mdash; 2<sup>e</sup> vague &amp; animations</span></h1>
  <p class="sub">Six <b>nouveaux</b> styles (d'autres territoires que la premi&egrave;re s&eacute;rie), et la r&eacute;ponse &agrave; ta question&nbsp;: <b>oui</b>, le titre et les onglets peuvent &ecirc;tre anim&eacute;s. Choisis un style, une animation de titre et une animation d'onglets &mdash; tout tourne en direct.</p>
</header>

<div class="bar">
  <div class="segs" id="orient"></div>
  <button id="replay" class="replay">&#8635; Rejouer les animations</button>
  <div class="spacer"></div>
  <div class="hint">Clique un onglet pour l'appui</div>
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
    <div class="grp"><h3>Animation du titre</h3><div class="opts" id="tanim"></div></div>
    <div class="grp"><h3>Animation des onglets</h3><div class="opts" id="banim"></div></div>
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
.sub{margin:.4em 0 0;color:var(--dim);max-width:82ch}
.bar{display:flex;align-items:center;gap:10px;margin:16px 0 12px;flex-wrap:wrap}
.segs{display:flex;gap:6px}
.segs button,.replay{background:#111a28;border:1px solid var(--line2);color:var(--dim);padding:8px 14px;
  cursor:pointer;font-size:12px;font-weight:600}
.segs button.on{border-color:var(--accent);background:#122a34;color:#fff}
.replay:hover{border-color:var(--accent);color:#fff}
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
.zoom{display:flex;align-items:center;justify-content:center;min-height:220px;overflow:hidden}
.zrow{display:flex;gap:18px;align-items:center;transform:scale(2)}
.side{display:flex;flex-direction:column;gap:12px}
.grp{background:var(--panel);border:1px solid var(--line);padding:12px}
.grp h3{margin:0 0 9px;font-size:12px;text-transform:uppercase;letter-spacing:.5px;color:var(--accent)}
.opts{display:flex;flex-direction:column;gap:6px}
.opt{border:1px solid transparent;padding:8px 10px;cursor:pointer;background:#0d1728}
.opt:hover{border-color:var(--line2)}
.opt.on{border-color:var(--accent);background:#122436}
.opt .t{font-weight:700;font-size:12.5px}
.opt .d{color:var(--dim);font-size:11px;line-height:1.35;margin-top:2px}
.note{color:var(--dim);font-size:12.5px}
.note b{color:var(--ink)}
.note code{color:#8fe6ff;font-family:ui-monospace,Consolas,monospace;font-size:11.5px}

/* ---------- menu ---------- */
.stage .bg{position:absolute;inset:0;background-size:cover;background-position:center}
.stage .veil{position:absolute;inset:0;background:rgba(8,13,20,.32)}
.stage .band{position:absolute;left:0;right:0;bottom:0;height:38%;
  background:linear-gradient(to bottom,rgba(5,8,13,0),rgba(5,8,13,.96))}
.g-title{color:#bcecff;white-space:nowrap;font-weight:900;letter-spacing:3px;
  text-shadow:0 0 10px rgba(10,60,90,.9),0 3px 0 #0a2c3e}
.g-title .ch{display:inline-block}
.g-tag{color:#5fe0ff;letter-spacing:6px;font-weight:700}
.play{display:flex;align-items:center;justify-content:center;color:#fff;background:#29a866;
  border:3px solid #66e2a0;box-shadow:0 0 26px rgba(41,168,102,.55);border-radius:14px;
  font-weight:800;letter-spacing:1px}
.cap{color:#cfe0f2;text-align:center;letter-spacing:1px}
.railrow{position:absolute;left:0;right:0;display:flex;gap:12px;justify-content:center;align-items:flex-end;flex-wrap:wrap}

/* ================= 2e VAGUE : LES STYLES ================= */
.tab{position:relative;cursor:pointer;user-select:none;color:#e2ecf7;font-weight:700;
  display:flex;align-items:center;justify-content:center;transition:transform .07s}
.tab:active{transform:translateY(2px) scale(.985)}
.tab .lbl{position:relative;z-index:3;white-space:nowrap}

/* 7 — STENCIL DECOUPE : le mot est DECOUPE dans la barre, lueur derriere */
.s-stencil{height:54px;padding:0 24px;font-size:17px;letter-spacing:3px;
  background:linear-gradient(180deg,#232a33,#0e1218);border:1px solid #060a0e;
  box-shadow:inset 0 1px 0 rgba(255,255,255,.18),0 3px 0 rgba(0,0,0,.5)}
.s-stencil .lbl{color:transparent;-webkit-background-clip:text;background-clip:text;
  background-image:linear-gradient(180deg,#ffffff 0%,var(--acc) 58%,color-mix(in srgb,var(--acc) 55%,#0b1016) 100%);
  filter:drop-shadow(0 0 10px var(--acc)) drop-shadow(0 0 22px color-mix(in srgb,var(--acc) 70%,transparent))}
.s-stencil::after{content:"";position:absolute;left:8px;right:8px;bottom:5px;height:2px;
  background:repeating-linear-gradient(90deg,rgba(255,255,255,.25) 0 6px,transparent 6px 12px)}

/* 8 — CARTOUCHE : douille/chargeur, nez arrondi a gauche, matricule frappe */
.s-cartouche{height:56px;padding:0 20px 0 30px;font-size:15px;letter-spacing:1.6px;
  background:linear-gradient(180deg,#5a4b2e 0%,#3a3120 40%,#2a2418 41%,#171308 100%);
  border:1px solid #0d0b05;border-radius:26px 4px 4px 26px;
  box-shadow:inset 2px 0 0 rgba(255,215,140,.35),inset 0 1px 0 rgba(255,235,190,.22),0 3px 0 rgba(0,0,0,.5);
  color:#f2e6c9;text-shadow:0 1px 0 rgba(0,0,0,.7)}
.s-cartouche::before{content:"";position:absolute;left:9px;top:50%;width:9px;height:9px;margin-top:-4.5px;
  border-radius:50%;background:var(--acc);box-shadow:0 0 8px var(--acc)}
.s-cartouche .ser{position:absolute;right:12px;bottom:5px;font-size:8px;letter-spacing:1px;
  color:rgba(255,235,190,.45);font-family:ui-monospace,Consolas,monospace;z-index:3}

/* 9 — ETIQUETTE SUSPENDUE : plaque percee, accrochee au rail, legerement inclinee */
.s-tag{height:58px;padding:0 18px 0 26px;font-size:14.5px;letter-spacing:1.8px;margin-top:16px;
  background:linear-gradient(180deg,#2b3540,#161d25);border:1px solid #0a0e13;
  clip-path:polygon(0 12px,10px 0,100% 0,100% 100%,10px 100%,0 calc(100% - 12px));
  transform:rotate(-1.4deg);box-shadow:0 4px 10px rgba(0,0,0,.55);color:#dfe9f5}
.s-tag::before{content:"";position:absolute;left:9px;top:50%;width:8px;height:8px;margin-top:-4px;
  border-radius:50%;background:#05080c;box-shadow:inset 0 0 0 2px #55636f}
.s-tag::after{content:"";position:absolute;left:11px;top:-16px;width:2px;height:18px;
  background:linear-gradient(180deg,transparent,var(--acc));opacity:.85}

/* 10 — CIRCUIT : le mot est un noeud sur une piste de carte, pastille de soudure */
.s-circuit{height:48px;padding:0 22px 0 34px;font-size:14px;letter-spacing:2px;
  background:rgba(8,16,14,.72);border:1px solid rgba(120,220,180,.22);color:#d8f3e6}
.s-circuit::before{content:"";position:absolute;left:-14px;top:50%;width:26px;height:2px;
  background:var(--acc);opacity:.8}
.s-circuit::after{content:"";position:absolute;left:12px;top:50%;width:11px;height:11px;margin-top:-5.5px;
  border-radius:50%;background:radial-gradient(circle,#fff 0 22%,var(--acc) 23% 62%,transparent 63%);
  filter:drop-shadow(0 0 5px var(--acc))}

/* 11 — CAPSULE : cartouche inseree dans un logement biseaute, temoin allume */
.s-capsule{height:56px;padding:0 26px 0 22px;font-size:14.5px;letter-spacing:1.8px;
  background:linear-gradient(180deg,#212a34,#0e141b);
  clip-path:polygon(0 0,calc(100% - 14px) 0,100% 14px,100% 100%,14px 100%,0 calc(100% - 14px));
  box-shadow:inset 0 0 0 1px rgba(140,180,210,.16)}
.s-capsule .slot{position:absolute;inset:0;pointer-events:none;
  background:linear-gradient(90deg,rgba(0,0,0,.45) 0 6px,transparent 6px),
             linear-gradient(270deg,rgba(0,0,0,.45) 0 6px,transparent 6px)}
.s-capsule .led{position:absolute;right:9px;top:9px;width:6px;height:6px;border-radius:50%;
  background:var(--acc);box-shadow:0 0 7px var(--acc)}

/* 12 — RUBAN : banniere a queue d'aronde, tissu legerement satine */
.s-ruban{height:50px;padding:0 30px;font-size:14.5px;letter-spacing:2.4px;
  background:linear-gradient(180deg,color-mix(in srgb,var(--acc) 55%,#0b1016),
             color-mix(in srgb,var(--acc) 22%,#080d12));
  clip-path:polygon(0 0,100% 0,calc(100% - 13px) 50%,100% 100%,0 100%,13px 50%);
  color:#fff;text-shadow:0 1px 2px rgba(0,0,0,.65)}
.s-ruban::after{content:"";position:absolute;inset:0;pointer-events:none;
  background:linear-gradient(180deg,rgba(255,255,255,.22),transparent 42%,rgba(0,0,0,.28))}

/* ================= ANIMATIONS DU TITRE ================= */
.ta-assemblage .ch{animation:asm .5s cubic-bezier(.2,.8,.25,1.05) backwards}
@keyframes asm{from{opacity:0;transform:translateY(-38px) rotate(-9deg) scale(1.25)}to{opacity:1;transform:none}}
.ta-frappe{animation:frap .5s cubic-bezier(.2,.9,.2,1.1)}
@keyframes frap{0%{transform:scale(1.5);opacity:0;filter:blur(6px)}55%{transform:scale(.97);opacity:1;filter:blur(0)}
  70%{transform:translateX(-4px)}82%{transform:translateX(3px)}100%{transform:none}}
.ta-balayage{position:relative}
.ta-balayage .ch{background-image:linear-gradient(100deg,transparent 42%,rgba(255,255,255,.95) 50%,transparent 58%);
  background-size:340% 100%;-webkit-background-clip:text;background-clip:text;animation:sweep 3.4s linear infinite}
@keyframes sweep{from{background-position:180% 0}to{background-position:-120% 0}}
.ta-glitch .ch{animation:gl 3.6s steps(1) infinite}
@keyframes gl{0%,86%{transform:none;text-shadow:0 0 10px rgba(10,60,90,.9),0 3px 0 #0a2c3e}
  88%{transform:translateX(-3px);text-shadow:3px 0 #ff3b6b,-3px 0 #35f6ff}
  90%{transform:translateX(3px);text-shadow:-3px 0 #ff3b6b,3px 0 #35f6ff}
  92%{transform:translateY(2px)}94%{transform:none;text-shadow:2px 0 #35f6ff}}
.ta-respiration{animation:resp 3s ease-in-out infinite}
@keyframes resp{0%,100%{text-shadow:0 0 10px rgba(10,60,90,.9),0 3px 0 #0a2c3e}
  50%{text-shadow:0 0 26px rgba(90,220,255,.85),0 0 46px rgba(60,180,230,.45),0 3px 0 #0a2c3e}}
.ta-chargement .ch{color:transparent;-webkit-background-clip:text;background-clip:text;
  background-image:linear-gradient(0deg,#7fe4ff 0 50%,#1b3a4a 50% 100%);background-size:100% 200%;
  animation:load .9s ease-out backwards}
@keyframes load{from{background-position:0 -100%}to{background-position:0 0}}

/* ================= ANIMATIONS DES ONGLETS ================= */
.ba-cascade .tab{animation:casc .42s cubic-bezier(.2,.85,.25,1.05) backwards}
@keyframes casc{from{opacity:0;transform:translateY(26px) scale(.94)}to{opacity:1;transform:none}}
.ba-balayage .tab::before{}
.ba-balayage .tab .shine{position:absolute;inset:0;pointer-events:none;overflow:hidden;z-index:4}
.ba-balayage .tab .shine::after{content:"";position:absolute;top:0;bottom:0;width:36%;
  background:linear-gradient(100deg,transparent,rgba(255,255,255,.5),transparent);
  animation:rail 3.6s ease-in-out infinite}
@keyframes rail{0%{left:-40%}55%,100%{left:120%}}
.ba-voyant .tab .dotv{position:absolute;left:6px;top:6px;width:5px;height:5px;border-radius:50%;
  background:var(--acc);z-index:4;animation:blink 1.6s ease-in-out infinite}
@keyframes blink{0%,100%{opacity:.18}50%{opacity:1;box-shadow:0 0 8px var(--acc)}}
.ba-arete .tab{animation:arete 2.6s ease-in-out infinite}
@keyframes arete{0%,100%{filter:none}50%{filter:drop-shadow(0 0 7px var(--acc))}}
</style>

<script>
const A=__ASSETS__;
const NAV=[{t:"ARSENAL",c:"#d09a3e",s:"A-114"},{t:"ÉQUIPEMENT",c:"#9b7bd4",s:"E-207"},{t:"GARAGE",c:"#5793d8",s:"G-031"},
           {t:"QUOTIDIEN",c:"#4fc98a",s:"Q-048"},{t:"HISTOIRE",c:"#e0725c",s:"H-002"}];

const STYLES=[
 {k:"stencil",n:"7 · STENCIL DÉCOUPÉ",d:"Le mot est DÉCOUPÉ dans la barre de métal, une lueur passe derrière. Le plus frappant.",
  godot:"Label en couleur + un TextureRect lumineux DERRIERE, masque par la police (BackBufferCopy ou simple Label colore + glow)"},
 {k:"cartouche",n:"8 · CARTOUCHE",d:"Douille de munition : nez arrondi, laiton usé, témoin, matricule frappé au dos.",
  godot:"StyleBoxFlat corner_radius asymetrique (26/4/4/26) + degrade + petit Label matricule"},
 {k:"tag",n:"9 · ÉTIQUETTE SUSPENDUE",d:"Plaque d'atelier percée, accrochée au rail, légèrement de travers. Très tactile.",
  godot:"_draw() polygone coin coupe + rotation 1.4deg + oeillet dessine (2 cercles) + brin de couleur"},
 {k:"circuit",n:"10 · CIRCUIT",d:"Chaque onglet est un nœud sur une piste de carte électronique, avec sa pastille de soudure.",
  godot:"draw_line pour la piste + draw_circle pour la pastille — le plus leger a dessiner"},
 {k:"capsule",n:"11 · CAPSULE",d:"Cartouche insérée dans un logement biseauté, avec témoin allumé en haut à droite.",
  godot:"_draw() octogone asymetrique + 2 bandes d'ombre laterales + petit cercle LED"},
 {k:"ruban",n:"12 · RUBAN",d:"Bannière à queue d'aronde, tissu satiné. Le plus coloré et le plus « honneur militaire ».",
  godot:"_draw() polygone 6 points (pointes rentrantes) + degrade vertical"}];

const TANIM=[
 {k:"assemblage",n:"A · Assemblage",d:"Les lettres tombent et se verrouillent une par une.",
  godot:"1 Label par lettre + Tween en cascade (delai 0.04s), position + rotation + alpha"},
 {k:"frappe",n:"B · Frappe",d:"Le titre s'abat d'un coup avec une secousse.",
  godot:"Tween scale 1.5->0.97->1 + 2 tweens de position pour la secousse"},
 {k:"balayage",n:"C · Balayage",d:"Un reflet traverse les lettres en boucle.",
  godot:"ShaderMaterial sur le Label : bande claire translatee (UV) en boucle"},
 {k:"glitch",n:"D · Glitch",d:"Bref décrochage numérique avec dédoublement rouge/cyan.",
  godot:"Shader : decalage UV + separation des canaux, declenche periodiquement"},
 {k:"respiration",n:"E · Respiration",d:"La lueur du titre enfle et retombe doucement.",
  godot:"Tween en boucle sur outline_color / un Sprite de halo derriere"},
 {k:"chargement",n:"F · Chargement",d:"Les lettres se remplissent d'énergie par le bas.",
  godot:"Shader : degradé vertical dont le seuil monte (progress 0->1)"},
 {k:"aucune",n:"— Aucune",d:"Titre fixe.",godot:"rien"}];

const BANIM=[
 {k:"cascade",n:"1 · Cascade",d:"Les onglets montent un par un à l'ouverture du menu.",
  godot:"Tween par onglet avec delai croissant (0.05s x index) : position_y + alpha"},
 {k:"balayage",n:"2 · Reflet",d:"Un reflet passe sur les onglets en boucle.",
  godot:"Shader de bande claire, ou Sprite additif translate en boucle"},
 {k:"voyant",n:"3 · Voyant",d:"Un petit témoin clignote sur chaque onglet.",
  godot:"Tween en boucle sur modulate:a d'un petit cercle"},
 {k:"arete",n:"4 · Halo d'arête",d:"L'arête colorée respire doucement.",
  godot:"Tween en boucle sur l'intensite du contour"},
 {k:"aucune",n:"— Aucune",d:"Onglets fixes.",godot:"rien"}];

let si=0, ti=0, bi=0, portrait=false, run=0;

function tabHTML(n,s,i){
  const acc=`--acc:${n.c}`;
  const extra = (BANIM[bi].k==="cascade") ? `animation-delay:${0.05*i}s;` :
                (BANIM[bi].k==="balayage") ? `` : ``;
  const shine = BANIM[bi].k==="balayage" ? `<span class="shine" style="animation-delay:${0.25*i}s"></span>` : "";
  const dotv  = BANIM[bi].k==="voyant" ? `<span class="dotv" style="animation-delay:${0.2*i}s"></span>` : "";
  const inner = (s==="capsule") ? `<span class="slot"></span><span class="led"></span>` :
                (s==="cartouche") ? `<span class="ser">${n.s}</span>` : "";
  return `<div class="tab s-${s}" style="${acc};${extra}">${inner}${shine}${dotv}<span class="lbl">${n.t}</span></div>`;
}
function titleHTML(fs){
  const cls = TANIM[ti].k==="aucune" ? "" : "ta-"+TANIM[ti].k;
  const per = (TANIM[ti].k==="assemblage"||TANIM[ti].k==="chargement");
  const chars=[..."MECHA-FORGE"].map((c,i)=>
    `<span class="ch" style="${per?`animation-delay:${0.045*i}s;`:""}">${c==="-"?"&#8209;":c}</span>`).join("");
  return `<div class="g-title ${cls}" style="font-size:${fs}px;line-height:1.05">${chars}</div>`;
}

const stage=document.getElementById("stage"), scaler=document.getElementById("scaler");
function draw(){
  const W = portrait?720:1280, H = portrait?1280:720, k=Math.min(W,H)/720;
  const s=STYLES[si].k;
  stage.style.width=W+"px"; stage.style.height=H+"px";
  const railcls = BANIM[bi].k==="aucune" ? "" : "ba-"+BANIM[bi].k;
  stage.innerHTML=`
    <div class="bg" style="background-image:url(${A.hero})"></div><div class="veil"></div><div class="band"></div>
    <div style="position:absolute;left:50%;transform:translateX(-50%);top:${(portrait?76:30)*k}px;text-align:center;width:max-content">
      <img src="${A.emblem}" style="width:${(portrait?100:92)*k}px;height:${(portrait?100:92)*k}px;object-fit:contain">
      ${titleHTML((portrait?46:66)*k)}
      <div class="g-tag" style="font-size:${17*k}px;margin-top:6px">SURVIVE THE HORDE</div>
    </div>
    <div style="position:absolute;left:50%;transform:translateX(-50%);top:${H*0.5+12*k}px;width:${Math.min(420*k,W-44*k)}px">
      <div class="cap" style="font-size:${14*k}px;margin-bottom:${7*k}px">CAMPAGNE · NORMAL</div>
      <div class="play" style="height:${94*k}px;font-size:${40*k}px">JOUER</div>
    </div>
    <div class="railrow ${railcls}" style="bottom:${46*k}px;padding:0 ${22*k}px">
      ${NAV.map((n,i)=>tabHTML(n,s,i)).join("")}
    </div>`;
  const av=scaler.clientWidth||860, f=Math.min(1,av/W);
  stage.style.transform=`scale(${f})`; scaler.style.height=(H*f)+"px";
  document.getElementById("zoom").innerHTML=
    `<div class="zrow ${railcls}">${NAV.slice(0,3).map((n,i)=>tabHTML(n,s,i)).join("")}</div>`;
  document.getElementById("note").innerHTML=
    `<h3>Dans Godot</h3><b>${STYLES[si].n}</b><br><code>${STYLES[si].godot}</code>`
    +`<br><br><b>Titre — ${TANIM[ti].n}</b><br><code>${TANIM[ti].godot}</code>`
    +`<br><br><b>Onglets — ${BANIM[bi].n}</b><br><code>${BANIM[bi].godot}</code>`
    +`<br><br>Les animations d'<b>entrée</b> (assemblage, frappe, cascade) se jouent à l'ouverture du menu ; les autres tournent en boucle.`;
}
function build(listId,arr,getI,setI){
  const w=document.getElementById(listId); w.innerHTML="";
  arr.forEach((o,i)=>{const d=document.createElement("div");d.className="opt"+(i===getI()?" on":"");
    d.innerHTML=`<div class="t">${o.n}</div><div class="d">${o.d}</div>`;
    d.addEventListener("click",()=>{setI(i);
      w.querySelectorAll(".opt").forEach((x,j)=>x.classList.toggle("on",j===i));draw();});
    w.append(d);});
}
window.addEventListener("resize",draw);
build("opts",STYLES,()=>si,i=>si=i);
build("tanim",TANIM,()=>ti,i=>ti=i);
build("banim",BANIM,()=>bi,i=>bi=i);
const orient=document.getElementById("orient");
[["Paysage",false],["Portrait",true]].forEach(([lbl,v])=>{const b=document.createElement("button");
  b.textContent=lbl;b.className=(v===portrait?"on":"");
  b.addEventListener("click",()=>{portrait=v;
    document.querySelectorAll("#orient button").forEach(x=>x.classList.toggle("on",x.textContent===lbl));draw();});
  orient.append(b);});
document.getElementById("replay").addEventListener("click",draw);
draw();
</script>
"""

HTML = HTML.replace("__ASSETS__", ASSETS_JSON)
dst = os.path.join(ROOT, "cine", "_show", "tab_styles2.html")
open(dst, "w", encoding="utf-8").write(HTML)
print("wrote", dst, "%.0f KB" % (os.path.getsize(dst) / 1024))
