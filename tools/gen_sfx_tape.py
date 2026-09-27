#!/usr/bin/env python3
"""
VCR foley for the checkpoint cassette (own script so the other generators'
random streams never shift):

  tape_insert  - cassette slid into the deck: plastic slide, the carriage
                 clunk, the drum spinning up
  tape_rewind  - fast rewind whirr that brakes to a stop, then PLAY clunk

  python3 tools/gen_sfx_tape.py
"""
import os, wave
import numpy as np
from scipy.signal import lfilter, butter

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio", "sfx")
rng = np.random.default_rng(1988)

class fx:
    SR = SR
    @staticmethod
    def t(d): return np.arange(int(d * SR)) / SR
    @staticmethod
    def band(x, lo, hi):
        b, a = butter(2, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band"); return lfilter(b, a, x)
    @staticmethod
    def lp(x, fc):
        b, a = butter(2, fc / (SR / 2), "low"); return lfilter(b, a, x)
    @staticmethod
    def sil(d): return np.zeros(int(d * SR))
    @staticmethod
    def cat(*parts): return np.concatenate(parts)
    @staticmethod
    def write(name, x, peak=0.85):
        x = x / (np.max(np.abs(x)) + 1e-9) * peak
        with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
            w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())

def whirr(d, f0, f1, amp=0.25):
    tt = fx.t(d)
    f = f0 + (f1 - f0) * (tt / d)
    ph = 2 * np.pi * np.cumsum(f) / SR
    motor = np.sin(ph) * 0.6 + np.sin(ph * 2.02) * 0.3 + np.sign(np.sin(ph * 0.5)) * 0.1
    hiss = fx.band(rng.uniform(-1, 1, len(tt)), 2000, 7000) * 0.25
    return (motor * 0.5 + hiss) * amp

def clunk(heavy=1.0):
    body = fx.lp(rng.uniform(-1, 1, int(0.09 * SR)), 900) * np.exp(-np.arange(int(0.09 * SR)) / SR * 45)
    tick = fx.band(rng.uniform(-1, 1, int(0.02 * SR)), 2500, 9000) * np.exp(-np.arange(int(0.02 * SR)) / SR * 300)
    out = body * 1.4 * heavy
    out[:len(tick)] += tick
    return out

def slide(d):
    n = rng.uniform(-1, 1, int(d * SR))
    env = np.sin(np.linspace(0, np.pi, len(n))) ** 2
    return fx.band(n, 600, 3500) * env * 0.35

ins = fx.cat(slide(0.16), clunk(1.0), fx.sil(0.05), whirr(0.35, 40, 95, 0.18) * np.linspace(0.4, 1.0, int(0.35 * SR)) * np.linspace(1, 0.2, int(0.35 * SR)), clunk(0.5))
rew = fx.cat(whirr(0.45, 260, 520, 0.22), whirr(0.12, 520, 120, 0.18) * np.linspace(1, 0.2, int(0.12 * SR)), clunk(0.9), fx.sil(0.04), clunk(0.5))
fx.write("tape_insert", ins, 0.7)
fx.write("tape_rewind", rew, 0.6)
print("tape sfx written")
