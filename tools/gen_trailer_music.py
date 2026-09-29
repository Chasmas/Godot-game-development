#!/usr/bin/env python3
"""HOTSHOT CALIFORNIA - the trailer score: the game's main theme (Checkout
Time's tune) arranged as a trailer, 120 bpm so a bar is 2 s and the cut
in tools/make_trailer.py lands on it.

  0-10   intro     rain, a dark pad, the hook teased on the bell
  10-22  verse     bass and a light beat come in, the verse tune
  22-32  build     the pre-chorus climbing, a snare roll, a riser; silence
  32-56  drop      the chorus with the full kit, brass, the bell doubling
  56-64  frenzy    the chorus doubled an octave up, 16th hats, tom fills
  64-72  title     one huge hit, then the hook slow and wide over the pads
  72-82  release   the hook resolves, the pads fade out

  python tools/gen_trailer_music.py <out.wav>
"""
import os, sys, wave
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_music_synth as S

SR = S.SR
BPM = 120
beat = 60.0 / BPM
st = beat / 4
B = beat * 4
TOTAL = 82.0
N = int(TOTAL * SR)

class Bus(S.Bus):
    def add(self, x, at, g=1.0, pan=0.0):
        # no wrap-around: a trailer has an end
        x = np.array(x, dtype=np.float64)
        f = min(len(x) // 2, int(0.004 * SR))
        if f > 1:
            ramp = np.linspace(0.0, 1.0, f)
            x[:f] *= ramp
            x[-f:] *= ramp[::-1]
        s = int(round(at * SR))
        if s >= self.n:
            return
        e = min(self.n, s + len(x))
        l = np.cos((pan + 1) * np.pi / 4) * 1.414 * g
        r = np.sin((pan + 1) * np.pi / 4) * 1.414 * g
        self.L[s:e] += x[:e - s] * l
        self.R[s:e] += x[:e - s] * r

song = S.SONGS["level_checkout"]
VERSE = song["verse"]
PRE = song["pre"]
CHORUS = song["chorus"]
PROG = song["prog"]

music = Bus(N)     # pads, bass, tune
drums = Bus(N)
fx = Bus(N)
kicks = []
K, SN, CL = S.kick(), S.snare(), S.clap()
HC, HO = S.hat(), S.hat(True)
prev = [None]

def br_of(root):
    b = root
    while b > 44:
        b -= 12
    while b < 33:
        b += 12
    return b

def tune(notes, t0, g, octave=0, synth="lead", pan=0.0, stretch=1.0):
    for (s, m, l) in notes:
        mm = m + 12 * octave
        d = st * l * 0.94 * stretch
        at = t0 + s * st * stretch
        if synth == "lead":
            music.add(S.lead(mm, d, prev[0]), at, g, pan)
            prev[0] = mm
        elif synth == "bell":
            music.add(S.bell(mm, max(d, st * 3)), at, g, pan)
        elif synth == "grit":
            music.add(S.soft(S.lead(mm, d, None, 5200) * 2.0, 2.0), at, g, pan)

def bar_slice(phrase, i):
    off = i * 16
    return [(s - off, m, l) for (s, m, l) in phrase if off <= s < off + 16]

def kit(t0, full=True, sixteenths=False, fill=False):
    for b4 in range(4):
        at = t0 + b4 * beat
        drums.add(K, at, 0.62)
        kicks.append(at)
        if full and b4 in (1, 3):
            drums.add(SN, at, 0.55)
            drums.add(CL, at, 0.22, 0.2)
        if full:
            drums.add(HO, at + beat * 0.5, 0.1, -0.3)
    for s16 in range(0, 16, 1 if sixteenths else 2):
        drums.add(HC, t0 + s16 * st, 0.09 if s16 % 4 else 0.13, 0.25 if s16 % 2 else -0.2)
    if fill:
        for k, m in enumerate((52, 50, 47, 45, 43, 40)):
            drums.add(S.tom(m), t0 + (10 + k) * st, 0.4, -0.5 + k * 0.2)

def harmony(t0, root, kind, pad_g=0.14, bass_style="octaves", cut=2400):
    ch = S.triad(root + 12, kind)
    b = br_of(root)
    music.add(S.pad(ch, B * 1.02, cut), t0, pad_g)
    if bass_style == "octaves":
        for s16 in range(0, 16, 2):
            music.add(S.bass(b + (12 if s16 % 4 == 2 else 0), st * 1.7), t0 + s16 * st, 0.5)
    elif bass_style == "long":
        music.add(S.bass(b, B * 0.95, 600, 2.0), t0, 0.5)
    return ch

# rain under the opening (and the story)
rain = S.lp(S.hp(S.noise(34.0), 1500), 7000) * 0.05
music.add(rain * np.minimum(1, np.linspace(0, 6, len(rain))) * np.minimum(1, np.linspace(6, 0, len(rain))), 0.0, 1.0)

bar = 0
# ---- intro: bars 0-4 (0-10 s)
for i in range(5):
    t0 = bar * B
    root, kind = PROG["intro"][i % 4]
    harmony(t0, root, kind, 0.12, "long" if i >= 2 else None, 1500)
    if i == 3:
        tune(bar_slice(CHORUS[0], 0), t0, 0.2, 0, "bell")
    if i == 4:
        tune(bar_slice(CHORUS[0], 1), t0, 0.2, 0, "bell")
        fx.add(S.riser(B), t0, 0.3)
    bar += 1
# ---- verse: bars 5-10 (10-22 s)
for i in range(6):
    t0 = bar * B
    root, kind = PROG["verse"][i % 4]
    harmony(t0, root, kind, 0.12)
    for b4 in (0, 2):
        drums.add(K, t0 + b4 * beat, 0.5)
        kicks.append(t0 + b4 * beat)
    for s16 in range(0, 16, 2):
        drums.add(HC, t0 + s16 * st, 0.08, 0.25)
    if i >= 2:
        drums.add(SN, t0 + 3 * beat, 0.3)
    ph = VERSE[(i // 2) % 4]
    tune([(s - (i % 2) * 16, m, l) for (s, m, l) in ph if (i % 2) * 16 <= s < (i % 2) * 16 + 16], t0, 0.26)
    bar += 1
# ---- build: bars 11-15 (22-32 s); the last half bar is silence
for i in range(5):
    t0 = bar * B
    root, kind = PROG["pre"][i % 4]
    harmony(t0, root, kind, 0.14 + 0.02 * i, "octaves", 2400 + 500 * i)
    for b4 in range(4):
        drums.add(K, t0 + b4 * beat, 0.5 + 0.04 * i)
        kicks.append(t0 + b4 * beat)
    if i < 4:
        tune(bar_slice(PRE, i), t0, 0.28)
    if i == 3:
        fx.add(S.riser(B * 2), t0, 0.5)
    if i == 4:
        # the snare roll, faster and louder, then nothing
        for r in range(12):
            drums.add(SN, t0 + r * (B * 0.5 / 12), 0.12 + 0.04 * r)
    bar += 1
# silence the last half bar of the build (31-32 s): cut everything there
cut0, cut1 = int(31.0 * SR), int(32.0 * SR)
# ---- drop: bars 16-27 (32-56 s)
for i in range(12):
    t0 = bar * B
    root, kind = PROG["chorus"][i % 8]
    ch = harmony(t0, root, kind, 0.15, "octaves", 3200)
    kit(t0, True, False, i % 4 == 3)
    if i % 4 == 0:
        fx.add(S.crash(), t0, 0.4)
    for s16 in (0, 6, 10):
        music.add(S.brass(ch, st * 2), t0 + s16 * st, 0.15, -0.15)
    half = CHORUS[(i // 4) % 2]
    part = bar_slice(half, i % 4)
    tune(part, t0, 0.34)
    tune(part, t0, 0.16, 0, "bell", -0.3)
    bar += 1
# ---- frenzy: bars 28-31 (56-64 s)
for i in range(4):
    t0 = bar * B
    root, kind = PROG["chorus"][4 + i]
    ch = harmony(t0, root, kind, 0.16, "octaves", 3600)
    kit(t0, True, True, True)
    for s16 in (0, 3, 6, 10, 12):
        music.add(S.brass(ch, st * 2), t0 + s16 * st, 0.14, -0.15)
    part = bar_slice(CHORUS[1], i)
    tune(part, t0, 0.34)
    tune(part, t0, 0.1, 1, "grit", 0.35)
    if i == 3:
        fx.add(S.riser(B), t0, 0.5)
    bar += 1
# ---- title: bars 32-35 (64-72 s) - one huge hit, then the hook slow
t0 = bar * B
hit = S.kick(1.2) * 1.4
fx.add(hit, t0, 0.9)
fx.add(S.crash(3.0), t0, 0.6)
fx.add(S.sub(33, 3.0) * np.exp(-S.t_ax(3.0) * 1.2), t0, 0.7)
for i in range(4):
    root, kind = [(41, "M"), (43, "M"), (40, "m"), (45, "m")][i]
    harmony(bar * B, root, kind, 0.2, "long", 3000)
    bar += 1
tune([(s, m, l) for (s, m, l) in CHORUS[0] if s < 32], t0, 0.3, 0, "lead", 0.0, 2.0)
tune([(s, m, l) for (s, m, l) in CHORUS[0] if s < 32], t0, 0.14, 0, "bell", -0.3, 2.0)
# ---- release: bars 36-40 (72-82 s) - the hook resolves, fade
t0 = bar * B
for i in range(5):
    root, kind = [(41, "M"), (43, "M"), (40, "M"), (45, "m"), (45, "m")][i]
    harmony(bar * B, root, kind, 0.18 - 0.02 * i, "long" if i < 4 else None, 2600)
    bar += 1
tune([(s - 32, m, l) for (s, m, l) in CHORUS[1] if s >= 32], t0, 0.28, 0, "lead", 0.0, 1.5)
tune([(0, 69, 16)], t0 + 3 * B, 0.18, 0, "bell")

# ---- mix
music.pump(kicks, 0.3, beat)
music.delay(beat * 0.75, 0.28, 0.16)
L = music.L + drums.L + fx.L
R = music.R + drums.R + fx.R
L, R = S.space(L, R, 0.24, 2.6)
L[cut0:cut1] *= 0.0
R[cut0:cut1] *= 0.0
# ramps in and out of the silence, and a long fade at the end
fade = int(0.02 * SR)
for a in (cut0,):
    L[a - fade:a] *= np.linspace(1, 0, fade); R[a - fade:a] *= np.linspace(1, 0, fade)
tail = int(4.0 * SR)
L[-tail:] *= np.linspace(1, 0, tail) ** 1.5
R[-tail:] *= np.linspace(1, 0, tail) ** 1.5
x = S.master(L, R, 0.9)
out = sys.argv[1] if len(sys.argv) > 1 else "score.wav"
with wave.open(out, "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
print("trailer score", out, f"{len(x) / SR:.1f}s")
