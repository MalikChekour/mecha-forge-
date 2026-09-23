# Builds cine/_show/menu_templates.html : a menu design review.
# Renders the CURRENT menu (absolute 1280x720 coords, straight from MetaScreen.gd)
# next to 5 calibrated template proposals, inside a stage whose width can be
# switched from 4:3 to 21:9 at a fixed 720 height -- exactly how Godot's
# stretch/aspect="expand" behaves -- so the calibration is visible, not claimed.
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AS = json.load(open(os.path.join(ROOT, "cine", "_show", "_menu_assets.json")))
ASSETS_JSON = json.dumps(AS, separators=(",", ":"))

HTML = r"""<div id="app">
<header>
  <h1>MECHA-FORGE <span>&middot; Menus &mdash; calibrage &amp; styles</span></h1>
  <p class="sub">Le menu actuel est pos&eacute; en <b>pixels absolus sur 1280&times;720</b>. Change le ratio ci-dessous&nbsp;: tu verras l'accueil actuel se d&eacute;caler, pendant que les templates restent cal&eacute;s. Choisis le style qui te pla&icirc;t.</p>
</header>

<div class="ratios" id="ratios"></div>

<main>
  <section class="stagewrap">
    <div class="stagehead">
      <span id="tname" class="tname"></span>
      <span id="tsize" class="tsize"></span>
      <label class="safechk"><input type="checkbox" id="safe"> zone s&ucirc;re 16:9</label>
    </div>
    <div class="scaler" id="scaler"><div class="stage" id="stage"></div></div>
    <div class="verdict" id="verdict"></div>
  </section>

  <aside class="side">
    <div class="list" id="list"></div>
    <div class="notes" id="notes"></div>
  </aside>
</main>
</div>

<style>
:root{--bg:#080c14;--panel:#0f1522;--line:#1d2939;--line2:#27374d;--ink:#e8eefb;--dim:#8ba1c0;
  --accent:#4fd8e8;--accent2:#7c5cff;--good:#2fbf74;--warn:#ff8a3c;--bad:#ff5d6c;}
*{box-sizing:border-box}
#app{max-width:1220px;margin:0 auto;padding:20px 18px 44px;color:var(--ink);
  font:14px/1.55 ui-sans-serif,system-ui,"Segoe UI",Roboto,sans-serif}
body{background:radial-gradient(1100px 560px at 12% -12%,#132238 0,transparent 62%),
  radial-gradient(900px 520px at 108% 4%,#1a1430 0,transparent 58%),var(--bg)}
header h1{margin:0;font-weight:800;letter-spacing:.3px;font-size:22px}
header h1 span{color:var(--accent);font-weight:600;font-size:15px;letter-spacing:.6px}
.sub{margin:.4em 0 0;color:var(--dim);max-width:76ch}
.ratios{display:flex;gap:7px;flex-wrap:wrap;margin:16px 0 12px}
.rb{background:#111a28;border:1px solid var(--line2);color:var(--dim);border-radius:9px;
  padding:8px 12px;cursor:pointer;font-size:12px;font-weight:600}
.rb b{color:var(--ink);font-weight:700}
.rb.on{border-color:var(--accent);background:#122a34;color:#fff}
main{display:grid;grid-template-columns:1fr 330px;gap:16px;align-items:start}
@media(max-width:940px){main{grid-template-columns:1fr}}
.stagewrap{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:12px;position:sticky;top:12px}
@media(max-width:940px){.stagewrap{position:relative}}
.stagehead{display:flex;align-items:center;gap:10px;margin-bottom:9px;flex-wrap:wrap}
.tname{font-weight:700;font-size:14px}
.tsize{color:var(--dim);font-size:12px;font-variant-numeric:tabular-nums}
.safechk{margin-left:auto;display:flex;align-items:center;gap:6px;color:var(--dim);font-size:12px;cursor:pointer}
.safechk input{width:15px;height:15px;accent-color:var(--accent)}
.scaler{overflow:hidden;border-radius:10px;border:1px solid var(--line2);background:#04060a}
.stage{position:relative;transform-origin:top left;overflow:hidden;font-family:ui-sans-serif,system-ui,"Segoe UI",Roboto,sans-serif}
.verdict{margin-top:10px;font-size:12.5px;padding:9px 11px;border-radius:9px;border:1px solid var(--line2);background:#0b1220}
.verdict.ok{border-color:#1e6b48;background:#0a1a14;color:#9fe8c4}
.verdict.ko{border-color:#6b2530;background:#1a0c10;color:#ffb6bd}
.side{display:flex;flex-direction:column;gap:12px}
.list{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:8px}
.trow{display:flex;gap:10px;align-items:flex-start;padding:9px 10px;border-radius:9px;cursor:pointer;border:1px solid transparent}
.trow:hover{background:#0d1728}
.trow.on{background:#122436;border-color:var(--accent)}
.trow .n{width:20px;flex:none;color:var(--dim);font-size:11px;font-weight:700;padding-top:2px}
.trow .t{font-weight:700;font-size:13px}
.trow .d{color:var(--dim);font-size:11.5px;line-height:1.4}
.trow.cur .t{color:var(--bad)}
.notes{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:13px}
.notes h3{margin:0 0 8px;font-size:12px;text-transform:uppercase;letter-spacing:.5px;color:var(--accent)}
.notes ul{margin:6px 0 0;padding-left:16px;color:var(--dim);font-size:12.5px}
.notes li{margin:4px 0}
.notes .pro::marker{color:var(--good)} .notes .con::marker{color:var(--warn)}

/* ---------- in-stage (game) styles ---------- */
.stage .bg{position:absolute;inset:0;background-size:cover;background-position:center;}
.stage .veil{position:absolute;inset:0;background:rgba(8,13,20,.30)}
.stage .band{position:absolute;left:0;right:0;bottom:0;height:340px;
  background:linear-gradient(to bottom,rgba(5,8,13,0),rgba(5,8,13,.96))}
.stage .safebox{position:absolute;top:0;bottom:0;left:50%;width:1280px;transform:translateX(-50%);
  outline:2px dashed rgba(79,216,232,.55);pointer-events:none}
.stage .safetag{position:absolute;top:6px;left:50%;transform:translateX(-50%);color:#4fd8e8;font-size:12px;
  background:rgba(4,10,16,.8);padding:2px 8px;border-radius:6px;letter-spacing:.5px}
.g-title{font-weight:900;letter-spacing:1px;color:#bcecff;text-shadow:0 0 10px rgba(10,60,90,.9),0 3px 0 #0a2c3e}
.g-tag{color:#5fe0ff;letter-spacing:3px;font-weight:700}
.chip{display:flex;align-items:center;gap:8px;height:40px;padding:0 12px;border-radius:10px;
  background:rgba(12,20,30,.9);border:2px solid #2c4a58;color:#e9f4ff;font-size:19px;white-space:nowrap}
.chip i{width:16px;height:16px;border-radius:50%;display:block;flex:none}
.chip .plus{color:#5cff8f;font-size:24px;font-weight:700;margin-left:2px}
.btn{display:flex;align-items:center;justify-content:center;border-radius:14px;color:#fff;
  font-weight:800;letter-spacing:1px;border:3px solid rgba(255,255,255,.32);text-align:center}
.btn.play{background:#29a866;border-color:#66e2a0;box-shadow:0 0 26px rgba(41,168,102,.55)}
.cap{color:#cfe0f2;text-align:center;letter-spacing:1px}
.foot{position:absolute;color:#7f8b9c;font-size:12px}
.navtile{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:5px;
  border-radius:12px;border:2px solid rgba(255,255,255,.18);color:#fff;font-weight:700;letter-spacing:.6px}
.navtile .ic{font-size:20px;line-height:1}
.socle{position:absolute;border-radius:50%;background:radial-gradient(ellipse at center,rgba(79,216,232,.28),rgba(79,216,232,0) 70%)}
.card{border-radius:16px;border:2px solid #2f5568;background:linear-gradient(180deg,rgba(11,20,31,.94),rgba(8,14,22,.96));
  box-shadow:0 10px 40px rgba(0,0,0,.5)}
.pbar{height:10px;border-radius:6px;background:#12212f;border:1px solid #2b4658;overflow:hidden}
.pbar i{display:block;height:100%;background:linear-gradient(90deg,#2fbf74,#7ce8b0)}
</style>

<script>
const A=__ASSETS__;
const RATIOS=[{k:"4:3",w:960,note:"tablette / vieux Android"},{k:"16:9",w:1280,note:"base du projet"},
  {k:"19.5:9",w:1560,note:"iPhone moderne"},{k:"20:9",w:1600,note:"Android courant"},{k:"21:9",w:1680,note:"ultra-large"}];
const H=720;
let ri=1, ti=0, showSafe=false;

// content shared by every template
const C={title:"MECHA-FORGE",tag:"SURVIVE THE HORDE",
  chips:[{t:"1 250 points",c:"#66ebff",plus:true},{t:"340",c:"#ffcc59"},{t:"12 cristaux",c:"#99c6ff"}],
  play:"JOUER",cap:"CAMPAGNE  ·  NORMAL",
  nav:[{t:"ARSENAL",i:"⚙",c:"#8c6636"},{t:"ÉQUIPEMENT",i:"🛡",c:"#6b5699"},{t:"GARAGE",i:"🔧",c:"#3d6b9e"},
       {t:"QUOTIDIEN",i:"🎁",c:"#3d805e"},{t:"HISTOIRE",i:"📖",c:"#994d3d"}],
  foot:"v9.7   ·   Musique K. MacLeod (incompetech) CC-BY 4.0   ·   SFX Kenney CC0"};

function chipHTML(c,fs){return `<div class="chip" style="font-size:${fs||19}px"><i style="background:${c.c}"></i>${c.t}${c.plus?'<span class="plus">+</span>':''}</div>`;}
function bgHTML(){return `<div class="bg" style="background-image:url(${A.hero})"></div><div class="veil"></div>`;}

// ---------------- T0 : the CURRENT menu, absolute 1280x720 coords from MetaScreen.gd ----------------
function T0(){return bgHTML()+`
<div class="band"></div>
<img src="${A.emblem}" style="position:absolute;left:34px;top:26px;width:122px;height:122px;object-fit:contain">
<div class="g-title" style="position:absolute;left:170px;top:42px;font-size:58px;line-height:1">${C.title}</div>
<div class="g-tag"  style="position:absolute;left:174px;top:112px;font-size:20px">${C.tag}</div>
<div style="position:absolute;left:792px;top:22px;width:168px">${chipHTML(C.chips[0])}</div>
<div style="position:absolute;left:970px;top:22px;width:140px">${chipHTML(C.chips[1])}</div>
<div style="position:absolute;left:1120px;top:22px;width:140px">${chipHTML(C.chips[2])}</div>
<div class="cap" style="position:absolute;left:430px;top:508px;width:420px;font-size:15px">${C.cap}</div>
<div class="btn play" style="position:absolute;left:430px;top:532px;width:420px;height:92px;font-size:42px">${C.play}</div>
`+C.nav.map((n,i)=>`<div class="btn" style="position:absolute;left:${48+i*240}px;top:648px;width:220px;height:60px;font-size:22px;background:${n.c}">${n.t}</div>`).join("")+`
<div class="foot" style="left:18px;top:700px">${C.foot}</div>`;}

// ---------------- T1 : CINÉMA — same look, properly anchored ----------------
function T1(){return bgHTML()+`
<div class="band"></div>
<div style="position:absolute;left:36px;top:26px;display:flex;align-items:center;gap:14px">
  <img src="${A.emblem}" style="width:118px;height:118px;object-fit:contain">
  <div><div class="g-title" style="font-size:56px;line-height:1.02">${C.title}</div>
       <div class="g-tag" style="font-size:19px;margin-top:6px">${C.tag}</div></div>
</div>
<div style="position:absolute;right:32px;top:22px;display:flex;gap:12px">${C.chips.map(c=>chipHTML(c)).join("")}</div>
<div style="position:absolute;left:50%;transform:translateX(-50%);bottom:112px;width:min(460px,52%)">
  <div class="cap" style="font-size:15px;margin-bottom:8px">${C.cap}</div>
  <div class="btn play" style="height:94px;font-size:42px">${C.play}</div>
</div>
<div style="position:absolute;left:40px;right:40px;bottom:34px;display:flex;gap:14px;justify-content:center">
  ${C.nav.map(n=>`<div class="btn" style="flex:1;max-width:230px;height:58px;font-size:21px;background:${n.c}">${n.t}</div>`).join("")}
</div>
<div class="foot" style="left:22px;bottom:10px">${C.foot}</div>`;}

// ---------------- T2 : DOCK LATÉRAL — landscape-native, thumb zones ----------------
function T2(){return bgHTML()+`
<div style="position:absolute;left:0;top:0;bottom:0;width:210px;background:linear-gradient(90deg,rgba(6,11,18,.96),rgba(6,11,18,.62))"></div>
<div style="position:absolute;left:22px;top:22px;display:flex;align-items:center;gap:10px">
  <img src="${A.emblem}" style="width:56px;height:56px;object-fit:contain">
  <div class="g-title" style="font-size:22px;line-height:1.05">${C.title}</div>
</div>
<div style="position:absolute;left:20px;top:100px;width:170px;display:flex;flex-direction:column;gap:11px">
  ${C.nav.map(n=>`<div class="navtile" style="flex-direction:row;justify-content:flex-start;gap:11px;padding:0 14px;height:60px;font-size:15px;background:${n.c}"><span class="ic">${n.i}</span>${n.t}</div>`).join("")}
</div>
<div class="socle" style="left:calc(50% - 60px);top:300px;width:420px;height:150px;transform:translateX(-50%)"></div>
<img src="${A.mech}" style="position:absolute;left:calc(50% - 60px);top:150px;transform:translateX(-50%);height:330px;object-fit:contain">
<div style="position:absolute;right:30px;top:22px;display:flex;gap:11px">${C.chips.map(c=>chipHTML(c,17)).join("")}</div>
<div style="position:absolute;right:34px;bottom:36px;width:min(400px,34%)">
  <div class="cap" style="font-size:14px;margin-bottom:7px;text-align:right">${C.cap}</div>
  <div class="btn play" style="height:96px;font-size:40px">${C.play}</div>
</div>
<div class="foot" style="left:22px;bottom:10px">${C.foot}</div>`;}

// ---------------- T3 : CARTE CHAPITRE — Survivor.io / Archero style ----------------
function T3(){return bgHTML()+`
<div class="band" style="height:200px"></div>
<div style="position:absolute;left:26px;top:20px;display:flex;align-items:center;gap:10px">
  <img src="${A.emblem}" style="width:52px;height:52px;object-fit:contain">
  <div class="g-title" style="font-size:20px">${C.title}</div>
</div>
<div style="position:absolute;right:28px;top:20px;display:flex;gap:11px">${C.chips.map(c=>chipHTML(c,17)).join("")}</div>
<div class="socle" style="left:230px;top:340px;width:360px;height:130px;transform:translateX(-50%)"></div>
<img src="${A.mech}" style="position:absolute;left:230px;top:170px;transform:translateX(-50%);height:320px;object-fit:contain">
<div class="card" style="position:absolute;left:50%;transform:translateX(-50%);top:118px;width:min(520px,46%);padding:20px 22px">
  <div style="color:#6fe3ff;font-size:13px;letter-spacing:2px;font-weight:700">CHAPITRE 2</div>
  <div style="color:#fff;font-size:34px;font-weight:900;line-height:1.1;margin-top:2px">Terres Calcinées</div>
  <div style="color:#9fb6cc;font-size:15px;margin-top:2px">La Traversée · désert</div>
  <div style="display:flex;align-items:center;gap:10px;margin-top:16px">
    <div class="pbar" style="flex:1"><i style="width:62%"></i></div>
    <div style="color:#cfe0f2;font-size:13px">62%</div>
  </div>
  <div style="color:#8fa6bd;font-size:12.5px;margin-top:9px">Prochain palier : <span style="color:#ffcc59">+250 ferraille</span></div>
</div>
<div style="position:absolute;left:50%;transform:translateX(-50%);top:390px;width:min(430px,38%)">
  <div class="cap" style="font-size:14px;margin-bottom:7px">${C.cap}</div>
  <div class="btn play" style="height:88px;font-size:38px">${C.play}</div>
</div>
<div style="position:absolute;left:0;right:0;bottom:0;height:104px;background:rgba(6,11,18,.9);border-top:2px solid #1e3446;
  display:flex;align-items:center;justify-content:center;gap:16px;padding:0 26px">
  ${C.nav.map(n=>`<div class="navtile" style="flex:1;max-width:180px;height:74px;font-size:13px;background:${n.c}"><span class="ic">${n.i}</span>${n.t}</div>`).join("")}
</div>
<div class="foot" style="right:18px;bottom:112px">${C.foot}</div>`;}

// ---------------- T4 : PANNEAUX TACTIQUES ----------------
function T4(){return bgHTML()+`
<div style="position:absolute;inset:0;background:linear-gradient(90deg,rgba(6,11,18,.86) 0%,rgba(6,11,18,.35) 45%,rgba(6,11,18,.9) 100%)"></div>
<div style="position:absolute;left:30px;top:24px;display:flex;align-items:center;gap:12px">
  <img src="${A.emblem}" style="width:66px;height:66px;object-fit:contain">
  <div><div class="g-title" style="font-size:26px;line-height:1.05">${C.title}</div>
       <div class="g-tag" style="font-size:13px;margin-top:3px">${C.tag}</div></div>
</div>
<div style="position:absolute;right:28px;top:22px;display:flex;gap:11px">${C.chips.map(c=>chipHTML(c,17)).join("")}</div>
<div class="socle" style="left:min(300px,26%);top:360px;width:400px;height:140px;transform:translateX(-50%)"></div>
<img src="${A.mech}" style="position:absolute;left:min(300px,26%);top:150px;transform:translateX(-50%);height:360px;object-fit:contain">
<div style="position:absolute;right:34px;top:112px;width:min(560px,46%);display:grid;grid-template-columns:1fr 1fr;gap:13px">
  ${C.nav.slice(0,4).map(n=>`<div class="card" style="height:104px;display:flex;align-items:center;gap:13px;padding:0 16px;border-color:${n.c}">
     <div style="width:46px;height:46px;border-radius:11px;background:${n.c};display:flex;align-items:center;justify-content:center;font-size:22px">${n.i}</div>
     <div><div style="color:#fff;font-weight:800;font-size:17px;letter-spacing:.6px">${n.t}</div>
          <div style="color:#8fa6bd;font-size:12px">3 am&eacute;liorations dispo</div></div></div>`).join("")}
</div>
<div style="position:absolute;right:34px;top:340px;width:min(560px,46%)">
  <div class="card" style="height:62px;display:flex;align-items:center;gap:12px;padding:0 16px;border-color:${C.nav[4].c}">
    <div style="width:34px;height:34px;border-radius:9px;background:${C.nav[4].c};display:flex;align-items:center;justify-content:center">${C.nav[4].i}</div>
    <div style="color:#fff;font-weight:800;font-size:15px;letter-spacing:.6px">${C.nav[4].t}</div>
  </div>
</div>
<div style="position:absolute;left:40px;right:40px;bottom:32px;display:flex;align-items:center;gap:20px">
  <div class="cap" style="font-size:15px;white-space:nowrap">${C.cap}</div>
  <div class="btn play" style="flex:1;height:86px;font-size:38px">${C.play}</div>
</div>
<div class="foot" style="left:22px;bottom:8px">${C.foot}</div>`;}

// ---------------- T5 : ÉPURÉ ----------------
function T5(){return bgHTML()+`
<div class="band" style="height:260px"></div>
<div style="position:absolute;left:50%;transform:translateX(-50%);top:64px;text-align:center">
  <img src="${A.emblem}" style="width:104px;height:104px;object-fit:contain">
  <div class="g-title" style="font-size:52px;line-height:1.05;margin-top:4px">${C.title}</div>
  <div class="g-tag" style="font-size:17px;margin-top:6px">${C.tag}</div>
</div>
<div style="position:absolute;right:26px;top:20px;display:flex;gap:10px">${C.chips.map(c=>chipHTML(c,16)).join("")}</div>
<div style="position:absolute;left:50%;transform:translateX(-50%);top:398px;width:min(400px,36%)">
  <div class="cap" style="font-size:14px;margin-bottom:8px">${C.cap}</div>
  <div class="btn play" style="height:98px;font-size:44px">${C.play}</div>
</div>
<div style="position:absolute;left:50%;transform:translateX(-50%);bottom:34px;display:flex;gap:10px;
     background:rgba(8,13,20,.72);border:1px solid #24384c;border-radius:14px;padding:9px 12px">
  ${C.nav.map(n=>`<div style="display:flex;align-items:center;gap:8px;height:44px;padding:0 15px;border-radius:10px;
     background:rgba(255,255,255,.05);border:1px solid ${n.c};color:#dceaf7;font-size:13.5px;font-weight:700;letter-spacing:.5px">
     <span style="font-size:16px">${n.i}</span>${n.t}</div>`).join("")}
</div>
<div class="foot" style="left:20px;bottom:10px">${C.foot}</div>`;}

const TPL=[
 {n:"ACTUEL (à corriger)",f:T0,cur:true,
  d:"Ce qui tourne aujourd'hui : tout en pixels absolus sur 1280×720.",
  why:["Rien n'est ancré : chaque élément a une position fixe en dur.",
       "Les chips vont jusqu'à x=1260 → coupées dès que l'écran est plus étroit (4:3).",
       "Sur écran plus large, tout reste collé à gauche et laisse un vide à droite.",
       "La rangée du bas (y=648) et le pied (y=700) sont calés sur une hauteur de 720 exacte."],
  con:[]},
 {n:"1 · CINÉMA",f:T1,
  d:"Ton menu actuel, mais recalibré : mêmes éléments, ancrages corrects.",
  why:["Logo ancré en haut-gauche, chips en haut-droite, CTA centré, rangée répartie, pied en bas.",
       "Le changement le plus rapide : on garde l'identité, on ne corrige que la mise en page."],
  pro:["Zéro dépaysement pour le joueur","Le moins de travail","Garde l'art plein cadre"],
  con:["Reste 5 boutons de même poids en bas","Peu de place pour du live-ops plus tard"]},
 {n:"2 · DOCK LATÉRAL",f:T2,
  d:"Navigation verticale à gauche, mecha en vedette, JOUER en bas-droite.",
  why:["Pensé paysage : les deux pouces tombent naturellement sur le dock (gauche) et le CTA (droite).",
       "La largeur en plus profite au mecha au centre, jamais à l'interface."],
  pro:["La meilleure ergonomie en paysage","Met le mecha en avant","S'étire proprement en 21:9"],
  con:["Mange une bande à gauche","Change franchement l'allure actuelle"]},
 {n:"3 · CARTE CHAPITRE",f:T3,
  d:"Style Survivor.io / Archero : la progression devient le cœur du menu.",
  why:["Le joueur voit où il en est (chapitre, %, prochaine récompense) avant de lancer.",
       "Barre de navigation persistante en bas : le schéma le plus standard du F2P mobile."],
  pro:["Donne une raison de relancer","Navigation familière","Place naturelle pour les récompenses"],
  con:["Le plus de travail (carte + progression)","Cache une partie de l'art"]},
 {n:"4 · PANNEAUX TACTIQUES",f:T4,
  d:"Mecha à gauche, panneaux d'accès en grille 2×2 à droite, JOUER en barre pleine.",
  why:["Chaque panneau peut porter une info (améliorations dispo, badge) — lisible d'un coup d'œil.",
       "Look console/atelier, cohérent avec le thème mécanique."],
  pro:["Panneaux informatifs, pas juste des boutons","Très bonne lisibilité","Extensible"],
  con:["Plus chargé","Demande des icônes propres"]},
 {n:"5 · ÉPURÉ",f:T5,
  d:"L'art domine, un seul geste évident, le reste dans un rail discret.",
  why:["Une seule action mise en avant : JOUER. Tout le reste est secondaire et regroupé.",
       "Le contraire du menu F2P encombré."],
  pro:["Le plus élégant","Mise en avant maximale du CTA","Très rapide à lire"],
  con:["Les sections sont moins visibles","Peu adapté si tu ajoutes beaucoup de live-ops"]}
];

// ---------------- render ----------------
const stage=document.getElementById("stage"),scaler=document.getElementById("scaler");
function render(){
  const w=RATIOS[ri].w, t=TPL[ti];
  stage.style.width=w+"px";stage.style.height=H+"px";
  stage.innerHTML=t.f()+(showSafe?`<div class="safebox"><div class="safetag">zone sûre 16:9 · 1280</div></div>`:"");
  fit();
  document.getElementById("tname").textContent=t.n;
  document.getElementById("tsize").textContent=`${RATIOS[ri].k} — ${w}×${H} (${RATIOS[ri].note})`;
  const v=document.getElementById("verdict");
  if(t.cur){const w0=RATIOS[ri].w;
    v.className="verdict ko";
    v.innerHTML = w0<1280 ? `<b>Cassé ici :</b> l'écran fait ${w0}px de large, or les chips vont jusqu'à x=1260 et la rangée du bas jusqu'à x=1228 → <b>coupés hors écran</b>.`
      : w0>1280 ? `<b>Décalé ici :</b> l'écran fait ${w0}px, mais tout est calé sur 1280 → <b>${w0-1280}px de vide à droite</b>, JOUER n'est plus centré.`
      : `À 1280×720 exactement, ça tombe juste — c'est la <b>seule</b> taille où ce menu est correct.`;
  } else {v.className="verdict ok";
    v.innerHTML=`<b>Calé :</b> ancré sur les bords + zone sûre. La largeur en plus devient de l'espace, jamais du contenu coupé.`;}
  document.querySelectorAll(".trow").forEach((r,i)=>r.classList.toggle("on",i===ti));
  const n=document.getElementById("notes");
  n.innerHTML=`<h3>${t.cur?"Pourquoi c'est mal calibré":"Pourquoi ce style"}</h3><ul>${(t.why||[]).map(x=>`<li>${x}</li>`).join("")}</ul>`
    +((t.pro&&t.pro.length)?`<h3 style="margin-top:12px">Points forts</h3><ul>${t.pro.map(x=>`<li class="pro">${x}</li>`).join("")}</ul>`:"")
    +((t.con&&t.con.length)?`<h3 style="margin-top:12px">À accepter</h3><ul>${t.con.map(x=>`<li class="con">${x}</li>`).join("")}</ul>`:"");
}
function fit(){const avail=scaler.clientWidth||880;const k=Math.min(1,avail/RATIOS[ri].w);
  stage.style.transform=`scale(${k})`;scaler.style.height=(H*k)+"px";}
window.addEventListener("resize",fit);

const rb=document.getElementById("ratios");
RATIOS.forEach((r,i)=>{const b=document.createElement("button");b.className="rb"+(i===ri?" on":"");
  b.innerHTML=`<b>${r.k}</b> · ${r.w}×${H}`;
  b.addEventListener("click",()=>{ri=i;document.querySelectorAll(".rb").forEach((x,j)=>x.classList.toggle("on",j===i));render();});
  rb.append(b);});
const list=document.getElementById("list");
TPL.forEach((t,i)=>{const d=document.createElement("div");d.className="trow"+(i===ti?" on":"")+(t.cur?" cur":"");
  d.innerHTML=`<div class="n">${t.cur?"!":i}</div><div><div class="t">${t.n}</div><div class="d">${t.d}</div></div>`;
  d.addEventListener("click",()=>{ti=i;render();});list.append(d);});
document.getElementById("safe").addEventListener("change",e=>{showSafe=e.target.checked;render();});
render();
</script>
"""

HTML = HTML.replace("__ASSETS__", ASSETS_JSON)
dst = os.path.join(ROOT, "cine", "_show", "menu_templates.html")
open(dst, "w", encoding="utf-8").write(HTML)
print("wrote", dst, "%.0f KB" % (os.path.getsize(dst) / 1024))
