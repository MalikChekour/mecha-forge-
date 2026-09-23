"""Catalog of the Gemini series-2 assets (traps + decor + walls + objectives) for review
BEFORE integration. Reads from the antigravity scratch folder where the Gemini agent placed them.
"""
import base64, io, os
from PIL import Image

SRC = r"C:\Users\Administrator\.gemini\antigravity\scratch\mecha-forge\refs\decor_gemini"
OUT = (r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude"
       r"\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad\series2_catalog.html")

GROUPS = [
    ("Pièges actifs", "#9A2E2E", [
        ("T1", "Capaciteur à rayon", "balaye un rayon traversant, dégâts aux 2 camps"),
        ("T2", "Balise d'invocation", "crache des ennemis jusqu'à destruction"),
        ("T3", "Pylône à arc électrique", "foudroie les ennemis proches, EMP si détruit"),
        ("T4", "Émetteur de ralentissement", "zone qui englue joueur et ennemis"),
        ("T5", "Mine de proximité", "s'arme quand tu ralentis près, explose"),
        ("T6", "Réservoir explosif", "explose au contact, dégâts de zone"),
        ("T7", "Tourelle hostile lourde", "tire dans son cône"),
        ("T8", "Geyser d'énergie", "éruptions verticales télégraphiées"),
        ("T9", "Lame rotative", "tourne sur un rayon fixe, dégâts au contact"),
        ("T10", "Diffuseur de spores", "nuage qui masque et blesse"),
    ]),
    ("Décor de biome", "#256B58", [
        ("D_earth1_a", "Rocher fissuré (var. A)", "Friche"),
        ("D_earth1_b", "Rocher fissuré (var. B)", "Friche"),
        ("D_earth2", "Souche calcinée", "Friche"),
        ("D_ice1_a", "Bloc de glace (var. A)", "Glace"),
        ("D_ice1_b", "Bloc de glace (var. B)", "Glace"),
        ("D_ice2", "Épave gelée", "Glace"),
        ("D_jungle1", "Champignon géant", "Jungle/Marais"),
        ("D_jungle2", "Fougère bioluminescente", "Jungle"),
        ("D_swamp1", "Souche à mangrove", "Marais"),
        ("D_volcanic1", "Cheminée de basalte", "Volcan"),
        ("D_desert1", "Mesa érodée", "Désert"),
        ("D_tech1", "Bloc serveur", "Tech/Vaisseau"),
        ("D_tech2", "Conduit d'énergie coudé", "Tech/Vaisseau"),
    ]),
    ("Murs & bordures d'arène", "#7A5C1E", [
        ("F1", "Falaise rocheuse", "bordure Friche/Désert"),
        ("F2", "Crête de glace", "bordure Glace"),
        ("F3", "Rempart de ruines", "bordure Ruines/Tech"),
        ("F4", "Mur de basalte", "bordure Volcan"),
    ]),
    ("Objectifs & bonus", "#3A5B8C", [
        ("O1", "Pylône de surcharge", "buff de cadence dans un rayon"),
        ("O2", "Cache blindée", "coffre à casser = grosse récompense"),
        ("O3", "Capsule de stase", "libère un allié à l'ouverture"),
    ]),
]

def uri(code):
    p = os.path.join(SRC, code + ".png")
    if not os.path.exists(p):
        return ""
    im = Image.open(p).convert("RGB")
    im.thumbnail((230, 230), Image.LANCZOS)
    buf = io.BytesIO(); im.save(buf, format="JPEG", quality=86, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()

n = 0
sections = []
for title, col, items in GROUPS:
    cards = []
    for code, name, note in items:
        n += 1
        u = uri(code)
        img = f'<img src="{u}" alt="{code}">' if u else '<div class="miss">manquant</div>'
        cards.append(f'''<figure class="card">
          <div class="code">{code}</div>
          <div class="thumb">{img}</div>
          <figcaption><div class="nm">{name}</div><div class="nt">{note}</div></figcaption>
        </figure>''')
    sections.append(f'''<section>
      <h2 style="--c:{col}">{title} <span>{len(items)}</span></h2>
      <div class="grid">{''.join(cards)}</div>
    </section>''')

HTML = f'''<title>MECHA-FORGE — Assets série 2 (à valider)</title>
<style>
  :root{{--bg:#12141a;--panel:#1b1e26;--ink:#e8ebf1;--muted:#98a1b0;--rule:#282d38}}
  @media(prefers-color-scheme:light){{:root{{--bg:#f1f2f5;--panel:#fff;--ink:#181b21;--muted:#5a6270;--rule:#e0e3e9}}}}
  :root[data-theme=light]{{--bg:#f1f2f5;--panel:#fff;--ink:#181b21;--muted:#5a6270;--rule:#e0e3e9}}
  :root[data-theme=dark]{{--bg:#12141a;--panel:#1b1e26;--ink:#e8ebf1;--muted:#98a1b0;--rule:#282d38}}
  *{{box-sizing:border-box;margin:0;padding:0}}
  body{{background:var(--bg);color:var(--ink);font-family:ui-sans-serif,system-ui,"Segoe UI",sans-serif}}
  .wrap{{max-width:74rem;margin:0 auto;padding:2.2rem 1.1rem 4rem}}
  .eyebrow{{font-family:ui-monospace,Consolas,monospace;font-size:.68rem;letter-spacing:.18em;
            text-transform:uppercase;color:#e0863f;margin-bottom:.4rem}}
  h1{{font-size:clamp(1.6rem,4vw,2.2rem);font-weight:650;letter-spacing:-.02em;margin-bottom:.4rem}}
  .lede{{color:var(--muted);max-width:44rem;margin-bottom:.6rem}}
  .warn{{background:#3a2a10;border:1px solid #6b4a12;color:#f0cd8a;border-radius:8px;
         padding:.7rem .9rem;font-size:.86rem;margin:1rem 0 .5rem;max-width:48rem}}
  @media(prefers-color-scheme:light){{.warn{{background:#fdf4e3;border-color:#e6c98a;color:#7a5710}}}}
  section{{margin-top:2.4rem}}
  h2{{font-size:1.15rem;font-weight:640;display:flex;align-items:center;gap:.6rem;
      padding-bottom:.5rem;border-bottom:2px solid var(--c);margin-bottom:1rem}}
  h2 span{{font-family:ui-monospace,monospace;font-size:.7rem;color:#fff;background:var(--c);
           padding:.1rem .45rem;border-radius:4px}}
  .grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:.9rem}}
  .card{{background:var(--panel);border:1px solid var(--rule);border-radius:10px;overflow:hidden;position:relative}}
  .code{{position:absolute;top:.4rem;left:.4rem;z-index:2;font-family:ui-monospace,monospace;
         font-size:.72rem;font-weight:700;background:rgba(0,0,0,.6);color:#fff;padding:.12rem .42rem;border-radius:4px}}
  .thumb{{aspect-ratio:1;display:flex;align-items:center;justify-content:center;background:#0c0e13}}
  .thumb img{{width:100%;height:100%;object-fit:contain}}
  .miss{{color:#8a93a1;font-size:.8rem}}
  figcaption{{padding:.55rem .7rem .7rem}}
  .nm{{font-weight:600;font-size:.95rem;letter-spacing:-.01em}}
  .nt{{color:var(--muted);font-size:.8rem;margin-top:.15rem}}
</style>
<div class="wrap">
  <div class="eyebrow">Généré par Gemini · à valider avant intégration</div>
  <h1>Assets série 2 — {n} nouveaux</h1>
  <p class="lede">Pièges, décors de biome, murs de bordure et objectifs. Fonds vert/magenta = à
  détourer (transparent) au moment de l'intégration.</p>
  <div class="warn">⚠️ Ces images sont dans la <b>copie Gemini</b> du projet
  (<code>.gemini/antigravity/scratch/mecha-forge</code>), <b>pas</b> dans le jeu que je build et
  pousse sur itch. Rien n'est encore en jeu — c'est bien une revue avant intégration.</div>
  {''.join(sections)}
</div>'''

os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, "w", encoding="utf-8").write(HTML)
print("catalogue ecrit:", OUT, f"({os.path.getsize(OUT)//1024} Ko, {n} assets)")
