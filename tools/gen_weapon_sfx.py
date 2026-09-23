#!/usr/bin/env python3
"""
Punchy per-WEAPON SFX -> game/assets/audio/sfx/*.wav (mono 44100).

One distinct, satisfying sound per weapon FAMILY (base + its evolution share it):
  w_autocannon  amber rapid gun  -> sharp mechanical crack + sub thump
  w_missile     fire missile pod -> launch whoosh + low fwoomp
  w_railgun     electric pierce  -> rising charge whine + bright crack
  w_plasma      violet AoE       -> warbly plasma vwoom + sparkle
  w_sabre       energy blade     -> band-swept swish + hum
Plus a beefier `explosion` (the old one was ASMR-soft). Pure numpy -> wav. No GPU.
"""
import numpy as np, wave, os

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "game", "assets", "audio", "sfx")
os.makedirs(OUT, exist_ok=True)
rng = np.random.RandomState(7)


def t(d):
    return np.linspace(0, d, int(d * SR), endpoint=False)


def lp(sig, frac):
    k = max(2, int(1.0 / max(1e-3, frac)))
    w = np.hanning(k * 2 + 1); w /= w.sum()
    return np.convolve(sig, w, mode="same")


def noise(d):
    return rng.uniform(-1, 1, int(d * SR))


def sweep(f0, f1, d, kind="sin"):
    tt = t(d)
    f = np.linspace(f0, f1, len(tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) if kind == "sin" else (2 * ((ph / (2 * np.pi)) % 1.0) - 1)


def norm(x, peak=0.92):
    x = np.tanh(x)
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def save(name, x):
    x = norm(x)
    # 3 ms fade in/out so there is never a click
    f = int(0.003 * SR)
    x[:f] *= np.linspace(0, 1, f); x[-f:] *= np.linspace(1, 0, f)
    pcm = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("%-14s %5.0f ms  peak=%.2f" % (name, len(x) / SR * 1000, np.max(np.abs(x))))


def w_autocannon():
    d = 0.11; tt = t(d)
    click = noise(d) * np.exp(-tt * 160.0) * 0.7
    body = sweep(240, 90, d, "saw") * np.exp(-tt * 30.0) * 0.8
    sub = np.sin(2 * np.pi * 62 * tt) * np.exp(-tt * 22.0) * 0.9
    return (lp(click, 0.5) + body + sub) * 1.4


def w_missile():
    d = 0.36; tt = t(d)
    whoosh = lp(noise(d), 0.12) * np.linspace(0.2, 1.0, len(tt)) * np.exp(-tt * 3.0)
    band = lp(noise(d), 0.05) * 0.6
    fwoomp = sweep(95, 48, 0.18, "sin")
    out = whoosh * 0.9 + band
    out[:len(fwoomp)] += fwoomp * np.exp(-t(0.18) * 12.0) * 0.9
    return out * 1.3


def w_railgun():
    d = 0.30; tt = t(d)
    charge = sweep(300, 1500, 0.13, "sin") * np.linspace(0.1, 0.7, int(0.13 * SR))
    out = np.zeros(int(d * SR))
    out[:len(charge)] += charge
    cs = int(0.12 * SR)                      # the crack lands after the charge
    crack = noise(d - 0.12) * np.exp(-t(d - 0.12) * 42.0)
    zap = sweep(1400, 300, d - 0.12, "saw") * np.exp(-t(d - 0.12) * 30.0)
    out[cs:cs + len(crack)] += (crack * 0.9 + zap * 0.7)
    return out * 1.5


def w_plasma():
    d = 0.30; tt = t(d)
    vib = 1.0 + 0.5 * np.sin(2 * np.pi * 30 * tt)
    core = np.sin(2 * np.pi * 190 * tt * vib) + 0.6 * np.sin(2 * np.pi * 255 * tt * vib)
    core *= np.exp(-tt * 9.0)
    spark = lp(noise(d), 0.25) * np.exp(-tt * 16.0) * 0.5
    swp = sweep(600, 140, d, "sin") * np.exp(-tt * 8.0) * 0.5
    return (lp(core, 0.4) + spark + swp) * 1.2


def w_sabre():
    d = 0.26; tt = t(d)
    # band-swept noise = an energy WHOOSH that rises then falls (a swing)
    n = noise(d)
    center = np.concatenate([np.linspace(0.06, 0.32, len(tt) // 2),
                             np.linspace(0.32, 0.10, len(tt) - len(tt) // 2)])
    swish = np.zeros(len(tt))
    # cheap time-varying band: mix a few fixed lp bands weighted by the sweep
    for c in (0.08, 0.16, 0.28):
        band = lp(n, c) - lp(n, c * 0.6)
        wgt = np.exp(-((center - c) ** 2) / (2 * 0.05 ** 2))
        swish += band * wgt
    hum = np.sin(2 * np.pi * 320 * tt) * 0.15 * np.exp(-tt * 5.0)
    env = np.sin(np.linspace(0, np.pi, len(tt)))   # swell then fade = a swing
    return (swish * 2.2 + hum) * env * 1.3


def explosion():
    d = 0.6; tt = t(d)
    sub = sweep(70, 28, d, "sin") * np.exp(-tt * 5.0)
    boom = lp(noise(d), 0.08) * np.exp(-tt * 6.0)
    crackle = lp(noise(d), 0.4) * np.exp(-tt * 10.0) * 0.5
    return (sub * 1.1 + boom * 0.9 + crackle) * 1.6


save("w_autocannon", w_autocannon())
save("w_missile", w_missile())
save("w_railgun", w_railgun())
save("w_plasma", w_plasma())
save("w_sabre", w_sabre())
save("explosion", explosion())
print("DONE ->", OUT)
