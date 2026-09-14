#!/usr/bin/env python
"""
slice_hero_views.py — turns Gemini hero turnaround art into the game's 4-direction sprites.

Accepts, per hero <h> in h1..h4, EITHER:
  A) one horizontal 3-pose sheet  refs/hero_gemini/views_<h>.png   [FACE][RIGHT][BACK]
  B) three separate views         refs/hero_gemini/<h>_front.png / _right.png / _back.png

Pipeline per view:
  - re-encode (kills JFIF-in-png)         -> real PNG Godot can read
  - flood-fill magenta #FF00FF from border-> transparent (feathered)
  - autocrop to content bbox
  - normalize scale so all 4 dirs share one height, feet on a common baseline
Outputs:
  game/assets/mecha/<hero>_idle_front.png / _back.png / _left.png / _right.png
  (left = mirror of right).  <hero> = "hx_gem".

Run:  python tools/slice_hero_views.py            # all heroes it can find
      python tools/slice_hero_views.py h1 h4      # only these
"""
import sys, os
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REFS = os.path.join(ROOT, "refs", "hero_gemini")
OUT  = os.path.join(ROOT, "game", "assets", "mecha")
TARGET_H = 220               # normalized sprite height in px

# rembg (u2net) session, created once. The Gemini planches use a pink/purple gradient
# background, not a flat chroma key, so an AI matte is far cleaner than a colour flood-fill.
_RB = None
def _rembg():
    global _RB
    if _RB is None:
        from rembg import new_session
        _RB = new_session("u2net")
    return _RB

def chroma_cut(im: Image.Image) -> Image.Image:
    """AI background removal (rembg) + slight feather + autocrop to content."""
    from rembg import remove
    im = im.convert("RGBA")
    cut = remove(im, session=_rembg(),
                 alpha_matting=True,
                 alpha_matting_foreground_threshold=240,
                 alpha_matting_background_threshold=15,
                 alpha_matting_erode_size=6)
    # gently feather the matte edge so it composites without a hard rim
    a = cut.split()[3].filter(ImageFilter.GaussianBlur(0.6))
    cut.putalpha(a)
    bbox = cut.getbbox()
    if bbox:
        cut = cut.crop(bbox)
    return cut

def load_real(path: str) -> Image.Image:
    """Load + force a clean re-encode (Gemini often saves JFIF-in-.png)."""
    im = Image.open(path)
    im.load()
    return im.convert("RGBA")

def split_sheet(im: Image.Image, n: int = 3):
    """Split a horizontal sheet into n equal columns, chroma-cut each."""
    w, h = im.size
    cw = w // n
    return [chroma_cut(im.crop((i*cw, 0, (i+1)*cw if i < n-1 else w, h))) for i in range(n)]

def normalize(views):
    """Scale every view to TARGET_H, pad to a common canvas, feet on baseline."""
    scaled = []
    maxw = 0
    for v in views:
        s = TARGET_H / max(1, v.height)
        v2 = v.resize((max(1, round(v.width*s)), TARGET_H), Image.LANCZOS)
        scaled.append(v2); maxw = max(maxw, v2.width)
    canvas_w = maxw + 8
    out = []
    for v in scaled:
        c = Image.new("RGBA", (canvas_w, TARGET_H+8), (0, 0, 0, 0))
        c.paste(v, ((canvas_w - v.width)//2, 0), v)
        out.append(c)
    return out

def process_hero(h: str) -> bool:
    # prefer the separate full-res views (1024 each) over a 3-in-one sheet (~341px/view)
    sep = {n: os.path.join(REFS, f"{h}_{n}.png") for n in ("front", "right", "back")}
    sheet = os.path.join(REFS, f"views_{h}.png")
    if all(os.path.exists(p) for p in sep.values()):
        front = chroma_cut(load_real(sep["front"]))
        right = chroma_cut(load_real(sep["right"]))
        back  = chroma_cut(load_real(sep["back"]))
    elif os.path.exists(sheet):
        front, right, back = split_sheet(load_real(sheet), 3)
    else:
        print(f"  [skip {h}] no views_{h}.png and no separate {h}_front/right/back.png")
        return False
    front, right, back = normalize([front, right, back])
    left = right.transpose(Image.FLIP_LEFT_RIGHT)
    chassis = f"{h}_gem"
    os.makedirs(OUT, exist_ok=True)
    mapping = {"front": front, "back": back, "right": right, "left": left}
    for d, img in mapping.items():
        img.save(os.path.join(OUT, f"{chassis}_idle_{d}.png"))
    print(f"  [{h}] -> {chassis}_idle_(front/back/left/right).png  {front.size}")
    return True

def main():
    heroes = [a.lower() for a in sys.argv[1:]] or ["h1", "h2", "h3", "h4"]
    done = 0
    for h in heroes:
        print(f"hero {h}:")
        if process_hero(h):
            done += 1
    print(f"\nDONE — {done}/{len(heroes)} heroes sliced into game/assets/mecha/")

if __name__ == "__main__":
    main()
