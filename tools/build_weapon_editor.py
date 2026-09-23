# Builds cine/_show/weapon_editor.html : MECHA-CENTRIC weapon-effect optimizer.
# The mech is centered and can be AIMED/ROTATED 360 deg (drag on it, angle dial,
# direction buttons, or auto-rotate) so every weapon effect can be checked firing
# in any direction. Only the REAL visible things are tuned: the arm-cannon shot
# (projectile + muzzle + impact), the orbitals, and enemy shots. Lots of params.
# Values in GAME UNITS. Self-contained, localStorage save, JSON export.
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AS = json.load(open(os.path.join(ROOT, "cine", "_show", "_wpn_assets.json")))
ASSETS_JSON = json.dumps(AS, separators=(",", ":"))

TEXPX = {"drone": 96, "blade": 128, "orb": 112, "missile_gunner": 128, "missile_boss": 128,
         "cannon_shoulder": 204, "autocannon": 178, "railgun": 214, "plasmacaster": 178, "missilepod": 178}

DEFAULTS = {
  "chassis": "player",
  "aim": 90,            # firing direction, degrees (90 = down/toward viewer)
  "rotateMech": True,   # rotate the mech body with the aim
  "autoRotate": False,  # spin the aim continuously
  "arm": {
    "ox": 0.10, "oy": 0.05, "rate": 1.1,
    "proj": {"sheet": "bullet_tracer", "size": 1.0, "trail": 5, "tint": "#7fe6ff",
             "speed": 1.0, "spin": 0, "glow": 0.6, "count": 1, "spread": 12},
    "muzzle": {"sheet": "muzzle_aaa", "size": 1.0, "tint": "#ffd27f", "glow": 0.6},
  },
  "orbital": {
    "drone": {"on": True,  "count": 3, "scale": 0.46, "orbit_base": 158, "orbit_step": 26, "spin": 2.2, "dir": 1, "self_spin": 0, "glow": 0.4},
    "blade": {"on": False, "count": 3, "scale": 0.62, "orbit_base": 130, "orbit_step": 22, "spin": 3.4, "dir": 1, "self_spin": 6, "glow": 0.3},
    "orb":   {"on": False, "count": 2, "scale": 0.42, "scale_charge": 0.30, "orbit_base": 176, "orbit_step": 20, "spin": 0.9, "cycle": 1.6, "dir": 1, "self_spin": 2, "glow": 0.5},
  },
  "enemy": {
    "missile": {"on": False, "size": 1.0, "trail": 8, "tint": "#ff8a3c", "speed": 1.0, "glow": 0.5},
    "neon":    {"on": False, "size": 1.0, "trail": 14, "width": 16, "tint": "#7fe6ff", "speed": 1.0, "glow": 0.6},
  },
  "impact": {"sheet": "impact_aaa", "size": 1.0, "tint": "#7fe6ff", "glow": 0.7},
}

HTML = r"""<div id="app">
<header>
  <h1>MECHA-FORGE <span>&middot; Atelier d'armes</span></h1>
  <p class="sub">Le mecha au centre &mdash; <b>glisse dessus</b> (ou l'angle / rotation auto) pour le <b>faire pivoter dans toutes les directions</b>. Choisis un effet &agrave; droite, r&egrave;gle-le, puis <b>Exporter</b>.</p>
</header>

<main>
  <section class="stage">
    <canvas id="cv" width="560" height="560"></canvas>
    <div class="hint" id="hint">Glisse sur le mecha pour viser</div>
    <div class="ori">
      <button class="dbtn" data-a="270" title="Haut">&#9650;</button>
      <button class="dbtn" data-a="0" title="Droite">&#9654;</button>
      <button class="dbtn" data-a="90" title="Bas">&#9660;</button>
      <button class="dbtn" data-a="180" title="Gauche">&#9664;</button>
      <label class="auto"><input type="checkbox" id="auto"> rotation auto</label>
      <label class="auto"><input type="checkbox" id="rotm" checked> pivoter le mecha</label>
    </div>
  </section>

  <aside class="side">
    <div class="chas">
      <div class="row2"><label>Ch&acirc;ssis</label><select id="chassis"></select></div>
      <div class="row2"><label>Angle</label><input type="range" id="aim" min="0" max="359" step="1"><output id="aimo"></output></div>
    </div>
    <div class="list" id="list"></div>
    <section class="ctrls" id="ctrls"></section>
  </aside>
</main>

<footer>
  <button id="save">&#128190; Sauvegarder</button>
  <button id="reset">&#8635; D&eacute;faut</button>
  <button id="export" class="primary">&#128228; Exporter le JSON</button>
  <div id="io" class="io"></div>
</footer>
</div>

<style>
:root{--bg:#0a0e17;--bg2:#111827;--panel:#0f1522;--line:#1e2a3f;--line2:#26374f;
  --ink:#e7eefb;--dim:#8aa0c0;--accent:#37e0c8;--accent2:#7c5cff;--hot:#ff7a45;--gold:#ffcf5c;}
*{box-sizing:border-box}
#app{max-width:1120px;margin:0 auto;padding:20px 18px 40px;color:var(--ink);
  font:14px/1.5 ui-sans-serif,system-ui,"Segoe UI",Roboto,sans-serif}
body{background:radial-gradient(1200px 600px at 20% -10%,#16243b 0,transparent 60%),
  radial-gradient(900px 500px at 110% 10%,#1a1330 0,transparent 55%),var(--bg);}
header h1{margin:0;font-weight:800;letter-spacing:.4px;font-size:22px}
header h1 span{color:var(--accent);font-weight:600;font-size:15px;letter-spacing:1px}
.sub{margin:.35em 0 0;color:var(--dim)}
main{display:grid;grid-template-columns:minmax(320px,440px) 1fr;gap:16px;align-items:start;margin-top:16px}
@media(max-width:860px){main{grid-template-columns:1fr}}
.stage{background:radial-gradient(520px 480px at 50% 46%,#0e1830 0,#070b13 80%);
  border:1px solid var(--line);border-radius:16px;padding:14px;position:sticky;top:14px;overflow:hidden}
@media(max-width:860px){.stage{position:relative}}
.stage::before{content:"";position:absolute;inset:0;background-image:
  linear-gradient(rgba(80,120,180,.06) 1px,transparent 1px),
  linear-gradient(90deg,rgba(80,120,180,.06) 1px,transparent 1px);background-size:28px 28px;pointer-events:none}
#cv{width:100%;height:auto;display:block;border-radius:10px;cursor:grab;touch-action:none}
#cv:active{cursor:grabbing}
.hint{position:absolute;left:16px;top:12px;color:var(--dim);font-size:11px;
  background:rgba(8,12,20,.7);padding:4px 9px;border-radius:7px;border:1px solid var(--line)}
.ori{position:absolute;left:12px;bottom:12px;display:flex;gap:6px;align-items:center;flex-wrap:wrap}
.dbtn{width:30px;height:30px;border-radius:8px;background:rgba(10,16,26,.85);border:1px solid var(--line2);
  color:var(--accent);cursor:pointer;font-size:12px;line-height:1}
.dbtn:hover{border-color:var(--accent)}
.ori .auto{display:flex;align-items:center;gap:5px;color:var(--dim);font-size:11px;
  background:rgba(10,16,26,.85);border:1px solid var(--line);border-radius:8px;padding:5px 8px;cursor:pointer}
.ori .auto input{width:14px;height:14px;accent-color:var(--accent)}
.side{display:flex;flex-direction:column;gap:12px}
.chas{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:12px}
.row2{display:grid;grid-template-columns:56px 1fr auto;gap:10px;align-items:center;margin:6px 0}
.row2 label{color:var(--dim);font-size:12px}
.row2 output{font-variant-numeric:tabular-nums;font-size:12px;min-width:34px;text-align:right}
.list{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:6px 10px 12px}
.gh{font-size:11px;letter-spacing:.6px;text-transform:uppercase;color:var(--dim);margin:12px 4px 6px}
.wrow{display:flex;align-items:center;gap:9px;padding:8px 10px;border-radius:9px;cursor:pointer;border:1px solid transparent;transition:.12s}
.wrow:hover{background:#0d1728}
.wrow.sel{background:#12263c;border-color:var(--accent);box-shadow:0 0 0 1px rgba(55,224,200,.2)}
.wrow input{width:16px;height:16px;accent-color:var(--accent);cursor:pointer;flex:none}
.wrow .wn{font-weight:600;font-size:13px}
.wrow .dot{width:8px;height:8px;border-radius:50%;flex:none;margin-left:auto}
select{width:100%;background:var(--bg2);color:var(--ink);border:1px solid var(--line2);border-radius:8px;padding:8px;font-size:13px}
.ctrls{background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:6px 16px 16px;min-height:60px}
.ctitle{display:flex;align-items:center;gap:10px;margin:12px 2px 4px;font-weight:700;font-size:15px}
.ctitle .pill{font-size:11px;font-weight:600;color:#0a0e17;background:var(--accent);padding:2px 8px;border-radius:20px}
.cgrid{display:grid;grid-template-columns:1fr 1fr;gap:0 26px}
@media(max-width:680px){.cgrid{grid-template-columns:1fr}}
.sub3{border-top:1px solid var(--line);padding:8px 0 2px;margin-top:8px}
.sub3 h4{margin:4px 0 2px;font-size:12px;letter-spacing:.4px;text-transform:uppercase;color:var(--accent2)}
.row{display:grid;grid-template-columns:96px 1fr 50px;align-items:center;gap:10px;margin:7px 0}
.row label{color:var(--dim);font-size:12px}
.row output{font-variant-numeric:tabular-nums;text-align:right;font-size:12px}
input[type=range]{-webkit-appearance:none;appearance:none;height:5px;border-radius:5px;
  background:linear-gradient(90deg,var(--accent),var(--accent2));outline:none;width:100%}
input[type=range]::-webkit-slider-thumb{-webkit-appearance:none;width:16px;height:16px;border-radius:50%;
  background:#fff;border:2px solid var(--accent);cursor:pointer;box-shadow:0 2px 6px rgba(0,0,0,.5)}
input[type=color]{width:100%;height:26px;border:1px solid var(--line2);border-radius:7px;background:none;cursor:pointer;padding:2px}
.chk{display:flex;align-items:center;gap:8px;color:var(--dim);font-size:12px;cursor:pointer;margin:8px 0}
.chk input{width:16px;height:16px;accent-color:var(--accent)}
.hintbox{color:var(--dim);font-size:13px;padding:10px 4px 2px}
footer{display:flex;gap:10px;align-items:center;margin-top:16px;flex-wrap:wrap}
footer button{background:var(--bg2);color:var(--ink);border:1px solid var(--line2);border-radius:10px;padding:10px 16px;cursor:pointer;font-weight:600;font-size:13px}
footer button:hover{border-color:var(--accent)}
footer button.primary{background:linear-gradient(180deg,#1f8f7f,#146356);border-color:var(--accent);color:#fff}
.io{flex-basis:100%;margin-top:6px}
.io textarea{width:100%;height:150px;background:#070b13;color:#9fe;border:1px solid var(--line2);border-radius:10px;padding:10px;font:12px/1.45 ui-monospace,Menlo,Consolas,monospace;resize:vertical}
.io .msg{color:var(--accent);font-size:12px;margin:6px 2px}
</style>

<script>
const ASSETS=__ASSETS__, TEXPX=__TEXPX__, DEF=__DEFAULTS__;
const KEY="mf_weapons_v4";
const clone=o=>JSON.parse(JSON.stringify(o));
function deepMerge(a,b){for(const k in b){if(b[k]&&typeof b[k]==="object"&&!Array.isArray(b[k])){a[k]=deepMerge(a[k]||{},b[k]);}else a[k]=b[k];}return a;}
let S=clone(DEF);
try{const j=localStorage.getItem(KEY);if(j)S=deepMerge(clone(DEF),JSON.parse(j));}catch(e){}

const IMG={};
function src2url(s){return (typeof s==="string"&&s.slice(0,5)!=="data:")?"data:image/png;base64,"+s:s;}
function img(src){src=src2url(src);if(IMG[src])return IMG[src];const i=new Image();i.src=src;IMG[src]=i;return i;}
for(const k in ASSETS.sprites)img(ASSETS.sprites[k]);
for(const k in ASSETS.sheets)img(ASSETS.sheets[k].png);
for(const k in ASSETS.mech)img(ASSETS.mech[k]);

const _off=document.createElement("canvas"),_oc=_off.getContext("2d");
function tinted(im,sx,sy,sw,sh,w,h,tint){_off.width=Math.max(1,w|0);_off.height=Math.max(1,h|0);
  _oc.clearRect(0,0,_off.width,_off.height);_oc.globalCompositeOperation="source-over";
  _oc.drawImage(im,sx,sy,sw,sh,0,0,_off.width,_off.height);
  _oc.globalCompositeOperation="multiply";_oc.fillStyle=tint;_oc.fillRect(0,0,_off.width,_off.height);
  _oc.globalCompositeOperation="destination-in";_oc.drawImage(im,sx,sy,sw,sh,0,0,_off.width,_off.height);
  _oc.globalCompositeOperation="source-over";return _off;}
function sheetFrame(name){const s=ASSETS.sheets[name];const fw=Math.round(img(s.png).naturalWidth/s.frames)||s.fh;return {s,im:img(s.png),fw,fh:s.fh,n:s.frames};}
function hx(h){h=h.replace("#","");return[parseInt(h.slice(0,2),16),parseInt(h.slice(2,4),16),parseInt(h.slice(4,6),16)];}
function hexA(h,a){const c=hx(h);return`rgba(${c[0]},${c[1]},${c[2]},${a})`;}

const cv=document.getElementById("cv"),ctx=cv.getContext("2d");
const CX=cv.width/2,CY=cv.height/2,PXU=0.52,MECH_H=360;
let T=0,SEL="arm";

function addAt(t,x,y){ctx.save();ctx.globalCompositeOperation="lighter";ctx.drawImage(t,x,y);ctx.restore();}
function glow(x,y,r,tint,a){if(a<=0)return;ctx.save();ctx.globalCompositeOperation="lighter";
  const g=ctx.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,hexA(tint,a));g.addColorStop(1,hexA(tint,0));
  ctx.fillStyle=g;ctx.beginPath();ctx.arc(x,y,r,0,7);ctx.fill();ctx.restore();}

function drawMech(ch){const im=img(ASSETS.mech[ch]||ASSETS.mech.player);if(!im.complete||!im.naturalWidth)return;
  const h=MECH_H*PXU,w=h*(im.naturalWidth/im.naturalHeight);
  ctx.save();ctx.translate(CX,CY);
  if(S.rotateMech)ctx.rotate((S.aim-90)*Math.PI/180);  // 90=down = sprite as-is
  ctx.drawImage(im,-w/2,-h/2,w,h);ctx.restore();}

function aimVec(){const a=S.aim*Math.PI/180;return {a,dx:Math.cos(a),dy:Math.sin(a),px:-Math.sin(a),py:Math.cos(a)};}

// ARM shot: fires along the aim from a muzzle point on the arm (ox=forward, oy=lateral)
function renderArm(){
  const A=S.arm,v=aimVec(),mh=MECH_H*PXU;
  const mx=CX+v.dx*(A.ox*mh)+v.px*(A.oy*mh);
  const my=CY+v.dy*(A.ox*mh)+v.py*(A.oy*mh);
  const range=CX*0.92, rate=A.rate;
  const f=sheetFrame(A.proj.sheet),fr=Math.floor(T*18)%f.n,pw=f.fh*A.proj.size;
  const count=Math.max(1,A.proj.count|0),spread=A.proj.spread*Math.PI/180;
  for(let s=0;s<count;s++){
    const off=count>1?(s-(count-1)/2)*spread/(count-1||1):0;
    const ca=Math.cos(off),sa=Math.sin(off);
    const ddx=v.dx*ca - v.dy*sa, ddy=v.dx*sa + v.dy*ca;   // aim rotated by off
    const cyc=((T*rate + s*0.13)%1);
    const frac=Math.min(1,cyc*A.proj.speed);
    const px=mx+ddx*frac*range, py=my+ddy*frac*range;
    const ang=Math.atan2(ddy,ddx)+T*A.proj.spin;
    glow(px,py,pw*1.4*A.proj.glow+2,A.proj.tint,0.5*A.proj.glow);
    ctx.save();ctx.translate(px,py);ctx.rotate(ang);
    addAt(tinted(f.im,fr*f.fw,0,f.fw,f.fh,pw,pw,A.proj.tint),-pw/2,-pw/2);ctx.restore();
    // trail behind along -dir
    for(let k=A.proj.trail;k>=1;k--){const tx=px-ddx*k*pw*0.42,ty=py-ddy*k*pw*0.42,al=0.4*(1-k/(A.proj.trail+1));
      const sz=pw*(1-k*0.06);ctx.save();ctx.globalAlpha=al;ctx.translate(tx,ty);ctx.rotate(ang);
      addAt(tinted(f.im,fr*f.fw,0,f.fw,f.fh,sz,sz,A.proj.tint),-sz/2,-sz/2);ctx.restore();}
    if(cyc>0.86){const g=sheetFrame(S.impact.sheet),gf=Math.floor((cyc-0.86)/0.14*g.n)%g.n,iw=g.fh*1.4*S.impact.size;
      const ix=mx+ddx*range,iy=my+ddy*range;glow(ix,iy,iw*0.6*S.impact.glow+3,S.impact.tint,0.5*S.impact.glow);
      addAt(tinted(g.im,gf*g.fw,0,g.fw,g.fh,iw,iw,S.impact.tint),ix-iw/2,iy-iw/2);}
  }
  // muzzle flash + glow at the arm on cadence
  const mc=(T*rate)%1;
  if(mc<0.16){const m=sheetFrame(A.muzzle.sheet),mf=Math.floor(mc/0.16*m.n)%m.n,mw=m.fh*1.3*A.muzzle.size;
    glow(mx,my,mw*0.55*A.muzzle.glow+3,A.muzzle.tint,0.6*A.muzzle.glow);
    ctx.save();ctx.translate(mx,my);ctx.rotate(v.a);
    addAt(tinted(m.im,mf*m.fw,0,m.fw,m.fh,mw,mw,A.muzzle.tint),-mw*0.2,-mw/2);ctx.restore();}
  if(SEL==="arm"){ctx.save();ctx.strokeStyle=hexA("#37e0c8",.9);ctx.lineWidth=1.5;
    ctx.beginPath();ctx.arc(mx,my,7,0,7);ctx.moveTo(mx-11,my);ctx.lineTo(mx+11,my);ctx.moveTo(mx,my-11);ctx.lineTo(mx,my+11);ctx.stroke();
    ctx.strokeStyle=hexA("#37e0c8",.35);ctx.beginPath();ctx.moveTo(mx,my);ctx.lineTo(mx+v.dx*40,my+v.dy*40);ctx.stroke();ctx.restore();}
}

function orbSprite(name,gs){return {im:img(ASSETS.sprites[name]),size:(TEXPX[name]||96)*gs*PXU};}
function renderOrbGroup(key,o){
  if(!o.on)return;
  const dir=o.dir||1,imm=img(ASSETS.sprites[key==="orb"?"orb":key]),sp=orbSprite(key,o.scale);
  for(let i=0;i<o.count;i++){
    const a=dir*T*o.spin + i*(Math.PI*2/Math.max(1,o.count)),r=(o.orbit_base+(i%3)*o.orbit_step)*PXU;
    const x=CX+Math.cos(a)*r,y=CY+Math.sin(a)*r;
    let sz=sp.size, alpha=1, self=(o.self_spin||0)*T;
    if(key==="orb"){const cyc=(T+i*0.5)%o.cycle,op=1-Math.min(1,(o.cycle-cyc)/o.cycle);
      sz=(TEXPX.orb*(o.scale+o.scale_charge*op))*PXU;alpha=0.72+0.28*op;
      if(op>0.92)glow(x,y,sz*1.4,"#7fe6ff",0.6);}
    if(key==="blade")self=a+Math.PI/2+(o.self_spin||0)*T*0.0;
    glow(x,y,sz*0.9*(o.glow||0),DOTS[key],0.5*(o.glow||0));
    ctx.save();ctx.translate(x,y);ctx.globalAlpha=alpha;
    if(key==="blade")ctx.rotate(a+Math.PI/2);else ctx.rotate(self);
    if(imm.complete&&imm.naturalWidth)ctx.drawImage(imm,-sz/2,-sz/2,sz,sz);ctx.restore();ctx.globalAlpha=1;
  }
}
function renderEnemy(){
  const e=S.enemy;
  if(e.missile.on){const m=e.missile,im=img(ASSETS.sprites.missile_gunner);const cyc=(T*0.5*m.speed)%1;
    const sx=CX+CX*0.9,ex=CX+50,x=sx-cyc*(sx-ex),y=CY-46,w=48*m.size;
    ctx.save();ctx.globalCompositeOperation="lighter";
    for(let k=1;k<=m.trail;k++){ctx.globalAlpha=0.5*(1-k/m.trail);ctx.beginPath();
      ctx.arc(x+k*7,y+Math.sin(T*10+k)*2,w*0.26*(1-k/m.trail*0.5),0,7);ctx.fillStyle=m.tint;ctx.fill();}
    ctx.restore();ctx.globalAlpha=1;glow(x,y,w*0.8*m.glow,m.tint,0.5*m.glow);
    ctx.save();ctx.translate(x,y);ctx.rotate(Math.PI);
    if(im.complete&&im.naturalWidth)ctx.drawImage(im,-w/2,-w/2,w,w);ctx.restore();
    if(cyc>0.9){const g=sheetFrame(S.impact.sheet),fr=Math.floor((cyc-0.9)/0.1*g.n)%g.n,iw=g.fh*1.2*S.impact.size;
      addAt(tinted(g.im,fr*g.fw,0,g.fw,g.fh,iw,iw,S.impact.tint),ex-iw/2,y-iw/2);}}
  if(e.neon.on){const n=e.neon;const cyc=(T*0.55*n.speed)%1;const sx=CX+CX*0.85,sy=CY-CY*0.75,ex=CX+40,ey=CY-30;
    const x=sx+(ex-sx)*cyc,y=sy+(ey-sy)*cyc,ang=Math.atan2(ey-sy,ex-sx),len=n.trail*7*n.size,pulse=0.7+0.3*Math.sin(T*12);
    glow(x,y,n.width*n.size*1.4*n.glow,n.tint,0.5*n.glow);
    ctx.save();ctx.globalCompositeOperation="lighter";ctx.translate(x,y);ctx.rotate(ang);
    const g=ctx.createLinearGradient(-len,0,0,0);g.addColorStop(0,hexA(n.tint,0));g.addColorStop(1,hexA(n.tint,.95));
    ctx.strokeStyle=g;ctx.lineCap="round";ctx.lineWidth=n.width*n.size*pulse;ctx.beginPath();ctx.moveTo(-len,0);ctx.lineTo(0,0);ctx.stroke();
    ctx.beginPath();ctx.arc(0,0,n.width*0.6*n.size*pulse,0,7);ctx.fillStyle=hexA(n.tint,1);ctx.fill();
    ctx.beginPath();ctx.arc(0,0,n.width*0.32*n.size,0,7);ctx.fillStyle="rgba(255,255,255,.9)";ctx.fill();ctx.restore();}
}
function frame(ts){T=ts/1000;
  if(S.autoRotate){S.aim=(S.aim+0.8)%360;const el=document.getElementById("aim");if(el){el.value=S.aim|0;document.getElementById("aimo").textContent=(S.aim|0)+"&deg;";}}
  ctx.clearRect(0,0,cv.width,cv.height);
  drawMech(S.chassis);
  renderArm();
  renderOrbGroup("drone",S.orbital.drone);renderOrbGroup("blade",S.orbital.blade);renderOrbGroup("orb",S.orbital.orb);
  renderEnemy();
  requestAnimationFrame(frame);}
requestAnimationFrame(frame);

// ---- aim interactions: drag on canvas, dial buttons, slider, auto/rotate toggles ----
function setAim(deg){S.aim=((deg%360)+360)%360;const el=document.getElementById("aim");el.value=S.aim|0;document.getElementById("aimo").innerHTML=(S.aim|0)+"&deg;";}
function ptrAngle(ev){const r=cv.getBoundingClientRect();const cx=r.left+r.width/2,cy=r.top+r.height/2;
  return Math.atan2(ev.clientY-cy,ev.clientX-cx)*180/Math.PI;}
let dragging=false;
cv.addEventListener("pointerdown",e=>{dragging=true;cv.setPointerCapture(e.pointerId);setAim(ptrAngle(e));});
cv.addEventListener("pointermove",e=>{if(dragging)setAim(ptrAngle(e));});
cv.addEventListener("pointerup",()=>dragging=false);
document.querySelectorAll(".dbtn").forEach(b=>b.addEventListener("click",()=>setAim(parseFloat(b.dataset.a))));
document.getElementById("auto").addEventListener("change",e=>S.autoRotate=e.target.checked);
document.getElementById("rotm").addEventListener("change",e=>S.rotateMech=e.target.checked);
const aimEl=document.getElementById("aim");aimEl.value=S.aim|0;document.getElementById("aimo").innerHTML=(S.aim|0)+"&deg;";
aimEl.addEventListener("input",e=>setAim(parseFloat(e.target.value)));
document.getElementById("auto").checked=S.autoRotate;document.getElementById("rotm").checked=S.rotateMech;

// ---- panel ----
const listEl=document.getElementById("list"),ctrlsEl=document.getElementById("ctrls"),chassisEl=document.getElementById("chassis");
function get(p){return p.split(".").reduce((o,k)=>o[k],S);}
function set(p,v){const ks=p.split(".");let o=S;for(let i=0;i<ks.length-1;i++)o=o[ks[i]];o[ks[ks.length-1]]=v;}
function fmt(v){return (Math.round(v*100)/100).toString();}
[["player","Joueur"],["base","Base"],["colosse","Colosse"],["broyeur","Broyeur"],["souverain","Souverain"]].forEach(x=>{
  const o=document.createElement("option");o.value=x[0];o.textContent=x[1];if(x[0]===S.chassis)o.selected=true;chassisEl.append(o);});
chassisEl.addEventListener("change",e=>S.chassis=e.target.value);

const LABELS={arm:"Tir du bras (arme principale)",drone:"Drone",blade:"Lame orbitale",orb:"Orbe charge/d&eacute;charge",missile:"Missile ennemi",neon:"Bolt n&eacute;on ennemi"};
const DOTS={arm:"#7fe6ff",drone:"#5cf0ff",blade:"#ffcf5c",orb:"#7c5cff",missile:"#ff8a3c",neon:"#7fe6ff"};

function wrow(sel,key,hasOn){const on=hasOn?get(sel+".on"):true;
  const d=document.createElement("div");d.className="wrow"+(SEL===sel?" sel":"");
  const cb=hasOn?`<input type="checkbox" ${on?"checked":""} title="Afficher">`:`<span style="width:16px"></span>`;
  d.innerHTML=`${cb}<span class="wn">${LABELS[key]||key}</span><span class="dot" style="background:${DOTS[key]||"#37e0c8"}"></span>`;
  if(hasOn)d.querySelector("input").addEventListener("click",e=>{e.stopPropagation();set(sel+".on",e.target.checked);});
  d.addEventListener("click",()=>{SEL=sel;if(hasOn)set(sel+".on",true);render();});
  return d;}
function gh(t){const d=document.createElement("div");d.className="gh";d.textContent=t;return d;}
function buildList(){listEl.innerHTML="";
  listEl.append(gh("Arme du mecha (bras)"));listEl.append(wrow("arm","arm",false));
  listEl.append(gh("Orbitales"));["drone","blade","orb"].forEach(k=>listEl.append(wrow("orbital."+k,k,true)));
  listEl.append(gh("Tirs ennemis"));["missile","neon"].forEach(k=>listEl.append(wrow("enemy."+k,k,true)));}

function R(label,path,min,max,step,unit){const v=get(path),d=document.createElement("div");d.className="row";
  d.innerHTML=`<label>${label}</label><input type="range" min="${min}" max="${max}" step="${step}" value="${v}"><output>${fmt(v)}${unit||""}</output>`;
  const o=d.querySelector("output");d.querySelector("input").addEventListener("input",e=>{set(path,parseFloat(e.target.value));o.innerHTML=fmt(parseFloat(e.target.value))+(unit||"");});return d;}
function C(label,path){const d=document.createElement("div");d.className="row";
  d.innerHTML=`<label>${label}</label><input type="color" value="${get(path)}"><span></span>`;
  d.querySelector("input").addEventListener("input",e=>set(path,e.target.value));return d;}
function CHK(label,path){const l=document.createElement("label");l.className="chk";
  l.innerHTML=`<input type="checkbox" ${get(path)?"checked":""}> ${label}`;
  l.querySelector("input").addEventListener("change",e=>set(path,e.target.checked));return l;}
function SELE(label,path,opts){const d=document.createElement("div");d.className="row";d.style.gridTemplateColumns="96px 1fr";
  d.innerHTML=`<label>${label}</label><select>${opts.map(x=>`<option value="${x[0]}" ${x[0]===get(path)?"selected":""}>${x[1]}</option>`).join("")}</select>`;
  d.querySelector("select").addEventListener("change",e=>set(path,e.target.value));return d;}
function DIR(label,path){const d=document.createElement("div");d.className="row";d.style.gridTemplateColumns="96px 1fr";
  const v=get(path);d.innerHTML=`<label>${label}</label><select><option value="1" ${v===1?"selected":""}>Horaire</option><option value="-1" ${v===-1?"selected":""}>Anti-horaire</option></select>`;
  d.querySelector("select").addEventListener("change",e=>set(path,parseInt(e.target.value)));return d;}
function sub(t){const d=document.createElement("div");d.className="sub3";d.innerHTML=`<h4>${t}</h4>`;return d;}

const MZ=[["muzzle_aaa","AAA"],["muzzle_hq","HQ"],["muzzle_dp","DP"]];
const BUL=[["bullet_tracer","Tracer"],["bullet_warhead","Ogive"],["bullet_orb","Orbe"],["bullet_lance","Lance"]];
const IMP=[["impact_aaa","AAA"],["impact_hq","HQ"],["explosion","Explosion"]];

function col(){return document.createElement("div");}
function buildCtrls(){
  ctrlsEl.innerHTML="";const parts=SEL.split("."),grp=parts[0],key=parts[1];
  const title=document.createElement("div");title.className="ctitle";
  const pill=grp==="arm"?"Arme du mecha":grp==="orbital"?"Orbitale":"Tir ennemi";
  title.innerHTML=`<span>${LABELS[grp==="arm"?"arm":key]||key}</span><span class="pill">${pill}</span>`;
  ctrlsEl.append(title);
  const g=document.createElement("div");g.className="cgrid";const c1=col(),c2=col();

  if(grp==="arm"){const b="arm";
    const n=document.createElement("div");n.className="hintbox";
    n.innerHTML="Seul canon visible = le bras. Aligne le <b>point de tir</b>, puis r&egrave;gle le <b>projectile</b>, le <b>flash</b> et l'<b>impact</b> qui en sortent. Fais pivoter le mecha pour v&eacute;rifier dans toutes les directions.";
    ctrlsEl.append(n);
    c1.append(sub("Point de tir (bras)"),
      R("Avance",b+".ox",-0.5,0.5,0.005),R("Lat&eacute;ral",b+".oy",-0.5,0.5,0.005),R("Cadence",b+".rate",0.4,3,0.1,"/s"),
      sub("Salve"),R("Nb projectiles",b+".proj.count",1,7,1),R("&Eacute;cart salve",b+".proj.spread",0,60,1,"&deg;"),
      sub("Flash de bouche"),SELE("Style",b+".muzzle.sheet",MZ),R("Taille",b+".muzzle.size",0.4,2.2,0.05,"&times;"),R("Halo",b+".muzzle.glow",0,1.5,0.05),C("Teinte",b+".muzzle.tint"));
    c2.append(sub("Projectile"),SELE("Style",b+".proj.sheet",BUL),R("Taille",b+".proj.size",0.4,2.4,0.05,"&times;"),
      R("Vitesse",b+".proj.speed",0.3,3,0.05,"&times;"),R("Tra&icirc;n&eacute;e",b+".proj.trail",0,12,1,"pts"),
      R("Rotation",b+".proj.spin",-8,8,0.2,"/s"),R("Halo",b+".proj.glow",0,1.5,0.05),C("Teinte",b+".proj.tint"));
  } else if(grp==="orbital"){const b="orbital."+key;
    ctrlsEl.append(CHK("Afficher cette orbitale",b+".on"));
    c1.append(sub("Orbite"),R("Nombre",b+".count",1,6,1),R("Rayon base",b+".orbit_base",70,260,1,"u"),
      R("&Eacute;cart/anneau",b+".orbit_step",0,60,1,"u"),R("Vitesse orbite",b+".spin",0.2,7,0.1),DIR("Sens",b+".dir"));
    c2.append(sub("Aspect"),R("Taille",b+".scale",0.2,1.4,0.01,"&times;"),R("Rotation propre",b+".self_spin",-10,10,0.2,"/s"),R("Halo",b+".glow",0,1.5,0.05));
    if(key==="orb")c2.append(sub("Charge/d&eacute;charge"),R("Gonfle charge",b+".scale_charge",0,0.8,0.01,"&times;"),R("Cycle",b+".cycle",0.6,3,0.1,"s"));
  } else {const b="enemy."+key;
    ctrlsEl.append(CHK("Afficher ce tir ennemi",b+".on"));
    c1.append(sub("Projectile"),R("Taille",b+".size",0.5,2.4,0.05,"&times;"),R("Vitesse",b+".speed",0.3,3,0.05,"&times;"),R("Tra&icirc;n&eacute;e",b+".trail",2,28,1,"pts"));
    if(key==="neon")c1.append(R("&Eacute;paisseur",b+".width",6,32,1,"px"));
    c2.append(sub("Aspect"),R("Halo",b+".glow",0,1.5,0.05),C("Teinte",b+".tint"));
  }
  g.append(c1,c2);ctrlsEl.append(g);
  const imp=document.createElement("div");imp.append(sub("Impact (commun &agrave; tous les tirs)"),
    SELE("Style","impact.sheet",IMP),R("Taille","impact.size",0.4,2.6,0.05,"&times;"),R("Halo","impact.glow",0,1.5,0.05),C("Teinte","impact.tint"));
  ctrlsEl.append(imp);
}
function render(){buildList();buildCtrls();}

document.getElementById("save").addEventListener("click",()=>{localStorage.setItem(KEY,JSON.stringify(S));flash("&#10003; Sauvegard&eacute; dans ce navigateur.");});
document.getElementById("reset").addEventListener("click",()=>{S=clone(DEF);setAim(S.aim);document.getElementById("auto").checked=S.autoRotate;document.getElementById("rotm").checked=S.rotateMech;render();flash("R&eacute;initialis&eacute;.");});
document.getElementById("export").addEventListener("click",()=>{localStorage.setItem(KEY,JSON.stringify(S));
  const io=document.getElementById("io");io.innerHTML=`<div class="msg">&#128203; Copie tout &ccedil;a et colle-le moi :</div><textarea readonly>${JSON.stringify(S,null,2)}</textarea>`;io.querySelector("textarea").select();});
function flash(t){document.getElementById("io").innerHTML=`<div class="msg">${t}</div>`;}
render();
</script>
"""

HTML = (HTML.replace("__ASSETS__", ASSETS_JSON)
            .replace("__TEXPX__", json.dumps(TEXPX))
            .replace("__DEFAULTS__", json.dumps(DEFAULTS)))
dst = os.path.join(ROOT, "cine", "_show", "weapon_editor.html")
open(dst, "w", encoding="utf-8").write(HTML)
print("wrote", dst, "%.0f KB" % (os.path.getsize(dst) / 1024))
