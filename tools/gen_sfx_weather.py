#!/usr/bin/env python3
"""
Weather and Chapter III foley (own script so the other generators' random
streams never shift):

  wind_loop     - seamless gusting wind bed (weather)
  fire_loop     - crackling fire bed (burning sets)
  flame_burst   - flamethrower whoosh
  flame_ignite  - pilot click and the fwoomp of ignition
  applause      - studio audience applause
  laugh_track   - canned studio laughter (a little too long)
  tote_ding     - telethon tote-board ding
  on_air_buzz   - ON AIR buzzer
  sprinkler     - pipes knock and cough, nothing comes out

  python tools/gen_sfx_weather.py
"""
import os, wave
import numpy as np
from scipy.signal import lfilter, butter

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio", "sfx")
rng = np.random.default_rng(1992)


def t(d): return np.arange(int(d * SR)) / SR
def noise(d): return rng.uniform(-1, 1, int(d * SR))
def band(x, lo, hi, o=2):
    b, a = butter(o, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band"); return lfilter(b, a, x)
def lp(x, fc, o=2):
    b, a = butter(o, min(fc, SR * 0.45) / (SR / 2), "low"); return lfilter(b, a, x)
def hp(x, fc, o=2):
    b, a = butter(o, fc / (SR / 2), "high"); return lfilter(b, a, x)
def norm(x, p=0.9):
    m = np.max(np.abs(x)) or 1.0; return x / m * p
def smooth_noise(d, rate):
    """Slow random curve 0..1 (for gusts)."""
    n = int(d * rate) + 3
    pts = rng.uniform(0, 1, n)
    xs = np.linspace(0, n - 1, int(d * SR))
    return np.interp(xs, np.arange(n), pts)
def loopify(x, xf=0.5):
    """Crossfade the tail into the head so the file loops without a seam."""
    n = int(xf * SR)
    head, tail = x[:n], x[-n:]
    k = np.linspace(0, 1, n)
    y = x[n:].copy()
    y[-n:] = tail * (1 - k) + head * k
    return y
def fade(x, fi=0.003, fo=0.02):
    x = x.copy(); a, b = int(fi * SR), int(fo * SR)
    if a: x[:a] *= np.linspace(0, 1, a)
    if b: x[-b:] *= np.linspace(1, 0, b)
    return x
def write(name, x):
    x = np.clip(x, -1, 1)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print("wrote", name)


def wind_loop():
    d = 8.5
    g = smooth_noise(d, 0.9) ** 1.6
    whistle_f = 380 + 260 * smooth_noise(d, 0.5)
    body = lp(noise(d), 500) * (0.35 + 0.9 * g)
    howl = band(noise(d), 250, 900) * g * 0.8
    ph = np.cumsum(whistle_f) / SR
    whistle = np.sin(2 * np.pi * ph) * (g ** 3) * 0.08
    rustle = hp(noise(d), 3000) * (g ** 2) * 0.12
    write("wind_loop", norm(loopify(body + howl + whistle + rustle), 0.8))


def fire_loop():
    d = 6.5
    roar = lp(noise(d), 350) * (0.6 + 0.4 * smooth_noise(d, 2.0))
    x = roar * 0.8
    n = int(d * SR)
    crackle = np.zeros(n)
    for _ in range(int(d * 45)):
        i = rng.integers(0, n - 800)
        L = rng.integers(40, 700)
        crackle[i:i + L] += hp(rng.uniform(-1, 1, L), 1800) * np.exp(-np.arange(L) / (L * 0.25)) * rng.uniform(0.3, 1.0)
    for _ in range(int(d * 3)):     # the odd pop
        i = rng.integers(0, n - 3000)
        crackle[i:i + 3000] += band(rng.uniform(-1, 1, 3000), 400, 3000) * np.exp(-np.arange(3000) / 300) * 1.6
    write("fire_loop", norm(loopify(x + crackle * 0.6), 0.75))


def flame_burst():
    d = 0.75
    e = np.minimum(t(d) / 0.05, 1.0) * np.exp(-np.maximum(t(d) - 0.35, 0) * 8)
    x = lp(noise(d), 900) * e + band(noise(d), 1500, 6000) * e * 0.35
    x += np.sin(2 * np.pi * 55 * t(d)) * e * 0.3
    write("flame_burst", norm(fade(np.tanh(x * 2.0)), 0.9))


def flame_ignite():
    d = 1.0
    click = np.zeros(int(d * SR)); click[:300] = hp(rng.uniform(-1, 1, 300), 3000) * np.linspace(1, 0, 300)
    whoomp = lp(noise(d), 200) * np.exp(-np.maximum(t(d) - 0.12, 0) * 5) * (t(d) > 0.12)
    whoomp += np.sin(2 * np.pi * (70 - 30 * t(d)) * t(d)) * np.exp(-np.maximum(t(d) - 0.12, 0) * 6) * (t(d) > 0.12) * 0.8
    write("flame_ignite", norm(fade(click + np.tanh(whoomp * 2.5)), 0.95))


def claps(d, density, start_env=None):
    n = int(d * SR)
    x = np.zeros(n)
    k = int(d * density)
    for _ in range(k):
        i = rng.integers(0, n - 900)
        L = rng.integers(250, 700)
        c = band(rng.uniform(-1, 1, L), rng.uniform(900, 1600), rng.uniform(2500, 5000)) * np.exp(-np.arange(L) / (L * 0.18))
        x[i:i + L] += c * rng.uniform(0.3, 1.0)
    return x


def applause():
    d = 3.2
    x = claps(d, 900)
    env = np.minimum(t(d) / 0.25, 1.0) * np.exp(-np.maximum(t(d) - 1.8, 0) * 2.2)
    cheer = band(noise(d), 500, 2500) * 0.25 * env
    write("applause", norm(fade(reverb_small(x * env + cheer)), 0.8))


def reverb_small(x, mix=0.3):
    out = np.zeros_like(x)
    for dly, gg in [(1116, .8), (1188, .79), (1277, .78), (1356, .77)]:
        a = np.zeros(dly + 1); a[0] = 1; a[dly] = -gg
        out += lfilter([1], a, x)
    return x * (1 - mix) + out * 0.25 * mix


def laugh_voice(d, f0, rate, vowel):
    """One audience member: pulsed 'ha-ha-ha' with vowel formants."""
    tt = t(d)
    pitch = f0 * (1 + 0.08 * np.sin(2 * np.pi * 0.7 * tt)) * (1 - 0.15 * tt / d)
    src = 2.0 * ((np.cumsum(pitch) / SR) % 1.0) - 1.0
    src = src * 0.6 + noise(d) * 0.4
    f1, f2 = vowel
    v = band(src, f1 * 0.8, f1 * 1.25) + 0.6 * band(src, f2 * 0.85, f2 * 1.2)
    pulses = np.clip(np.sin(2 * np.pi * rate * tt + rng.uniform(0, 6)), 0, 1) ** 1.5
    env = np.minimum(tt / 0.1, 1.0) * np.exp(-np.maximum(tt - d * 0.55, 0) * 2.5)
    return v * pulses * env


def laugh_track():
    d = 3.0
    x = np.zeros(int(d * SR))
    for i in range(22):
        f0 = rng.uniform(110, 300)
        vow = [(750, 1200), (600, 1000), (400, 2000), (700, 1100)][i % 4]
        x += laugh_voice(d, f0, rng.uniform(4.0, 6.5), vow) * rng.uniform(0.4, 1.0)
    x = reverb_small(lp(x, 5000), 0.45)
    # tape wow: the reel isn't quite at speed
    write("laugh_track", norm(fade(x, 0.01, 0.4), 0.75))


def tote_ding():
    d = 0.9
    x = sum(np.sin(2 * np.pi * f * t(d)) * np.exp(-t(d) * k) * a for f, k, a in [(1318, 4, 1.0), (1975, 6, 0.5), (2637, 9, 0.25)])
    write("tote_ding", norm(fade(x), 0.8))


def on_air_buzz():
    d = 0.7
    x = np.sign(np.sin(2 * np.pi * 110 * t(d))) * 0.5 + np.sign(np.sin(2 * np.pi * 116 * t(d))) * 0.5
    write("on_air_buzz", norm(fade(lp(x, 2500), 0.005, 0.05), 0.7))


def sprinkler():
    d = 2.2
    n = int(d * SR)
    x = np.zeros(n)
    for at in (0.05, 0.4, 0.62, 1.1):
        i = int(at * SR)
        L = 5000
        x[i:i + L] += band(rng.uniform(-1, 1, L), 150, 900) * np.exp(-np.arange(L) / 700) * 1.5
    hiss = hp(noise(d), 2500) * np.exp(-np.abs(t(d) - 1.4) * 4) * 0.35
    cough = band(noise(d), 300, 1200) * (np.abs(np.sin(2 * np.pi * 3 * t(d))) ** 4) * (t(d) > 1.2) * np.exp(-(t(d) - 1.2).clip(0) * 2) * 0.6
    write("sprinkler", norm(fade(x + hiss + cough), 0.8))


if __name__ == "__main__":
    wind_loop(); fire_loop(); flame_burst(); flame_ignite(); applause(); laugh_track(); tote_ding(); on_air_buzz(); sprinkler()
