# -*- coding: utf-8 -*-
"""Optimiseur de boucliers (v3, ANIME comme le jeu) : replique EXACTEMENT l'animation en jeu
(pulse sin(t*4), couches contra-rotatives +0.5/-0.22, cycle aura 0.7s + flash + breathe, ordre
des couches par porteur). Reglages par porteur, sauvegarde localStorage + export."""
import json

A = json.load(open("cine/_show/_sh_assets.json"))
BEARERS = [
    ("player", "Aura joueur"), ("base", "Ennemis blindes"),
    ("colosse", "Colosse"), ("broyeur", "Broyeur Titan"), ("souverain", "Souverain"),
]
STYLES = ["hex", "bubble", "plated", "electric", "runic"]

def mech(k): return "data:image/png;base64," + A["mech"][k]
def shield(k): return "data:image/jpeg;base64," + A["shield"][k]

DEFAULTS = {
    "player": {"style": "bubble", "w": 1.93, "h": 2.09, "ox": -0.01, "oy": -0.02, "rot": 0, "tint": "#6ad0ff", "bright": 1.0, "backA": 0.4, "frontA": 0.55, "gap": 1.06},
    "base": {"style": "hex", "w": 1.52, "h": 1.77, "ox": 0.0, "oy": -0.05, "rot": 0, "tint": "#6ad0ff", "bright": 1.0, "backA": 0.35, "frontA": 0.55, "gap": 1.05},
    "colosse": {"style": "plated", "w": 1.64, "h": 1.89, "ox": 0.0, "oy": -0.05, "rot": 0, "tint": "#ffbe37", "bright": 1.0, "backA": 0.35, "frontA": 0.55, "gap": 1.05},
    "broyeur": {"style": "electric", "w": 1.43, "h": 1.95, "ox": 0.0, "oy": -0.04, "rot": 0, "tint": "#ff7a45", "bright": 1.05, "backA": 0.37, "frontA": 0.58, "gap": 1.05},
    "souverain": {"style": "runic", "w": 1.35, "h": 1.73, "ox": 0.0, "oy": -0.05, "rot": 0, "tint": "#e055c0", "bright": 1.0, "backA": 0.35, "frontA": 0.55, "gap": 1.05},
}

cards = "".join('<div class="cell" data-b="%s"><canvas id="cv_%s" width="230" height="230"></canvas><div class="cap">%s</div></div>' % (k, k, n) for k, n in BEARERS)
imgs = "".join('<img id="m_%s" src="%s" style="display:none">' % (k, mech(k)) for k, _ in BEARERS)
imgs += "".join('<img id="s_%s" src="%s" style="display:none">' % (s, shield(s)) for s in STYLES)

CSS = """
:root{--bg:#0b0e13;--panel:#141922;--line:#242d3a;--txt:#e7eaf0;--dim:#8b93a6;--acc:#39d0ff}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--txt);font-family:"Segoe UI",system-ui,sans-serif}
header{padding:18px 20px 4px;text-align:center}h1{margin:0;font-size:21px}.sub{color:var(--dim);font-size:14px;margin:6px 0 0}
.cells{display:flex;gap:12px;justify-content:center;flex-wrap:wrap;padding:14px}
.cell{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:8px;cursor:pointer}
.cell.sel{border-color:var(--acc);box-shadow:0 0 0 2px rgba(57,208,255,.25)}
canvas{width:200px;height:200px;background:radial-gradient(circle at 50% 44%,#1c2029,#090b10);border-radius:8px;display:block}
.cap{text-align:center;color:var(--dim);font-size:12px;margin-top:6px}
.panel{max-width:760px;margin:0 auto 40px;background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:16px}
.hint{color:var(--dim);font-size:13px;margin-bottom:8px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:6px 22px}
.row{display:flex;align-items:center;gap:10px;margin:6px 0}
.row label{width:96px;color:var(--dim);font-size:13px}
input[type=range]{flex:1;min-width:90px}input[type=color]{width:46px;height:30px;border:1px solid var(--line);border-radius:8px;background:none;cursor:pointer}
select{background:#1b2230;color:var(--txt);border:1px solid var(--line);border-radius:8px;padding:6px 9px}
.val{color:var(--acc);font-variant-numeric:tabular-nums;width:46px;text-align:right;font-size:13px}
.btns{display:flex;gap:8px;margin-top:12px;flex-wrap:wrap}
button{background:#1e2632;color:var(--txt);border:1px solid var(--line);border-radius:8px;padding:9px 14px;cursor:pointer}
button:hover{border-color:var(--acc)}
textarea{width:100%;height:120px;background:#0c0f15;color:#9fe7ff;border:1px solid var(--line);border-radius:8px;padding:10px;font-family:ui-monospace,monospace;font-size:12px;margin-top:8px}
.badge{display:inline-block;background:#123;border:1px solid var(--acc);color:var(--acc);border-radius:20px;padding:3px 10px;font-size:12px;margin-left:8px}
"""

SLIDERS = [
    ("w", "Largeur", 20, 260, 100, 2), ("h", "Hauteur", 20, 260, 100, 2),
    ("ox", "Decalage X", -60, 60, 100, 2), ("oy", "Decalage Y", -60, 60, 100, 2),
    ("rot", "Rotation base", -180, 180, 1, 0), ("bright", "Luminosite", 30, 220, 100, 2),
    ("backA", "Couche fond", 0, 100, 100, 2), ("frontA", "Couche avant", 0, 100, 100, 2),
    ("gap", "Ecart couches", 90, 140, 100, 2),
]
sliders_html = ""
for sid, lab, lo, hi, fac, dec in SLIDERS:
    sliders_html += ('<div class="row"><label>%s</label><input type="range" id="%s" min="%d" max="%d">'
                     '<span class="val" id="%sv"></span></div>') % (lab, sid, lo, hi, sid)

JS = """
const BEARERS=__BEARERS__, STYLES=__STYLES__, DEF=__DEFAULTS__, SL=__SLIDERS__;
let st=JSON.parse(localStorage.getItem("mf_shields2")||"null")||JSON.parse(JSON.stringify(DEF));
for(const k in DEF){for(const p in DEF[k]){if(st[k][p]===undefined)st[k][p]=DEF[k][p];}}
let cur="player", ready=false;
function gv(i){return document.getElementById(i);}
const off=document.createElement("canvas"); off.width=off.height=256; const octx=off.getContext("2d");
const tintCache={};
function tinted(style,tint){
  const key=style+"|"+tint; if(tintCache[key])return tintCache[key];
  octx.clearRect(0,0,256,256); octx.filter="none"; octx.globalCompositeOperation="source-over"; octx.globalAlpha=1;
  octx.drawImage(gv("s_"+style),0,0,256,256);
  octx.globalCompositeOperation="multiply"; octx.fillStyle=tint; octx.fillRect(0,0,256,256);
  octx.globalCompositeOperation="source-over";
  const c=document.createElement("canvas"); c.width=c.height=256; c.getContext("2d").drawImage(off,0,0);
  tintCache[key]=c; return c;
}
function layer(ctx,img,cx,cy,w,h,rot,alpha,bright){
  ctx.save(); ctx.globalCompositeOperation="lighter"; ctx.globalAlpha=Math.max(0,Math.min(1,alpha));
  ctx.filter="brightness("+bright.toFixed(2)+")"; ctx.translate(cx,cy); ctx.rotate(rot);
  ctx.drawImage(img,-w/2,-h/2,w,h); ctx.restore();
}
function drawFrame(k,t){
  const s=st[k], cv=gv("cv_"+k), ctx=cv.getContext("2d"), C=230;
  ctx.clearRect(0,0,C,C);
  const mi=gv("m_"+k); if(!mi.complete||!mi.naturalWidth)return;
  const sc=Math.min(160/mi.naturalWidth,160/mi.naturalHeight), mw=mi.naturalWidth*sc, mh=mi.naturalHeight*sc;
  const cx=C/2+s.ox*mh, cy=C/2+s.oy*mh, bw=mh*s.w, bh=mh*s.h, tex=tinted(s.style,s.tint), rot0=s.rot*Math.PI/180;
  if(k==="player"){
    // AURA : cycle charge/decharge 0.7s (comme le jeu). dome DERRIERE, membrane DEVANT (tourne).
    const cyc=t%0.7, p=cyc/0.7, flash=Math.max(0,1-cyc*3), breathe=0.95+0.05*Math.sin(t*5.88);
    const dS=breathe*(0.9+0.1*p);
    layer(ctx,tex,cx,cy,bw*dS,bh*dS,rot0, s.backA*(0.55+0.45*p)+flash*0.5, s.bright);   // dome (fond)
    ctx.drawImage(mi,C/2-mw/2,C/2-mh/2,mw,mh);                                            // mecha
    const fS=s.gap*(1.0+0.04*p);
    layer(ctx,tex,cx,cy,bw*fS,bh*fS,rot0+t*0.6, s.frontA*(0.6+0.4*p)+flash*0.6, s.bright);// membrane (tourne)
  } else {
    // BOUCLIER ENNEMI : 2 couches PAR-DESSUS le mecha, contra-rotatives, pulse sin(t*4).
    ctx.drawImage(mi,C/2-mw/2,C/2-mh/2,mw,mh);
    const pulse=0.5+0.5*Math.sin(t*4);
    layer(ctx,tex,cx,cy,bw,bh, rot0 - t*0.22, s.backA+0.14*pulse, s.bright);              // fond
    layer(ctx,tex,cx,cy,bw*s.gap,bh*s.gap, rot0 + t*0.5, s.frontA+0.14*pulse, s.bright);  // avant (tourne)
  }
}
function loop(now){ if(ready){const t=now/1000; BEARERS.forEach(b=>drawFrame(b[0],t));} requestAnimationFrame(loop); }
function saveExport(){localStorage.setItem("mf_shields2",JSON.stringify(st)); gv("out").value=JSON.stringify(st,null,2);}
function selectB(k){
  cur=k; document.querySelectorAll(".cell").forEach(c=>c.classList.toggle("sel",c.dataset.b===k));
  gv("style").value=st[k].style; gv("tint").value=st[k].tint;
  gv("curname").textContent=BEARERS.find(b=>b[0]===k)[1];
  SL.forEach(([id,lab,lo,hi,fac,dec])=>{gv(id).min=lo;gv(id).max=hi;gv(id).value=Math.round(st[k][id]*fac);gv(id+"v").textContent=(fac===1?st[k][id]:st[k][id].toFixed(dec));});
}
gv("style").addEventListener("change",e=>{st[cur].style=e.target.value;saveExport();});
gv("tint").addEventListener("input",e=>{st[cur].tint=e.target.value;saveExport();});
SL.forEach(([id,lab,lo,hi,fac,dec])=>{gv(id).addEventListener("input",e=>{st[cur][id]=+e.target.value/fac;gv(id+"v").textContent=(fac===1?st[cur][id]:st[cur][id].toFixed(dec));saveExport();});});
document.querySelectorAll(".cell").forEach(c=>c.addEventListener("click",()=>selectB(c.dataset.b)));
gv("reset").addEventListener("click",()=>{st[cur]=JSON.parse(JSON.stringify(DEF[cur]));selectB(cur);saveExport();});
gv("resetAll").addEventListener("click",()=>{st=JSON.parse(JSON.stringify(DEF));selectB(cur);saveExport();});
gv("copy").addEventListener("click",()=>{const t=gv("out");t.select();document.execCommand("copy");const b=gv("copy");b.textContent="Copie \\u2713";setTimeout(()=>b.textContent="Copier tout (sauvegarde)",1200);});
let imgs=[...document.querySelectorAll("img")],left=imgs.length;
imgs.forEach(im=>{if(im.complete&&im.naturalWidth){if(--left<=0)go();}else im.onload=()=>{if(--left<=0)go();};});
function go(){ready=true; selectB("player"); saveExport(); requestAnimationFrame(loop);}
"""
JS = (JS.replace("__BEARERS__", json.dumps([[b[0], b[1]] for b in BEARERS]))
        .replace("__STYLES__", json.dumps(STYLES))
        .replace("__DEFAULTS__", json.dumps(DEFAULTS))
        .replace("__SLIDERS__", json.dumps(SLIDERS)))

opts = "".join('<option value="%s">%s</option>' % (s, s) for s in STYLES)
html = (
    "<title>MECHA-FORGE - Optimiseur de boucliers (anime)</title>\n<style>" + CSS + "</style>\n"
    "<header><h1>Optimiseur de boucliers <span class=\"badge\">anime comme en jeu</span></h1>"
    "<p class=\"sub\">L'apercu tourne/pulse EXACTEMENT comme le jeu (aura = cycle charge/decharge). Regle, ca se SAUVEGARDE tout seul.</p></header>\n"
    "<div class=\"cells\">" + cards + "</div>\n" + imgs + "\n"
    "<div class=\"panel\">"
    "<div class=\"hint\">Porteur : <b id=\"curname\">Aura joueur</b> &nbsp;|&nbsp; largeur/hauteur = x hauteur du mecha ; les 2 couches tournent en sens inverse comme en jeu.</div>"
    "<div class=\"row\"><label>Style</label><select id=\"style\">" + opts + "</select>"
    "&nbsp;&nbsp;<label style=\"width:auto\">Teinte</label><input type=\"color\" id=\"tint\" value=\"#6ad0ff\"></div>"
    "<div class=\"grid\">" + sliders_html + "</div>"
    "<div class=\"btns\"><button id=\"reset\">Reset ce porteur</button><button id=\"resetAll\">Reset tout</button><button id=\"copy\">Copier tout (sauvegarde)</button></div>"
    "<textarea id=\"out\" readonly></textarea></div>\n"
    "<script>" + JS + "</script>"
)
open("cine/_show/shield_editor.html", "w", encoding="utf-8").write(html)
print("animated shield editor built", len(html), "bytes")
