#!/usr/bin/env python3
"""
Procedural chiptune loops -> game/assets/audio/music/*.wav (then convert to .ogg
with ffmpeg). Placeholder music so the audio system can be evaluated; swap for real
CC0/licensed tracks later. Two moods: 'battle' (driving) and 'boss' (heavier/tense).
"""
import numpy as np, wave, os, subprocess

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "assets", "audio", "music")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}

def freq(name, octv):
    return 440.0 * 2 ** ((NOTE[name] + (octv - 4) * 12 - 9) / 12.0)

def square(f, n, duty=0.5):
    t = np.arange(n) / SR
    return np.where((f * t) % 1.0 < duty, 1.0, -1.0)

def tri(f, n):
    t = np.arange(n) / SR
    return 2 * np.abs(2 * ((f * t) % 1.0) - 1) - 1

def env(n, r=0.05):
    e = np.ones(n); ri = int(r * SR)
    if ri > 0 and ri < n:
        e[-ri:] = np.linspace(1, 0, ri)
    e[:int(0.005 * SR)] = np.linspace(0, 1, int(0.005 * SR))
    return e

def note(f, dur, wave_fn=square, amp=0.3, duty=0.5):
    n = int(dur * SR)
    w = wave_fn(f, n, duty) if wave_fn is square else wave_fn(f, n)
    return w * env(n) * amp

def kick(dur):
    n = int(dur * SR); t = np.arange(n) / SR
    f = np.linspace(160, 45, n)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 18) * 0.7

def hat(dur):
    n = int(dur * SR); t = np.arange(n) / SR
    return rng.uniform(-1, 1, n) * np.exp(-t * 60) * 0.25


def build(prog, octv_bass, tempo, arp_duty, boss=False):
    beat = 60.0 / tempo
    step = beat / 2.0            # eighth notes
    bars_per_chord = 2
    track = []
    for (root, third, fifth) in prog:
        seg_len = int(beat * 4 * bars_per_chord * SR)
        seg = np.zeros(seg_len)
        # bass: root on each beat
        pos = 0
        while pos < seg_len:
            b = note(freq(root, octv_bass), beat * 0.9, tri, 0.34)
            seg[pos:pos + len(b)] += b[:seg_len - pos]
            pos += int(beat * SR)
        # arp lead: root-third-fifth-octave eighth notes
        arp = [freq(root, octv_bass + 2), freq(third, octv_bass + 2),
               freq(fifth, octv_bass + 2), freq(root, octv_bass + 3)]
        pos = 0; i = 0
        while pos < seg_len:
            a = note(arp[i % 4], step * 0.95, square, 0.20, arp_duty)
            seg[pos:pos + len(a)] += a[:seg_len - pos]
            pos += int(step * SR); i += 1
        # drums
        pos = 0; i = 0
        while pos < seg_len:
            k = kick(beat * 0.5)
            seg[pos:pos + len(k)] += k[:seg_len - pos]
            if i % 2 == 1 or boss:
                h = hat(step * 0.5)
                hp = pos + int(step * SR)
                if hp < seg_len:
                    seg[hp:hp + len(h)] += h[:seg_len - hp]
            pos += int(beat * SR); i += 1
        track.append(seg)
    return np.concatenate(track)


def save_ogg(name, y):
    y = y / (np.max(np.abs(y)) + 1e-9) * 0.8
    data = (y * 32767).astype(np.int16)
    wavp = os.path.join(OUT, name + ".wav")
    with wave.open(wavp, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())
    oggp = os.path.join(OUT, name + ".ogg")
    try:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wavp, "-c:a", "libvorbis", "-q:a", "3", oggp], check=True)
        os.remove(wavp)
        print("MUSIC", name + ".ogg", "%.1fs" % (len(y) / SR))
    except Exception as e:
        print("MUSIC", name + ".wav (ffmpeg failed:", e, ")")


# Am - F - C - G  (i - VI - III - VII), driving
BATTLE = [("A", "C", "E"), ("F", "A", "C"), ("C", "E", "G"), ("G", "B", "D")]
# Dm - Bb - F - A  darker/tenser for boss
BOSS = [("D", "F", "A"), ("A#", "D", "F"), ("F", "A", "C"), ("A", "C#", "E")]

if __name__ == "__main__":
    save_ogg("battle", build(BATTLE, 3, 140, 0.5))
    save_ogg("boss", build(BOSS, 2, 152, 0.35, boss=True))
    print("DONE music ->", OUT)
