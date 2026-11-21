# SPDX-License-Identifier: GPL-3.0-or-later
# Música ORIGINAL de ambiente club (128 BPM, La menor) sintetizada con numpy: sin muestras ni melodías de terceros, sin copyright.
# Uso: python3 crear-musica.py [salida.wav]   (dura ~97,5 s; semilla fija, siempre sale igual)
import sys, numpy as np, wave
SR = 44100; BPM = 128; BEAT = 60 / BPM; STEP = BEAT / 4; BARS = 52
N = int(BARS * 4 * BEAT * SR) + SR
rng = np.random.default_rng(128)
def buf(): return np.zeros(N)
def put(b, t0, x):
    i = int(t0 * SR); j = min(i + len(x), len(b))
    if i < j: b[i:j] += x[:j - i]
def tt(d): return np.arange(int(d * SR)) / SR
def noise_band(d, lo, hi):
    n = rng.standard_normal(int(d * SR)); f = np.fft.rfft(n); fr = np.fft.rfftfreq(len(n), 1 / SR)
    f[(fr < lo) | (fr > hi)] = 0; return np.fft.irfft(f, len(n))
def kick():
    t = tt(0.4); fr = 46 + 120 * np.exp(-t * 32); ph = 2 * np.pi * np.cumsum(fr) / SR
    return np.sin(ph) * np.exp(-t * 9) * 1.0 + np.exp(-t * 400) * 0.25 * rng.standard_normal(len(t))
def clap():
    t = tt(0.3); n = noise_band(0.3, 900, 4500)
    env = sum(np.exp(-np.clip(t - o, 0, None) * 45) * (t >= o) for o in (0, 0.012, 0.024)) * 0.5 + np.exp(-t * 14) * 0.35
    return n * env * 0.8
def hat(abierto=False):
    d = 0.35 if abierto else 0.07; t = tt(d); return noise_band(d, 6500, 16000) * np.exp(-t * (14 if abierto else 70)) * (0.45 if abierto else 0.5)
def saw(f, t, h=9): return sum(np.sin(2 * np.pi * k * f * t) / k for k in range(1, h + 1)) * 0.55
def bajo(f, d):
    t = tt(d); return (np.sin(2 * np.pi * f * t) * 0.8 + saw(f, t, 5) * 0.35) * np.minimum(t * 200, 1) * np.exp(-t * 3.2)
def pluck(f, d=0.22):
    t = tt(d); x = sum(saw(f * (1 + e), t, 10) for e in (-0.004, 0, 0.004)) / 3
    return x * np.exp(-t * 13) * np.minimum(t * 400, 1)
def pad(freqs, d):
    t = tt(d); x = sum(np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t) for f in freqs) / len(freqs)
    return x * np.minimum(t * 1.5, 1) * np.minimum((d - t) * 3, 1)
midi = lambda m: 440 * 2 ** ((m - 69) / 12)
ACORDES = [([57, 60, 64], 33), ([53, 57, 60], 29), ([48, 52, 55], 36), ([55, 59, 62], 31)]   # Am F C G; raíz del bajo
K, B, C, H, A, P = buf(), buf(), buf(), buf(), buf(), buf()
for bar in range(BARS):
    t0 = bar * 4 * BEAT; notas, raiz = ACORDES[bar % 4]
    kick_on = bar not in (24, 25, 26, 27) and bar < 51
    if kick_on:
        for b in range(4): put(K, t0 + b * BEAT, kick())
    for s in range(16):
        ts = t0 + s * STEP
        if s % 2 == 0 and bar >= 0: put(H, ts + STEP / 2 if s % 4 == 2 else ts, hat(abierto=(s % 4 == 2 and bar >= 8)))
        if bar >= 4 and bar < 51 and s in (0, 3, 6, 8, 11, 14): put(B, ts, bajo(midi(raiz - 12 if s < 8 else raiz), STEP * 2.6))
        if bar >= 16 and bar < 48:
            n = (notas + [m + 12 for m in notas])[[0, 2, 4, 3, 1, 5, 4, 2][s % 8]]
            if s % 2 == 0 or bar >= 32: put(A, ts, pluck(midi(n + 12)) * (0.7 if s % 2 else 1.0))
    if bar >= 8 and bar < 51:
        put(C, t0 + BEAT, clap()); put(C, t0 + 3 * BEAT, clap())
        if bar in (28, 29, 30, 31):
            for s in range(0, 16, 2 if bar < 31 else 1): put(C, t0 + s * STEP, clap() * (0.4 + 0.6 * (bar - 28) / 3))
    if bar >= 8 and bar < 51: put(P, t0, pad([midi(m) for m in notas], 4 * BEAT) * 0.5)
# sidechain: todo menos el bombo se agacha con cada golpe
t = np.arange(N) / SR; fase = (t % BEAT)
duck = 1 - 0.75 * np.exp(-fase * 11)
mezcla = K * 0.55 + C * 0.9 + H * 0.9 + (B * 0.38 + A * 1.5 + P * 0.55) * duck
mezcla = np.tanh(mezcla * 1.15)
dur = BARS * 4 * BEAT; mezcla = mezcla[:int(dur * SR)]
mezcla *= np.minimum(np.arange(len(mezcla)) / (SR * 0.3), 1) * np.minimum((len(mezcla) - np.arange(len(mezcla))) / (SR * 4), 1)
mezcla = mezcla / np.max(np.abs(mezcla)) * 0.85
est = np.stack([mezcla, np.roll(mezcla, int(0.0004 * SR)) * 0.98], axis=1)       # estéreo muy suave
out = sys.argv[1] if len(sys.argv) > 1 else "musica-original.wav"
with wave.open(out, "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((est * 32767).astype("<i2").tobytes())
print(out, round(dur, 1), "s")
