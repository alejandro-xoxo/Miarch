#!/usr/bin/env python3
"""Genera desbloqueo.wav: sonido de teclado mecánico generado por código, sin muestras de terceros.
Sintetiza las pulsaciones de teclado mecánico que acompañan la aparición del log
en la pantalla de desbloqueo (27 líneas más cabecera con cadencia ~79 ms y Enter final)."""
import os, wave
import numpy as np

os.chdir(os.path.dirname(os.path.abspath(__file__)))

SR = 44100
T = 2.5
n = int(SR * T)
rng = np.random.default_rng(2026)

out_l = np.zeros(n)
out_r = np.zeros(n)

base_cadence = np.linspace(0.05, 2.10, 27)
jitter = rng.uniform(-0.015, 0.015, 27)
t_keys = base_cadence + jitter
for i in range(1, len(t_keys)):
    if t_keys[i] <= t_keys[i - 1] + 0.035:
        t_keys[i] = t_keys[i - 1] + 0.040

t_all = np.append(t_keys, 2.20)
space_indices = {7, 16}

for idx, t_k in enumerate(t_all):
    is_enter = (idx == len(t_all) - 1)
    is_space = (idx in space_indices)

    dur = 0.16
    n_k = int(dur * SR)
    start = int(t_k * SR)
    end = min(n, start + n_k)
    actual_len = end - start
    if actual_len <= 0:
        continue
    tk = np.arange(actual_len) / SR

    if is_enter:
        f0 = rng.uniform(110, 130)
        thock_decay = rng.uniform(0.030, 0.035)
        vel = 1.15
        pan = 0.0
    elif is_space:
        f0 = rng.uniform(120, 145)
        thock_decay = rng.uniform(0.028, 0.034)
        vel = rng.uniform(1.0, 1.15)
        pan = rng.uniform(-0.08, 0.08)
    else:
        f0 = rng.uniform(150, 240)
        thock_decay = rng.uniform(0.020, 0.030)
        vel = rng.uniform(0.85, 1.12)
        pan = rng.uniform(-0.25, 0.25)

    # 1. Clic al pulsar: ráfaga breve de ruido filtrado (2-4 ms)
    click_decay = rng.uniform(0.002, 0.0035)
    noise_press = rng.standard_normal(actual_len)
    m = int(0.0035 * SR)
    tm = np.arange(m) / SR
    h_click = np.sin(2 * np.pi * 3600 * tm) * np.exp(-tm / 0.001)
    click = np.convolve(noise_press, h_click, mode="full")[:actual_len]
    click = click * np.exp(-tk / click_decay)
    click = click / (np.max(np.abs(click)) + 1e-9) * 0.45

    # 2. Thock: senoidal 120-260 Hz con caída de 20-35 ms
    f_inst = f0 * (1.0 + 0.35 * np.exp(-tk / 0.008))
    phase = 2 * np.pi * np.cumsum(f_inst) / SR
    thock = np.sin(phase) * np.exp(-tk / thock_decay)
    thock += 0.28 * np.sin(2 * phase) * np.exp(-tk / (thock_decay * 0.75))
    thock = thock / (np.max(np.abs(thock)) + 1e-9) * 0.80

    press = (click + thock) * vel

    # 3. Clic al soltar unos 50-90 ms después
    rel_time = rng.uniform(0.055, 0.085)
    rel_decay = rng.uniform(0.002, 0.003)
    tk_rel = np.maximum(0, tk - rel_time)
    noise_rel = rng.standard_normal(actual_len)
    m_rel = int(0.003 * SR)
    tm_rel = np.arange(m_rel) / SR
    h_rel = np.sin(2 * np.pi * 4600 * tm_rel) * np.exp(-tm_rel / 0.0008)
    click_rel = np.convolve(noise_rel, h_rel, mode="full")[:actual_len]
    click_rel = click_rel * np.exp(-tk_rel / rel_decay) * (tk >= rel_time)
    click_rel = click_rel / (np.max(np.abs(click_rel)) + 1e-9) * 0.20 * vel

    sig = press + click_rel

    # Paneo estéreo suave (potencia constante)
    angle = (pan + 1.0) * (np.pi / 4)
    g_l = np.cos(angle)
    g_r = np.sin(angle)

    out_l[start:end] += sig * g_l
    out_r[start:end] += sig * g_r

# Cola corta de sala (sin reverberación larga)
ir_len = int(0.04 * SR)
tir = np.arange(ir_len) / SR
ir = rng.standard_normal(ir_len) * np.exp(-tir / 0.012)
ir /= np.sum(np.abs(ir)) + 1e-9
out_l = out_l + 0.12 * np.convolve(out_l, ir, mode="full")[:n]
out_r = out_r + 0.12 * np.convolve(out_r, ir, mode="full")[:n]

# Desvanecimiento en los últimos 30 ms
fade_len = int(0.03 * SR)
out_l[-fade_len:] *= np.linspace(1, 0, fade_len)
out_r[-fade_len:] *= np.linspace(1, 0, fade_len)

st = np.stack([out_l, out_r], axis=1)
peak = np.max(np.abs(st))
st = st / peak * 0.70

w = wave.open("desbloqueo.wav", "wb")
w.setnchannels(2)
w.setsampwidth(2)
w.setframerate(SR)
w.writeframes((st * 32767).astype("<i2").tobytes())
w.close()
print("desbloqueo.wav", T, "s")
