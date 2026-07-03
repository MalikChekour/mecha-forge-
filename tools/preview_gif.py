#!/usr/bin/env python3
"""
mecha-forge — animated showcase v3: TWO chassis, TWO loadouts, side by side.

This is the customization proof: VANGUARD (blue, crest head) with rotary
autocannon + missile pod, and TITAN (olive heavy, bunker head) with railgun +
plasmacaster — both assembled from the same part-layer system and animated by
the same procedural model, each with its own rig.json (anchors + gait constants,
so the titan walks slower and heavier).

The math here is the reference implementation of MechaRig.gd (same constants,
same transforms). Screen convention: +y down, +angle = clockwise on screen.

  python preview_gif.py
"""
import os, json, math
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MECHA = os.path.join(ROOT, "game", "assets", "mecha")
WEAP = os.path.join(ROOT, "game", "assets", "weapons")
DOCS = os.path.join(ROOT, "docs")
os.makedirs(DOCS, exist_ok=True)

N = 56        # frames in the loop
FPS = 20
CHASSIS_PARTS = ["thigh_left", "thigh_right", "shin_left", "shin_right", "torso", "core", "head"]

CANVAS_W, CANVAS_H = 760, 400


def rot2(v, a):
    c, s = math.cos(a), math.sin(a)
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c)


class Mecha:
    """One chassis instance: loads its part layers + rig.json, poses per frame."""

    def __init__(self, chassis, loadout):
        self.dir = os.path.join(MECHA, chassis)
        self.rig = json.load(open(os.path.join(self.dir, "rig.json")))
        self.A = self.rig["anim"]
        self.F = int(self.rig["frame"])
        self.C = self.F / 2.0
        self.L = {n: Image.open(os.path.join(self.dir, n + ".png")).convert("RGBA")
                  for n in CHASSIS_PARTS}
        self.W = {}
        # loadout: list of (weapon_id, side, base_aim_deg, fire_frame)
        self.loadout = loadout
        for wid, _side, _aim, _ff in loadout:
            if wid not in self.W:
                self.W[wid] = Image.open(os.path.join(WEAP, wid + ".png")).convert("RGBA")
        self.hip = {s: tuple(self.rig["hips"][s]) for s in ("left", "right")}
        self.knee = {s: tuple(self.rig["knees"][s]) for s in ("left", "right")}
        self.foot = {s: tuple(self.rig["feet"][s]) for s in ("left", "right")}
        self.shoulder = {s: tuple(self.rig["shoulders"][s]) for s in ("left", "right")}
        self.rock_pivot = (0.0, self.hip["left"][1])

    # -- layer compositor: rotate about pivot (frame coords rel center), translate,
    #    optional vertical squash keeping anchor_y fixed. Same as MechaRig._place. --
    def comp(self, canvas, ox, img, a=0.0, pivot=(0.0, 0.0), translate=(0.0, 0.0),
             scale_y=1.0, anchor_y=None):
        F, C = self.F, self.C
        im = img
        dy_sq = 0.0
        if scale_y != 1.0:
            h2 = max(1, int(round(F * scale_y)))
            im = im.resize((F, h2), Image.LANCZOS)
            pad = Image.new("RGBA", (F, F), (0, 0, 0, 0))
            pad.paste(im, (0, 0), im)
            im = pad
            ay = C + (anchor_y if anchor_y is not None else 0.0)
            dy_sq = ay * (1.0 - scale_y)
        if a != 0.0:
            im = im.rotate(-math.degrees(a), resample=Image.BICUBIC, center=(C, C))
        dx = pivot[0] - rot2(pivot, a)[0] + translate[0]
        dy = pivot[1] - rot2(pivot, a)[1] + translate[1] + dy_sq
        shifted = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        px = int(round(ox - C + dx))
        py = int(round(CANVAS_H / 2.0 - C + dy))
        shifted.paste(im, (px, py), im)
        canvas.alpha_composite(shifted, (0, 0))

    def leg_pose(self, side, p):
        A, F = self.A, self.F
        sg = -1.0 if side == "left" else 1.0
        if side == "right":
            p = p + math.pi
        swing = max(0.0, math.sin(p))
        stance = max(0.0, -math.sin(p))
        th = sg * A["thigh_rot"] * swing
        dx = A["stride"] * F * math.sin(p) * 0.35
        dyt = -A["lift_thigh"] * F * swing
        hip, knee, foot = self.hip[side], self.knee[side], self.foot[side]
        thigh = (th, hip, (dx, dyt))
        knee_now = (rot2(knee, th)[0] + hip[0] - rot2(hip, th)[0] + dx,
                    rot2(knee, th)[1] + hip[1] - rot2(hip, th)[1] + dyt)
        ps = th + sg * A["shin_rot"] * swing
        extra = -A["lift_shin"] * F * swing
        sq = 1.0 - A["squash"] * (stance ** 3)
        sdx = knee_now[0] - rot2(knee, ps)[0]
        sdy = knee_now[1] - rot2(knee, ps)[1] + extra
        shin = (ps, (0.0, 0.0), (sdx, sdy), sq, foot[1])
        return thigh, shin

    def draw(self, canvas, ox, i, t_glob):
        A, F = self.A, self.F
        # walk phase driven by this chassis' own cadence — the titan lumbers
        p = 2 * math.pi * A["step_freq"] * t_glob
        dip = (0.5 + 0.5 * math.cos(2 * p)) ** 1.5
        bob = A["bob"] * F * dip
        lat = A["lat"] * F * math.sin(p)
        rock = A["rock"] * math.sin(p)
        head_dy = A["head_bob"] * F * (0.5 + 0.5 * math.cos(2 * p - 0.6))
        core_a = 0.88 + 0.12 * math.sin(2 * math.pi * A["core_pulse_hz"] * t_glob)

        def rc(fire_i):
            d = (i - fire_i) % N
            return math.exp(-d / 2.2) if d < 8 else 0.0

        # recoil + counter-rock from this mecha's own loadout
        recs = {}
        for wid, side, aim0, ff in self.loadout:
            r = rc(ff)
            recs[(wid, side)] = r
            rock += A["recoil_rock"] * (0.6 if side == "left" else -0.6) * r

        # ground shadow
        sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(sh)
        fy = CANVAS_H / 2.0 + self.foot["left"][1] + 8
        sw = 150 - bob * 2.5
        sd.ellipse([ox - sw / 2, fy - 15, ox + sw / 2, fy + 15], fill=(0, 0, 0, 130))
        canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)), (0, 0))

        for side in ("left", "right"):
            thigh, _ = self.leg_pose(side, p)
            self.comp(canvas, ox, self.L["thigh_%s" % side], thigh[0], thigh[1], thigh[2])
        for side in ("left", "right"):
            _, shin = self.leg_pose(side, p)
            self.comp(canvas, ox, self.L["shin_%s" % side], shin[0], shin[1], shin[2], shin[3], shin[4])

        self.comp(canvas, ox, self.L["torso"], rock, self.rock_pivot, (lat, bob))
        core = self.L["core"].copy()
        core.putalpha(core.getchannel("A").point(lambda v: int(v * core_a)))
        glow = core.filter(ImageFilter.GaussianBlur(6))
        glow.putalpha(glow.getchannel("A").point(lambda v: int(v * 0.8)))
        self.comp(canvas, ox, glow, rock, self.rock_pivot, (lat, bob))
        self.comp(canvas, ox, core, rock, self.rock_pivot, (lat, bob))
        self.comp(canvas, ox, self.L["head"], rock * 0.5, self.rock_pivot, (lat, bob + head_dy))

        # weapons — mounts inherit torso motion; small personal aim sweep
        tips = []
        for wid, side, aim0, ff in self.loadout:
            aim = math.radians(aim0 + 8.0 * math.sin(2 * math.pi * (i / N) + (0 if side == "right" else 1.7)))
            m = self.shoulder[side]
            mr = rot2((m[0] - self.rock_pivot[0], m[1] - self.rock_pivot[1]), rock)
            mount = (mr[0] + self.rock_pivot[0] + lat, mr[1] + self.rock_pivot[1] + bob)
            k = recs[(wid, side)] * A["recoil"] * F
            av = (math.cos(aim), math.sin(aim))
            tr = (mount[0] - av[0] * k, mount[1] - av[1] * k)
            self.comp(canvas, ox, self.W[wid], aim, (0.0, 0.0), tr)
            muz = self.rig["weapons"][wid]["muzzle"][0]
            tip = (ox + tr[0] + rot2((muz, 0.0), aim)[0],
                   CANVAS_H / 2.0 + tr[1] + rot2((muz, 0.0), aim)[1])
            tips.append((tip, ff))
        return tips


def muzzle_flash(size, heat):
    m = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(m)
    c = size / 2.0
    rings = [(size * 0.50, (90, 220, 255), 70), (size * 0.32, (160, 240, 255), 150),
             (size * 0.16, (255, 255, 255), 235)]
    for r, col, alpha in rings:
        rr = r * (0.6 + 0.4 * heat)
        d.ellipse([c - rr, c - rr, c + rr, c + rr], fill=(*col, int(alpha * heat)))
    return m.filter(ImageFilter.GaussianBlur(1.6))


def make_bg():
    bg = Image.new("RGBA", (CANVAS_W, CANVAS_H), (14, 13, 24, 255))
    d = ImageDraw.Draw(bg)
    for x in range(0, CANVAS_W, 48):
        d.line([(x, 0), (x, CANVAS_H)], fill=(26, 26, 42, 255), width=1)
    for y in range(0, CANVAS_H, 48):
        d.line([(0, y), (CANVAS_W, y)], fill=(26, 26, 42, 255), width=1)
    return bg


def main():
    vanguard = Mecha("vanguard", [("autocannon", "right", -14.0, N // 4),
                                  ("missilepod", "left", 194.0, 3 * N // 4)])
    titan = Mecha("titan", [("railgun", "right", -10.0, N // 3),
                            ("plasmacaster", "left", 190.0, 5 * N // 6)])
    BG = make_bg()

    frames = []
    for i in range(N):
        t = i / FPS
        canvas = BG.copy()
        tips = vanguard.draw(canvas, CANVAS_W * 0.27, i, t)
        tips += titan.draw(canvas, CANVAS_W * 0.73, i, t)
        for tip, ff in tips:
            d = (i - ff) % N
            if d < 2:
                fl = muzzle_flash(64, 1.0 - 0.5 * d)
                canvas.alpha_composite(fl, (int(tip[0] - 32), int(tip[1] - 32)))
        frames.append(canvas.convert("RGB"))

    out = os.path.join(DOCS, "mecha_walk.gif")
    frames[0].save(out, save_all=True, append_images=frames[1:],
                   duration=int(1000 / FPS), loop=0, optimize=True)
    frames[N // 4].save(os.path.join(DOCS, "mecha_hero.png"))

    idx = [0, 7, 14, 21, 28, 35, 42, 49]
    w, h = frames[0].size
    half = (w // 2, h // 2)
    sheet = Image.new("RGB", (half[0] * 4, half[1] * 2), (8, 8, 14))
    for k, j in enumerate(idx):
        sheet.paste(frames[j].resize(half, Image.LANCZOS), ((k % 4) * half[0], (k // 4) * half[1]))
    sheet.save(os.path.join(DOCS, "mecha_contact.png"))

    # phone-scale: both mechas at in-game sprite size
    strip = Image.new("RGB", (190 * 2, 100), (10, 9, 18))
    for k, j in enumerate((idx[1], idx[5])):
        strip.paste(frames[j].resize((190, 100), Image.LANCZOS), (190 * k, 0))
    strip = strip.resize((190 * 2 * 3, 300), Image.NEAREST)
    strip.save(os.path.join(DOCS, "mecha_phone_scale.png"))
    print("GIF", out, "frames", N)


if __name__ == "__main__":
    main()
