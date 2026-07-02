#!/usr/bin/env python3
"""
mecha-forge — animated walk-cycle proof v2.

Composites the rendered part-layers with the SHARED procedural animation model
(constants live in rig.json; MechaRig.gd implements the identical math) into a
looping GIF. v2 after the art-director pass:
- TWO-SEGMENT legs (thigh FK about hip + shin FK about knee) → a knee that bends,
  feet that visibly lift and PLANT (with a squash beat) — the walk must read.
- torso weight: bob dips on each footfall, lateral shift toward the planted foot,
  rock about the pelvis; head follows with a small lag.
- weapons inherit the torso motion (no more floating off the shoulders), kick along
  -aim on fire with a 2-frame white→cyan muzzle flash and a torso counter-rock.

Screen convention: +y down, angles + = clockwise on screen (Godot-compatible).
PIL's Image.rotate is CCW-visual, hence rotate(-degrees(a)).

  python preview_gif.py
"""
import os, json, math
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MECHA = os.path.join(ROOT, "game", "assets", "mecha")
WEAP = os.path.join(ROOT, "game", "assets", "weapons")
DOCS = os.path.join(ROOT, "docs")
os.makedirs(DOCS, exist_ok=True)

rig = json.load(open(os.path.join(MECHA, "rig.json")))
A = rig["anim"]
F = int(rig["frame"])
CX = CY = F / 2.0

N = 48        # frames in the loop
STRIDES = 2   # leg cycles per loop
FPS = 20

CHASSIS = ["thigh_left", "thigh_right", "shin_left", "shin_right", "torso", "core", "head"]
L = {n: Image.open(os.path.join(MECHA, n + ".png")).convert("RGBA") for n in CHASSIS}
W = {n: Image.open(os.path.join(WEAP, n + ".png")).convert("RGBA") for n in ["autocannon", "missilepod"]}

HIP = {s: tuple(rig["hips"][s]) for s in ("left", "right")}
KNEE = {s: tuple(rig["knees"][s]) for s in ("left", "right")}
FOOT = {s: tuple(rig["feet"][s]) for s in ("left", "right")}
SHOULDER = {s: tuple(rig["shoulders"][s]) for s in ("left", "right")}
ROCK_PIVOT = (0.0, HIP["left"][1])   # rock about the pelvis line → shoulders sway most


def rot2(v, a):
    """screen-space rotation, +a = clockwise visually (y down)."""
    c, s = math.cos(a), math.sin(a)
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c)


def comp(canvas, img, a=0.0, pivot=(0.0, 0.0), translate=(0.0, 0.0), scale_y=1.0, anchor_y=None):
    """Composite a full-frame layer rotated by `a` about `pivot` (frame coords rel
    center) then translated. Optional vertical squash keeping `anchor_y` fixed."""
    im = img
    dy_sq = 0.0
    if scale_y != 1.0:
        h2 = max(1, int(round(F * scale_y)))
        im = im.resize((F, h2), Image.LANCZOS)
        pad = Image.new("RGBA", (F, F), (0, 0, 0, 0))
        pad.paste(im, (0, 0), im)
        im = pad
        ay = CY + (anchor_y if anchor_y is not None else 0.0)
        dy_sq = ay * (1.0 - scale_y)
    if a != 0.0:
        im = im.rotate(-math.degrees(a), resample=Image.BICUBIC, center=(CX, CY))
    dx = pivot[0] - rot2(pivot, a)[0] + translate[0]
    dy = pivot[1] - rot2(pivot, a)[1] + translate[1] + dy_sq
    shifted = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    shifted.paste(im, (int(round(dx)), int(round(dy))), im)
    canvas.alpha_composite(shifted, (0, 0))


def make_bg():
    bg = Image.new("RGBA", (F, F), (14, 13, 24, 255))
    d = ImageDraw.Draw(bg)
    for x in range(0, F, 48):
        d.line([(x, 0), (x, F)], fill=(26, 26, 42, 255), width=1)
    for y in range(0, F, 48):
        d.line([(0, y), (F, y)], fill=(26, 26, 42, 255), width=1)
    return bg

BG = make_bg()


def muzzle_flash(size, heat):
    """heat 1.0 = frame 0 (white-hot), 0.5 = frame 1 (cyan tail)."""
    m = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(m)
    c = size / 2.0
    rings = [(size * 0.50, (90, 220, 255), 70), (size * 0.32, (160, 240, 255), 150),
             (size * 0.16, (255, 255, 255), 235)]
    for r, col, alpha in rings:
        rr = r * (0.6 + 0.4 * heat)
        d.ellipse([c - rr, c - rr, c + rr, c + rr], fill=(*col, int(alpha * heat)))
    return m.filter(ImageFilter.GaussianBlur(1.6))


def leg_pose(side, p):
    """Two-segment FK leg. Returns (thigh transform, shin transform) as dicts.
    Legs are in ANTIPHASE: the right leg runs half a cycle behind the left."""
    sg = -1.0 if side == "left" else 1.0     # mirror the gait
    if side == "right":
        p = p + math.pi                       # antiphase — one leg up while the other plants
    swing = max(0.0, math.sin(p))            # leg airborne
    stance = max(0.0, -math.sin(p))          # leg planted
    th = sg * A["thigh_rot"] * swing          # thigh swings out during the step
    dx = A["stride"] * F * math.sin(p) * 0.35
    dyt = -A["lift_thigh"] * F * swing
    thigh = {"a": th, "pivot": HIP[side], "translate": (dx, dyt)}
    # knee position after the thigh transform
    kx = rot2(KNEE[side], th)
    kdx = HIP[side][0] - rot2(HIP[side], th)[0] + dx
    kdy = HIP[side][1] - rot2(HIP[side], th)[1] + dyt
    knee_now = (kx[0] + kdx, kx[1] + kdy)
    # shin: extra knee bend + extra lift during swing; squash on plant
    ps = th + sg * A["shin_rot"] * swing
    extra = -A["lift_shin"] * F * swing
    sq = 1.0 - A["squash"] * (stance ** 3)
    # solve shin translate so its KNEE anchor lands on knee_now (+extra lift)
    sdx = knee_now[0] - rot2(KNEE[side], ps)[0]
    sdy = knee_now[1] - rot2(KNEE[side], ps)[1] + extra
    shin = {"a": ps, "pivot": (0.0, 0.0), "translate": (sdx, sdy),
            "scale_y": sq, "anchor_y": FOOT[side][1]}
    # translate is absolute here (pivot 0), since we solved the offset directly
    return thigh, shin


def frame(i):
    t = i / N
    p = 2 * math.pi * STRIDES * t

    # torso weight: dip on each footfall (p=0, pi), lateral toward planted foot, rock
    dip = (0.5 + 0.5 * math.cos(2 * p)) ** 1.5
    bob = A["bob"] * F * dip
    lat = A["lat"] * F * math.sin(p)
    rock = A["rock"] * math.sin(p)
    head_dy = A["head_bob"] * F * (0.5 + 0.5 * math.cos(2 * p - 0.6))
    # gentle brightness breathing — never dips into 'dead grey disc' territory
    core_a = 0.88 + 0.12 * math.sin(2 * math.pi * A["core_pulse_hz"] * (i / FPS))

    # fire events (right at 1/4, left at 3/4) + recoil impulses
    def rc(fire_i):
        d = (i - fire_i) % N
        return math.exp(-d / 2.2) if d < 8 else 0.0
    rc_r, rc_l = rc(N // 4), rc(3 * N // 4)
    rock += A["recoil_rock"] * (rc_l - rc_r) * 0.6   # counter-rock on fire

    aim_r = math.radians(-14.0 + 10.0 * math.sin(2 * math.pi * t))   # up-right, small sweep
    aim_l = math.radians(194.0 + 10.0 * math.sin(2 * math.pi * t))   # up-left

    canvas = BG.copy()

    # ground shadow (squash with bob)
    sh = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    fy = CY + FOOT["left"][1] + 8
    sw = 150 - bob * 2.5
    sd.ellipse([CX - sw / 2, fy - 15, CX + sw / 2, fy + 15], fill=(0, 0, 0, 130))
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)), (0, 0))

    # legs (thigh behind shin)
    for side in ("left", "right"):
        thigh, shin = leg_pose(side, p)
        comp(canvas, L["thigh_%s" % side], thigh["a"], thigh["pivot"], thigh["translate"])
    for side in ("left", "right"):
        thigh, shin = leg_pose(side, p)
        comp(canvas, L["shin_%s" % side], shin["a"], shin["pivot"], shin["translate"],
             shin["scale_y"], shin["anchor_y"])

    # torso + core + head (rock about pelvis, bob+lat translate)
    comp(canvas, L["torso"], rock, ROCK_PIVOT, (lat, bob))
    core = L["core"].copy()
    core.putalpha(core.getchannel("A").point(lambda v: int(v * core_a)))
    # cheap bloom: blurred copy under the sharp core sells the emissive glow
    glow = core.filter(ImageFilter.GaussianBlur(6))
    glow.putalpha(glow.getchannel("A").point(lambda v: int(v * 0.8)))
    comp(canvas, glow, rock, ROCK_PIVOT, (lat, bob))
    comp(canvas, core, rock, ROCK_PIVOT, (lat, bob))
    comp(canvas, L["head"], rock * 0.5, ROCK_PIVOT, (lat, bob + head_dy))

    # weapons: mount inherits the torso motion, then aim + recoil
    def weapon(name, side, aim, kick):
        m = SHOULDER[side]
        mr = rot2((m[0] - ROCK_PIVOT[0], m[1] - ROCK_PIVOT[1]), rock)
        mount = (mr[0] + ROCK_PIVOT[0] + lat, mr[1] + ROCK_PIVOT[1] + bob)
        av = (math.cos(aim), math.sin(aim))
        k = kick * A["recoil"] * F
        tr = (mount[0] - av[0] * k, mount[1] - av[1] * k)
        comp(canvas, W[name], aim, (0.0, 0.0), tr)
        muz = rig["weapons"][name]["muzzle"][0]
        tip = (CX + tr[0] + rot2((muz, 0.0), aim)[0], CY + tr[1] + rot2((muz, 0.0), aim)[1])
        return tip
    tip_r = weapon("autocannon", "right", aim_r, rc_r)
    tip_l = weapon("missilepod", "left", aim_l, rc_l)

    # muzzle flashes (2-frame white → cyan)
    for tip, fire_i in ((tip_r, N // 4), (tip_l, 3 * N // 4)):
        d = (i - fire_i) % N
        if d < 2:
            fl = muzzle_flash(64, 1.0 - 0.5 * d)
            canvas.alpha_composite(fl, (int(tip[0] - 32), int(tip[1] - 32)))

    return canvas.convert("RGB")


def main():
    frames = [frame(i) for i in range(N)]
    box = (30, 8, F - 30, F - 4)
    frames = [f.crop(box) for f in frames]
    out = os.path.join(DOCS, "mecha_walk.gif")
    frames[0].save(out, save_all=True, append_images=frames[1:],
                   duration=int(1000 / FPS), loop=0, optimize=True)
    frames[N // 4].save(os.path.join(DOCS, "mecha_hero.png"))

    # contact sheet (8 frames across the loop)
    idx = [0, 6, 12, 18, 24, 30, 36, 42]
    w, h = frames[0].size
    sheet = Image.new("RGB", (w * 4, h * 2), (8, 8, 14))
    for k, j in enumerate(idx):
        sheet.paste(frames[j], ((k % 4) * w, (k // 4) * h))
    sheet.save(os.path.join(DOCS, "mecha_contact.png"))

    # phone-scale readability test: the hero frame at in-game sprite size (~72px)
    hero = frames[N // 4]
    small = hero.resize((72, 72), Image.LANCZOS)
    strip = Image.new("RGB", (72 * 4, 72), (10, 9, 18))
    for k in range(4):
        strip.paste(frames[idx[k * 2]].resize((72, 72), Image.LANCZOS), (72 * k, 0))
    strip = strip.resize((72 * 4 * 3, 72 * 3), Image.NEAREST)   # zoom for inspection
    strip.save(os.path.join(DOCS, "mecha_phone_scale.png"))
    print("GIF", out, "frames", N)


if __name__ == "__main__":
    main()
