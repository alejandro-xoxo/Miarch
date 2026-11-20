#!/usr/bin/env python3
"""Genera desbloqueo.wav: sonido original de Miarch al desbloquear, estilo tráiler de cine (sin muestras de terceros).
Línea de tiempo (coincide con la animación de la pantalla de bloqueo, 3,6 s):
  0.00 - 2.66 s  subida de tensión: zumbido grave de metales que se abre, barrido de ruido y un vacío justo antes del golpe
  2.74 s         golpe: bombo profundo con caída de tono, metales graves detonando y metal que resuena (ritmo del destello)
  2.74 - 6.50 s  cola larga: cuerdas luminosas de re mayor que se abren y reverberación de catedral"""
import numpy as np, wave
SR = 44100
rng = np.random.default_rng(11)
T = 6.5
n = int(SR * T)
t = np.arange(n) / SR
IMP = 2.74                                         # instante del golpe (76 % de 3,6 s)
act = (t >= IMP).astype(float)
s = np.clip(t - IMP, 0, None)                      # tiempo desde el golpe

def saw_aditivo(f, tt, maxhz=5000):
    """Diente de sierra por suma de armónicos (sin aliasing)."""
    v = np.zeros_like(tt)
    for h in range(1, int(maxhz / f) + 1):
        v += np.sin(2 * np.pi * f * h * tt) / h
    return v * (2 / np.pi)

def pasabajos(x, corte):
    """Dos polos con corte variable (array en Hz o número)."""
    corte = np.broadcast_to(np.asarray(corte, dtype=float), x.shape)
    a = 1 - np.exp(-2 * np.pi * corte / SR)
    y1 = np.zeros_like(x); y2 = np.zeros_like(x); p = q = 0.0
    for i in range(len(x)):
        p += a[i] * (x[i] - p); q += a[i] * (p - q); y2[i] = q
    return y2

def suave(x): x = np.clip(x, 0, 1); return x * x * (3 - 2 * x)

# --- 1) subida de tensión (0 → golpe): metales graves que se abren
sube = np.clip(t / IMP, 0, 1)
env_sube = (sube ** 2.6) * (t < IMP)
# vacío justo antes del golpe: baja casi a cero 180 ms para que el golpe pegue más
vacio = 1 - 0.9 * suave((t - (IMP - 0.18)) / 0.05) * (t < IMP)
bajos = np.zeros(n)
for f, a in ((36.71, 1.0), (55.0, 0.7), (73.42, 0.6), (110.0, 0.35)):        # re1 la1 re2 la2
    for det in (-0.35, 0.0, 0.35):                                           # desafinación leve = grosor
        bajos += a * saw_aditivo(f * (1 + det / 100), t, 2200)
corte_met = 90 * (14 ** sube)                                                # 90 → ~1260 Hz
metales = pasabajos(bajos * env_sube, np.where(t < IMP, corte_met, 1260))
metales *= vacio * 0.55

# barrido de ruido (whoosh) que sube hacia el golpe
ruido = rng.standard_normal(n)
barrido = pasabajos(ruido, 250 * (28 ** sube)) * (sube ** 3.2) * (t < IMP) * vacio * 0.22

# tono que sube (tensión): re3 → re4 en glissando con vibrato lento
fglis = 146.83 * (2 ** (sube * 1.0))
fase = 2 * np.pi * np.cumsum(fglis) / SR
tension = (np.sin(fase) + 0.4 * np.sin(2 * fase)) * env_sube * vacio * 0.05 * (1 + 0.15 * np.sin(2 * np.pi * 5 * t))

# --- 2) golpe: bombo profundo + metales detonando + metal que resuena + chasquido
f_bombo = 30 + 70 * np.exp(-s * 7.5)
bombo = np.sin(2 * np.pi * np.cumsum(f_bombo) / SR) * np.exp(-s * 1.6) * act * 1.25
brass = np.zeros(n)
for f, a in ((36.71, 1.0), (73.42, 0.8), (110.0, 0.55), (146.83, 0.45), (220.0, 0.3)):
    for det in (-0.4, 0.0, 0.4):
        brass += a * saw_aditivo(f * (1 + det / 100), t, 3000)
brass = pasabajos(brass * act * np.minimum(1, s / 0.015), 700 + 2400 * np.exp(-s * 3.5)) * np.exp(-s * 0.95) * 0.5
metal = np.zeros(n)
for f, a in ((312.0, 1.0), (598.0, 0.7), (871.0, 0.5), (1347.0, 0.35), (2210.0, 0.2)):   # parciales inarmónicos: golpe de metal
    metal += a * np.sin(2 * np.pi * f * t) * np.exp(-s * (1.6 + f / 900))
metal *= act * 0.05
chasq = rng.standard_normal(n) * np.exp(-s * 26) * act * 0.45
chasq -= np.convolve(chasq, np.ones(30) / 30, mode="same")

# --- 3) cola: cuerdas luminosas de re mayor add9 que se abren despacio
cuerdas = np.zeros(n)
for f, a in ((293.66, 1.0), (369.99, 0.8), (440.0, 0.9), (587.33, 0.7), (739.99, 0.5), (880.0, 0.45), (1174.7, 0.25)):
    for det in (-0.25, 0.25):
        cuerdas += a * saw_aditivo(f * (1 + det / 100), t, 4500) * (1 + 0.04 * np.sin(2 * np.pi * (4.7 + det) * t))
env_cu = suave(s / 1.4) * np.exp(-np.clip(s - 1.4, 0, None) * 0.55) * act
cuerdas = pasabajos(cuerdas * env_cu, 900 + 2600 * suave(s / 1.8)) * 0.034

seco = metales + barrido + tension + bombo + brass + metal + chasq + cuerdas

# --- 4) reverberación de catedral: ruido que decae (4 s), oscurecido; convolución por FFT
ri = int(SR * 4.2)
tr = np.arange(ri) / SR
ir = rng.standard_normal(ri) * np.exp(-tr * 1.55)
ir = pasabajos(ir, np.maximum(900, 7000 * np.exp(-tr * 0.9)))
ir[: int(0.02 * SR)] *= np.linspace(0, 1, int(0.02 * SR))
L = n + ri
humedo = np.fft.irfft(np.fft.rfft(seco, L) * np.fft.rfft(ir, L), L)[:n]
humedo *= np.max(np.abs(seco)) / (np.max(np.abs(humedo)) + 1e-9)
mezcla = seco * 0.80 + humedo * 0.62

# --- 5) estéreo, normalización y cierre
izq = mezcla + 0.18 * np.roll(mezcla, int(0.013 * SR)) - 0.05 * np.roll(humedo, int(0.031 * SR))
der = mezcla + 0.18 * np.roll(mezcla, int(0.019 * SR)) + 0.05 * np.roll(humedo, int(0.027 * SR))
st = np.stack([izq, der], axis=1)
st = np.tanh(st * 1.15) / np.tanh(1.15)            # saturación suave: pega fuerte sin recortar
st = st / np.max(np.abs(st)) * 0.85
fade = int(SR * 0.9); st[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 2
w = wave.open("desbloqueo.wav", "wb"); w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
w.writeframes((st * 32767).astype("<i2").tobytes()); w.close()
print("desbloqueo.wav", T, "s")
