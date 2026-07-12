#!/usr/bin/env python3
"""
SOFT/ASMR-leaning SFX -> game/assets/audio/sfx/*.wav (mono 44100).
Sine/triangle based, gentle envelopes, low peak level -> soothing, not harsh.
Placeholder (we own them); swap for polished CC0 later. Deterministic.
"""
import numpy as np, wave, os

SR = 44100
PEAK = 0.55                 # keep it gentle
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "assets", "audio", "sfx")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(42)


def _t(dur):
    return np.linspace(0, dur, int(dur * SR), endpoint=False)


def _sine(f, t):
    return np.sin(2 * np.pi * f * t) if np.isscalar(f) else np.sin(2 * np.pi * np.cumsum(f) / SR)


def _tri(f, t):
    ph = (f * t) % 1.0 if np.isscalar(f) else (np.cumsum(f) / SR) % 1.0
    return 2 * np.abs(2 * ph - 1) - 1


def _env(n, a=0.01, r=0.12):
    e = np.ones(n)
    ai, ri = int(a * SR), int(r * SR)
    if ai > 0:
        e[:ai] = np.linspace(0, 1, ai) ** 2       # soft attack
    if ri > 0 and ri < n:
        e[-ri:] = np.linspace(1, 0, ri) ** 1.8     # soft release
    return e


def _softnoise(n, cut=0.15):
    x = rng.uniform(-1, 1, n)
    # one-pole low-pass -> airy, not harsh
    y = np.zeros(n); a = cut
    for i in range(1, n):
        y[i] = a * x[i] + (1 - a) * y[i - 1]
    return y


def save(name, y, amp=1.0):
    y = np.asarray(y, dtype=np.float64)
    y = y / (np.max(np.abs(y)) + 1e-9) * PEAK * amp
    data = (y * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("SFX", name, "%.2fs" % (len(y) / SR))


def shoot():                # soft airy "pew"
    t = _t(0.12); f = np.linspace(660, 330, len(t))
    y = _sine(f, t) * _env(len(t), 0.004, 0.1) + _softnoise(len(t)) * 0.06
    save("shoot", y, 0.6)


def hit():                  # gentle low tap
    t = _t(0.09); f = np.linspace(300, 160, len(t))
    y = _sine(f, t) * _env(len(t), 0.003, 0.07)
    save("hit", y, 0.7)


def crit():                 # soft bright bell
    t = _t(0.28); f = 1046.0
    y = (_sine(f, t) + 0.4 * _sine(f * 2.01, t)) * np.exp(-t * 7.0)
    save("crit", y, 0.7)


def explosion():            # soft filtered whoomph
    t = _t(0.55); n = len(t)
    low = _sine(np.linspace(110, 50, n), t) * np.exp(-t * 5.0)
    air = _softnoise(n, 0.05) * np.exp(-t * 6.0)
    save("explosion", low * 0.8 + air * 0.5, 0.8)


def xp():                   # gentle rising chime
    t = _t(0.18); y = _sine(np.linspace(660, 990, len(t)), t) * _env(len(t), 0.005, 0.14)
    save("xp", y, 0.5)


def scrap():
    t = _t(0.14); y = _tri(np.linspace(520, 700, len(t)), t) * _env(len(t), 0.005, 0.11)
    save("scrap", y, 0.5)


def levelup():              # soft major arpeggio (sine)
    notes = [523.25, 659.25, 783.99, 1046.5]; segs = []
    for f in notes:
        t = _t(0.13)
        segs.append(_sine(f, t) * _env(len(t), 0.006, 0.09))
    save("levelup", np.concatenate(segs), 0.6)


def hurt():                 # soft low pulse
    t = _t(0.2); f = np.linspace(220, 110, len(t))
    y = _sine(f, t) * _env(len(t), 0.004, 0.16) + _softnoise(len(t)) * 0.05
    save("hurt", y, 0.7)


def boss():                 # gentle low swell (ominous but soft)
    t = _t(1.1); f = 98.0
    y = (_sine(f, t) + 0.5 * _sine(f * 1.5, t)) * _env(len(t), 0.15, 0.4)
    save("boss", y, 0.75)


def overdrive():            # soft rising shimmer
    t = _t(0.7); f = np.linspace(300, 1200, len(t))
    y = (_sine(f, t) + 0.4 * _sine(f * 2, t)) * _env(len(t), 0.03, 0.25)
    save("overdrive", y, 0.6)


def click():                # soft tick
    t = _t(0.05); y = _sine(760, t) * _env(len(t), 0.002, 0.04)
    save("click", y, 0.5)


def victory():              # gentle major run
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]; segs = []
    for f in notes:
        t = _t(0.16)
        segs.append((_sine(f, t) + 0.3 * _sine(f * 2, t)) * _env(len(t), 0.006, 0.1))
    save("victory", np.concatenate(segs), 0.65)


if __name__ == "__main__":
    for fn in [shoot, hit, crit, explosion, xp, scrap, levelup, hurt, boss, overdrive, click, victory]:
        fn()
    print("DONE soft sfx ->", OUT)
