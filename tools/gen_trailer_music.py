#!/usr/bin/env python3
"""The announcement trailer's score: 80 seconds, E minor, 120 bpm, cut to
the edit in tools/make_trailer.py (the beat grid is shared: BAR = 2 s).

  0-16   intro   pad, glassy plucks, a heartbeat kick        (studio, creator, story)
  16-32  build   the hypnotic bass, hats, the hook teased, a riser, a half-beat of silence
  32-64  drop    full kit, gritty 8th bass, the hook, stabs  (gameplay montage)
  64-72  logo    one huge chord and the hook echoing out
  72-80  card    the pad and the studio chime               (release card)

  python tools/gen_trailer_music.py OUT.wav
"""
import os, sys, wave
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_music_dream as D
import gen_music_hm as H

SR = D.SR
BPM = 120
BEAT = 60 / BPM
ST = BEAT / 4
BAR = BEAT * 4
BARS = 40
N = int(BAR * BARS * SR)

L = np.zeros(N); R = np.zeros(N)
bus = {k: [np.zeros(N), np.zeros(N)] for k in ("pad", "pluck", "bass", "drums", "lead", "fx")}

def add(name, x, at, g=1.0, pan=0.0):
    s = int(at * SR)
    if s >= N:
        return
    # declick: every note eases in and out over 3 ms (hard onsets crackled)
    x = np.array(x, dtype=np.float64)
    f = min(len(x) // 2, int(0.003 * SR))
    if f > 1:
        ramp = np.linspace(0.0, 1.0, f)
        x[:f] *= ramp
        x[-f:] *= ramp[::-1]
    l = np.cos((pan + 1) * np.pi / 4) * 1.414 * g
    r = np.sin((pan + 1) * np.pi / 4) * 1.414 * g
    e = min(N, s + len(x))
    bus[name][0][s:e] += x[: e - s] * l
    bus[name][1][s:e] += x[: e - s] * r

PROG = [[40, 43, 47], [36, 40, 43], [43, 47, 50], [38, 42, 45]]   # Em C G D
HOOK = [(0, 71, 3), (3, 76, 3), (6, 79, 6), (12, 78, 2), (14, 76, 2), (16, 74, 4), (20, 76, 4), (24, 71, 8)]
kicks = []

for bar in range(BARS):
    t0 = bar * BAR
    ch = PROG[bar % 4]
    root = ch[0]
    # pad throughout, opening up as it goes, dying away in the last bars
    padg = 0.16 if bar < 36 else 0.16 * (40 - bar) / 4
    add("pad", D.supersaw([n + 12 for n in ch], BAR * 1.02, 700 + min(bar, 32) * 45), t0, padg)
    # glassy plucks
    if bar < 34 or bar >= 36:
        pat = [ch[0] + 24, ch[1] + 24, ch[2] + 24, ch[1] + 36, ch[2] + 24, ch[1] + 24, ch[0] + 24, ch[2] + 12]
        dens = 2 if bar < 8 else 1
        for s in range(0, 16, dens):
            add("pluck", D.pluck(pat[s % 8], ST * 0.95), t0 + s * ST, 0.11 if s % 4 else 0.15, -0.4 if s % 2 else 0.4)
    # heartbeat in the intro
    if bar < 8:
        add("drums", D.kick(0.4), t0, 0.5); add("drums", D.kick(0.4), t0 + BEAT * 0.4, 0.3)
        kicks.append(t0)
    # the build: the hypnotic bass, 16ths of hat, the hook's first notes teased
    if 8 <= bar < 16:
        for s in range(16):
            fig = [0, 0, 12, 0, 7, 0, 12, 3][s % 8]
            add("bass", H.gritbass(root - 12 + fig, ST * 0.9, 900, 2.6), t0 + s * ST, 0.33)
            add("drums", D.hat(), t0 + s * ST, 0.05 + 0.02 * (s % 2), 0.3)
        add("drums", D.kick(), t0, 0.75); add("drums", D.kick(), t0 + 2 * BEAT, 0.75)
        kicks += [t0, t0 + 2 * BEAT]
        if bar % 4 == 3:
            for (s, m, l) in [x for x in HOOK if x[0] < 12]:
                add("lead", D.warm_lead(m, ST * l * 0.95), t0 + s * ST, 0.22)
        if bar >= 14:
            add("fx", H.riser(BAR * 2), t0 if bar == 14 else 0, 0.7) if bar == 14 else None
            if bar == 15:
                for k in range(16):
                    if k < 14:
                        add("drums", H.snare(0.2), t0 + k * ST, 0.12 + 0.03 * k)
    # the drop
    if 16 <= bar < 32:
        for b4 in range(4):
            at = t0 + b4 * BEAT
            add("drums", H.kick(), at, 0.95); kicks.append(at)
            if b4 in (1, 3):
                add("drums", H.snare(), at, 0.55); add("drums", H.clap(), at, 0.3, 0.15)
            add("drums", H.hat(open_=True), at + BEAT * 0.5, 0.12, 0.4)
        for e8 in range(8):
            m = root - 12 + (12 if e8 % 2 else 0)
            add("bass", H.gritbass(m, ST * 1.8, 1100, 3.4), t0 + e8 * ST * 2, 0.5)
        for s in (0, 3, 6, 10, 12):
            add("fx", H.stab([root + 12, root + 19, root + 24], ST * 2), t0 + s * ST, 0.18, -0.1)
        # the hook: 2-bar phrase, answered a fourth up on the second pair; the
        # last eight bars an octave up with the counter-line
        up = 12 if bar >= 24 else 0
        half = (bar % 2) * 16
        shift = 0 if (bar % 4) < 2 else 5
        prev = None
        for (s, m, l) in HOOK:
            if half <= s < half + 16:
                mm = m + shift + up - 12
                add("lead", D.warm_lead(mm, ST * l * 0.95, prev), t0 + (s - half) * ST, 0.3, 0.05)
                if up:
                    add("lead", D.warm_lead(mm - 9, ST * l * 0.9), t0 + (s - half) * ST + ST * 0.5, 0.12, -0.5)
                prev = mm
        if bar % 8 == 0:
            add("drums", H.crash(), t0, 0.45)
        if bar % 8 == 7:
            for i, m in enumerate((50, 47, 45, 43)):
                add("drums", H.tom(m), t0 + (12 + i) * ST, 0.45, -0.4 + i * 0.25)
    # the logo hit
    if bar == 32:
        for n in (40, 47, 52, 55, 59, 64):
            add("fx", H.saw(D.mtof(n), 6.0) * np.exp(-D.T(6.0) * 0.55) * 0.25, t0, 0.6)
        add("drums", H.kick(0.8), t0, 1.3); add("drums", H.crash(3.5), t0, 0.9)
        add("fx", H.sat(H.sweep(120, 28, 5.0, 3) * np.exp(-D.T(5.0) * 0.9), 2.0), t0, 1.2)
        for k, (s, m, l) in enumerate([x for x in HOOK if x[0] < 16]):
            add("lead", D.warm_lead(m, ST * l * 1.4) * 0.8, t0 + BAR * 0.5 + s * ST * 1.5, 0.22)
    # the release card: the chime
    if bar == 36:
        chime_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio", "sfx", "studio_chime.wav")
        with wave.open(chime_path, "rb") as w:
            c = np.frombuffer(w.readframes(w.getnframes()), np.int16) / 32767.0
        add("fx", c, t0, 0.8)

# the chain
def side(Lx, Rx, depth):
    return D.sidechain(Lx, Rx, kicks, N, BEAT, depth)
pl, pr = D.pingpong(*bus["pluck"], BEAT * 0.75, 0.45, 0.45)
ll, lr = D.pingpong(*bus["lead"], BEAT * 0.75, 0.3, 0.25)
music_l = pl + ll + bus["pad"][0] + bus["bass"][0] + bus["fx"][0]
music_r = pr + lr + bus["pad"][1] + bus["bass"][1] + bus["fx"][1]
music_l, music_r = side(music_l, music_r, 0.4)
Lf, Rf = D.space(music_l + bus["drums"][0] * 0.25, music_r + bus["drums"][1] * 0.25, 0.3, 2.6)
Lf += bus["drums"][0] * 0.75
Rf += bus["drums"][1] * 0.75
# fade the very end
fade = int(3.0 * SR)
Lf[-fade:] *= np.linspace(1, 0, fade); Rf[-fade:] *= np.linspace(1, 0, fade)
x = np.stack([D.hp(Lf, 30), D.hp(Rf, 30)], axis=1)
# no saturation on the master: clean, with headroom (peaks at -1.5 dB)
x = x / (np.max(np.abs(x)) + 1e-9) * 0.84
out = sys.argv[1] if len(sys.argv) > 1 else "trailer_score.wav"
with wave.open(out, "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((x * 32767).astype(np.int16).tobytes())
print("score", out, f"{len(x) / SR:.1f}s")
