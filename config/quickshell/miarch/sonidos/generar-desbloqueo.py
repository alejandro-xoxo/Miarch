#!/usr/bin/env python3
"""Genera desbloqueo.wav: síntesis algorítmica de teclado mecánico con switches rojos (Cherry MX Red).
Sin muestras de terceros ni grabaciones externas:
- Switches rojos lineales: sin clic metálico agudo.
- 'Thock' de fondo: senoidal amortiguada de 90-190 Hz con ataque suave (3-5 ms), caída de 35-70 ms
  y segundo modo armónico (2.1-2.6x) más débil (carcasa y placa metálica).
- 'Tap' de fondo: ruido paso banda entre 700 y 1600 Hz (6-10 ms) al 30-40% del thock.
- Retorno al soltar: golpecito amortiguado 55-95 ms después (15-25% de amplitud), sin agudos.
- Filtro paso bajo suave (~4 kHz) y reverb corta de sala (55 ms, mezcla 8%).
- Variación por tecla en volumen (±20%) y tono (±5%), paneo estéreo sutil.
- Espacio y Enter más graves y anchos (60-110 Hz).
Cadencia: 28 pulsaciones (cabecera + 27 líneas de log) entre 0.05 y 2.10 s (~79 ms) y Enter final a ~2.20 s.
"""
import os
import wave
import numpy as np

os.chdir(os.path.dirname(os.path.abspath(__file__)))

SR = 44100
T = 2.5
n = int(SR * T)
rng = np.random.default_rng(2026)

out_l = np.zeros(n)
out_r = np.zeros(n)

# 28 pulsaciones entre 0.05 y 2.10 s con variación de ±15 ms (~79 ms cadencia)
base_cadence = np.linspace(0.05, 2.10, 28)
jitter = rng.uniform(-0.015, 0.015, 28)
t_keys = base_cadence + jitter
for i in range(1, len(t_keys)):
    if t_keys[i] <= t_keys[i - 1] + 0.035:
        t_keys[i] = t_keys[i - 1] + 0.040

# Enter al final a ~2.20 s
t_all = np.append(t_keys, 2.20)
space_indices = {7, 16, 23}

def envelope(t, attack, decay):
    env = np.zeros_like(t)
    att_idx = t < attack
    env[att_idx] = 0.5 * (1 - np.cos(np.pi * t[att_idx] / attack))
    dec_idx = ~att_idx
    env[dec_idx] = np.exp(-(t[dec_idx] - attack) / decay)
    return env

# Filtro FIR paso bajo (~4 kHz, ventana Hamming)
def make_lowpass(fc=4000, sr=SR, numtaps=65):
    t = np.arange(numtaps) - (numtaps - 1) / 2
    h = np.sinc(2 * fc * t / sr) * np.hamming(numtaps)
    return h / np.sum(h)

h_lp = make_lowpass(4000, SR, 65)

for idx, t_k in enumerate(t_all):
    is_enter = (idx == len(t_all) - 1)
    is_space = (idx in space_indices)

    dur = 0.18
    n_k = int(dur * SR)
    start = int(t_k * SR)
    end = min(n, start + n_k)
    actual_len = end - start
    if actual_len <= 0:
        continue
    tk = np.arange(actual_len) / SR

    var_vel = rng.uniform(0.80, 1.20)
    var_pitch = rng.uniform(0.95, 1.05)

    if is_enter:
        f0 = rng.uniform(65, 95) * var_pitch
        thock_decay = rng.uniform(0.055, 0.070)
        vel = 1.15 * var_vel
        pan = 0.0
    elif is_space:
        f0 = rng.uniform(75, 110) * var_pitch
        thock_decay = rng.uniform(0.045, 0.065)
        vel = 1.05 * var_vel
        pan = rng.uniform(-0.08, 0.08)
    else:
        f0 = rng.uniform(110, 165) * var_pitch
        thock_decay = rng.uniform(0.038, 0.060)
        vel = 0.95 * var_vel
        pan = rng.uniform(-0.25, 0.25)

    # 1. Thock: golpe de fondo suave y grave
    attack_time = rng.uniform(0.003, 0.005)
    env_thock = envelope(tk, attack_time, thock_decay)
    mode2_ratio = rng.uniform(2.1, 2.6)
    mode2_amp = rng.uniform(0.18, 0.28)
    f_inst1 = f0 * (1.0 + 0.15 * np.exp(-tk / 0.010))
    phase1 = 2 * np.pi * np.cumsum(f_inst1) / SR
    f_inst2 = (f0 * mode2_ratio) * (1.0 + 0.10 * np.exp(-tk / 0.008))
    phase2 = 2 * np.pi * np.cumsum(f_inst2) / SR
    thock = (np.sin(phase1) + mode2_amp * np.sin(phase2)) * env_thock
    thock = thock / (np.max(np.abs(thock)) + 1e-9)

    # 2. Tap de fondo: ruido paso banda 700-1600 Hz (6-10 ms)
    tap_dur = rng.uniform(0.006, 0.010)
    tap_env = np.where(tk < tap_dur, np.sin(np.pi * tk / tap_dur) ** 2, 0.0)
    noise = rng.standard_normal(actual_len)
    f_mid = rng.uniform(1000, 1300)
    bw = rng.uniform(400, 600)
    t_ir = np.arange(int(0.008 * SR)) / SR
    ir_tap = np.sin(2 * np.pi * f_mid * t_ir) * np.exp(-t_ir * bw * np.pi)
    tap_raw = np.convolve(noise, ir_tap, mode="full")[:actual_len]
    tap_amp = rng.uniform(0.30, 0.40)
    tap = tap_raw * tap_env
    tap = tap / (np.max(np.abs(tap)) + 1e-9) * tap_amp

    # 3. Retorno al soltar: suave (55-95 ms después)
    rel_time = rng.uniform(0.055, 0.095)
    rel_amp = rng.uniform(0.15, 0.25)
    rel_dur = rng.uniform(0.008, 0.015)
    tk_rel = tk - rel_time
    rel_active = (tk_rel >= 0) & (tk_rel < rel_dur)
    rel_env = np.where(rel_active, np.sin(np.pi * tk_rel / rel_dur) ** 2, 0.0)
    f_rel = rng.uniform(220, 380)
    rel_sig = np.sin(2 * np.pi * f_rel * np.maximum(0, tk_rel)) * rel_env
    rel_noise = rng.standard_normal(actual_len)
    ir_rel = np.sin(2 * np.pi * 500 * t_ir) * np.exp(-t_ir * 600 * np.pi)
    rel_filt_noise = np.convolve(rel_noise, ir_rel, mode="full")[:actual_len] * rel_env * 0.3
    rel = rel_sig + rel_filt_noise
    rel = rel / (np.max(np.abs(rel)) + 1e-9) * rel_amp

    key_sig = (thock + tap + rel) * vel

    # Paneo estéreo
    angle = (pan + 1.0) * (np.pi / 4)
    out_l[start:end] += key_sig * np.cos(angle)
    out_r[start:end] += key_sig * np.sin(angle)

# Filtro paso bajo (~4 kHz)
out_l = np.convolve(out_l, h_lp, mode="same")
out_r = np.convolve(out_r, h_lp, mode="same")

# Reverb muy corta (55 ms, mezcla 8%)
ir_len = int(0.055 * SR)
tir = np.arange(ir_len) / SR
ir_rev = rng.standard_normal(ir_len) * np.exp(-tir / 0.018)
ir_rev = np.convolve(ir_rev, h_lp, mode="same")
ir_rev /= (np.sum(np.abs(ir_rev)) + 1e-9)

out_l = out_l + 0.08 * np.convolve(out_l, ir_rev, mode="same")
out_r = out_r + 0.08 * np.convolve(out_r, ir_rev, mode="same")

# Desvanecimiento en los últimos 30 ms
fade_len = int(0.03 * SR)
out_l[-fade_len:] *= np.linspace(1, 0, fade_len)
out_r[-fade_len:] *= np.linspace(1, 0, fade_len)

st = np.stack([out_l, out_r], axis=1)
peak = np.max(np.abs(st))
st = st / peak * 0.70

out_wav = "desbloqueo.wav"
w = wave.open(out_wav, "wb")
w.setnchannels(2)
w.setsampwidth(2)
w.setframerate(SR)
w.writeframes((st * 32767).astype("<i2").tobytes())
w.close()

# Comprobaciones acústicas con numpy
mono = np.mean(st, axis=1)
env_signal = np.abs(mono)
win = int(0.020 * SR)
smoothed_env = np.convolve(env_signal, np.ones(win) / win, mode="same")

def find_peaks_numpy(x, min_height, min_dist):
    pks = []
    last_p = -min_dist
    for i in range(1, len(x) - 1):
        if x[i] > x[i - 1] and x[i] > x[i + 1] and x[i] >= min_height:
            if i - last_p >= min_dist:
                pks.append(i)
                last_p = i
            elif x[i] > x[pks[-1]]:
                pks[-1] = i
                last_p = i
    return np.array(pks)

detected_peaks = find_peaks_numpy(smoothed_env, 0.05 * np.max(smoothed_env), int(0.050 * SR))
fft_l = np.fft.rfft(st[:, 0])
freqs = np.fft.rfftfreq(len(st), 1 / SR)
psd = np.abs(fft_l) ** 2
total_energy = np.sum(psd)
energy_above_6k = np.sum(psd[freqs > 6000])
pct_above_6k = (energy_above_6k / total_energy) * 100
centroid = np.sum(freqs * psd) / total_energy

print(f"Generado {out_wav}:")
print(f"  Duración: {len(st) / SR:.2f} s (debe ser 2.4 - 2.6 s)")
print(f"  Pico máx: {np.max(np.abs(st)):.2f} (debe ser 0.55 - 0.80)")
print(f"  Pulsaciones detectadas: {len(detected_peaks)} (debe ser 26 - 32)")
print(f"  Energía > 6 kHz: {pct_above_6k:.4f}% (debe ser < 3%)")
print(f"  Centroide espectral: {centroid:.1f} Hz (debe ser < 1800 Hz)")
