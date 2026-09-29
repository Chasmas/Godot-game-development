#!/usr/bin/env python3
"""Voices for pain and death: formant-synthesised grunts, groans and cries.

  python tools/gen_sfx_voice.py

A glottal pulse train (with jitter and a falling pitch) through three vowel
formants, breath noise on top, a fast attack and a ragged decay. Writes
assets/audio/sfx/:
  vox_hurt_m0..5   short male grunts (hit, knocked down)
  vox_die_m0..5    male death groans / cut-off cries
  vox_hurt_f0..3   Cass hurt
  vox_die_f0..2    Cass dying
  vox_boss_die0..1 deep, long boss groans
  vox_dog_die0..2  a dog's whine collapsing to a whimper
"""
import os, wave
import numpy as np
from scipy.signal import butter, lfilter

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "sfx")
rng = np.random.default_rng(1987)

def bp(x, lo, hi):
    b, a = butter(2, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band")
    return lfilter(b, a, x)

def lp(x, fc):
    b, a = butter(2, fc / (SR / 2), "low")
    return lfilter(b, a, x)

VOWELS = {   # F1, F2, F3 (Hz)
    "uh": (640, 1190, 2390), "ah": (780, 1250, 2500), "oh": (520, 900, 2400),
    "eh": (550, 1770, 2500), "ugh": (600, 1000, 2300), "ee": (300, 2300, 3000),
}

def voice(d, f0, f_end, vowel, vowel_end=None, breath=0.25, rough=0.0, shift=1.0, env_shape="grunt"):
    n = int(d * SR)
    t = np.arange(n) / SR
    k = t / d
    f = f0 + (f_end - f0) * k ** 0.7
    f = f * (1 + 0.012 * rng.standard_normal(n).cumsum() / np.sqrt(np.arange(1, n + 1)))   # jitter
    f = f * (1 + rough * 0.08 * np.sin(2 * np.pi * 31 * t))                              # growl
    ph = np.cumsum(f) / SR
    glott = (2 * (ph % 1.0) - 1) ** 3 + 0.4 * np.sign(np.sin(2 * np.pi * ph)) * rough
    breathy = rng.uniform(-1, 1, n) * breath
    src = glott + breathy
    F = np.array(VOWELS[vowel], float) * shift
    Fe = np.array(VOWELS[vowel_end or vowel], float) * shift
    y = np.zeros(n)
    # formants drifting from one vowel to the next, in a few blocks
    blocks = 6
    for bi in range(blocks):
        a0, a1 = bi * n // blocks, (bi + 1) * n // blocks
        kk = bi / max(1, blocks - 1)
        fm = F + (Fe - F) * kk
        seg = src[max(0, a0 - 400):a1]
        o = sum(bp(seg, fm[i] * 0.8, fm[i] * 1.2) * g for i, g in enumerate((1.0, 0.6, 0.3)))
        y[a0:a1] = o[-(a1 - a0):]
    if env_shape == "grunt":
        e = np.minimum(1, t / 0.015) * np.exp(-t * (5.0 / d))
    elif env_shape == "groan":
        e = np.minimum(1, t / 0.05) * np.clip(1.2 - k, 0, 1) ** 1.5
    else:   # cry: swells, holds, breaks off
        e = np.minimum(1, t / 0.03) * np.clip((1 - k) * 3, 0, 1) * (0.8 + 0.2 * np.sin(2 * np.pi * 6 * t))
    y = y * e + lp(rng.uniform(-1, 1, n), 3000) * e * breath * 0.2
    fl = int(0.004 * SR)
    y[:fl] *= np.linspace(0, 1, fl)
    y[-fl:] *= np.linspace(1, 0, fl)
    return y / (np.max(np.abs(y)) + 1e-9) * 0.85

def write(name, x):
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())
    print("sfx", name, f"{len(x) / SR:.2f}s")

def main():
    for i in range(6):
        f0 = rng.uniform(105, 150)
        v = ["uh", "ugh", "ah", "oh", "uh", "eh"][i]
        write(f"vox_hurt_m{i}", voice(rng.uniform(0.16, 0.26), f0 * 1.15, f0 * 0.8, v, None, 0.3, rng.uniform(0.2, 0.6), 1.0, "grunt"))
    for i in range(6):
        f0 = rng.uniform(110, 160)
        v, ve = [("ah", "uh"), ("oh", "ugh"), ("uh", "uh"), ("ah", "oh"), ("eh", "uh"), ("ugh", "oh")][i]
        shape = "cry" if i in (0, 3) else "groan"
        write(f"vox_die_m{i}", voice(rng.uniform(0.45, 0.8), f0 * (1.35 if shape == "cry" else 1.05), f0 * 0.62, v, ve, 0.35, rng.uniform(0.3, 0.8), 1.0, shape))
    for i in range(4):
        f0 = rng.uniform(230, 290)
        write(f"vox_hurt_f{i}", voice(rng.uniform(0.15, 0.22), f0 * 1.1, f0 * 0.85, ["ah", "uh", "eh", "ugh"][i], None, 0.35, 0.15, 1.16, "grunt"))
    for i in range(3):
        f0 = rng.uniform(240, 300)
        write(f"vox_die_f{i}", voice(rng.uniform(0.55, 0.8), f0 * 1.3, f0 * 0.7, ["ah", "oh", "eh"][i], "uh", 0.4, 0.2, 1.16, "cry"))
    for i in range(2):
        write(f"vox_boss_die{i}", voice(1.6, 95, 52, ["ah", "oh"][i], "ugh", 0.35, 0.9, 0.9, "groan"))
    for i in range(3):
        f0 = rng.uniform(600, 800)
        write(f"vox_dog_die{i}", voice(rng.uniform(0.5, 0.7), f0 * 1.2, f0 * 0.45, "ee", "oh", 0.25, 0.1, 1.6, "cry"))

if __name__ == "__main__":
    main()
