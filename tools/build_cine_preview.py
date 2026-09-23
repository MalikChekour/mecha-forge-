"""Build an ANIMATED cinematic preview (motion-comic) from the generated panels.
Ken Burns pan/zoom + crossfades + story text, autoplaying, plus a panel grid. Output: HTML artifact.
"""
import base64, io, os
from PIL import Image

CINE = r"C:\Users\Administrator\mecha-forge\cine"
OUT = (r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude"
       r"\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad\cine_preview.html")

# story order: file, caption, ken-burns start->end (scale/translate), duration ms
BEATS = [
    ("p1", "La guerre des machines ne s'est jamais arrêtée.",        "kb-in-tl"),
    ("p2", "Dans les cendres d'une forge oubliée…",                   "kb-in-r"),
    ("p3", "…un dernier pilote.",                                     "kb-in-up"),
    ("p4", "Le noyau se rallume.",                                    "kb-punch"),
    ("p5", "Seul contre la horde.",                                   "kb-in-l"),
    ("p6", "La forge n'est pas éteinte.",                             "kb-out"),
]
HOLD = 4200   # ms per panel

def datauri(name):
    im = Image.open(os.path.join(CINE, name + ".png")).convert("RGB")
    im.thumbnail((1280, 1280), Image.LANCZOS)
    buf = io.BytesIO(); im.save(buf, format="JPEG", quality=84, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()

uris = {n: datauri(n) for n, _, _ in BEATS}

slides = "".join(f'''<div class="slide" data-i="{i}">
  <div class="img {kb}" style="background-image:url('{uris[n]}')"></div>
</div>''' for i, (n, cap, kb) in enumerate(BEATS))

caps = "".join(f'<div class="cap" data-i="{i}">{cap}</div>' for i, (n, cap, kb) in enumerate(BEATS))
dots = "".join(f'<span class="dot" data-i="{i}"></span>' for i in range(len(BEATS)))
thumbs = "".join(f'''<figure class="tcard"><div class="tnum">{i+1:02d}</div>
  <div class="tthumb" style="background-image:url('{uris[n]}')"></div>
  <figcaption>{cap}</figcaption></figure>''' for i, (n, cap, kb) in enumerate(BEATS))

HTML = f'''<title>MECHA-FORGE — Aperçu cinématique</title>
<style>
  *{{box-sizing:border-box;margin:0;padding:0}}
  body{{background:#05060a;color:#e9edf4;font-family:ui-sans-serif,system-ui,"Segoe UI",sans-serif;
        -webkit-font-smoothing:antialiased;overflow-x:hidden}}
  .wrap{{max-width:1100px;margin:0 auto;padding:1.5rem 1rem 4rem}}
  .eyebrow{{font-family:ui-monospace,Consolas,monospace;font-size:.68rem;letter-spacing:.22em;
            text-transform:uppercase;color:#e0863f;text-align:center;margin-bottom:.4rem}}
  h1{{text-align:center;font-size:clamp(1.4rem,4vw,2rem);font-weight:640;letter-spacing:-.01em;margin-bottom:.3rem}}
  .sub{{text-align:center;color:#8b93a4;font-size:.9rem;margin-bottom:1.3rem}}

  /* ---- cinematic stage ---- */
  .stage{{position:relative;width:100%;aspect-ratio:16/9;background:#000;border-radius:12px;
          overflow:hidden;box-shadow:0 10px 40px rgba(0,0,0,.6);border:1px solid #1a1f2b}}
  .slide{{position:absolute;inset:0;opacity:0;transition:opacity 1.1s ease}}
  .slide.on{{opacity:1}}
  .img{{position:absolute;inset:-6%;background-size:cover;background-position:center;
        transform:scale(1.06);will-change:transform}}
  .slide.on .img{{animation-duration:{HOLD+1100}ms;animation-timing-function:linear;
                  animation-fill-mode:forwards}}
  .slide.on .kb-in-tl{{animation-name:kbInTl}} .slide.on .kb-in-r{{animation-name:kbInR}}
  .slide.on .kb-in-up{{animation-name:kbInUp}} .slide.on .kb-punch{{animation-name:kbPunch}}
  .slide.on .kb-in-l{{animation-name:kbInL}}  .slide.on .kb-out{{animation-name:kbOut}}
  @keyframes kbInTl{{from{{transform:scale(1.02) translate(2%,2%)}}to{{transform:scale(1.16) translate(-3%,-3%)}}}}
  @keyframes kbInR{{from{{transform:scale(1.14) translate(4%,0)}}to{{transform:scale(1.04) translate(-4%,0)}}}}
  @keyframes kbInUp{{from{{transform:scale(1.02) translate(0,4%)}}to{{transform:scale(1.15) translate(0,-4%)}}}}
  @keyframes kbPunch{{from{{transform:scale(1.22)}}to{{transform:scale(1.02)}}}}
  @keyframes kbInL{{from{{transform:scale(1.14) translate(-4%,0)}}to{{transform:scale(1.04) translate(4%,0)}}}}
  @keyframes kbOut{{from{{transform:scale(1.02)}}to{{transform:scale(1.18) translate(0,-3%)}}}}
  /* letterbox + vignette */
  .stage::before{{content:"";position:absolute;inset:0;z-index:3;pointer-events:none;
    box-shadow:inset 0 0 160px rgba(0,0,0,.75);
    background:linear-gradient(180deg,rgba(0,0,0,.55),transparent 22%,transparent 62%,rgba(0,0,0,.85))}}
  .cap{{position:absolute;left:0;right:0;bottom:8%;z-index:4;text-align:center;padding:0 8%;
        font-size:clamp(1rem,2.6vw,1.5rem);font-weight:600;letter-spacing:.01em;
        text-shadow:0 2px 18px rgba(0,0,0,.9);opacity:0;transform:translateY(10px);
        transition:opacity .8s ease,transform .8s ease}}
  .cap.on{{opacity:1;transform:none}}
  /* end title card */
  .title{{position:absolute;inset:0;z-index:5;display:flex;flex-direction:column;align-items:center;
          justify-content:center;opacity:0;transition:opacity 1s ease;pointer-events:none;
          background:radial-gradient(ellipse at center,rgba(0,0,0,.25),rgba(0,0,0,.7))}}
  .title.on{{opacity:1}}
  .title .logo{{font-weight:800;letter-spacing:.06em;font-size:clamp(2rem,7vw,4.2rem);
    background:linear-gradient(180deg,#eafcff,#4fd0ff 55%,#1a86c9);-webkit-background-clip:text;
    background-clip:text;color:transparent;filter:drop-shadow(0 0 18px rgba(60,190,255,.5));text-align:center}}
  .title .tl{{color:#e0863f;font-family:ui-monospace,monospace;letter-spacing:.3em;font-size:.7rem;
    text-transform:uppercase;margin-top:.6rem}}

  .bar{{display:flex;align-items:center;gap:1rem;justify-content:center;margin:1rem 0 .3rem}}
  .dots{{display:flex;gap:.4rem}}
  .dot{{width:9px;height:9px;border-radius:50%;background:#2a3342;transition:background .3s,transform .3s;cursor:pointer}}
  .dot.on{{background:#4fd0ff;transform:scale(1.25)}}
  button{{background:#141a24;color:#dfe6f0;border:1px solid #2a3342;border-radius:7px;
          padding:.5rem .9rem;font-size:.85rem;cursor:pointer}}
  button:hover{{border-color:#4fd0ff}}
  .note{{text-align:center;color:#6b7484;font-size:.8rem;max-width:40rem;margin:.6rem auto 0;line-height:1.5}}

  .gridh{{margin:2.5rem 0 .8rem;font-size:.7rem;letter-spacing:.16em;text-transform:uppercase;
          color:#8b93a4;border-top:1px solid #1a1f2b;padding-top:1.3rem}}
  .grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:.8rem}}
  .tcard{{background:#0d1017;border:1px solid #1a1f2b;border-radius:9px;overflow:hidden;position:relative}}
  .tnum{{position:absolute;top:.4rem;left:.4rem;z-index:2;font-family:ui-monospace,monospace;
         font-size:.72rem;font-weight:700;background:rgba(0,0,0,.6);padding:.1rem .4rem;border-radius:4px}}
  .tthumb{{aspect-ratio:16/9;background-size:cover;background-position:center}}
  .tcard figcaption{{padding:.55rem .7rem;font-size:.82rem;color:#aeb6c4}}
</style>

<div class="wrap">
  <div class="eyebrow">Aperçu · motion-comic généré</div>
  <h1>Cinématique d'introduction</h1>
  <p class="sub">6 panneaux, zoom/panoramique + fondus — l'intro telle qu'elle jouerait en jeu.</p>

  <div class="stage" id="stage">
    {slides}
    {caps}
    <div class="title" id="title">
      <div class="logo">MECHA-FORGE</div>
      <div class="tl">La forge n'est pas éteinte</div>
    </div>
  </div>

  <div class="bar">
    <button id="replay">↻ Rejouer</button>
    <div class="dots">{dots}</div>
    <button id="pause">❚❚ Pause</button>
  </div>
  <p class="note">Images générées via FLUX (gratuit). Le montage final (musique, titre animé, rythme)
  se fera en Remotion pour le trailer et en moteur pour l'intro jouable. Panneaux échangeables par
  des versions premium sans rien casser.</p>

  <div class="gridh">Les 6 panneaux</div>
  <div class="grid">{thumbs}</div>
</div>

<script>
  const HOLD = {HOLD};
  const slides = [...document.querySelectorAll('.slide')];
  const caps = [...document.querySelectorAll('.cap')];
  const dots = [...document.querySelectorAll('.dot')];
  const title = document.getElementById('title');
  let i = -1, timer = null, paused = false;

  function show(n){{
    slides.forEach((s,k)=>s.classList.toggle('on',k===n));
    caps.forEach((c,k)=>c.classList.toggle('on',k===n));
    dots.forEach((d,k)=>d.classList.toggle('on',k===n));
    // restart ken-burns
    const img = slides[n].querySelector('.img');
    img.style.animation='none'; void img.offsetWidth; img.style.animation='';
    title.classList.toggle('on', n===slides.length-1);
  }}
  function next(){{
    if(paused) return;
    i=(i+1)%slides.length; show(i);
    timer=setTimeout(next, HOLD);
  }}
  function go(n){{ clearTimeout(timer); i=n; show(i); if(!paused) timer=setTimeout(next,HOLD); }}

  dots.forEach((d,k)=>d.addEventListener('click',()=>go(k)));
  document.getElementById('replay').addEventListener('click',()=>{{paused=false;document.getElementById('pause').textContent='❚❚ Pause';go(0);}});
  document.getElementById('pause').addEventListener('click',(e)=>{{
    paused=!paused;
    e.target.textContent = paused ? '▶ Lire' : '❚❚ Pause';
    if(!paused){{ timer=setTimeout(next,1400); }} else {{ clearTimeout(timer); }}
  }});
  next();
</script>'''

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8") as f:
    f.write(HTML)
print("preview ecrit:", OUT, f"({os.path.getsize(OUT)//1024} Ko)")
