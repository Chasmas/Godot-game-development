#!/usr/bin/env python3
"""
Speech "babble" for dialogue and speech bubbles: short formant-synthesised
vowel grains, played one per couple of letters as text types out. The
vowel follows the letter being revealed and the pitch follows the speaker,
so lines sound like gibberish speech rather than a beep.

  python3 tools/gen_voice.py      -> assets/audio/sfx/vox_*.wav, bubble_pop.wav, type_clack.wav

Kinds:
  vox    - a person in the room
  voxtel - through a telephone / answering machine (THE VOICE)
  voxtv  - through a TV speaker (the anchor, Marv)
  voxbot - the answering machine's own voice
"""
import os, wave
import numpy as np
from scipy.signal import lfilter, butter

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "sfx")
rng = np.random.default_rng(7)

FORMANTS = {  # F1, F2, F3 (Hz), rough adult averages
    "a": (800, 1200, 2500),
    "e": (420, 1950, 2600),
    "i": (300, 2250, 3000),
    "o": (520, 880, 2400),
    "u": (340, 760, 2300),
}

def write(name, x):
    x = np.clip(x, -1, 1)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())

def resonator(x, f, bw):
    r = np.exp(-np.pi * bw / SR)
    a = [1.0, -2.0 * r * np.cos(2 * np.pi * f / SR), r * r]
    return lfilter([1.0 - r], a, x)

def band(x, lo, hi):
    b, a = butter(2, [lo / (SR / 2), hi / (SR / 2)], "band"); return lfilter(b, a, x)

def glottal(f0_curve):
    # band-limited-ish pulse train: sum of harmonics with a -12 dB/oct tilt
    ph = np.cumsum(f0_curve) / SR
    out = np.zeros_like(ph)
    for h in range(1, 28):
        if np.max(f0_curve) * h > SR * 0.45:
            break
        out += np.sin(2 * np.pi * h * ph) / (h ** 1.15)
    return out

def grain(vowel, glide, dur=0.085, f0=150.0, breath=0.05):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f0c = f0 * (1.0 + glide * (t / dur)) * (1.0 + 0.01 * np.sin(2 * np.pi * 6 * t))
    src = glottal(f0c) + rng.normal(0, breath, n)
    F1, F2, F3 = FORMANTS[vowel]
    y = resonator(src, F1, 90) * 1.0 + resonator(src, F2, 120) * 0.55 + resonator(src, F3, 180) * 0.25
    env = np.minimum(1.0, t / 0.008) * np.minimum(1.0, (dur - t) / 0.03)
    env = np.clip(env, 0, 1) ** 1.2
    y = y * env
    return y / (np.max(np.abs(y)) or 1.0)

def kinds(y):
    out = {"vox": y * 0.8}
    tel = band(y, 380, 3200)
    out["voxtel"] = np.tanh(tel / (np.max(np.abs(tel)) or 1) * 2.4) * 0.6
    tv = band(y, 180, 5000)
    out["voxtv"] = tv / (np.max(np.abs(tv)) or 1) * 0.75
    return out

def bot(vowel, glide):
    # the answering machine: stepped square tone with a hint of formant
    n = int(0.08 * SR); t = np.arange(n) / SR
    f = 190.0 * (1.0 + 0.12 * np.round(glide * 4) / 4)
    sq = np.sign(np.sin(2 * np.pi * f * t))
    F1, F2, _ = FORMANTS[vowel]
    y = resonator(sq, F1, 200) + resonator(sq, F2, 300) * 0.5
    env = np.minimum(1.0, t / 0.004) * np.minimum(1.0, (0.08 - t) / 0.012)
    y = y * np.clip(env, 0, 1)
    return y / (np.max(np.abs(y)) or 1.0) * 0.55

def main():
    for v in "aeiou":
        for k, glide in ((1, 0.08), (2, -0.10)):
            y = grain(v, glide)
            for kind, x in kinds(y).items():
                write(f"{kind}_{v}{k}", x)
            write(f"voxbot_{v}{k}", bot(v, glide))
    # speech-bubble pop: a soft rising "bip" with a click
    n = int(0.09 * SR); t = np.arange(n) / SR
    f = 380 + 900 * (1 - np.exp(-t * 60))
    pop = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 38)
    pop[:60] += np.linspace(0.6, 0, 60)
    write("bubble_pop", pop / np.max(np.abs(pop)) * 0.7)
    # narration: a typewriter key
    n = int(0.05 * SR); t = np.arange(n) / SR
    cl = band(rng.uniform(-1, 1, n), 1800, 7000) * np.exp(-t * 140)
    cl += np.sin(2 * np.pi * 180 * t) * np.exp(-t * 90) * 0.4
    write("type_clack", cl / np.max(np.abs(cl)) * 0.6)
    print("voice grains written")

if __name__ == "__main__":
    main()
