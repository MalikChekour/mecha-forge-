"""Sons des tirs de tourelle (15/10) : 9 niveaux x (depart _a, impact _b), synthese pure numpy -> WAV 22,05 kHz mono.
Chaque niveau a un TIMBRE different (crepitement, cloche, bois, grondement, pom, verre, sirene, blorp, souffle)."""
import numpy as np, wave, os
SR = 22050
OUT = os.path.join("game", "assets", "audio", "sfx")
rng = np.random.default_rng(7)

def t_(d): return np.linspace(0, d, int(SR * d), endpoint=False)
def env(n, a=0.005, d=0.2, p=2.0):
    x = np.arange(n) / SR
    return np.minimum(1.0, x / max(a, 1e-4)) * np.exp(-x / d) ** p if False else np.minimum(1.0, x / max(a, 1e-4)) * np.exp(-x / d)
def noise(d): return rng.uniform(-1, 1, int(SR * d))
def lp(x, k):  # passe-bas simple
    y = np.zeros_like(x); a = 1.0 / (1.0 + k)
    for i in range(1, len(x)): y[i] = y[i-1] + a * (x[i] - y[i-1])
    return y
def hp(x, k): return x - lp(x, k)
def sweep(f0, f1, d, shape="exp"):
    t = t_(d); f = f0 * (f1 / f0) ** (t / d) if shape == "exp" else np.linspace(f0, f1, len(t))
    return np.sin(2 * np.pi * np.cumsum(f) / SR)
def save(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.8
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())

# 1 soudeuse : crepitement + bourdonnement 120 Hz / zap sec
n = int(SR * 0.7); t = t_(0.7)
save("ts_weld_a", (hp(noise(0.7), 3) * (rng.random(n) > 0.6) * 0.7 + 0.5 * np.sin(2*np.pi*120*t) * np.sin(2*np.pi*7*t)**2) * env(n, 0.01, 0.5))
n = int(SR * 0.18); save("ts_weld_b", hp(noise(0.18), 2) * env(n, 0.001, 0.05) + sweep(2500, 400, 0.18) * env(n, 0.001, 0.07))
# 2 solaire : balayage montant puis cloche aigue / grésillement
n = int(SR * 1.0); a = sweep(300, 3200, 1.0, "lin") * np.linspace(0.1, 1, n) ** 2 * 0.6
save("ts_solar_a", a)
n = int(SR * 0.6); t = t_(0.6)
save("ts_solar_b", (np.sin(2*np.pi*2400*t) + 0.5*np.sin(2*np.pi*3600*t) + 0.3*np.sin(2*np.pi*5300*t)) * env(n, 0.001, 0.22) + hp(noise(0.6), 3) * env(n, 0.001, 0.12) * 0.4)
# 3 cosse : "pop" de bois + sifflement / craquement de feuilles
n = int(SR * 0.3); save("ts_pod_a", sweep(380, 110, 0.3) * env(n, 0.001, 0.07) + 0.3 * sweep(1800, 900, 0.3) * env(n, 0.001, 0.12))
n = int(SR * 0.4); save("ts_pod_b", hp(noise(0.4), 4) * env(n, 0.001, 0.1) * (rng.random(n) > 0.4) + sweep(220, 90, 0.4) * env(n, 0.001, 0.08) * 0.6)
# 4 lave : thump grave + souffle / splash lourd
n = int(SR * 0.6); save("ts_slag_a", sweep(90, 38, 0.6) * env(n, 0.002, 0.2) + lp(noise(0.6), 30) * env(n, 0.01, 0.25) * 0.8)
n = int(SR * 0.8); save("ts_slag_b", lp(noise(0.8), 12) * env(n, 0.002, 0.3) + sweep(70, 32, 0.8) * env(n, 0.001, 0.25) * 1.2)
# 5 DCA : "pom" sec / claque d'eclatement
n = int(SR * 0.25); save("ts_flak_a", sweep(210, 80, 0.25) * env(n, 0.001, 0.06) + lp(noise(0.25), 6) * env(n, 0.001, 0.05))
n = int(SR * 0.35); save("ts_flak_b", noise(0.35) * env(n, 0.001, 0.07) + sweep(160, 60, 0.35) * env(n, 0.001, 0.1) * 0.7)
# 6 givre : tintement de verre + souffle / craquement de glace
n = int(SR * 0.7); t = t_(0.7)
save("ts_frost_a", (np.sin(2*np.pi*3100*t) + 0.6*np.sin(2*np.pi*4700*t) + 0.4*np.sin(2*np.pi*6100*t)) * env(n, 0.002, 0.3) * 0.5 + hp(noise(0.7), 5) * env(n, 0.05, 0.3) * 0.3)
n = int(SR * 0.5); save("ts_frost_b", hp(noise(0.5), 3) * (rng.random(n) > 0.75) * env(n, 0.001, 0.12) + sweep(1800, 300, 0.5) * env(n, 0.001, 0.1) * 0.5)
# 7 plasma : sirene montante (charge) / eclair cassant
n = int(SR * 1.3); save("ts_plasma_a", sweep(180, 1500, 1.3, "lin") * np.linspace(0.2, 1, n) * 0.7 + 0.25 * sweep(360, 3000, 1.3, "lin") * np.linspace(0.1, 1, n))
n = int(SR * 0.35); save("ts_plasma_b", hp(noise(0.35), 2) * env(n, 0.001, 0.07) + sweep(1600, 200, 0.35) * env(n, 0.001, 0.12))
# 8 acide : « blorp » humide / chuintement
n = int(SR * 0.35); t = t_(0.35); save("ts_acid_a", np.sin(2*np.pi*np.cumsum(180 + 380 * (t/0.35) + 40*np.sin(2*np.pi*22*t))/SR) * env(n, 0.003, 0.14))
n = int(SR * 0.7); save("ts_acid_b", hp(noise(0.7), 6) * env(n, 0.005, 0.35) * 0.8 + np.pad(sweep(300, 120, 0.2) * env(int(SR*0.2), 0.001, 0.06), (0, n-int(SR*0.2))) * 0.5)
# 9 missiles : souffle de lancement + bip de verrouillage / explosion plasma
n = int(SR * 0.7); a = lp(noise(0.7), 5) * np.linspace(0.3, 1, n) * env(n, 0.02, 0.5); t = t_(0.7)
save("ts_missile_a", a + 0.4 * np.sin(2*np.pi*1400*t) * ((t % 0.18) < 0.06))
n = int(SR * 0.9); save("ts_missile_b", lp(noise(0.9), 10) * env(n, 0.002, 0.3) + sweep(180, 40, 0.9) * env(n, 0.001, 0.28) * 1.1 + 0.3 * sweep(2200, 500, 0.9) * env(n, 0.001, 0.1))
print("OK 18 sons ->", OUT)
