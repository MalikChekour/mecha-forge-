#!/usr/bin/env python3
"""
SYNTHWAVE trailer bed -> cine/synthwave.wav (+ mp3 via ffmpeg).

Procedural 1980s retrowave for the MECHA-FORGE trailer: four-on-the-floor kick,
gated-reverb snare, offbeat hats, arpeggiated analog bass, detuned saw pad on an
Am-F-C-G loop, and a heroic lead. Structured as a TRAILER (not a loop):
intro (atmosphere) -> build -> main -> climax -> outro tail. ~52s to match the
7-shot storyboard (6 story beats + title card).

No external music API, no GPU: pure numpy synthesis, mp3 muxed by ffmpeg.
"""
import numpy as np, wave, os, subprocess

SR = 44100
BPM = 118.0
BEAT = 60.0 / BPM
BAR = 4.0 * BEAT
N_BARS = 26
TOTAL = int(N_BARS * BAR * SR) + SR  # +1s tail
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "cine")
os.makedirs(OUT, exist_ok=True)

buf = np.zeros(TOTAL, dtype=np.float64)


def midi_f(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def add(start, sig, gain=1.0):
    s = int(start)
    e = min(s + len(sig), TOTAL)
    if s < 0 or s >= TOTAL:
        return
    buf[s:e] += sig[: e - s] * gain


def lp(sig, cutoff_frac):
    """cheap vectorized lowpass: convolve with a Hann window sized by cutoff."""
    k = max(2, int(1.0 / max(1e-3, cutoff_frac)))
    w = np.hanning(k * 2 + 1)
    w /= w.sum()
    return np.convolve(sig, w, mode="same")


def saw(freq, dur, detune=0.008, voices=3):
    t = np.linspace(0, dur, int(dur * SR), endpoint=False)
    y = np.zeros(len(t))
    for i in range(voices):
        d = 1.0 + detune * (i - (voices - 1) / 2.0)
        ph = (freq * d * t) % 1.0
        y += 2.0 * ph - 1.0
    return y / voices


def env_ad(dur, a, d, floor=0.0):
    n = int(dur * SR)
    at = int(a * SR)
    e = np.ones(n)
    if at > 0:
        e[:at] = np.linspace(0, 1, at)
    dn = n - at
    if dn > 0:
        e[at:] = np.linspace(1, floor, dn) if floor > 0 else np.exp(-np.linspace(0, 6, dn))
    return e


# ---- drum voices -----------------------------------------------------------
def kick():
    d = 0.32
    t = np.linspace(0, d, int(d * SR), endpoint=False)
    f = 120.0 * np.exp(-t * 28.0) + 46.0
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t * 7.5)
    click = (np.random.rand(len(t)) * 2 - 1) * np.exp(-t * 220.0) * 0.5
    return np.tanh((body + click) * 1.5)


def snare(gated=True):
    d = 0.30
    t = np.linspace(0, d, int(d * SR), endpoint=False)
    noise = np.random.rand(len(t)) * 2 - 1
    tone = np.sin(2 * np.pi * 190 * t) * 0.4
    body = (lp(noise, 0.5) * 0.9 + tone) * np.exp(-t * 18.0)
    if gated:  # 80s gated reverb: bright noise tail cut hard at ~0.18s
        tail = lp(np.random.rand(len(t)) * 2 - 1, 0.35) * 0.5
        g = np.ones(len(t)); cut = int(0.17 * SR)
        g[cut:] = np.linspace(1, 0, min(len(t) - cut, int(0.02 * SR)) or 1).mean() * 0
        g[cut:] = 0.0
        g[:cut] *= np.exp(-t[:cut] * 4.0)
        body = body + tail * g
    return np.tanh(body * 1.2)


def hat(open_=False):
    d = 0.12 if open_ else 0.045
    t = np.linspace(0, d, int(d * SR), endpoint=False)
    n = np.random.rand(len(t)) * 2 - 1
    hi = n - lp(n, 0.15)  # crude highpass
    return hi * np.exp(-t * (34.0 if not open_ else 12.0)) * 0.6


# ---- harmony ---------------------------------------------------------------
# Am - F - C - G  (i VI III VII in A minor), one chord per bar, looping.
PROG = [
    (45, [57, 60, 64]),   # Am : A2 bass, A3 C4 E4
    (41, [57, 60, 65]),   # F  : F2 bass, A3 C4 F4
    (48, [55, 60, 64]),   # C  : C3 bass, G3 C4 E4
    (43, [55, 59, 62]),   # G  : G2 bass, G3 B3 D4
]
# heroic lead motif per bar (MIDI, 8th-note steps; None = rest), octave 5-6
LEAD = [
    [69, None, 72, None, 76, None, 72, 69],
    [69, None, 65, None, 69, None, 72, None],
    [67, None, 72, None, 76, None, 79, None],
    [74, None, 71, None, 67, None, 71, None],
]


def bar_time(b):
    return b * BAR


def synth_song():
    for b in range(N_BARS):
        root, triad = PROG[b % 4]
        t0 = bar_time(b)

        # sections
        drums = b >= 4
        full = b >= 8
        climax = 16 <= b < 24
        outro = b >= 24

        # --- pad (all bars) ---
        pdur = BAR * (1.02)
        pad = np.zeros(int(pdur * SR))
        for m in triad:
            s = saw(midi_f(m + (12 if outro else 0)), pdur, detune=0.012, voices=3)
            pad[: len(s)] += s
        pad = lp(pad, 0.05) * env_ad(pdur, 0.12, pdur - 0.12, floor=0.55)
        add(t0 * SR, pad, 0.16 if not outro else 0.24)

        # --- arp (16ths, from intro) ---
        steps = 16
        for i in range(steps):
            m = triad[i % 3] + 12
            st = t0 + i * (BEAT / 4.0)
            a = saw(midi_f(m), BEAT / 4.0 * 0.9, detune=0.006, voices=2)
            a *= np.exp(-np.linspace(0, 5, len(a)))
            g = 0.05 if b < 4 else (0.09 if not climax else 0.11)
            add(st * SR, lp(a, 0.25), g)

        # --- bass (from build) ---
        if b >= 4:
            for i in range(8):  # 8th-note root/fifth arp
                bm = root + (0 if i % 2 == 0 else 7) - (0 if i < 4 else -12) * 0
                bm = root if i % 4 in (0, 1) else root + 7
                st = t0 + i * (BEAT / 2.0)
                bs = saw(midi_f(bm), BEAT / 2.0 * 0.95, detune=0.004, voices=2)
                bs = lp(bs, 0.09) * env_ad(len(bs) / SR, 0.005, len(bs) / SR, floor=0.3)
                add(st * SR, bs, 0.22)

        # --- lead (main + climax) ---
        if full and not outro:
            for i, m in enumerate(LEAD[b % 4]):
                if m is None:
                    continue
                mm = m + (12 if climax else 0)
                st = t0 + i * (BEAT / 2.0)
                dur = BEAT / 2.0 * 1.3
                ld = saw(midi_f(mm), dur, detune=0.01, voices=3)
                vib = 1.0 + 0.004 * np.sin(2 * np.pi * 5.5 * np.linspace(0, dur, len(ld)))
                ld *= vib
                ld = lp(ld, 0.35) * env_ad(dur, 0.01, dur, floor=0.2)
                add(st * SR, ld, 0.16)
                # slap-back echo
                add((st + BEAT * 0.375) * SR, ld, 0.07)

        # --- drums ---
        if drums and not outro:
            for beat in range(4):
                st = t0 + beat * BEAT
                add(st * SR, kick(), 0.9)
                if beat in (1, 3):
                    add(st * SR, snare(gated=True), 0.5)
                # hats: offbeat 8ths
                add((st + BEAT * 0.5) * SR, hat(open_=(beat == 3 and full)), 0.5)
                if full:
                    add((st + BEAT * 0.25) * SR, hat(), 0.28)
                    add((st + BEAT * 0.75) * SR, hat(), 0.28)

        # --- outro crash + let-ring ---
        if b == 24:
            cr = lp(np.random.rand(int(1.4 * SR)) * 2 - 1, 0.6)
            cr *= np.exp(-np.linspace(0, 5, len(cr)))
            add(t0 * SR, cr - lp(cr, 0.2), 0.35)
            add(t0 * SR, kick(), 1.0)


synth_song()

# master: soft-clip, normalize, gentle fade in/out
buf = np.tanh(buf * 1.1)
buf /= (np.max(np.abs(buf)) + 1e-9)
buf *= 0.92
fi = int(0.05 * SR); fo = int(1.6 * SR)
buf[:fi] *= np.linspace(0, 1, fi)
buf[-fo:] *= np.linspace(1, 0, fo)

wav_path = os.path.join(OUT, "synthwave.wav")
pcm = (buf * 32767).astype(np.int16)
with wave.open(wav_path, "w") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print("WROTE", wav_path, os.path.getsize(wav_path) // 1024, "Ko", round(len(buf)/SR, 1), "s")

mp3 = os.path.join(OUT, "synthwave.mp3")
r = subprocess.run(["ffmpeg", "-y", "-i", wav_path, "-b:a", "192k", mp3],
                   capture_output=True, text=True)
print("MP3", "ok" if r.returncode == 0 else r.stderr[-300:])
