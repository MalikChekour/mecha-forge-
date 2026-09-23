"""Build a visual catalog of every decor prop actually used in the game.

Each g-file is thumbnailed (keeps the artifact small) and embedded as a data URI, with its number,
name, biomes, current gameplay function, and whether it's a deletion candidate. Output: an HTML
file for the Artifact tool.
"""
import base64, io, os
from PIL import Image

DECOR_DIR = r"C:\Users\Administrator\mecha-forge\game\assets\decor"
OUT = (r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude"
       r"\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad\decor_catalog.html")

# (name, file, function, category) — order = catalog number. category drives the colour tag.
# categories: fonction (has a real mechanic) | naturel (wall/obstacle) | inerte (no function yet) | loot
# Après suppression des nos 19-35 (patron) : 18 décors restants.
DECOR = [
    ("baril",       "g20",  "Explose au contact (dégâts de zone, touche ennemis + toi)", "fonction"),
    ("caisses",     "g21",  "Cassable → peut lâcher une compétence", "loot"),
    ("generateur",  "g22",  "Cassable seulement — AUCUNE fonction", "inerte"),
    ("antenne",     "g23",  "BALISE : crache des ennemis jusqu'à destruction", "fonction"),
    ("conduit",     "g24",  "Cassable seulement — AUCUNE fonction", "inerte"),
    ("emetteur",    "g25",  "Cassable seulement — AUCUNE fonction (même image que capaciteur)", "inerte"),
    ("epave",       "g26",  "Couverture cassable — aussi dans les ruines maintenant", "inerte"),
    ("tourelle",    "g27",  "Tourelle hostile : te tire dessus", "fonction"),
    ("container",   "g28",  "Cassable → peut lâcher une compétence", "loot"),
    ("capaciteur",  "g25",  "Rayon traversant neutre (dégâts aux deux camps)", "fonction"),
    ("rocher",      "g29",  "Naturel : bloque / sert de mur (indestructible)", "naturel"),
    ("cristaux",    "g30",  "Naturel : bloque (indestructible)", "naturel"),
    ("arbre",       "g31",  "Naturel : obstacle (indestructible)", "naturel"),
    ("plante",      "g32",  "Naturel : décor (indestructible)", "naturel"),
    ("glace",       "g33",  "Naturel : bloque (indestructible)", "naturel"),
    ("arche",       "g34",  "Naturel : bloque — rendue SOLIDE (plus see-through)", "naturel"),
    ("lave",        "g35",  "Naturel : bloque (indestructible)", "naturel"),
    ("racines",     "g36",  "Naturel : décor (indestructible)", "naturel"),
]

BIOME_DECOR = {
    "earth": ["rocher", "arbre", "epave", "caisses", "baril"],
    "volcanic": ["lave", "rocher", "epave", "caisses", "baril"],
    "spaceship": ["generateur", "conduit", "capaciteur", "tourelle", "antenne",
                  "cristaux", "container", "caisses", "baril"],
    "tech": ["generateur", "conduit", "antenne", "capaciteur", "tourelle",
             "cristaux", "container", "caisses", "baril"],
    "desert": ["arche", "rocher", "epave", "caisses", "baril"],
    "ice": ["glace", "cristaux", "epave", "caisses", "baril"],
    "jungle": ["plante", "racines", "arbre", "epave", "caisses"],
    "swamp": ["racines", "plante", "arbre", "epave", "caisses"],
    "ruines": ["epave", "rocher", "capaciteur", "caisses", "baril", "container", "cristaux"],
}
BIOME_LABEL = {"earth": "Friche", "volcanic": "Volcan", "spaceship": "Vaisseau", "tech": "Tech",
               "desert": "Désert", "ice": "Glace", "jungle": "Jungle", "swamp": "Marais",
               "ruines": "Ruines"}

def biomes_of(name):
    return [BIOME_LABEL[b] for b, ks in BIOME_DECOR.items() if name in ks]

def thumb_datauri(gfile, box=190):
    path = os.path.join(DECOR_DIR, gfile + ".png")
    if not os.path.exists(path):
        return ""
    im = Image.open(path).convert("RGBA")
    im.thumbnail((box, box), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, format="PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()

CAT_TAG = {
    "fonction": ("#256B58", "A une fonction"),
    "naturel":  ("#7A5C1E", "Naturel / obstacle"),
    "loot":     ("#3A5B8C", "Butin"),
    "inerte":   ("#9A2E2E", "Sans fonction"),
}

cards = []
for i, (name, gf, func, cat) in enumerate(DECOR, 1):
    uri = thumb_datauri(gf)
    col, label = CAT_TAG[cat]
    bl = biomes_of(name)
    biomes_html = "".join(f'<span class="bi">{b}</span>' for b in bl) or '<span class="bi none">aucun (non placé)</span>'
    img = f'<img src="{uri}" alt="{name}">' if uri else '<div class="noimg">image manquante</div>'
    cards.append(f'''<figure class="card cat-{cat}">
      <div class="num">{i:02d}</div>
      <div class="thumb">{img}</div>
      <figcaption>
        <div class="nm">{name}</div>
        <div class="fn">{func}</div>
        <div class="tag" style="--tag:{col}">{label}</div>
        <div class="biomes">{biomes_html}</div>
      </figcaption>
    </figure>''')

n_inerte = sum(1 for d in DECOR if d[3] == "inerte")
STYLE = '''<title>MECHA-FORGE — Catalogue décor</title>
<style>
  :root{
    --bg:#14161c; --panel:#1c1f27; --tile:#0f1116; --ink:#e8eaef;
    --muted:#9aa2b1; --faint:#6b7382; --rule:#2a2e39; --accent:#e0863f;
  }
  @media (prefers-color-scheme: light){
    :root{ --bg:#f1f2f5; --panel:#ffffff; --tile:#e9ebf0; --ink:#181b21;
           --muted:#5a6270; --faint:#8b93a1; --rule:#dfe2e8; --accent:#b45715; }
  }
  :root[data-theme="light"]{ --bg:#f1f2f5; --panel:#ffffff; --tile:#e9ebf0; --ink:#181b21;
           --muted:#5a6270; --faint:#8b93a1; --rule:#dfe2e8; --accent:#b45715; }
  :root[data-theme="dark"]{ --bg:#14161c; --panel:#1c1f27; --tile:#0f1116; --ink:#e8eaef;
           --muted:#9aa2b1; --faint:#6b7382; --rule:#2a2e39; --accent:#e0863f; }
  *{ box-sizing:border-box; }
  body{ background:var(--bg); color:var(--ink);
        font-family:ui-sans-serif,system-ui,"Segoe UI",Roboto,sans-serif; line-height:1.5; }
  .wrap{ max-width:76rem; margin:0 auto; padding:2.5rem 1.2rem 4rem; }
  .eyebrow{ font-family:ui-monospace,Consolas,monospace; font-size:.7rem; letter-spacing:.16em;
            text-transform:uppercase; color:var(--accent); margin-bottom:.5rem; }
  h1{ font-size:clamp(1.7rem,4vw,2.4rem); font-weight:650; letter-spacing:-.02em; margin:0 0 .5rem; }
  .lede{ color:var(--muted); max-width:44rem; margin:0 0 1rem; }
  .lede b{ color:var(--ink); }
  .legend{ display:flex; flex-wrap:wrap; gap:.5rem 1rem; margin-top:1rem;
           padding-top:1rem; border-top:1px solid var(--rule); }
  .lg{ font-size:.8rem; color:var(--muted); display:flex; align-items:center; gap:.4rem; }
  .lg::before{ content:""; width:.7rem; height:.7rem; border-radius:2px; background:var(--c); }
  .grid{ display:grid; grid-template-columns:repeat(auto-fill,minmax(200px,1fr));
         gap:1rem; margin-top:1.8rem; }
  .card{ position:relative; background:var(--panel); border:1px solid var(--rule);
         border-radius:10px; overflow:hidden; margin:0; box-shadow:0 1px 3px rgba(0,0,0,.15); }
  .card.cat-inerte{ border-color:#9A2E2E66; }
  .num{ position:absolute; top:.5rem; left:.5rem; z-index:2; font-family:ui-monospace,monospace;
        font-size:.82rem; font-weight:700; background:rgba(0,0,0,.55); color:#fff;
        padding:.15rem .45rem; border-radius:5px; }
  .thumb{ background:var(--tile); aspect-ratio:1/1; display:flex; align-items:center;
          justify-content:center; padding:.7rem;
          background-image:linear-gradient(45deg,rgba(128,128,128,.06) 25%,transparent 25%,transparent 75%,rgba(128,128,128,.06) 75%),
                           linear-gradient(45deg,rgba(128,128,128,.06) 25%,transparent 25%,transparent 75%,rgba(128,128,128,.06) 75%);
          background-size:18px 18px; background-position:0 0,9px 9px; }
  .thumb img{ max-width:100%; max-height:100%; object-fit:contain;
              filter:drop-shadow(0 3px 6px rgba(0,0,0,.4)); }
  .noimg{ color:var(--faint); font-size:.8rem; }
  figcaption{ padding:.7rem .8rem .85rem; }
  .nm{ font-weight:640; font-size:1.02rem; letter-spacing:-.01em; }
  .fn{ color:var(--muted); font-size:.83rem; margin:.25rem 0 .5rem; min-height:2.4em; }
  .tag{ display:inline-block; font-size:.68rem; font-weight:600; letter-spacing:.03em;
        text-transform:uppercase; color:#fff; background:var(--tag);
        padding:.14rem .5rem; border-radius:4px; }
  .biomes{ margin-top:.55rem; display:flex; flex-wrap:wrap; gap:.28rem; }
  .bi{ font-size:.68rem; color:var(--muted); border:1px solid var(--rule);
       padding:.08rem .4rem; border-radius:4px; }
  .bi.none{ color:var(--faint); font-style:italic; }
</style>
'''
html = STYLE + f'''<div class="wrap">
<header>
  <div class="eyebrow">MECHA-FORGE · catalogue décor</div>
  <h1>Décors du jeu — après nettoyage</h1>
  <p class="lede">{len(DECOR)} décors restants après suppression (les nos 19-35 ont été retirés).
  Il reste <b>{n_inerte}</b> sans fonction (rouge) — à qui donner un rôle ou à supprimer aussi.</p>
  <div class="legend">
    <span class="lg" style="--c:#256B58">A une fonction</span>
    <span class="lg" style="--c:#7A5C1E">Naturel / obstacle</span>
    <span class="lg" style="--c:#3A5B8C">Butin</span>
    <span class="lg" style="--c:#9A2E2E">Sans fonction — à trancher</span>
  </div>
</header>
<div class="grid">{''.join(cards)}</div>
</div>'''

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8") as f:
    f.write(html)
print("catalogue ecrit:", OUT, f"({os.path.getsize(OUT)//1024} Ko, {len(DECOR)} decors)")
