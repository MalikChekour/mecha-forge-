"""Chroma-key detour: remove the solid green (#00FF00) or magenta (#FF00FF) background to
transparent, despill the edge fringe, and autocrop to the object. This is the exact step used to
bring a generated prop into the game — run it here first to review the result.
"""
import os, sys
import numpy as np
from PIL import Image, ImageFilter


def detour(src, dst):
    im = Image.open(src).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # detect background from the 4 corners
    c = np.concatenate([a[:14, :14].reshape(-1, 3), a[:14, -14:].reshape(-1, 3),
                        a[-14:, :14].reshape(-1, 3), a[-14:, -14:].reshape(-1, 3)])
    bg = np.median(c, axis=0)
    green = bg[1] > bg[0] and bg[1] > bg[2]
    if green:
        key = g - np.maximum(r, b)            # high on green bg, ~0 on the object
        g = np.minimum(g, np.maximum(r, b))   # despill: kill green spill
    else:                                     # magenta
        key = np.minimum(r, b) - g
        spill = key > 0
        r = np.where(spill, g + (r - g) * 0.35, r)  # despill magenta
        b = np.where(spill, g + (b - g) * 0.35, b)
    # soft alpha ramp: key>=60 -> transparent, key<=15 -> opaque
    alpha = np.clip((60.0 - key) / 45.0, 0.0, 1.0)
    rgba = np.dstack([np.stack([r, g, b], -1), alpha * 255.0]).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA")
    # feather the alpha edge 1px so the cutout isn't jagged
    al = img.getchannel("A").filter(ImageFilter.GaussianBlur(0.6))
    img.putalpha(al)
    bbox = img.getbbox()
    if bbox:
        # small margin so the crop doesn't clip a soft glow
        x0, y0, x1, y1 = bbox
        m = 8
        img = img.crop((max(0, x0 - m), max(0, y0 - m),
                        min(img.width, x1 + m), min(img.height, y1 + m)))
    img.save(dst)
    return img.size


if __name__ == "__main__":
    print(detour(sys.argv[1], sys.argv[2]))
