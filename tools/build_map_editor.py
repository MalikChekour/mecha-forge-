# Builds cine/_show/map_editor.html : a MAP DECORATOR over the FULL arena.
# The whole bounded arena (6000x6000 world units) is the decorating field, so the
# mech is a small ~6% reference and there is lots of room. Camera with zoom
# (wheel / slider) + pan (Vue mode / middle-drag) to work precisely. Objects and
# mech are stored in arena-normalized coords (0..1) with sizes as arena fractions,
# so everything is resolution- and zoom-independent. Self-contained, per-biome save.
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AS = json.load(open(os.path.join(ROOT, "cine", "_show", "_map_assets.json")))
ASSETS_JSON = json.dumps(AS, separators=(",", ":"))

HTML = r"""<div id="app">
<header>
  <h1>MECHA-FORGE <span>&middot; D&eacute;corateur de cartes</span></h1>
  <p class="sub">Chaque carte s'ouvre <b>d&eacute;j&agrave; d&eacute;cor&eacute;e comme dans le jeu</b> (objets, densit&eacute; et bordure du biome) &mdash; tu <b>ajoutes ou retires</b> &agrave; partir de l&agrave;. <b>Molette</b> = zoom, mode <b>Vue</b> = d&eacute;placer. &laquo;&nbsp;D&eacute;co du jeu&nbsp;&raquo; recharge l'&eacute;tat d'origine.</p>
</header>

<main>
  <section class="stage">
    <div class="toolbar">
      <button id="mode_place" class="tbtn on" title="Poser des objets">&#9998; Poser</button>
      <button id="mode_sel" class="tbtn" title="S&eacute;lectionner / d&eacute;placer">&#9995; S&eacute;lection</button>
      <button id="mode_view" class="tbtn" title="D&eacute;placer la vue">&#9995;&#65039; Vue</button>
      <span class="brush" id="brush"></span>
      <span class="count" id="count"></span>
    </div>
    <canvas id="cv" width="700" height="700"></canvas>
    <div class="viewbar">
      <label class="zl">Zoom <input type="range" id="zoom" min="1" max="8" step="0.1" value="1"></label>
      <span id="zlab" class="zlab">&times;1.0</span>
      <button id="fit" class="tbtn sm">&#9635; Tout voir</button>
      <span class="hint">clic droit = supprimer &middot; molette = zoom</span>
    </div>
  </section>

  <aside class="side">
    <div class="bar">
      <div class="row2"><label>Biome</label><select id="biome"></select></div>
      <div class="acts">
        <button id="save">&#128190; Enregistrer</button>
        <button id="regen">&#9851; D&eacute;co du jeu</button>
        <button id="clear">&#128465; Vider</button>
        <button id="export" class="primary">&#128228; Exporter</button>
      </div>
    </div>

    <div class="mechbar" id="mechbar"></div>
    <div class="selbox" id="selbox"></div>
    <div class="palette" id="palette"></div>
    <div id="io" class="io"></div>
  </aside>
</main>
</div>

<style>
:root{--bg:#0a0e17;--bg2:#111827;--panel:#0f1522;--line:#1e2a3f;--line2:#26374f;
  --ink:#e7eefb;--dim:#8aa0c0;--accent:#37e0c8;--accent2:#7c5cff;--hot:#ff7a45;--gold:#ffcf5c;}
*{box-sizing:border-box}
#app{max-width:1160px;margin:0 auto;padding:20px 18px 40px;color:var(--ink);
  font:14px/1.5 ui-sans-serif,system-ui,"Segoe UI",Roboto,sans-serif}
body{background:radial-gradient(1200px 600px at 20% -10%,#16243b 0,transparent 60%),
  radial-gradient(900px 500px at 110% 10%,#1a1330 0,transparent 55%),var(--bg);}
header h1{margin:0;font-weight:800;letter-spacing:.4px;font-size:22px}
header h1 span{color:var(--accent);font-weight:600;font-size:15px;letter-spacing:1px}
.sub{margin:.35em 0 0;color:var(--dim)}
main{display:grid;grid-template-columns:minmax(340px,540px) 1fr;gap:16px;align-items:start;margin-top:16px}
@media(max-width:900px){main{grid-template-columns:1fr}}
.stage{background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:12px;position:sticky;top:14px}
@media(max-width:900px){.stage{position:relative}}
.toolbar{display:flex;align-items:center;gap:8px;margin-bottom:10px;flex-wrap:wrap}
.tbtn{background:var(--bg2);color:var(--dim);border:1px solid var(--line2);border-radius:9px;padding:8px 12px;cursor:pointer;font-weight:600;font-size:13px}
.tbtn.sm{padding:6px 10px;font-size:12px}
.tbtn.on{background:#14263c;border-color:var(--accent);color:#fff}
.brush{display:flex;align-items:center;gap:6px;color:var(--dim);font-size:12px;margin-left:6px}
.brush img{width:26px;height:26px;object-fit:contain;background:#0a1220;border:1px solid var(--line);border-radius:6px}
.count{margin-left:auto;color:var(--dim);font-size:12px;font-variant-numeric:tabular-nums}
#cv{width:100%;height:auto;display:block;border-radius:10px;border:1px solid var(--line);
  background:#070b12;cursor:crosshair;touch-action:none}
.viewbar{display:flex;align-items:center;gap:10px;margin-top:9px;flex-wrap:wrap}
.viewbar .zl{display:flex;align-items:center;gap:8px;color:var(--dim);font-size:12px;flex:1;min-width:150px}
.viewbar .zl input{flex:1}
.zlab{font-variant-numeric:tabular-nums;color:var(--ink);font-size:12px;min-width:34px}
.viewbar .hint{color:var(--dim);font-size:11px}
input[type=range]{-webkit-appearance:none;appearance:none;height:5px;border-radius:5px;
  background:linear-gradient(90deg,var(--accent),var(--accent2));outline:none;width:100%}
input[type=range]::-webkit-slider-thumb{-webkit-appearance:none;width:16px;height:16px;border-radius:50%;
  background:#fff;border:2px solid var(--accent);cursor:pointer;box-shadow:0 2px 6px rgba(0,0,0,.5)}
.side{display:flex;flex-direction:column;gap:12px}
.bar{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:12px}
.row2{display:grid;grid-template-columns:56px 1fr;gap:10px;align-items:center}
.row2 label{color:var(--dim);font-size:12px}
select{width:100%;background:var(--bg2);color:var(--ink);border:1px solid var(--line2);border-radius:8px;padding:8px;font-size:13px}
.acts{display:flex;gap:8px;margin-top:10px;flex-wrap:wrap}
.acts button{flex:1;background:var(--bg2);color:var(--ink);border:1px solid var(--line2);border-radius:9px;padding:9px;cursor:pointer;font-weight:600;font-size:12px}
.acts button:hover{border-color:var(--accent)}
.acts button.primary{background:linear-gradient(180deg,#1f8f7f,#146356);border-color:var(--accent);color:#fff}
.mechbar{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:12px}
.mechbar h3{margin:0 0 8px;font-size:13px;color:var(--accent);text-transform:uppercase;letter-spacing:.5px}
.mechbar .mnote{color:var(--dim);font-size:11px;margin-top:6px}
.mechbar .mline{display:grid;grid-template-columns:70px 1fr;gap:10px;align-items:center;margin:6px 0}
.mechbar .mline label{color:var(--dim);font-size:12px}
.chk{display:flex;align-items:center;gap:8px;color:var(--dim);font-size:12px;cursor:pointer;margin:6px 0}
.chk input{width:16px;height:16px;accent-color:var(--accent)}
.selbox{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:12px;display:none}
.selbox.on{display:block}
.selbox h3{margin:0 0 8px;font-size:13px;color:var(--accent);text-transform:uppercase;letter-spacing:.5px}
.row{display:grid;grid-template-columns:78px 1fr 46px;align-items:center;gap:10px;margin:7px 0}
.row label{color:var(--dim);font-size:12px}
.row output{font-variant-numeric:tabular-nums;text-align:right;font-size:12px}
.selacts{display:flex;gap:7px;flex-wrap:wrap;margin-top:8px}
.selacts button{flex:1;min-width:60px;background:var(--bg2);color:var(--ink);border:1px solid var(--line2);border-radius:8px;padding:7px 6px;cursor:pointer;font-size:12px;font-weight:600}
.selacts button:hover{border-color:var(--accent)}
.selacts button.del{border-color:#6a2530;color:#ffb4b4}
.selacts button.del:hover{background:#3a1620}
.palette{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:6px 12px 14px;max-height:560px;overflow-y:auto}
.pgh{font-size:11px;letter-spacing:.5px;text-transform:uppercase;color:var(--dim);margin:12px 2px 6px;position:sticky;top:0;background:var(--panel);padding:4px 0}
.pgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(58px,1fr));gap:7px}
.pcell{background:#0a1220;border:1px solid var(--line);border-radius:9px;padding:5px;cursor:pointer;
  display:flex;align-items:center;justify-content:center;height:58px;transition:.12s}
.pcell:hover{border-color:var(--line2);transform:translateY(-1px)}
.pcell.on{border-color:var(--accent);box-shadow:0 0 0 1px rgba(55,224,200,.3)}
.pcell img{max-width:100%;max-height:100%;object-fit:contain;pointer-events:none}
.io{margin-top:2px}
.io textarea{width:100%;height:130px;background:#070b13;color:#9fe;border:1px solid var(--line2);border-radius:10px;padding:10px;font:12px/1.4 ui-monospace,Menlo,Consolas,monospace;resize:vertical}
.io .msg{color:var(--accent);font-size:12px;margin:6px 2px}
</style>

<script>
const ASSETS=__ASSETS__;
const KEY="mf_maps_v3";
const clone=o=>JSON.parse(JSON.stringify(o));
const MLAB={player:"Joueur",base:"Base",colosse:"Colosse",broyeur:"Broyeur",souverain:"Souverain"};

// REAL arena: ARENA_HALF=3000 -> 6000 units across. Sizes are arena fractions.
const ARENA=6000;
const MECH_HFRAC_GAME=360/ARENA;   // 0.06 : mech is ~6% of the arena
const PROP_S_GAME=110/ARENA;       // 0.018 : a standard prop -> mech reads ~3.3x

let S={biome:ASSETS.biomes[0], layouts:{}, mech:{on:true,chassis:"player",nx:0.5,ny:0.5,hfrac:MECH_HFRAC_GAME}};
try{const j=localStorage.getItem(KEY);if(j){const p=JSON.parse(j);S.biome=p.biome||S.biome;S.layouts=p.layouts||{};if(p.mech)S.mech=Object.assign(S.mech,p.mech);}}catch(e){}
ASSETS.biomes.forEach(b=>{if(!S.layouts[b])S.layouts[b]=[];});

// ---- In-game decoration (faithful reproduction of PropScatter.gd) ----
// kind -> sprite file (g##) + target world height (sz). Same table as the game.
const DEFS={baril:{f:"g20",sz:80},caisses:{f:"g21",sz:92},generateur:{f:"g22",sz:128},
  antenne:{f:"g23",sz:176},conduit:{f:"g24",sz:118},emetteur:{f:"g25",sz:118},epave:{f:"g26",sz:168},
  tourelle:{f:"g27",sz:130},container:{f:"g28",sz:140},capaciteur:{f:"g25",sz:188},rocher:{f:"g29",sz:120},
  cristaux:{f:"g30",sz:100},arbre:{f:"g31",sz:178},plante:{f:"g32",sz:78},glace:{f:"g33",sz:122},
  arche:{f:"g34",sz:196},lave:{f:"g35",sz:112},racines:{f:"g36",sz:132}};
const HAZARDS=["generateur","antenne","conduit","tourelle","capaciteur","baril","emetteur"];
const BIOME_DECOR={
  earth:["rocher","tourelle","capaciteur","generateur","baril","antenne","arbre","epave","caisses"],
  volcanic:["lave","tourelle","capaciteur","generateur","baril","lave","rocher","epave","caisses"],
  spaceship:["generateur","conduit","capaciteur","tourelle","antenne","emetteur","baril","cristaux","container","caisses"],
  tech:["generateur","conduit","antenne","capaciteur","tourelle","emetteur","baril","cristaux","container","caisses"],
  desert:["arche","tourelle","capaciteur","generateur","baril","antenne","rocher","epave","caisses"],
  ice:["glace","tourelle","capaciteur","generateur","baril","conduit","cristaux","epave","caisses"],
  jungle:["plante","tourelle","capaciteur","generateur","baril","antenne","racines","arbre","epave","caisses"],
  swamp:["racines","tourelle","capaciteur","generateur","baril","conduit","plante","arbre","epave","caisses"],
  ruines:["epave","rocher","capaciteur","tourelle","epave","caisses","baril","container","cristaux"]};
const BIOME_BORDER={earth:["rocher","arbre"],volcanic:["lave","rocher"],desert:["arche","rocher"],
  ice:["glace","cristaux"],jungle:["arbre","racines"],swamp:["arbre","racines"],
  tech:["rocher","cristaux"],spaceship:["rocher","cristaux"],ruines:["rocher","cristaux"]};
const BORDER_SZ={rocher:210,arche:210,lave:175,glace:120,cristaux:110,arbre:200,racines:190};

function strhash(s){let h=2166136261>>>0;for(let i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619);}return h>>>0;}
function mulberry32(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;};}

// PropScatter: arena in 1000-unit chunks (CHUNK), ~PER_CHUNK props each, 1 hazard/chunk max,
// + a BORDER ring of oversized biome props walling the arena. Reproduced here so each map opens
// already decorated as in the game (positions are stable per biome, not a specific run's seed).
function generateBiome(b){
  const rnd=mulberry32(strhash("mecha:"+b));
  const kinds=BIOME_DECOR[b]||BIOME_DECOR.tech;
  const objs=[]; const CH=6, cell=1/CH, marg=170/ARENA;
  for(let cx=0;cx<CH;cx++)for(let cy=0;cy<CH;cy++){
    let haz=false;
    for(let k=0;k<2;k++){
      let kind=kinds[Math.floor(rnd()*kinds.length)];
      if(HAZARDS.indexOf(kind)>=0 && haz){const nh=kinds.filter(x=>HAZARDS.indexOf(x)<0);if(nh.length)kind=nh[Math.floor(rnd()*nh.length)];}
      if(HAZARDS.indexOf(kind)>=0)haz=true;
      const d=DEFS[kind];if(!d)continue;
      const nx=cx*cell+marg+rnd()*(cell-2*marg), ny=cy*cell+marg+rnd()*(cell-2*marg);
      const rs=0.82+rnd()*0.5;
      objs.push({a:d.f,nx:nx,ny:ny,s:(d.sz*rs)/ARENA,r:0,f:rnd()<0.5});
    }
  }
  const bk=BIOME_BORDER[b]||["rocher","arbre"], per=13, inset=0.022;
  for(let side=0;side<4;side++)for(let i=0;i<per;i++){
    const t=(i+0.5)/per; let nx,ny;
    if(side===0){nx=t;ny=inset;}else if(side===1){nx=1-inset;ny=t;}else if(side===2){nx=1-t;ny=1-inset;}else{nx=inset;ny=1-t;}
    const kind=bk[Math.floor(rnd()*bk.length)], d=DEFS[kind];if(!d)continue;
    const bsz=BORDER_SZ[kind]||d.sz*1.6, rs=0.9+rnd()*0.4;
    objs.push({a:d.f,nx:nx,ny:ny,s:(bsz*rs)/ARENA,r:0,f:rnd()<0.5});
  }
  return objs;
}
// first run (or new schema): open every map already decorated like the game
if(!S.initialized){ASSETS.biomes.forEach(b=>{S.layouts[b]=generateBiome(b);});S.initialized=true;try{localStorage.setItem(KEY,JSON.stringify(S));}catch(e){}}

function layout(){return S.layouts[S.biome];}

const IMG={};
function img(url){if(IMG[url])return IMG[url];const i=new Image();i.src=url;IMG[url]=i;return i;}
for(const b in ASSETS.grounds)img(ASSETS.grounds[b]);
for(const n in ASSETS.decor)img(ASSETS.decor[n].url);
for(const m in (ASSETS.mech||{}))img(ASSETS.mech[m]);

const cv=document.getElementById("cv"),ctx=cv.getContext("2d");
const W=cv.width,H=cv.height;
let mode="place", brush=null, sel=-1;
let dragging=false, dragMech=false, panning=false, dragDX=0, dragDY=0, panSX=0, panSY=0;
let groundPat=null, groundBiome=null;
const cam={zoom:1, cx:0.5, cy:0.5};

function clampCam(){const hwx=0.5/cam.zoom, hwy=0.5/cam.zoom;
  cam.cx = hwx>=0.5?0.5:Math.min(1-hwx,Math.max(hwx,cam.cx));
  cam.cy = hwy>=0.5?0.5:Math.min(1-hwy,Math.max(hwy,cam.cy));}
function w2s(nx,ny){return {x:(nx-cam.cx)*W*cam.zoom+W/2, y:(ny-cam.cy)*H*cam.zoom+H/2};}
function s2w(sx,sy){return {x:(sx-W/2)/(W*cam.zoom)+cam.cx, y:(sy-H/2)/(H*cam.zoom)+cam.cy};}

function buildGround(){const g=ASSETS.grounds[S.biome];if(!g){groundPat=null;return;}
  const im=img(g);if(!im.complete||!im.naturalWidth){groundPat=null;return;}
  groundPat=ctx.createPattern(im,"repeat");groundBiome=S.biome;}

function objScreen(o){const d=ASSETS.decor[o.a];if(!d)return null;const c=w2s(o.nx,o.ny);
  const M=Math.max(d.w,d.h), longPx=o.s*W*cam.zoom, k=longPx/M;
  return {c, w:d.w*k, h:d.h*k, d};}
function mechScreen(){const m=S.mech,im=ASSETS.mech?img(ASSETS.mech[m.chassis]):null;
  const asp=(im&&im.naturalWidth)?im.naturalWidth/im.naturalHeight:0.6;
  const c=w2s(m.nx,m.ny), h=m.hfrac*H*cam.zoom, w=h*asp; return {c,w,h,im};}

function draw(){
  ctx.clearRect(0,0,W,H);
  if(groundBiome!==S.biome||!groundPat)buildGround();
  if(groundPat){ctx.fillStyle=groundPat;ctx.fillRect(0,0,W,H);}else{ctx.fillStyle="#0a1220";ctx.fillRect(0,0,W,H);}
  // arena border + light grid, in world space
  const tl=w2s(0,0), br=w2s(1,1);
  ctx.save();ctx.strokeStyle="rgba(120,160,210,.13)";ctx.lineWidth=1;
  for(let i=1;i<8;i++){const gx=w2s(i/8,0).x, gy=w2s(0,i/8).y;
    ctx.beginPath();ctx.moveTo(gx,tl.y);ctx.lineTo(gx,br.y);ctx.moveTo(tl.x,gy);ctx.lineTo(br.x,gy);ctx.stroke();}
  ctx.strokeStyle="rgba(55,224,200,.45)";ctx.lineWidth=2;ctx.strokeRect(tl.x,tl.y,br.x-tl.x,br.y-tl.y);ctx.restore();
  const L=layout();
  for(let i=0;i<L.length;i++){const s=objScreen(L[i]);if(!s)continue;const o=L[i],im=img(s.d.url);
    if(!im.complete||!im.naturalWidth)continue;
    ctx.save();ctx.translate(s.c.x,s.c.y);ctx.rotate((o.r||0)*Math.PI/180);if(o.f)ctx.scale(-1,1);
    ctx.drawImage(im,-s.w/2,-s.h/2,s.w,s.h);ctx.restore();
    if(i===sel){ctx.save();ctx.translate(s.c.x,s.c.y);ctx.rotate((o.r||0)*Math.PI/180);
      ctx.strokeStyle="#37e0c8";ctx.lineWidth=1.5;ctx.setLineDash([5,4]);
      ctx.strokeRect(-s.w/2-2,-s.h/2-2,s.w+4,s.h+4);ctx.restore();}
  }
  drawMech();
  document.getElementById("count").textContent=L.length+" objet"+(L.length>1?"s":"");
  requestAnimationFrame(draw);
}
function drawMech(){const m=S.mech;if(!m.on||!ASSETS.mech)return;const b=mechScreen();
  if(!b.im||!b.im.complete||!b.im.naturalWidth)return;
  ctx.save();ctx.globalCompositeOperation="lighter";
  const g=ctx.createRadialGradient(b.c.x,b.c.y+b.h*0.42,0,b.c.x,b.c.y+b.h*0.42,b.w*0.6);
  g.addColorStop(0,"rgba(55,224,200,.20)");g.addColorStop(1,"rgba(55,224,200,0)");
  ctx.fillStyle=g;ctx.beginPath();ctx.ellipse(b.c.x,b.c.y+b.h*0.42,b.w*0.55,b.h*0.14,0,0,7);ctx.fill();ctx.restore();
  ctx.drawImage(b.im,b.c.x-b.w/2,b.c.y-b.h/2,b.w,b.h);
  ctx.save();ctx.fillStyle="rgba(55,224,200,.95)";ctx.font="bold 11px system-ui";ctx.textAlign="center";
  ctx.fillText("MECHA (repère)",b.c.x,b.c.y-b.h/2-6);ctx.restore();}
requestAnimationFrame(draw);

// ---- hit tests ----
function hit(px,py){const L=layout();
  for(let i=L.length-1;i>=0;i--){const s=objScreen(L[i]);if(!s)continue;const o=L[i];
    const dx=px-s.c.x, dy=py-s.c.y, a=-(o.r||0)*Math.PI/180;
    let lx=dx*Math.cos(a)-dy*Math.sin(a), ly=dx*Math.sin(a)+dy*Math.cos(a);
    if(o.f)lx=-lx;
    if(Math.abs(lx)<=s.w/2 && Math.abs(ly)<=s.h/2)return i;}
  return -1;}
function hitMech(px,py){if(!S.mech.on)return false;const b=mechScreen();
  return Math.abs(px-b.c.x)<=b.w/2 && Math.abs(py-b.c.y)<=b.h/2;}

// ---- pointer ----
function evPos(e){const r=cv.getBoundingClientRect();return {x:(e.clientX-r.left)/r.width*W, y:(e.clientY-r.top)/r.height*H};}
cv.addEventListener("pointerdown",e=>{const p=evPos(e);
  if(e.button===2)return;
  if(e.button===1 || mode==="view"){panning=true;cv.setPointerCapture(e.pointerId);panSX=p.x;panSY=p.y;return;}
  if(mode==="sel" && hitMech(p.x,p.y)){dragMech=true;cv.setPointerCapture(e.pointerId);
    const c=w2s(S.mech.nx,S.mech.ny);dragDX=p.x-c.x;dragDY=p.y-c.y;sel=-1;buildSel();return;}
  if(mode==="place" && brush){const w=s2w(p.x,p.y);
    layout().push({a:brush,nx:Math.min(1,Math.max(0,w.x)),ny:Math.min(1,Math.max(0,w.y)),s:PROP_S_GAME,r:0,f:false});
    sel=layout().length-1;buildSel();persist();return;}
  const i=hit(p.x,p.y);sel=i;buildSel();
  if(i>=0){dragging=true;cv.setPointerCapture(e.pointerId);const c=w2s(layout()[i].nx,layout()[i].ny);dragDX=p.x-c.x;dragDY=p.y-c.y;}
});
cv.addEventListener("pointermove",e=>{const p=evPos(e);
  if(panning){const dx=(p.x-panSX)/(W*cam.zoom), dy=(p.y-panSY)/(H*cam.zoom);cam.cx-=dx;cam.cy-=dy;clampCam();panSX=p.x;panSY=p.y;return;}
  if(dragMech){const w=s2w(p.x-dragDX,p.y-dragDY);S.mech.nx=Math.min(1,Math.max(0,w.x));S.mech.ny=Math.min(1,Math.max(0,w.y));return;}
  if(dragging&&sel>=0){const w=s2w(p.x-dragDX,p.y-dragDY);const o=layout()[sel];o.nx=Math.min(1,Math.max(0,w.x));o.ny=Math.min(1,Math.max(0,w.y));}
});
cv.addEventListener("pointerup",()=>{dragging=false;dragMech=false;panning=false;persist();});
cv.addEventListener("contextmenu",e=>{e.preventDefault();const p=evPos(e);const i=hit(p.x,p.y);
  if(i>=0){layout().splice(i,1);sel=-1;buildSel();persist();}});
cv.addEventListener("wheel",e=>{e.preventDefault();const p=evPos(e);const wpt=s2w(p.x,p.y);
  const f=Math.exp(-e.deltaY*0.0016);cam.zoom=Math.min(8,Math.max(1,cam.zoom*f));
  cam.cx=wpt.x-(p.x-W/2)/(W*cam.zoom);cam.cy=wpt.y-(p.y-H/2)/(H*cam.zoom);clampCam();syncZoom();},{passive:false});
window.addEventListener("keydown",e=>{if(sel<0)return;const o=layout()[sel];if(!o)return;
  if(e.key==="Delete"||e.key==="Backspace"){layout().splice(sel,1);sel=-1;buildSel();persist();e.preventDefault();}
  else if(e.key==="["){o.r=(o.r||0)-5;buildSel();persist();}
  else if(e.key==="]"){o.r=(o.r||0)+5;buildSel();persist();}
  else if(e.key==="+"||e.key==="="){o.s*=1.08;buildSel();persist();}
  else if(e.key==="-"){o.s/=1.08;buildSel();persist();}});

// ---- zoom UI ----
const zoomEl=document.getElementById("zoom");
function syncZoom(){zoomEl.value=cam.zoom.toFixed(1);document.getElementById("zlab").innerHTML="&times;"+cam.zoom.toFixed(1);}
zoomEl.addEventListener("input",e=>{const z=parseFloat(e.target.value);cam.zoom=z;clampCam();syncZoom();});
document.getElementById("fit").addEventListener("click",()=>{cam.zoom=1;cam.cx=0.5;cam.cy=0.5;clampCam();syncZoom();});

// ---- modes ----
function setMode(m){mode=m;cv.style.cursor=(m==="place")?"crosshair":(m==="view")?"grab":"default";
  document.getElementById("mode_place").classList.toggle("on",m==="place");
  document.getElementById("mode_sel").classList.toggle("on",m==="sel");
  document.getElementById("mode_view").classList.toggle("on",m==="view");}
document.getElementById("mode_place").addEventListener("click",()=>setMode("place"));
document.getElementById("mode_sel").addEventListener("click",()=>setMode("sel"));
document.getElementById("mode_view").addEventListener("click",()=>setMode("view"));

// ---- biome ----
const biomeEl=document.getElementById("biome");
ASSETS.biomes.forEach(b=>{const o=document.createElement("option");o.value=b;o.textContent=ASSETS.biome_label[b]||b;if(b===S.biome)o.selected=true;biomeEl.append(o);});
biomeEl.addEventListener("change",e=>{S.biome=e.target.value;sel=-1;groundPat=null;buildSel();persist();});

// ---- palette ----
function buildPalette(){const pal=document.getElementById("palette");pal.innerHTML="";
  const groups={};for(const n in ASSETS.decor){const g=ASSETS.decor[n].group;(groups[g]=groups[g]||[]).push(n);}
  const order=["Roches & terrain","Flore","Cristaux","Structures & debris","Features de biome","Divers (g##)","Autres"];
  const keys=Object.keys(groups).sort((a,b)=>{const ia=order.indexOf(a),ib=order.indexOf(b);return (ia<0?99:ia)-(ib<0?99:ib);});
  keys.forEach(g=>{const h=document.createElement("div");h.className="pgh";h.textContent=g;pal.append(h);
    const grid=document.createElement("div");grid.className="pgrid";
    groups[g].forEach(n=>{const c=document.createElement("div");c.className="pcell"+(brush===n?" on":"");c.dataset.n=n;
      const im=document.createElement("img");im.src=ASSETS.decor[n].url;im.alt=n;im.title=n;c.append(im);
      c.addEventListener("click",()=>{brush=n;setMode("place");buildBrush();
        pal.querySelectorAll(".pcell").forEach(x=>x.classList.toggle("on",x.dataset.n===n));});
      grid.append(c);});
    pal.append(grid);});}
function buildBrush(){const b=document.getElementById("brush");
  if(brush)b.innerHTML=`<img src="${ASSETS.decor[brush].url}"> ${brush}`;else b.innerHTML="<i>aucun objet</i>";}

// ---- selected object ----
function buildSel(){const box=document.getElementById("selbox");
  if(sel<0||!layout()[sel]){box.classList.remove("on");box.innerHTML="";return;}
  const o=layout()[sel];box.classList.add("on");box.innerHTML=`<h3>Objet : ${o.a}</h3>`;
  box.append(rowR("Taille","s",0.004,0.14,0.001,o.s,""));
  box.append(rowR("Rotation","r",-180,180,1,o.r||0,"&deg;"));
  const acts=document.createElement("div");acts.className="selacts";
  acts.innerHTML=`<button data-k="flip">&#8646; Miroir</button><button data-k="dup">&#10697; Dupliquer</button>
    <button data-k="front">&#9650; Devant</button><button data-k="back">&#9660; Derri&egrave;re</button>
    <button data-k="del" class="del">&#128465; Supprimer</button>`;
  acts.querySelectorAll("button").forEach(b=>b.addEventListener("click",()=>selAct(b.dataset.k)));box.append(acts);}
function rowR(label,key,min,max,step,val,unit){const d=document.createElement("div");d.className="row";
  d.innerHTML=`<label>${label}</label><input type="range" min="${min}" max="${max}" step="${step}" value="${val}"><output>${fmt(val)}${unit||""}</output>`;
  const out=d.querySelector("output");d.querySelector("input").addEventListener("input",e=>{
    const v=parseFloat(e.target.value);layout()[sel][key]=v;out.innerHTML=fmt(v)+(unit||"");persist();});return d;}
function fmt(v){return (Math.round(v*1000)/1000).toString();}
function selAct(k){const L=layout();if(sel<0)return;const o=L[sel];
  if(k==="flip")o.f=!o.f;
  else if(k==="dup"){const n=clone(o);n.nx=Math.min(1,n.nx+0.02);n.ny=Math.min(1,n.ny+0.02);L.push(n);sel=L.length-1;}
  else if(k==="front"){L.splice(sel,1);L.push(o);sel=L.length-1;}
  else if(k==="back"){L.splice(sel,1);L.unshift(o);sel=0;}
  else if(k==="del"){L.splice(sel,1);sel=-1;}
  buildSel();persist();}

// ---- mech reference ----
function buildMechBar(){const box=document.getElementById("mechbar");const m=S.mech;
  box.innerHTML=`<h3>&#129470; Mecha (rep&egrave;re de taille)</h3>`;
  const l1=document.createElement("label");l1.className="chk";
  l1.innerHTML=`<input type="checkbox" ${m.on?"checked":""}> Afficher le mecha sur la carte`;
  l1.querySelector("input").addEventListener("change",e=>{m.on=e.target.checked;persist();});box.append(l1);
  const c=document.createElement("div");c.className="mline";
  c.innerHTML=`<label>Ch&acirc;ssis</label><select>${Object.keys(ASSETS.mech||{}).map(k=>`<option value="${k}" ${k===m.chassis?"selected":""}>${MLAB[k]||k}</option>`).join("")}</select>`;
  c.querySelector("select").addEventListener("change",e=>{m.chassis=e.target.value;persist();});box.append(c);
  const sz=document.createElement("div");sz.className="mline";
  sz.innerHTML=`<label>Taille</label><input type="range" min="0.02" max="0.2" step="0.002" value="${m.hfrac}">`;
  sz.querySelector("input").addEventListener("input",e=>{m.hfrac=parseFloat(e.target.value);persist();});box.append(sz);
  const btn=document.createElement("button");btn.className="tbtn sm";btn.style.marginTop="6px";
  btn.textContent="↺ Taille réelle du jeu";
  btn.addEventListener("click",()=>{m.hfrac=MECH_HFRAC_GAME;buildMechBar();persist();});box.append(btn);
  const n=document.createElement("div");n.className="mnote";
  n.innerHTML="Ar&egrave;ne = 6000&times;6000 &middot; mecha ~6&nbsp;% (=&times;3,3 un objet standard). Mode <b>S&eacute;lection</b> pour le d&eacute;placer.";
  box.append(n);}

// ---- persist + actions ----
function persist(){try{localStorage.setItem(KEY,JSON.stringify(S));}catch(e){}}
document.getElementById("save").addEventListener("click",()=>{persist();flash("&#10003; Carte enregistr&eacute;e dans ce navigateur.");});
document.getElementById("regen").addEventListener("click",()=>{
  if(layout().length && !confirm("Remplacer la déco de ce biome par celle du jeu ? (tes ajouts seront perdus)"))return;
  S.layouts[S.biome]=generateBiome(S.biome);sel=-1;buildSel();persist();flash("&#9851; D&eacute;co du jeu recharg&eacute;e pour ce biome.");});
document.getElementById("clear").addEventListener("click",()=>{if(layout().length && !confirm("Vider toute la d&eacute;co de ce biome ?"))return;
  S.layouts[S.biome]=[];sel=-1;buildSel();persist();flash("Biome vid&eacute;.");});
document.getElementById("export").addEventListener("click",()=>{persist();const io=document.getElementById("io");
  const data={arene:ARENA,biome:S.biome,objets:layout(),mech:S.mech,tous:S.layouts};
  io.innerHTML=`<div class="msg">&#128203; Copie et colle-moi &ccedil;a :</div><textarea readonly>${JSON.stringify(data,null,2)}</textarea>`;io.querySelector("textarea").select();});
function flash(t){document.getElementById("io").innerHTML=`<div class="msg">${t}</div>`;}

buildPalette();buildBrush();buildSel();buildMechBar();setMode("place");syncZoom();
</script>
"""

HTML = HTML.replace("__ASSETS__", ASSETS_JSON)
dst = os.path.join(ROOT, "cine", "_show", "map_editor.html")
open(dst, "w", encoding="utf-8").write(HTML)
print("wrote", dst, "%.0f KB" % (os.path.getsize(dst) / 1024))
