# -*- coding: utf-8 -*-
"""Genere le module HTML 'Peintre d'ennemis' : recolorisation live (armure/accent/yeux) en canvas."""
import json, os

A = json.load(open("cine/_show/_pnt.json"))
enemies = [("tech", "Machine Tech"), ("gunner", "Artilleur"), ("desert", "Raider")]
keys = [k for k, _ in enemies]

def dataimg(k): return "data:image/png;base64," + A[k]

cells = ""
for k, n in enemies:
    cells += ('<div class="cell"><canvas id="cv_%s" width="200" height="200"></canvas>'
              '<div class="cap">%s</div><img id="src_%s" src="%s" style="display:none"></div>' % (k, n, k, dataimg(k)))

CSS = """
:root{--bg:#0e1116;--panel:#171b23;--line:#28303c;--txt:#e7eaf0;--dim:#8b93a6;--acc:#ff7a3a}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--txt);font-family:"Segoe UI",system-ui,sans-serif}
header{padding:22px 20px 6px;text-align:center}h1{margin:0;font-size:22px}.sub{color:var(--dim);font-size:14px;margin:6px 0 0}
.previews{display:flex;gap:16px;justify-content:center;flex-wrap:wrap;padding:16px}
.cell{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:10px}
canvas{width:200px;height:200px;background:radial-gradient(circle at 50% 42%,#20252f,#0d0f14);border-radius:8px;display:block}
.cap{text-align:center;color:var(--dim);font-size:12px;margin-top:6px}
.panel{max-width:760px;margin:0 auto 40px;background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:16px}
.row{display:flex;align-items:center;gap:12px;margin:10px 0;flex-wrap:wrap}
.row label{width:150px;color:var(--dim);font-size:14px}
input[type=color]{width:52px;height:34px;border:1px solid var(--line);border-radius:8px;background:none;cursor:pointer}
input[type=range]{flex:1;min-width:160px}
.val{color:var(--acc);font-variant-numeric:tabular-nums;width:46px;text-align:right}
.pre{display:flex;gap:8px;flex-wrap:wrap}
.pre button,button.act{background:#222a35;color:var(--txt);border:1px solid var(--line);border-radius:20px;padding:6px 12px;cursor:pointer;font-size:12px}
button.act{border-radius:8px;padding:9px 14px}
.pre button:hover,button.act:hover{border-color:var(--acc)}
textarea{width:100%;height:96px;background:#0d1016;color:#9fe7ff;border:1px solid var(--line);border-radius:8px;padding:10px;font-family:ui-monospace,monospace;font-size:12px;margin-top:8px}
"""

JS = """
const KEYS=__KEYS__;
const PRESETS={
  terminator:{armor:"#22262c",accent:"#8a2b2b",eyes:"#ff2018",contrast:150,accf:90},
  toxic:{armor:"#2c3a22",accent:"#8cff32",eyes:"#c8ff3c",contrast:120,accf:120},
  ice:{armor:"#2b3b48",accent:"#7fe0ff",eyes:"#d0f4ff",contrast:110,accf:110},
  gold:{armor:"#1b1d22",accent:"#ffbe37",eyes:"#ffd060",contrast:150,accf:110},
  crimson:{armor:"#2a1416",accent:"#c8323c",eyes:"#ff4030",contrast:140,accf:100}
};
function hx(h){return [parseInt(h.slice(1,3),16),parseInt(h.slice(3,5),16),parseInt(h.slice(5,7),16)];}
function gv(id){return document.getElementById(id);}
const srcData={};
function loadSrc(k){
  const img=gv("src_"+k), off=document.createElement("canvas"); off.width=200; off.height=200;
  const octx=off.getContext("2d");
  const s=Math.min(180/img.naturalWidth,180/img.naturalHeight), w=img.naturalWidth*s, h=img.naturalHeight*s;
  octx.drawImage(img,(200-w)/2,(200-h)/2,w,h);
  srcData[k]=octx.getImageData(0,0,200,200); render(k);
}
function render(k){
  if(!srcData[k])return;
  const armor=hx(gv("armor").value), accent=hx(gv("accent").value), eyes=hx(gv("eyes").value);
  const contrast=+gv("contrast").value/100, accf=+gv("accf").value/100;
  const src=srcData[k].data, ctx=gv("cv_"+k).getContext("2d"), out=ctx.createImageData(200,200), d=out.data;
  for(let i=0;i<src.length;i+=4){
    const r=src[i],g=src[i+1],b=src[i+2],a=src[i+3];
    if(a<20){d[i+3]=0;continue;}
    const L=(0.299*r+0.587*g+0.114*b)/255, mx=Math.max(r,g,b),mn=Math.min(r,g,b),sat=(mx-mn)/(mx+1);
    let cr,cg,cb;
    if(r>150&&g<100&&b<120){cr=eyes[0];cg=eyes[1];cb=eyes[2];}
    else if(sat>0.30&&L>0.26){const kf=(0.5+0.6*L)*accf;cr=accent[0]*kf;cg=accent[1]*kf;cb=accent[2]*kf;}
    else {const Lc=Math.max(0,Math.min(1,(L-0.5)*contrast+0.5)),kf=0.22+1.05*Lc;cr=armor[0]*kf;cg=armor[1]*kf;cb=armor[2]*kf;}
    d[i]=Math.min(255,cr);d[i+1]=Math.min(255,cg);d[i+2]=Math.min(255,cb);d[i+3]=a;
  }
  ctx.clearRect(0,0,200,200); ctx.putImageData(out,0,0);
}
function renderAll(){KEYS.forEach(render); exportP();}
function exportP(){
  const o={armure:gv("armor").value,accent:gv("accent").value,yeux:gv("eyes").value,contraste:(+gv("contrast").value/100),force_accent:(+gv("accf").value/100)};
  gv("out").value=JSON.stringify(o,null,2);
}
["armor","accent","eyes"].forEach(id=>gv(id).addEventListener("input",renderAll));
gv("contrast").addEventListener("input",e=>{gv("contrastv").textContent=(+e.target.value/100).toFixed(2);renderAll();});
gv("accf").addEventListener("input",e=>{gv("accfv").textContent=e.target.value+"%";renderAll();});
document.querySelectorAll(".pre button").forEach(btn=>btn.addEventListener("click",()=>{
  const p=PRESETS[btn.dataset.p]; gv("armor").value=p.armor; gv("accent").value=p.accent; gv("eyes").value=p.eyes;
  gv("contrast").value=p.contrast; gv("contrastv").textContent=(p.contrast/100).toFixed(2);
  gv("accf").value=p.accf; gv("accfv").textContent=p.accf+"%"; renderAll();
}));
gv("copy").addEventListener("click",()=>{const t=gv("out");t.select();document.execCommand("copy");const b=gv("copy");b.textContent="Copie \\u2713";setTimeout(()=>b.textContent="Copier la palette",1200);});
KEYS.forEach(k=>{const im=gv("src_"+k); if(im.complete)loadSrc(k); else im.onload=()=>loadSrc(k);});
""".replace("__KEYS__", json.dumps(keys))

html = ('<title>MECHA-FORGE - Peintre d\'ennemis</title>\n<style>' + CSS + '</style>\n'
        '<header><h1>Peintre d\'ennemis - recolorise a ta main</h1>'
        '<p class="sub">Choisis l\'armure, l\'accent et les yeux : l\'apercu se met a jour en direct. Copie la palette et donne-la moi.</p></header>\n'
        '<div class="previews">' + cells + '</div>\n'
        '<div class="panel">'
        '<div class="row"><label>Preset rapide</label><div class="pre">'
        '<button data-p="terminator">Terminator</button><button data-p="toxic">Toxique</button>'
        '<button data-p="ice">Givre</button><button data-p="gold">Elite or</button><button data-p="crimson">Sang</button></div></div>'
        '<div class="row"><label>Armure (corps)</label><input type="color" id="armor" value="#3a4048"></div>'
        '<div class="row"><label>Accent (liseres)</label><input type="color" id="accent" value="#39d0ff"></div>'
        '<div class="row"><label>Yeux / coeur</label><input type="color" id="eyes" value="#ff3020"></div>'
        '<div class="row"><label>Contraste armure</label><input type="range" id="contrast" min="60" max="200" value="120"><span class="val" id="contrastv">1.20</span></div>'
        '<div class="row"><label>Force accent</label><input type="range" id="accf" min="0" max="150" value="100"><span class="val" id="accfv">100%</span></div>'
        '<div class="row"><button class="act" id="copy">Copier la palette</button></div>'
        '<textarea id="out" readonly></textarea></div>\n'
        '<script>' + JS + '</script>')

open("cine/_show/enemy_painter.html", "w", encoding="utf-8").write(html)
print("painter built", len(html), "bytes")
