#!/usr/bin/env python3
"""
CALM / AMBIENT music loops -> game/assets/audio/music/*.ogg (44100, via ffmpeg).
Slow sine PADS on gentle chord progressions, soft amplitude movement, a quiet high
shimmer. NO drums, NO harsh waves -> soothing / ASMR-leaning. Two moods:
'battle' (warm major) and 'boss' (softly tense minor + low drone). Placeholder.
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


def pad(chord, base_oct, dur, lfo_hz=0.13):
    """A soft evolving pad from a chord (list of note names)."""
    t = _t(dur); y = np.zeros(len(t))
    for i, nm in enumerate(chord):
        f = freq(nm, base_oct + (1 if i >= 3 else 0))
        # two slightly detuned sines (warmth) + a quiet octave partial
        y += np.sin(2 * np.pi * f * t)
        y += 0.7 * np.sin(2 * np.pi * f * 1.005 * t)
        y += 0.25 * np.sin(2 * np.pi * f * 2.0 * t)
    # slow breathing amplitude
    lfo = 0.72 + 0.28 * np.sin(2 * np.pi * lfo_hz * t + i)
    # soft attack / release so chords blend
    env = np.ones(len(t)); a = int(0.6 * SR); r = int(0.9 * SR)
    env[:a] = np.linspace(0, 1, a) ** 2
    env[-r:] = np.linspace(1, 0, r) ** 1.6
    # a quiet high shimmer with gentle tremolo
    shim = 0.10 * np.sin(2 * np.pi * freq(chord[0], base_oct + 3) * t) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.35 * t))
    return (y * lfo + shim) * env


def build(prog, base_oct, chord_dur=5.0):
    return np.concatenate([pad(ch, base_oct, chord_dur) for ch in prog])


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
        print("MUSIC", name + ".ogg", "%.1fs" % (len(y) / SR))
    except Exception as e:
        print("MUSIC", name, "ffmpeg failed:", e)


# warm, soothing (Cmaj7 - Am7 - Fmaj7 - G)
BATTLE = [["C", "E", "G", "B"], ["A", "C", "E", "G"], ["F", "A", "C", "E"], ["G", "B", "D", "F#"]]
# softly tense (Am - Fmaj7 - Dm7 - Em) — minor but still calm
BOSS = [["A", "C", "E"], ["F", "A", "C", "E"], ["D", "F", "A", "C"], ["E", "G", "B"]]

if __name__ == "__main__":
    save_ogg("battle", build(BATTLE, 3, 5.5))
    save_ogg("boss", build(BOSS, 2, 5.0))
    print("DONE ambient music ->", OUT)
