#!/usr/bin/env python3
"""
CALM / AMBIENT music loops -> game/assets/audio/music/*.ogg (44100, via ffmpeg).
Slow sine PADS on gentle chord progressions, soft amplitude movement, a quiet high
shimmer. NO drums, NO harsh waves, NO aggression -> soothing / ASMR-leaning.

ONE TRACK PER BIOME, each shaped to its map (see VOICES): the mood comes from the
chord colour + register + how fast it breathes + how much shimmer/drone/air it has,
never from tempo or percussion. Plus 'boss' (softly tense) and 'battle' (fallback).
"""
import numpy as np, wave, os, subprocess

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "assets", "audio", "music")
os.makedirs(OUT, exist_ok=True)

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}

def freq(name, octv):
    return 440.0 * 2 ** ((NOTE[name] + (octv - 4) * 12 - 9) / 12.0)

def _t(dur):
    return np.linspace(0, dur, int(dur * SR), endpoint=False)


def pad(chord, base_oct, dur, lfo_hz=0.13, shimmer=0.10, detune=1.005, drone=0.0, air=0.0):
    """A soft evolving pad from a chord (list of note names).

    shimmer -> quiet crystalline high partial (ice/tech).  drone -> low sustained
    fundamental (volcanic/swamp).  air -> gentle filtered-noise wind bed (desert/jungle).
    """
    t = _t(dur); y = np.zeros(len(t))
    for i, nm in enumerate(chord):
        f = freq(nm, base_oct + (1 if i >= 3 else 0))
        # two slightly detuned sines (warmth) + a quiet octave partial
        y += np.sin(2 * np.pi * f * t)
        y += 0.7 * np.sin(2 * np.pi * f * detune * t)
        y += 0.25 * np.sin(2 * np.pi * f * 2.0 * t)
    if drone > 0.0:
        f0 = freq(chord[0], max(0, base_oct - 2))
        y += drone * (np.sin(2 * np.pi * f0 * t) + 0.5 * np.sin(2 * np.pi * f0 * 1.5 * t))
    # slow breathing amplitude
    lfo = 0.72 + 0.28 * np.sin(2 * np.pi * lfo_hz * t + len(chord))
    # soft attack / release so chords blend
    env = np.ones(len(t)); a = int(0.6 * SR); r = int(0.9 * SR)
    env[:a] = np.linspace(0, 1, a) ** 2
    env[-r:] = np.linspace(1, 0, r) ** 1.6
    out = y * lfo
    if shimmer > 0.0:
        sh = np.sin(2 * np.pi * freq(chord[0], base_oct + 3) * t) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.35 * t))
        out = out + shimmer * sh
    if air > 0.0:
        # very soft wind bed: heavily smoothed noise, no hiss spikes
        n = np.random.default_rng(7).normal(0, 1, len(t))
        k = 900
        n = np.convolve(n, np.ones(k) / k, mode="same")
        n /= (np.max(np.abs(n)) + 1e-9)
        out = out + air * n * (0.7 + 0.3 * np.sin(2 * np.pi * 0.08 * t))
    return out * env


def build(prog, base_oct, chord_dur=5.0, **kw):
    return np.concatenate([pad(ch, base_oct, chord_dur, **kw) for ch in prog])


def save_ogg(name, y):
    y = y / (np.max(np.abs(y)) + 1e-9) * 0.5          # gentle overall level
    data = (y * 32767).astype(np.int16)
    wavp = os.path.join(OUT, name + ".wav")
    with wave.open(wavp, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())
    oggp = os.path.join(OUT, name + ".ogg")
    try:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wavp, "-c:a", "libvorbis", "-q:a", "4", oggp], check=True)
        os.remove(wavp)
        print("MUSIC %-13s %5.1fs %6.1f KB" % (name + ".ogg", len(y) / SR, os.path.getsize(oggp) / 1024))
    except Exception as e:
        print("MUSIC", name, "ffmpeg failed:", e)


# --- ONE VOICE PER MAP -------------------------------------------------------------
# prog: chord progression | oct: register | dur: seconds per chord (longer = calmer)
# lfo: breathing speed | shimmer: crystalline highs | drone: heavy lows | air: wind bed
VOICES = {
    # SECTEUR TECH — clean, synthetic, cool. Bright major 7ths, crystalline, tight detune.
    "tech":      dict(prog=[["C","E","G","B"], ["A","C","E","G"], ["F","A","C","E"], ["G","B","D","F#"]],
                      oct=3, dur=5.5, lfo=0.16, shimmer=0.16, detune=1.003, drone=0.0, air=0.0),
    # FRICHE — warm, organic, a little melancholic. Low-ish, slow, barely any shimmer.
    "earth":     dict(prog=[["A","C","E","G"], ["F","A","C","E"], ["C","E","G","B"], ["G","B","D"]],
                      oct=3, dur=6.0, lfo=0.10, shimmer=0.05, detune=1.006, drone=0.10, air=0.05),
    # GRAVITE FAIBLE — floaty, wide, weightless. Suspended chords that never resolve.
    "spaceship": dict(prog=[["D","G","A"], ["C","F","G"], ["A","D","E"], ["G","C","D"]],
                      oct=3, dur=7.0, lfo=0.07, shimmer=0.14, detune=1.008, drone=0.06, air=0.04),
    # VOLCAN — deep, smouldering, heavy. Dark minor + strong low drone, still slow and calm.
    "volcanic":  dict(prog=[["D","F","A"], ["A#","D","F"], ["A","C","E"], ["F","A","C"]],
                      oct=2, dur=6.5, lfo=0.09, shimmer=0.02, detune=1.007, drone=0.34, air=0.06),
    # DESERT — dry, sparse, wide open. Bare fifths + a Phrygian hint, wind bed.
    "desert":    dict(prog=[["E","B"], ["F","C"], ["D","A"], ["E","B"]],
                      oct=3, dur=7.5, lfo=0.06, shimmer=0.06, detune=1.010, drone=0.12, air=0.16),
    # GLACE — crystalline, high, still. Bright register, heavy shimmer, no drone.
    "ice":       dict(prog=[["E","G#","B"], ["C#","E","G#"], ["A","C#","E"], ["B","D#","F#"]],
                      oct=4, dur=6.0, lfo=0.11, shimmer=0.26, detune=1.002, drone=0.0, air=0.05),
    # JUNGLE — lush, verdant, alive. Rich 9ths, quicker breath, soft air.
    "jungle":    dict(prog=[["D","F#","A","C#"], ["G","B","D","F#"], ["E","G","B","D"], ["A","C#","E"]],
                      oct=3, dur=5.5, lfo=0.18, shimmer=0.10, detune=1.006, drone=0.08, air=0.12),
    # MARAIS — murky, sunken, very slow. Low and dark, sluggish breath, muted highs.
    "swamp":     dict(prog=[["C","D#","G"], ["G#","C","D#"], ["A#","D","F"], ["G","A#","D"]],
                      oct=2, dur=8.0, lfo=0.05, shimmer=0.02, detune=1.009, drone=0.28, air=0.10),
    # VILLE EN RUINES (map parked; kept so re-enabling it needs no extra work)
    "ruines":    dict(prog=[["A","C","E"], ["F","A","C"], ["D","F","A"], ["E","G","B"]],
                      oct=2, dur=7.0, lfo=0.08, shimmer=0.07, detune=1.008, drone=0.22, air=0.08),
    # BOSS — softly tense minor. Still NO drums: the pressure lives in the harmony, not the beat.
    "boss":      dict(prog=[["A","C","E"], ["F","A","C","E"], ["D","F","A","C"], ["E","G","B"]],
                      oct=2, dur=5.0, lfo=0.14, shimmer=0.06, detune=1.007, drone=0.20, air=0.0),
    # fallback for any caller still asking for "battle"
    "battle":    dict(prog=[["C","E","G","B"], ["A","C","E","G"], ["F","A","C","E"], ["G","B","D","F#"]],
                      oct=3, dur=5.5, lfo=0.13, shimmer=0.10, detune=1.005, drone=0.0, air=0.0),
}

if __name__ == "__main__":
    for name, v in VOICES.items():
        y = build(v["prog"], v["oct"], v["dur"], lfo_hz=v["lfo"], shimmer=v["shimmer"],
                  detune=v["detune"], drone=v["drone"], air=v["air"])
        save_ogg(name, y)
    print("DONE ambient music ->", OUT)
