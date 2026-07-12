#!/usr/bin/env python3
"""
Procedural arcade SFX generator -> game/assets/audio/sfx/*.wav (mono 22050).
No assets on this server, so we synthesize placeholder sounds (CC0-equivalent,
we own them) so the audio SYSTEM can be heard and evaluated. Swap for polished
Kenney/pro CC0 packs later. Deterministic (seeded) -> reproducible.
"""
import numpy as np, wave, os, struct

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "assets", "audio", "sfx")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(42)


def _env(n, a=0.005, d=0.05, s=0.0, r=0.08, sl=0.5):
    # simple ADSR over n samples
    ai, di, ri = int(a * SR), int(d * SR), int(r * SR)
    si = max(0, n - ai - di - ri)
    e = np.concatenate([
        np.linspace(0, 1, max(1, ai)),
        np.linspace(1, sl, max(1, di)),
        np.full(si, sl),
        np.linspace(sl, 0, max(1, ri)),
    ])
    return e[:n] if len(e) >= n else np.pad(e, (0, n - len(e)))


def _t(dur):
    return np.linspace(0, dur, int(dur * SR), endpoint=False)


def _sine(f, t):
    return np.sin(2 * np.pi * f * t)


def _square(f, t, duty=0.5):
    return np.where((f * t) % 1.0 < duty, 1.0, -1.0)


def _noise(n):
    return rng.uniform(-1, 1, n)


def save(name, y):
    y = np.asarray(y, dtype=np.float64)
    y = y / (np.max(np.abs(y)) + 1e-9) * 0.85
    data = (y * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("SFX", name, "%.2fs" % (len(y) / SR))


def shoot():
    t = _t(0.14); f = np.linspace(880, 240, len(t))          # downward zap
    y = _square(f, t, 0.35) * _env(len(t), d=0.02, r=0.1, sl=0.7)
    save("shoot", y)


def hit():
    t = _t(0.10); f = np.linspace(400, 130, len(t))
    y = (_sine(f, t) * 0.6 + _noise(len(t)) * 0.4) * _env(len(t), d=0.03, r=0.06)
    save("hit", y)


def crit():
    t = _t(0.16); f = np.linspace(1200, 500, len(t))
    y = (_square(f, t, 0.5) * 0.7 + _sine(f * 1.5, t) * 0.3) * _env(len(t), d=0.04, r=0.1, sl=0.8)
    save("crit", y)


def explosion():
    t = _t(0.5); n = len(t)
    body = _noise(n) * np.exp(-t * 7.0)
    rumble = _sine(np.linspace(120, 40, n), t) * np.exp(-t * 4.0)
    save("explosion", body * 0.7 + rumble * 0.6)


def xp():
    t = _t(0.12); y = _sine(np.linspace(700, 1400, len(t)), t) * _env(len(t), d=0.02, r=0.08, sl=0.8)
    save("xp", y)


def scrap():
    t = _t(0.10); y = _square(np.linspace(500, 900, len(t)), t, 0.5) * _env(len(t), r=0.06, sl=0.7)
    save("scrap", y)


def levelup():
    # ascending arpeggio C-E-G-C
    notes = [523, 659, 784, 1047]; segs = []
    for f in notes:
        t = _t(0.09)
        segs.append(_square(f, t, 0.5) * _env(len(t), d=0.02, r=0.05, sl=0.8))
    save("levelup", np.concatenate(segs))


def hurt():
    t = _t(0.22); f = np.linspace(300, 90, len(t))
    y = (_square(f, t, 0.5) * 0.6 + _noise(len(t)) * 0.4) * _env(len(t), d=0.05, r=0.12)
    save("hurt", y)


def boss():
    # ominous descending brass-ish
    t = _t(0.9); f = np.linspace(220, 110, len(t))
    y = (_square(f, t, 0.5) * 0.5 + _sine(f, t) * 0.5) * _env(len(t), a=0.05, d=0.2, r=0.3, sl=0.7)
    save("boss", y)


def overdrive():
    t = _t(0.6); f = np.linspace(200, 1600, len(t))          # rising power-up
    y = (_square(f, t, 0.5) * 0.6 + _sine(f * 2, t) * 0.4) * _env(len(t), a=0.02, r=0.2, sl=0.8)
    save("overdrive", y)


def click():
    t = _t(0.05); y = _square(880, t, 0.5) * _env(len(t), r=0.03, sl=0.6)
    save("click", y)


def victory():
    notes = [523, 659, 784, 1047, 784, 1047]; segs = []
    for i, f in enumerate(notes):
        t = _t(0.14)
        segs.append(_square(f, t, 0.5) * _env(len(t), d=0.03, r=0.08, sl=0.8))
    save("victory", np.concatenate(segs))


if __name__ == "__main__":
    for fn in [shoot, hit, crit, explosion, xp, scrap, levelup, hurt, boss, overdrive, click, victory]:
        fn()
    print("DONE sfx ->", OUT)
