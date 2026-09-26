#!/usr/bin/env python3
"""
Extra foley for animation and new mechanics (kept apart from gen_audio.py
so regenerating these never shifts that script's random stream):

  mag_out, mag_in, slide_rack, shell_insert  - reload steps
  beat_tick        - a kill landing on the beat
  rec_beep         - the REC finisher / hidden camera
  camera_break     - shooting a hidden camera
  sniper_charge    - the sniper's laser settling on you
  whoosh           - melee swing air
  throw            - throwing a bottle/ashtray
  snore            - a guard dozing
  python3 tools/gen_sfx_extra.py
"""
import os, wave
import numpy as np
from scipy.signal import lfilter, butter

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio", "sfx")
rng = np.random.default_rng(58)

def t(d): return np.arange(int(d * SR)) / SR
def noise(d): return rng.uniform(-1, 1, int(d * SR))
def band(x, lo, hi):
    b, a = butter(2, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band"); return lfilter(b, a, x)
def lp(x, fc):
    b, a = butter(2, fc / (SR / 2), "low"); return lfilter(b, a, x)
def write(name, x, peak=0.85):
    x = x / (np.max(np.abs(x)) or 1) * peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
def click(d, lo, hi, k):
    return band(noise(d), lo, hi) * np.exp(-t(d) * k)
def cat(*parts):
    return np.concatenate(parts)
def sil(d): return np.zeros(int(d * SR))

write("mag_out", cat(click(0.03, 800, 6000, 120), sil(0.03), click(0.06, 300, 2500, 60) * 0.6))
write("mag_in", cat(click(0.02, 1500, 8000, 200) * 0.5, sil(0.02), click(0.05, 400, 5000, 90) + np.sin(2 * np.pi * 220 * t(0.05)) * np.exp(-t(0.05) * 60) * 0.5))
write("slide_rack", cat(click(0.05, 1200, 9000, 50) * 0.7, sil(0.04), click(0.04, 600, 7000, 110)))
write("shell_insert", cat(click(0.025, 1000, 6000, 160), sil(0.015), click(0.04, 250, 2000, 90) * 0.8))
tt = t(0.12)
write("beat_tick", np.sin(2 * np.pi * 1760 * tt) * np.exp(-tt * 40) + np.sin(2 * np.pi * 880 * tt) * np.exp(-tt * 25) * 0.6, 0.6)
tt = t(0.18)
write("rec_beep", np.sign(np.sin(2 * np.pi * 1200 * tt)) * np.exp(-tt * 8) * (tt < 0.14), 0.4)
write("camera_break", cat(click(0.08, 2000, 12000, 30) + band(noise(0.08), 200, 800) * np.exp(-t(0.08) * 20), lp(noise(0.25), 3000) * np.exp(-t(0.25) * 12) * 0.5))
tt = t(0.6)
write("sniper_charge", np.sin(2 * np.pi * (400 + 900 * tt / 0.6) * tt) * (0.3 + 0.7 * tt / 0.6) * np.minimum(1, (0.6 - tt) / 0.03), 0.4)
tt = t(0.16)
write("whoosh", band(noise(0.16), 400, 3000) * np.sin(np.pi * tt / 0.16) ** 2, 0.6)
write("throw", band(noise(0.2), 300, 2000) * np.sin(np.pi * t(0.2) / 0.2) ** 3, 0.55)
tt = t(1.4)
breath = lp(noise(1.4), 900) * (np.sin(np.pi * tt / 1.4) ** 2) * (1 + 0.8 * np.sign(np.sin(2 * np.pi * 38 * tt)) * (tt < 0.8))
write("snore", breath, 0.35)
print("extra sfx written")
