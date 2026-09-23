import base64, io, glob, os
from PIL import Image

ENE = "game/assets/enemies"

def load_front(chassis):
    for anim in ["idle", "walk", "hover", "attack", "run"]:
        p = f"{ENE}/{chassis}_{anim}_front.png"
        if os.path.exists(p):
            return Image.open(p).convert("RGBA")
    # fallback: any front sheet for this chassis
    g = sorted(glob.glob(f"{ENE}/{chassis}_*_front.png"))
    if g:
        return Image.open(g[0]).convert("RGBA")
    # last resort: any sheet
    g = sorted(glob.glob(f"{ENE}/{chassis}_*.png"))
    return Image.open(g[0]).convert("RGBA") if g else None

def frame(chassis, idx=0, out=170):
    sh = load_front(chassis)
    if sh is None:
        return None
    fw = sh.height  # square frames, N across
    n = max(1, sh.width // fw)
    idx = min(idx, n - 1)
    fr = sh.crop((fw * idx, 0, fw * (idx + 1), sh.height))
    bb = fr.getbbox()
    if bb:
        fr = fr.crop(bb)
    # fit into out x out, keep aspect, centered
    s = out / max(fr.width, fr.height)
    fr = fr.resize((max(1, int(fr.width * s)), max(1, int(fr.height * s))), Image.LANCZOS)
    canvas = Image.new("RGBA", (out, out), (0, 0, 0, 0))
    canvas.paste(fr, ((out - fr.width) // 2, (out - fr.height) // 2), fr)
    return canvas

def tint(im, col):
    if im is None:
        return None
    r, g, b = col
    lr = [min(255, int(i * r)) for i in range(256)]
    lg = [min(255, int(i * g)) for i in range(256)]
    lb = [min(255, int(i * b)) for i in range(256)]
    R, G, B, A = im.split()
    return Image.merge("RGBA", (R.point(lr), G.point(lg), B.point(lb), A))

def b64(im):
    bio = io.BytesIO(); im.save(bio, "PNG"); return base64.b64encode(bio.getvalue()).decode()

TINT = {
    "tech": (0.82, 0.92, 1.10), "earth": (1.10, 0.92, 0.70), "spaceship": (0.90, 0.88, 1.14),
    "volcanic": (1.30, 0.72, 0.54), "desert": (1.16, 1.00, 0.68), "ice": (0.74, 0.94, 1.18),
    "jungle": (0.76, 1.14, 0.74), "swamp": (0.86, 1.04, 0.68), "ruines": (1.08, 0.90, 0.78),
}
BIOME_NAME = {"tech": "SECTEUR TECH", "earth": "FRICHE", "spaceship": "VAISSEAU (faible G)",
    "volcanic": "VOLCAN", "desert": "DÉSERT", "ice": "GLACE", "jungle": "JUNGLE",
    "swamp": "MARAIS", "ruines": "RUINES"}

UNIV = [("Rôdeur", "brute", "NUÉE — corps-à-corps"), ("Guêpe", "drone", "HARCELEUR — tir volant"),
        ("Bélier", "quadshell", "CHARGEUR — fonce")]
SPEC = {
    "tech": [("Sentinelle", "shielded", "PORTE-BOUCLIER"), ("Tourelle", "warden", "TIREUR")],
    "earth": [("Charognard", "elite", "NUÉE+"), ("Broyeur", "crusher", "MASSE")],
    "spaceship": [("Voltigeur", "quadshell", "CHARGEUR erratique"), ("Essaim", "eyedrone", "HARCELEUR×")],
    "volcanic": [("Lance-feu", "warden", "TIREUR"), ("Fondeur", "crusher", "MASSE")],
    "desert": [("Pillard", "elite", "NUÉE rapide"), ("Foreuse", "quadshell", "CHARGEUR lourd")],
    "ice": [("Éclat", "shielded", "PORTE-BOUCLIER"), ("Givre", "crusher", "MASSE lente")],
    "jungle": [("Fourmi", "brute", "NUÉE××"), ("Cracheur", "warden", "TIREUR")],
    "swamp": [("Rampant", "shielded", "PORTE-BOUCLIER"), ("Sangsue", "crusher", "MASSE")],
    "ruines": [("Garde d'assaut", "elite", "MÊLÉE d'élite"), ("Artilleur", "warden", "TIREUR")],
}

def card(name, chassis, role, col):
    im = tint(frame(chassis), col)
    src = b64(im) if im else ""
    return (f'<figure class="c"><div class="im"><img src="data:image/png;base64,{src}" alt="{name}"></div>'
            f'<figcaption><b>{name}</b><span>{role}</span></figcaption></figure>')

univ = "".join(card(n, ch, r, (1, 1, 1)) for n, ch, r in UNIV)
sections = ""
for b in ["tech", "earth", "spaceship", "volcanic", "desert", "ice", "jungle", "swamp", "ruines"]:
    col = TINT[b]
    tiles = card("Rôdeur", "brute", "universel (teinté)", col)  # show corruption on a universal
    for n, ch, r in SPEC[b]:
        tiles += card(n, ch, r, col)
    sw = "%d,%d,%d" % (int(col[0] * 90), int(col[1] * 90), int(col[2] * 90))
    sections += (f'<section><h3><span class="dot" style="background:rgb({sw})"></span>{BIOME_NAME[b]}</h3>'
                 f'<div class="row">{tiles}</div></section>')

html = f'''<title>MECHA-FORGE — Bestiaire visuel</title>
<style>
:root{{--bg:#0e1117;--panel:#161b24;--ink:#eef2f8;--mut:#9aa4b6;--faint:#6a7385;--line:#262e3b;--ac:#e0733a;--ac2:#40c0d8}}
@media(prefers-color-scheme:light){{:root{{--bg:#eef1f6;--panel:#fff;--ink:#151a22;--mut:#586074;--faint:#8b93a4;--line:#e2e7ee}}}}
:root[data-theme="dark"]{{--bg:#0e1117;--panel:#161b24;--ink:#eef2f8;--mut:#9aa4b6;--faint:#6a7385;--line:#262e3b}}
:root[data-theme="light"]{{--bg:#eef1f6;--panel:#fff;--ink:#151a22;--mut:#586074;--faint:#8b93a4;--line:#e2e7ee}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--ink);font-family:ui-sans-serif,system-ui,"Segoe UI",Roboto,sans-serif;padding:34px 16px 64px}}
.wrap{{max-width:960px;margin:0 auto}}h1{{font-size:clamp(23px,4.5vw,36px);font-weight:850;margin:0 0 4px;letter-spacing:-.01em}}
.lede{{color:var(--mut);font-size:15px;max-width:70ch;margin:0 0 8px}}
h2{{font-size:12px;letter-spacing:.16em;text-transform:uppercase;color:var(--ac);font-weight:800;margin:34px 0 12px}}
h3{{font-size:14px;font-weight:750;margin:22px 0 10px;display:flex;align-items:center;gap:9px;color:var(--ac2)}}
.dot{{width:12px;height:12px;border-radius:50%;display:inline-block;box-shadow:0 0 0 1px var(--line)}}
.row{{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}}
@media(max-width:640px){{.row{{grid-template-columns:repeat(2,1fr)}}}}
.c{{margin:0;background:var(--panel);border:1px solid var(--line);border-radius:12px;overflow:hidden}}
.im{{background:repeating-conic-gradient(#0000 0% 25%,#ffffff08 0% 50%) 0/22px 22px;display:flex;align-items:center;justify-content:center;padding:8px}}
.im img{{display:block;width:100%;max-width:150px;height:auto;image-rendering:auto}}
figcaption{{padding:9px 11px 11px;border-top:1px solid var(--line)}}figcaption b{{display:block;font-size:14px}}figcaption span{{font-size:11.5px;color:var(--mut)}}
.note{{color:var(--faint);font-size:12.5px;margin-top:6px}}
</style>
<div class="wrap">
<h1>Bestiaire visuel — à valider</h1>
<p class="lede">Les vrais sprites (chassis bakés) avec la <b>teinte de corruption</b> de chaque biome. Les 3 universels sont montrés neutres, puis chaque biome affiche un universel <i>teinté</i> + ses 2 spécialistes — pour voir la corruption <b>et</b> les spécialistes.</p>
<p class="note">Rappel : tout est machine, aucun re-bake — la variété par carte vient des rôles + de la teinte. La teinte est volontairement subtile (lisibilité) ; je peux la renforcer si tu veux.</p>
<h2>Universels — sur toutes les cartes</h2>
<div class="row">{univ}</div>
<h2>Par biome — un universel teinté + 2 spécialistes</h2>
{sections}
</div>'''
open("cine/artifact/bestiary_visual.html", "w", encoding="utf-8").write(html)
print("OK bestiary_visual.html", len(html) // 1024, "Ko")
