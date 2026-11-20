#!/usr/bin/env python3
"""Genera desbloqueo.wav (sonido original de Miarch al desbloquear, sin muestras de terceros). Uso: python3 generar-desbloqueo.py
Línea de tiempo (coincide con la animación de la pantalla de bloqueo, 2,3 s):
  0.0 - 1.43 s  subida de tensión: ruido que se abre + tono que sube, mientras se teclea el log
  1.43 s        golpe: bombo grave con caída de tono + acorde brillante de re mayor con reverberación
  hasta 3.6 s   cola larga"""
import numpy as np, wave
SR = 44100
rng = np.random.default_rng(7)
T = 3.6
n = int(SR * T)
t = np.arange(n) / SR
imp = 1.43                                         # instante del golpe

def lowpass_barrido(x, f0, f1, dur):
    """Filtro de un polo cuyo corte sube de f0 a f1 durante dur segundos."""
    out = np.zeros_like(x); y = 0.0
    m = int(SR * dur)
    for i in range(min(len(x), m)):
        f = f0 * (f1 / f0) ** (i / m)
        a = 1 - np.exp(-2 * np.pi * f / SR)
        y += a * (x[i] - y); out[i] = y
    return out

# 1) subida de tensión
ruido = rng.standard_normal(n)
sube = lowpass_barrido(ruido, 180, 7000, imp)
env_sube = np.where(t < imp, (t / imp) ** 2.2, 0.0)
riser = sube * env_sube * 0.75
tono_f = 90 * (4.2 ** np.clip(t / imp, 0, 1))      # 90 → ~380 Hz
fase = 2 * np.pi * np.cumsum(tono_f) / SR
riser += 0.12 * np.sin(fase) * env_sube + 0.05 * np.sin(2 * fase) * env_sube

# 2) golpe: bombo grave con caída de tono + chasquido
s = np.clip(t - imp, 0, None); activo = (t >= imp)
f_bombo = 42 + 70 * np.exp(-s * 9)
bombo = np.sin(2 * np.pi * np.cumsum(f_bombo) / SR) * np.exp(-s * 2.2) * activo * 1.5
chasquido = rng.standard_normal(n) * np.exp(-s * 38) * activo * 0.5
chasquido -= np.convolve(chasquido, np.ones(40) / 40, mode="same")      # solo agudos

# 3) acorde de re mayor (re2 la2 re3 fa#3 la3 re4 fa#4), con brillo y un poco de desafinación
notas = [73.42, 110.0, 146.83, 185.0, 220.0, 293.66, 369.99, 587.33]
acorde = np.zeros(n)
for k, f in enumerate(notas):
    for det in (-0.12, 0.12):
        ff = f * (1 + det / 100 * 6)
        v = np.zeros(n)
        for h, amp in ((1, 1.0), (2, 0.5), (3, 0.33), (4, 0.22), (5, 0.12)):
            v += amp * np.sin(2 * np.pi * ff * h * t)
        acorde += v * (0.55 if k < 3 else 0.4)
env_ac = np.minimum(1, s / 0.012) * np.exp(-s * 1.15) * activo
acorde = acorde * env_ac * 0.06
brillo = (np.sin(2 * np.pi * 1174.7 * t) + 0.6 * np.sin(2 * np.pi * 1760.0 * t)) * np.exp(-s * 1.6) * activo * (0.6 + 0.4 * np.sin(2 * np.pi * 6 * t)) * 0.05

seco = riser + bombo + chasquido + acorde + brillo

# 4) reverberación: respuesta al impulso de ruido que decae (convolución por FFT)
ri = int(SR * 1.8)
tr = np.arange(ri) / SR
ir = rng.standard_normal(ri) * np.exp(-tr * 2.6)
ir = np.convolve(ir, np.ones(6) / 6, mode="same")
L = n + ri
mezcla = np.fft.irfft(np.fft.rfft(seco, L) * np.fft.rfft(ir, L), L)[:n]
mezcla = seco * 0.78 + mezcla * 0.20 * (np.max(np.abs(seco)) / (np.max(np.abs(mezcla)) + 1e-9)) * 3.5

# 5) estéreo: la reverb y el brillo se abren a los lados; normaliza y cierra con fundido
izq = mezcla + 0.15 * np.roll(mezcla, int(0.011 * SR))
der = mezcla + 0.15 * np.roll(mezcla, int(0.017 * SR))
st = np.stack([izq, der], axis=1)
st = st / np.max(np.abs(st)) * 0.8
fade = int(SR * 0.25); st[-fade:] *= np.linspace(1, 0, fade)[:, None]
w = wave.open("desbloqueo.wav", "wb"); w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
w.writeframes((st * 32767).astype("<i2").tobytes()); w.close()
print("desbloqueo.wav", round(T, 2), "s")
