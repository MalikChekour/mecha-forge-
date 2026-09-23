"""Hand-crafted TRUE pixel-art mecha (v2): native low-res, limited palette, chamfered angled plates
(hard-surface look, not boxy), heroic proportions, authored per-frame leg poses -> crisp + 100%
consistent, no AI. Renders idle + walk strip/GIF, nearest-neighbor upscaled."""
import os, math
from PIL import Image, ImageDraw

OUT = r"C:\Users\Administrator\mecha-forge\cine\pixmech"
os.makedirs(OUT, exist_ok=True)

P = {
    "out": (12, 14, 24), "sd": (34, 39, 60), "md": (54, 62, 92), "lt": (90, 102, 140),
    "hl": (150, 165, 205), "asd": (150, 68, 24), "alt": (238, 134, 58), "ah": (255, 186, 110),
    "co": (34, 140, 195), "cl": (86, 216, 255), "cb": (210, 250, 255), "mtl": (120, 130, 150),
}
W, H = 54, 68


def poly(d, pts, base, light=None, shadow=None):
    d.polygon(pts, fill=base, outline=P["out"])
    if light:   # top + left edges
        d.line([pts[0], pts[1]], fill=light)
        d.line([pts[-1], pts[0]], fill=light)
    if shadow:  # bottom edge (pts assumed clockwise from top-left)
        n = len(pts)
        d.line([pts[n // 2], pts[n // 2 + 1]] if n > 3 else [pts[1], pts[2]], fill=shadow)


def chamf(d, x0, y0, x1, y1, base, light, shadow, c=2):
    """A rectangular plate with chamfered top corners -> reads as armor, not a box."""
    pts = [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1), (x0, y1), (x0, y0 + c)]
    d.polygon(pts, fill=base, outline=P["out"])
    d.line([(x0 + c, y0), (x1 - c, y0)], fill=light)     # top light
    d.line([(x0, y0 + c), (x0, y1)], fill=light)         # left light
    d.line([(x1, y0 + c), (x1, y1)], fill=shadow)        # right shadow
    d.line([(x0, y1), (x1, y1)], fill=shadow)            # bottom shadow


def leg(d, hipx, lift, fwd, front):
    ty = 42 - lift
    lt, md, sd = (P["lt"], P["md"], P["sd"]) if front else (P["md"], P["sd"], P["out"])
    # thigh (angled, armored)
    poly(d, [(hipx - 3, ty), (hipx + 3, ty), (hipx + 3, ty + 8), (hipx + fwd + 2, ty + 9),
             (hipx + fwd - 2, ty + 9), (hipx - 3, ty + 8)], md, lt, sd)
    kx = hipx + fwd
    # knee accent
    d.rectangle([kx - 2, ty + 8, kx + 1, ty + 9], fill=P["asd"])
    # shin
    chamf(d, kx - 3, ty + 9, kx + 3, ty + 18, sd, md, P["out"], c=1)
    d.line([kx - 2, ty + 11, kx - 2, ty + 16], fill=P["mtl"])   # piston glint
    # foot (angled forward)
    poly(d, [(kx - 3, ty + 18), (kx + 4, ty + 18), (kx + 6, ty + 21), (kx - 3, ty + 21)], P["sd"], P["md"], P["out"])


def torso(d, bob, armswing=0):
    o = bob
    # antennae
    for ax in (20, 30):
        d.line([ax, 0 + o, ax, 5 + o], fill=P["out"]); d.point([ax, 0 + o], fill=P["ah"])
    # head/visor (chamfered helmet)
    chamf(d, 20, 5 + o, 31, 14 + o, P["md"], P["lt"], P["sd"], c=2)
    d.rectangle([22, 8 + o, 29, 10 + o], fill=P["co"])
    d.rectangle([22, 8 + o, 24, 9 + o], fill=P["cl"]); d.point([22, 8 + o], fill=P["cb"])
    # pauldrons (big, chamfered outward, rim-lit left)
    chamf(d, 3, 13 + o, 17, 24 + o, P["md"], P["hl"], P["sd"], c=3)
    chamf(d, 34, 13 + o, 48, 24 + o, P["md"], P["lt"], P["sd"], c=3)
    d.rectangle([6, 16 + o, 9, 19 + o], fill=P["asd"]); d.rectangle([6, 16 + o, 7, 17 + o], fill=P["alt"])
    d.rectangle([41, 16 + o, 44, 19 + o], fill=P["alt"]); d.rectangle([43, 18 + o, 44, 19 + o], fill=P["asd"])
    # upper arms + fists (swing with walk)
    aL = armswing; aR = -armswing
    chamf(d, 5, 24 + o, 12, 33 + o + aL, P["sd"], P["md"], P["out"], c=1)
    chamf(d, 39, 24 + o, 46, 33 + o + aR, P["sd"], P["md"], P["out"], c=1)
    poly(d, [(5, 33 + o + aL), (12, 33 + o + aL), (12, 39 + o + aL), (6, 40 + o + aL), (5, 39 + o + aL)], P["md"], P["lt"], P["sd"])
    poly(d, [(39, 33 + o + aR), (46, 33 + o + aR), (46, 39 + o + aR), (40, 40 + o + aR), (39, 39 + o + aR)], P["md"], P["lt"], P["sd"])
    # chest (broad, chamfered, tapering to waist)
    poly(d, [(18, 15 + o), (33, 15 + o), (34, 20 + o), (34, 30 + o), (30, 34 + o),
             (21, 34 + o), (17, 30 + o), (17, 20 + o)], P["md"], P["lt"], P["sd"])
    # chest side vents
    for vx in (19, 31):
        d.line([vx, 24 + o, vx, 30 + o], fill=P["sd"])
    # core reactor (glowing, layered)
    cx, cy = 25, 23 + o
    d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=P["out"])
    d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=P["co"])
    d.ellipse([cx - 2, cy - 3, cx + 2, cy + 3], fill=P["cl"])
    d.rectangle([cx - 1, cy - 1, cx + 1, cy + 1], fill=P["cb"])
    # abdomen / hip block
    chamf(d, 19, 34 + o, 31, 43 + o, P["sd"], P["md"], P["out"], c=1)
    d.rectangle([23, 37 + o, 27, 39 + o], fill=P["asd"]); d.rectangle([23, 37 + o, 25, 38 + o], fill=P["alt"])


def frame(kind, i, n):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if kind == "idle":
        bob = -1 if i % 2 == 0 else 0
        leg(d, 21, 0, 0, front=False); leg(d, 29, 0, 0, front=True)
        torso(d, bob, 0)
    else:
        ph = 2 * math.pi * i / n
        s = math.sin(ph)
        bob = -1 if abs(s) > 0.5 else 0
        liftL = 4 if s > 0.3 else 0
        liftR = 4 if s < -0.3 else 0
        fwdL = int(round(4 * s)); fwdR = int(round(-4 * s))
        arms = int(round(-2 * s))
        # planted leg drawn in front for depth
        if s >= 0:
            leg(d, 29, liftR, fwdR, front=False); leg(d, 21, liftL, fwdL, front=True)
        else:
            leg(d, 21, liftL, fwdL, front=False); leg(d, 29, liftR, fwdR, front=True)
        torso(d, bob, arms)
    return im


def up(im, k=8):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


idle = [frame("idle", i, 2) for i in range(2)]
walk = [frame("walk", i, 6) for i in range(6)]


def strip(frames, name, k=7):
    cells = []
    for f in frames:
        u = up(f, k); bg = Image.new("RGB", u.size, (30, 33, 42)); bg.paste(u, (0, 0), u); cells.append(bg)
    board = Image.new("RGB", (sum(c.width for c in cells) + 6 * (len(cells) - 1), cells[0].height), (18, 20, 26))
    x = 0
    for c in cells:
        board.paste(c, (x, 0)); x += c.width + 6
    board.save(os.path.join(OUT, name))


strip(idle + walk, "sheet.png")
disp = []
for f in walk:
    u = up(f, 8); bg = Image.new("RGB", u.size, (30, 33, 42)); bg.paste(u, (0, 0), u); disp.append(bg)
pal = disp[0].quantize(colors=64)
q = [x.quantize(palette=pal) for x in disp]
q[0].save(os.path.join(OUT, "walk.gif"), save_all=True, append_images=q[1:], duration=120, loop=0, disposal=2)
print("done", (W, H))
