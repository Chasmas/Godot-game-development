#!/usr/bin/env python3
"""
HOTSHOT CALIFORNIA - "Neon Vigil", the title theme, third take: smooth,
dreamy synthwave in the lineage of the 1980s-by-way-of-2012 scores (glassy
plucks bouncing through a ping-pong delay, lush chorused pads, a warm lead
with a real melody, clean punchy drums, everything sitting in a long hall).
All original material.

Also exposes `space()` - the reverb/chorus finishing chain - for the level
composer.

  python tools/gen_music_dream.py            (needs ffmpeg on PATH)
"""
import os, sys, subprocess, wave
import numpy as np
from scipy.signal import butter, lfilter, fftconvolve

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUS = os.path.join(ROOT, "music")
rng = np.random.default_rng(1984)

def T(d): return np.arange(int(d * SR)) / SR
def mtof(m): return 440.0 * 2 ** ((m - 69) / 12.0)
def lp(x, f, o=2):
    b, a = butter(o, min(f, SR * 0.45) / (SR / 2), "low"); return lfilter(b, a, x)
def hp(x, f, o=2):
    b, a = butter(o, f / (SR / 2), "high"); return lfilter(b, a, x)
def bp(x, lo, hi, o=2):
    b, a = butter(o, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band"); return lfilter(b, a, x)
def sat(x, d=1.5): return np.tanh(x * d) / np.tanh(d)
def N(d): return rng.uniform(-1, 1, int(d * SR))
def saw_ph(ph): return 2.0 * (ph % 1.0) - 1.0

def adsr(n, a, d, s, r):
    e = np.full(n, s)
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    if a: e[:min(a, n)] = np.linspace(0, 1, a)[:min(a, n)]
    if d and a < n:
        seg = np.linspace(1, s, d)[:max(0, min(d, n - a))]
        e[a:a + len(seg)] = seg
    if r: e[-min(r, n):] *= np.linspace(1, 0, min(r, n))
    return e

def tvf(x, f0, f1, rate):
    """a filter envelope: cutoff falls from f0 to f1, processed in blocks"""
    y = np.zeros_like(x)
    n = len(x)
    for i in range(0, n, 256):
        f = f1 + (f0 - f1) * np.exp(-(i / SR) * rate)
        y[i:i + 256] = lp(x[i:i + 256], f)
    return y

# ------------------------------------------------------------ instruments
def pluck(m, d):
    """glassy pluck: saw + square an octave up, a snappy filter envelope"""
    t = T(d); f = mtof(m)
    x = saw_ph(t * f) * 0.6 + np.sign(np.sin(2 * np.pi * f * 2 * t)) * 0.25 + np.sin(2 * np.pi * f * t) * 0.3
    return tvf(x, 5200, 700, 16) * np.exp(-t * 5.5) * adsr(len(t), 0.002, 0.0, 1.0, 0.02)

def supersaw(notes, d, cut=1400, voices=5, att=0.6, rel=0.8):
    t = T(d)
    x = np.zeros(len(t))
    for m in notes:
        for v in range(voices):
            det = (v - (voices - 1) / 2) * 0.006
            x += saw_ph(t * mtof(m) * (1 + det) + rng.random())
    x /= voices * len(notes)
    return lp(x, cut) * adsr(len(t), att, 0.4, 0.85, rel)

def warm_lead(notes, d, glide_from=None):
    t = T(d); f0 = mtof(notes)
    f = np.full_like(t, f0)
    if glide_from is not None:
        f = f0 + (mtof(glide_from) - f0) * np.exp(-t * 28)
    f = f * (1 + 0.005 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.15) / 0.3, 0, 1))
    ph = np.cumsum(f) / SR
    x = saw_ph(ph) * 0.45 + saw_ph(ph * 1.004 + 0.3) * 0.35 + np.sign(np.sin(2 * np.pi * ph)) * 0.2
    return lp(sat(x, 1.2), 3000) * adsr(len(t), 0.012, 0.15, 0.8, 0.12)

def sub_bass(m, d):
    t = T(d); f = mtof(m)
    x = np.sin(2 * np.pi * f * t) * 0.8 + lp(saw_ph(t * f), 600) * 0.45
    return sat(x, 1.4) * adsr(len(t), 0.004, 0.1, 0.8, 0.04)

def kick(d=0.5):
    t = T(d)
    f = 45 + 110 * np.exp(-t * 28)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 6.5)
    return sat(x * 1.3 + hp(N(d), 4000) * np.exp(-t * 250) * 0.3, 1.8)

def clap(d=0.4):
    t = T(d); n = bp(N(d), 1000, 5200)
    e = sum(np.exp(-np.maximum(t - o, 0) * 55) * (t >= o) for o in (0.0, 0.009, 0.018))
    e += np.exp(-np.maximum(t - 0.026, 0) * 11) * 0.6 * (t >= 0.026)
    return n * e * 0.7

def hat(d=0.06, open_=False):
    d = 0.35 if open_ else d
    t = T(d)
    return hp(N(d), 8000) * np.exp(-t * (8 if open_ else 60)) * 0.4

# ------------------------------------------------------------ the space
def _ir(secs, damp, seed):
    r = np.random.default_rng(seed)
    t = T(secs)
    ir = lp(r.uniform(-1, 1, len(t)), damp) * np.exp(-t * (6.9 / secs))
    ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))   # predelay-ish
    return ir / np.sqrt(np.sum(ir ** 2))

def space(L, R, wet=0.28, secs=2.6, damp=5000):
    """stereo hall (decorrelated noise IRs) + gentle chorus"""
    irl, irr = _ir(secs, damp, 1), _ir(secs, damp, 2)
    wl = fftconvolve(L, irl)[: len(L)]
    wr = fftconvolve(R, irr)[: len(R)]
    # chorus: two slowly modulated short delays
    n = len(L)
    idx = np.arange(n)
    mod = (0.012 + 0.003 * np.sin(2 * np.pi * 0.35 * idx / SR)) * SR
    cl = np.interp(idx - mod, idx, L, left=0)
    cr = np.interp(idx - (0.014 * SR + 0.003 * SR * np.sin(2 * np.pi * 0.29 * idx / SR + 1.3)), idx, R, left=0)
    return (L * 0.82 + cl * 0.18 + wl * wet, R * 0.82 + cr * 0.18 + wr * wet)

class Mix:
    def __init__(self, bpm, bars):
        self.beat = 60.0 / bpm
        self.st = self.beat / 4
        self.bar = self.beat * 4
        self.n = int(round(self.bar * bars * SR))
        self.buses = {}
    def bus(self, name):
        if name not in self.buses:
            self.buses[name] = [np.zeros(self.n), np.zeros(self.n)]
        return self.buses[name]
    def add(self, name, x, at, g=1.0, pan=0.0):
        L, R = self.bus(name)
        # declick: every note eases in and out over 3 ms (hard onsets crackled)
        x = np.array(x, dtype=np.float64)
        f = min(len(x) // 2, int(0.003 * SR))
        if f > 1:
            ramp = np.linspace(0.0, 1.0, f)
            x[:f] *= ramp
            x[-f:] *= ramp[::-1]
        s = int(at * SR) % self.n
        l = np.cos((pan + 1) * np.pi / 4) * 1.414 * g
        r = np.sin((pan + 1) * np.pi / 4) * 1.414 * g
        e = min(self.n, s + len(x))
        L[s:e] += x[: e - s] * l
        R[s:e] += x[: e - s] * r
        rest = x[e - s:]
        if len(rest):       # wrap the tail round: the theme loops seamlessly
            m = min(len(rest), self.n)
            L[:m] += rest[:m] * l
            R[:m] += rest[:m] * r

def pingpong(L, R, secs, fb=0.42, wet=0.35, n=6):
    d = int(secs * SR)
    outL, outR = np.zeros_like(L), np.zeros_like(R)
    src = (L + R) * 0.5
    g = 1.0
    for k in range(1, n + 1):
        g *= fb
        sh = np.roll(src, d * k)
        if k % 2:
            outR += sh * g
        else:
            outL += sh * g
    return L + lp(outL, 5000) * wet, R + lp(outR, 5000) * wet

def sidechain(L, R, kicks, n, beat, depth=0.45):
    gate = np.ones(n)
    rel = int(beat * 0.85 * SR)
    shape = 1 - depth * np.exp(-np.linspace(0, 4.5, rel))
    for at in kicks:
        s = int(at * SR) % n
        e = min(n, s + rel)
        gate[s:e] = np.minimum(gate[s:e], shape[: e - s])
    return L * gate, R * gate

def write_ogg(name, L, R, peak=0.92, q=5):
    x = np.stack([hp(L, 30), hp(R, 30)], axis=1)
    x = x / (np.max(np.abs(x)) + 1e-9) * min(peak, 0.84)   # clean: no drive on the master
    tmp = os.path.join(MUS, name + ".tmp.wav")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-ar", "44100", "-c:a", "libvorbis", "-q:a", str(q), os.path.join(MUS, name + ".ogg")], check=True)
    os.remove(tmp)
    print("music", name, f"{len(x) / SR:.1f}s")

# ------------------------------------------------------------ Neon Vigil
# A minor / C major, 108 bpm. Fmaj7 - G6 - Em7 - Am9, then Fmaj7 - G - Am -
# Am/E. Intro (pad, plucks) / A (+ drums, bass) / B (+ the melody) /
# C (melody an octave up with a counter-line, full kit) - and round again.
PROG = [[53, 57, 60, 64], [55, 59, 62, 64], [52, 55, 59, 62], [57, 60, 64, 71],
        [53, 57, 60, 64], [55, 59, 62, 67], [57, 60, 64, 67], [52, 57, 60, 64]]
BASS = [41, 43, 40, 45, 41, 43, 45, 40]
MEL_A = [(0, 76, 4), (4, 79, 2), (6, 81, 2), (8, 84, 4), (12, 83, 2), (14, 81, 2),
         (16, 79, 6), (22, 76, 2), (24, 74, 2), (26, 76, 2), (28, 79, 4)]
MEL_B = [(0, 76, 4), (4, 79, 2), (6, 81, 2), (8, 83, 4), (12, 81, 2), (14, 79, 2),
         (16, 76, 8), (24, 72, 2), (26, 74, 2), (28, 76, 4)]

def neon_vigil():
    bars = 32
    mx = Mix(108, bars)
    st, beat, B = mx.st, mx.beat, mx.bar
    kicks = []
    for bar in range(bars):
        t0 = bar * B
        sec = bar // 8           # 0 intro, 1 A, 2 B, 3 C
        ch = PROG[bar % 8]
        # pad on every bar, brighter as it builds
        mx.add("pad", supersaw(ch, B * 1.02, 900 + 350 * sec), t0, 0.22)
        # glassy plucks: up and down the chord across two octaves in 16ths
        pat = [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[3] + 12, ch[2] + 24, ch[3] + 12, ch[1] + 12, ch[2] + 12]
        for s in range(16):
            vel = 0.16 if s % 4 == 0 else 0.1
            mx.add("pluck", pluck(pat[s % 8], st * 0.95), t0 + s * st, vel, -0.35 if s % 2 else 0.35)
        if sec >= 1:
            # bass: pulsing 8ths, octave jump on the "and" of 4
            for e8 in range(8):
                m = BASS[bar % 8] - 12 + (12 if e8 == 7 else 0)
                mx.add("bass", sub_bass(m, st * 1.7), t0 + e8 * st * 2, 0.42)
            for b4 in range(4):
                mx.add("drums", kick(), t0 + b4 * beat, 0.8)
                kicks.append(t0 + b4 * beat)
                if b4 in (1, 3):
                    mx.add("drums", clap(), t0 + b4 * beat, 0.42, 0.1)
                mx.add("drums", hat(open_=True), t0 + b4 * beat + beat * 0.5, 0.09, 0.3)
            for s in range(16):
                if sec >= 2 and s % 2 == 1:
                    mx.add("drums", hat(), t0 + s * st, 0.05, -0.3)
        if bar % 8 == 7:
            # a little fill into the next section
            for k in range(4):
                mx.add("drums", clap(0.25), t0 + (12 + k) * st, 0.18 + k * 0.05)
        # the melody from section B, an octave up with a counter-line in C
        if sec >= 2:
            phrase = MEL_A if (bar % 4) < 2 else MEL_B
            half = (bar % 2) * 16
            prev = None
            up = 12 if sec == 3 else 0
            for (s, m, l) in phrase:
                if half <= s < half + 16:
                    mx.add("lead", warm_lead(m + up - 12, st * l * 0.96, prev), t0 + (s - half) * st, 0.3, 0.05)
                    prev = m + up - 12
            if sec == 3 and bar % 2 == 0:
                mx.add("lead", warm_lead(ch[1] + 12, B * 0.9) * 0.5, t0, 0.14, -0.4)
    # the chain: plucks through a dotted-8th ping-pong, the pad and lead
    # chorused in a hall, everything but the drums breathing with the kick
    Lp, Rp = mx.bus("pluck")
    Lp, Rp = pingpong(Lp, Rp, beat * 0.75, 0.45, 0.5)
    Ll, Rl = mx.bus("lead")
    Ll, Rl = pingpong(Ll, Rl, beat * 0.75, 0.3, 0.25)
    La, Ra = mx.bus("pad")
    Lb, Rb = mx.bus("bass")
    Ld, Rd = mx.bus("drums")
    L = Lp + Ll + La + Lb
    R = Rp + Rl + Ra + Rb
    L, R = sidechain(L, R, kicks, mx.n, beat, 0.4)
    L, R = space(L + Ld * 0.3, R + Rd * 0.3, 0.32, 2.8)
    L += Ld * 0.7
    R += Rd * 0.7
    write_ogg("title_neon_vigil", L, R)

if __name__ == "__main__":
    neon_vigil()
