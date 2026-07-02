#!/usr/bin/env python3
"""
mecha-forge — animated walk-cycle proof.

Composites the rendered part-layers with the SHARED procedural animation model
(the identical math is reimplemented in game/actors/MechaRig.gd) into a looping
GIF: heavy-mecha walk (alternating leg stomp + weight bob + torso rock), core
reactor pulse, and the two shoulder hardpoints sweeping their aim + kicking on
fire with a muzzle flash. This is the visible artifact; the engine rig is the
runtime twin.

  python preview_gif.py
"""
import os, json, math
from PIL import Image, ImageDraw, ImageFilter

MECHA = r"C:\Users\Administrator\mecha-forge\game\assets\mecha"
WEAP = r"C:\Users\Administrator\mecha-forge\game\assets\weapons"
DOCS = r"C:\Users\Administrator\mecha-forge\docs"
os.makedirs(DOCS, exist_ok=True)

rig = json.load(open(os.path.join(MECHA, "rig.json")))
F = rig["frame"]
CX = CY = F / 2.0

# ---- shared animation constants (fractions of frame; mirrored in MechaRig.gd) ----
A_LIFT   = 0.028   # leg vertical lift on swing
A_STRIDE = 0.016   # leg fore/aft stride
A_BOB    = 0.014   # torso vertical weight-bob
A_ROCK   = 0.030   # torso rock (radians)
A_HEADB  = 0.010   # head extra bob
RECOIL   = 0.055   # weapon kick (fraction of frame) along -aim
FLASH_FR = 2       # muzzle-flash duration (frames)

N = 48             # frames in the loop
STRIDES = 2        # leg cycles per loop
FPS = 20


def load(p):
    return Image.open(p).convert("RGBA")

L = {n: load(os.path.join(MECHA, n + ".png")) for n in ["leg_left", "leg_right", "torso", "core", "head"]}
W = {n: load(os.path.join(WEAP, n + ".png")) for n in ["autocannon", "missilepod"]}


def shifted(im, dx, dy):
    c = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    c.paste(im, (int(round(dx)), int(round(dy))), im)
    return c


def rot_about_center(im, deg):
    # rotate about texture center (== rig root for chassis, == mount for weapons)
    return im.rotate(deg, resample=Image.BICUBIC, center=(CX, CY))


def make_bg():
    bg = Image.new("RGBA", (F, F), (16, 15, 26, 255))
    d = ImageDraw.Draw(bg)
    step = 48
    for x in range(0, F, step):
        d.line([(x, 0), (x, F)], fill=(30, 30, 48, 255), width=1)
    for y in range(0, F, step):
        d.line([(0, y), (F, y)], fill=(30, 30, 48, 255), width=1)
    return bg

BG = make_bg()


def muzzle_flash(size, intensity):
    m = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(m)
    c = size / 2.0
    for r, a in ((size*0.5, 60), (size*0.34, 130), (size*0.18, 230)):
        col = (150, 235, 255, int(a * intensity))
        d.ellipse([c-r, c-r, c+r, c+r], fill=col)
    return m.filter(ImageFilter.GaussianBlur(1.5))


def frame(i):
    t = i / N
    ph = 2 * math.pi * STRIDES * t                       # walk phase
    # legs: opposite phase; lift is a positive-only swing, stride is fore/aft
    def leg(off):
        p = ph + off
        dy = -A_LIFT * F * max(0.0, math.sin(p))          # up on swing
        dy += A_STRIDE * F * math.cos(p) * 0.5            # settle
        dx = A_STRIDE * F * math.sin(p) * 0.35
        return dx, dy
    ll_dx, ll_dy = leg(0.0)
    lr_dx, lr_dy = leg(math.pi)
    # torso weight-bob (dips on each footfall) + rock
    bob = A_BOB * F * (0.5 - 0.5 * math.cos(2 * ph))       # 0..1 twice/cycle
    rock = A_ROCK * math.sin(ph)
    head_dy = -A_HEADB * F * (0.5 - 0.5 * math.cos(2 * ph))
    core_pulse = 0.75 + 0.25 * math.sin(2 * math.pi * (t * 1.5))

    # weapon aim sweep (degrees, screen). +CCW. Right gun up-right, left up-left.
    sweep = 30.0 * math.sin(2 * math.pi * t)
    aim_r = -18.0 + sweep       # autocannon (right shoulder)
    aim_l = 198.0 + sweep       # missilepod (left shoulder)

    # fire events: right at 1/4, left at 3/4
    def recoil(fire_i):
        d = (i - fire_i) % N
        return math.exp(-d / 3.0) if d < 8 else 0.0
    rc_r = recoil(N // 4)
    rc_l = recoil(3 * N // 4)

    canvas = BG.copy()
    # ground shadow (squashes with bob)
    sh = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    fy = CY + rig["feet"]["left"][1]
    sw = 128 - bob * 2.2
    sd.ellipse([CX - sw/2, fy - 14, CX + sw/2, fy + 14], fill=(0, 0, 0, 120))
    canvas = Image.alpha_composite(canvas, sh.filter(ImageFilter.GaussianBlur(4)))

    # chassis, back-to-front
    canvas = Image.alpha_composite(canvas, shifted(L["leg_left"], ll_dx, ll_dy))
    canvas = Image.alpha_composite(canvas, shifted(L["leg_right"], lr_dx, lr_dy))
    torso = rot_about_center(L["torso"], math.degrees(rock))
    canvas = Image.alpha_composite(canvas, shifted(torso, 0, bob))
    # core (pulse via alpha)
    core = L["core"].copy()
    ca = core.getchannel("A").point(lambda v: int(v * core_pulse))
    core.putalpha(ca)
    canvas = Image.alpha_composite(canvas, shifted(rot_about_center(core, math.degrees(rock)), 0, bob))
    canvas = Image.alpha_composite(canvas, shifted(L["head"], 0, bob + head_dy))

    # weapons on shoulders (rotate about mount, shift to shoulder, apply recoil along -aim)
    def place_weapon(name, shoulder, aim_deg, rc):
        a = math.radians(aim_deg)
        kick = rc * RECOIL * F
        sx = shoulder[0] - math.cos(a) * kick
        sy = shoulder[1] + math.sin(a) * kick     # screen y down
        w = rot_about_center(W[name], aim_deg)
        return shifted(w, sx, sy), (sx, sy, a)
    wr, (rx, ry, ra) = place_weapon("autocannon", rig["shoulders"]["right"], aim_r, rc_r)
    wl, (lx, ly, la) = place_weapon("missilepod", rig["shoulders"]["left"], aim_l, rc_l)
    canvas = Image.alpha_composite(canvas, wr)
    canvas = Image.alpha_composite(canvas, wl)

    # muzzle flashes
    def flash(name, sx, sy, a, rc, fire_i):
        d = (i - fire_i) % N
        if d >= FLASH_FR:
            return canvas
        muz = rig["weapons"][name]["muzzle"][0]
        mx = CX + sx + math.cos(a) * muz
        my = CY + sy + math.sin(a) * muz
        fl = muzzle_flash(64, 1.0 - d / FLASH_FR)
        c = canvas.copy()
        c.alpha_composite(fl, (int(mx - 32), int(my - 32)))
        return c
    canvas = flash("autocannon", rx, ry, ra, rc_r, N // 4)
    canvas = flash("missilepod", lx, ly, la, rc_l, 3 * N // 4)
    return canvas.convert("RGB")


def main():
    frames = [frame(i) for i in range(N)]
    # crop a bit tighter around the mecha for a punchier view
    box = (44, 26, F - 44, F - 20)
    frames = [f.crop(box) for f in frames]
    out = os.path.join(DOCS, "mecha_walk.gif")
    frames[0].save(out, save_all=True, append_images=frames[1:],
                   duration=int(1000 / FPS), loop=0, optimize=True)
    # also a static hero + spritesheet strip
    frames[N // 4].save(os.path.join(DOCS, "mecha_hero.png"))
    print("GIF", out, "frames", N)


if __name__ == "__main__":
    main()
