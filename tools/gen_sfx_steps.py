#!/usr/bin/env python3
"""Footsteps by surface, three takes each (assets/audio/sfx/step_<surface><n>.wav).

  python tools/gen_sfx_steps.py

carpet: a soft muffled thud      wood: a hollow knock with a creak
tile:   a heel click              metal: a ringing clang of a grating
hard:   a gritty scuff (concrete, asphalt)   dirt: a crunch of gravel
grass:  a swish                   water: a small splash
"""
import os, wave
import numpy as np
from scipy.signal import butter, lfilter

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio", "sfx")
rng = np.random.default_rng(88)

def filt(x, lo=None, hi=None):
    if lo and hi:
        b, a = butter(2, [lo / (SR / 2), hi / (SR / 2)], "band")
    elif lo:
        b, a = butter(2, lo / (SR / 2), "high")
    else:
        b, a = butter(2, hi / (SR / 2), "low")
    return lfilter(b, a, x)

def T(d): return np.arange(int(d * SR)) / SR
def N(d): return rng.uniform(-1, 1, int(d * SR))

def thump(d, f0, f1, k):
    t = T(d); f = f1 + (f0 - f1) * np.exp(-t * 40)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * k)

def mix(*parts):
    n = max(int(o * SR) + len(x) for o, x, g in parts)
    y = np.zeros(n)
    for o, x, g in parts:
        s = int(o * SR); y[s:s + len(x)] += x * g
    return y

def take(kind, i):
    v = rng.uniform(0.9, 1.1)
    if kind == "carpet":
        return mix((0, thump(0.1, 140 * v, 70, 45), 1.0), (0, filt(N(0.08), hi=900) * np.exp(-T(0.08) * 50), 0.5))
    if kind == "wood":
        return mix((0, thump(0.14, 260 * v, 150, 30), 0.9), (0, filt(N(0.03), 1500, 6000) * np.exp(-T(0.03) * 120), 0.5),
                   (0.02, np.sin(2 * np.pi * np.cumsum(np.linspace(420, 380, int(0.08 * SR))) / SR) * np.exp(-T(0.08) * 30), 0.12 if i == 1 else 0.0))
    if kind == "tile":
        return mix((0, filt(N(0.02), 2500, 9000) * np.exp(-T(0.02) * 220), 1.0), (0, thump(0.06, 320 * v, 200, 60), 0.6))
    if kind == "metal":
        t = T(0.35)
        ring = sum(np.sin(2 * np.pi * f * v * t) * np.exp(-t * dcy) for f, dcy in ((520, 14), (1370, 18), (2210, 25))) / 3
        return mix((0, ring, 0.6), (0, filt(N(0.03), 1000, 8000) * np.exp(-T(0.03) * 150), 0.7), (0, thump(0.08, 180, 90, 40), 0.5))
    if kind == "hard":
        return mix((0, filt(N(0.07), 900, 7000) * np.exp(-T(0.07) * 60), 0.9), (0, thump(0.08, 200 * v, 110, 50), 0.6))
    if kind == "dirt":
        n = N(0.14) * (rng.random(int(0.14 * SR)) > 0.6)
        return mix((0, filt(n, 1200, 8000) * np.exp(-T(0.14) * 22), 1.0), (0, thump(0.08, 150, 80, 45), 0.5))
    if kind == "grass":
        return mix((0, filt(N(0.16), 2000, 9000) * np.sin(np.linspace(0, np.pi, int(0.16 * SR))) ** 2, 0.8), (0, thump(0.08, 120, 70, 50), 0.35))
    if kind == "water":
        t = T(0.25)
        drops = sum(np.sin(2 * np.pi * np.cumsum(np.linspace(f, f * 1.8, len(t))) / SR) * np.exp(-np.maximum(t - o, 0) * 40) * (t >= o)
                    for f, o in ((900, 0.0), (1300, 0.03), (700, 0.06)))
        return mix((0, filt(N(0.2), 600, 6000) * np.exp(-T(0.2) * 16), 0.8), (0, drops, 0.3))

def write(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.8
    fl = int(0.003 * SR)
    x[-fl:] *= np.linspace(1, 0, fl)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print("sfx", name)

for kind in ("carpet", "wood", "tile", "metal", "hard", "dirt", "grass", "water"):
    for i in range(3):
        write(f"step_{kind}{i}", take(kind, i))
