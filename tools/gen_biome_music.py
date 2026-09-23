#!/usr/bin/env python3
"""
DRIVING, LOOPABLE battle music -> game/assets/audio/music/<biome>.ogg (+ battle/boss).

Replaces the old calm ASMR pads (gen_music.py) with energetic action loops: four-on-the-floor
/ driving drums, sub bass, arpeggios and a biome-themed lead. Each biome has its own tempo,
scale, chord loop and drum feel so the map SOUNDS like its world — never boring, always moving.
Seamless loop (integer bars + head/tail crossfade). Pure numpy synthesis -> ffmpeg ogg. No GPU.
"""
import numpy as np, wave, os, subprocess

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "game", "assets", "audio", "music")
os.makedirs(OUT, exist_ok=True)

MINOR = [0, 2, 3, 5, 7, 8, 10]
PHRYG = [0, 1, 3, 5, 7, 8, 10]
DORIAN = [0, 2, 3, 5, 7, 9, 10]


def midi_f(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def saw(freq, dur, detune=0.008, voices=3):
    t = np.linspace(0, dur, int(dur * SR), endpoint=False)
    y = np.zeros(len(t))
    for i in range(voices):
        d = 1.0 + detune * (i - (voices - 1) / 2.0)
        y += 2.0 * ((freq * d * t) % 1.0) - 1.0
    return y / voices


def square(freq, dur, duty=0.5):
    t = np.linspace(0, dur, int(dur * SR), endpoint=False)
    return np.where((freq * t) % 1.0 < duty, 1.0, -1.0)


def lp(sig, frac):
    k = max(2, int(1.0 / max(1e-3, frac)))
    w = np.hanning(k * 2 + 1); w /= w.sum()
    return np.convolve(sig, w, mode="same")


def env(dur, a, d, floor=0.0):
    n = int(dur * SR); at = max(1, int(a * SR))
    e = np.ones(n)
    e[:at] = np.linspace(0, 1, at)
    dn = n - at
    if dn > 0:
        e[at:] = np.linspace(1, floor, dn) if floor > 0 else np.exp(-np.linspace(0, 5, dn))
    return e


def kick():
    d = 0.30; t = np.linspace(0, d, int(d * SR), endpoint=False)
    f = 135.0 * np.exp(-t * 30.0) + 48.0
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 8.0)
    click = (np.random.rand(len(t)) * 2 - 1) * np.exp(-t * 200.0) * 0.4
    return np.tanh((body + click) * 1.6)


def snare(bright=1.0):
    d = 0.22; t = np.linspace(0, d, int(d * SR), endpoint=False)
    noise = np.random.rand(len(t)) * 2 - 1
    body = (lp(noise, 0.55) * 0.9 + np.sin(2 * np.pi * 185 * t) * 0.4) * np.exp(-t * 22.0)
    tail = lp(np.random.rand(len(t)) * 2 - 1, 0.4 * bright) * 0.4 * np.exp(-t * 12.0)
    return np.tanh((body + tail) * 1.2)


def hat(open_=False):
    d = 0.13 if open_ else 0.04; t = np.linspace(0, d, int(d * SR), endpoint=False)
    n = np.random.rand(len(t)) * 2 - 1
    hi = n - lp(n, 0.12)
    return hi * np.exp(-t * (10.0 if open_ else 40.0)) * 0.5


# ---- biome configs: (bpm, scale, root MIDI, chord-root degrees, drum, bright, lead-style) ------
CFG = {
    "tech":      dict(bpm=130, scale=MINOR, root=45, prog=[0, 5, 3, 5], drum="drive", bright=0.42, lead="arp"),
    "earth":     dict(bpm=120, scale=DORIAN, root=43, prog=[0, 3, 5, 4], drum="four", bright=0.30, lead="pluck"),
    "spaceship": dict(bpm=134, scale=MINOR, root=48, prog=[0, 5, 3, 7], drum="drive", bright=0.50, lead="arp"),
    "volcanic":  dict(bpm=132, scale=PHRYG, root=40, prog=[0, 1, 0, 5], drum="heavy", bright=0.26, lead="power"),
    "desert":    dict(bpm=124, scale=PHRYG, root=45, prog=[0, 1, 3, 1], drum="four", bright=0.34, lead="pluck"),
    "ice":       dict(bpm=126, scale=MINOR, root=50, prog=[0, 5, 3, 5], drum="drive", bright=0.60, lead="arp"),
    "jungle":    dict(bpm=138, scale=DORIAN, root=47, prog=[0, 3, 5, 3], drum="tribal", bright=0.44, lead="pluck"),
    "swamp":     dict(bpm=112, scale=MINOR, root=38, prog=[0, 5, 1, 5], drum="heavy", bright=0.24, lead="power"),
    "boss":      dict(bpm=142, scale=PHRYG, root=38, prog=[0, 1, 0, 1], drum="heavy", bright=0.30, lead="power"),
    "battle":    dict(bpm=128, scale=MINOR, root=45, prog=[0, 5, 3, 4], drum="drive", bright=0.40, lead="arp"),
}
N_BARS = 16


def triad(root_m, scale):
    # minor-ish triad from the scale root (root, +3rd-scale-step, +5th-scale-step)
    return [root_m, root_m + scale[2], root_m + scale[4]]


def build(cfg):
    beat = 60.0 / cfg["bpm"]; bar = 4 * beat
    total = int(N_BARS * bar * SR) + int(0.5 * SR)
    buf = np.zeros(total)
    scale, root = cfg["scale"], cfg["root"]

    def add(start, sig, g=1.0):
        s = int(start * SR); e = min(s + len(sig), total)
        if 0 <= s < total:
            buf[s:e] += sig[:e - s] * g

    for b in range(N_BARS):
        deg = cfg["prog"][b % len(cfg["prog"])]
        chord_root = root + (scale[deg % 7] + 12 * (deg // 7))
        tri = triad(chord_root, scale)
        t0 = b * bar

        # pad bed (warm saws, low)
        pdur = bar * 1.01
        pad = np.zeros(int(pdur * SR))
        for m in tri:
            s = saw(midi_f(m + 12), pdur, detune=0.012, voices=3)
            pad[:len(s)] += s
        pad = lp(pad, 0.05) * env(pdur, 0.06, pdur, floor=0.6)
        add(t0, pad, 0.10)

        # bass — root, eighth-note driving with octave bounce
        for i in range(8):
            bm = chord_root - 12
            st = t0 + i * (beat / 2.0)
            bdur = beat / 2.0 * 0.95
            bs = saw(midi_f(bm), bdur, detune=0.004, voices=2)
            bs = lp(bs, 0.10) * env(bdur, 0.004, bdur, floor=0.25)
            add(st, bs, 0.30)

        # arp / pluck (16ths) — brightness sets the low-pass
        steps = 16
        for i in range(steps):
            m = tri[i % 3] + 24
            st = t0 + i * (beat / 4.0)
            a = saw(midi_f(m), beat / 4.0 * 0.95, detune=0.006, voices=2)
            a *= np.exp(-np.linspace(0, 4, len(a)))
            g = 0.11 if cfg["lead"] == "arp" else 0.06
            add(st, lp(a, cfg["bright"]), g)

        # lead motif (bars alternate) — power chords or a pluck line high up
        if cfg["lead"] == "power" and b % 2 == 0:
            for i in range(4):
                m = chord_root + 12
                st = t0 + i * beat
                pw = saw(midi_f(m), beat * 0.9, detune=0.02, voices=3) + \
                     saw(midi_f(m + 7), beat * 0.9, detune=0.02, voices=2)
                pw = lp(pw, cfg["bright"]) * env(beat * 0.9, 0.01, beat * 0.9, floor=0.3)
                add(st, pw, 0.10)
        elif cfg["lead"] in ("arp", "pluck") and b % 4 in (2, 3):
            motif = [tri[2] + 24, tri[1] + 24, tri[2] + 24, tri[0] + 36,
                     tri[2] + 24, tri[1] + 24, tri[0] + 24, tri[2] + 24]
            for i, m in enumerate(motif):
                st = t0 + i * (beat / 2.0)
                ld = saw(midi_f(m), beat / 2.0 * 1.2, detune=0.01, voices=2)
                ld = lp(ld, min(0.6, cfg["bright"] + 0.2)) * env(beat / 2.0 * 1.2, 0.01, beat / 2.0 * 1.2, floor=0.2)
                add(st, ld, 0.09)
                add(st + beat * 0.375, ld, 0.04)  # echo

        # drums
        dp = cfg["drum"]
        for beat_i in range(4):
            st = t0 + beat_i * beat
            if dp in ("four", "drive", "heavy"):
                add(st, kick(), 0.95)
            if dp == "heavy" and beat_i == 3:
                add(st + beat * 0.5, kick(), 0.8)
            if dp == "drive" and beat_i in (1, 3):
                add(st + beat * 0.5, kick(), 0.6)
            if dp == "tribal":
                add(st, kick(), 0.9)
                if beat_i in (1, 2):
                    add(st + beat * 0.5, kick(), 0.7)
            if beat_i in (1, 3):
                add(st, snare(cfg["bright"] * 2), 0.55)
            # hats
            sub = 4 if dp in ("drive", "tribal") else 2
            for h in range(sub):
                add(st + h * (beat / sub), hat(open_=(h == sub - 1 and beat_i == 3)), 0.30)

    # loop point: crossfade the 0.5s tail overhang back into the head so the seam is seamless
    loop_len = int(N_BARS * bar * SR)
    xf = int(0.20 * SR)
    tail = buf[loop_len:loop_len + xf].copy()
    if len(tail) == xf:
        buf[:xf] = buf[:xf] * np.linspace(1, 1, xf) + tail  # fold tail decay back onto the head
    loop = buf[:loop_len]

    # master
    loop = np.tanh(loop * 1.15)
    loop /= (np.max(np.abs(loop)) + 1e-9)
    loop *= 0.94
    return loop, N_BARS * bar


for name, cfg in CFG.items():
    loop, dur = build(cfg)
    wavp = os.path.join(OUT, name + ".wav")
    pcm = (loop * 32767).astype(np.int16)
    with wave.open(wavp, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    oggp = os.path.join(OUT, name + ".ogg")
    r = subprocess.run(["ffmpeg", "-y", "-i", wavp, "-c:a", "libvorbis", "-qscale:a", "5", oggp],
                       capture_output=True, text=True)
    os.remove(wavp)
    ok = "ok" if r.returncode == 0 else r.stderr[-160:]
    rms = float(np.sqrt(np.mean(loop ** 2)))
    print("%-10s %5.1fs  %3dBPM  rms=%.3f  %s" % (name, dur, cfg["bpm"], rms, ok))
print("DONE ->", OUT)
