#!/usr/bin/env python3
"""
Rhythm-first level scores for HOTSHOT CALIFORNIA's beat-synced combat.

Every stem sits on the same grid and the pulse is audible at every
intensity, so you can play to it:
  explore  - (always on) heartbeat kick on every beat, rimshot on 2 and 4,
             pulsing noir bass and a slow pad. Quiet, but you can count it.
  combat   - (an alerted enemy has spotted you) four-on-the-floor, claps,
             16th hats, a driving synthwave arpeggio.
  combo    - (combo 3+) the hook: a gated lead melody and an acid bass,
             crash on every phrase.
  danger   - (combo 6+ / swarmed) detuned stabs, tom fills, a riser into
             each phrase.

Two scores, same stem layout (see data/music.json):
  "Checkout Time" (motel, 120 bpm, E minor, Barstow neon)
  "Dog Days"      (salvage yard, 126 bpm, C# phrygian, harder and dirtier)

  python3 tools/gen_music_rhythm.py
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
import gen_audio as ga
from gen_audio import (Seq, kick, snare, clap, hat, bass_note, pad_chord, pluck, acid_note, lead,
                       sat, lp, hp, bp, noise, env_exp, sine, reverb, delay, master, render_ogg, mtof, t_axis, saw)

def rim(d=0.08):
    return bp(noise(d), 1500, 6000) * env_exp(d, 60) + sine(820, d) * env_exp(d, 50) * .4

def tom(m, d=0.3):
    t = t_axis(d); f = mtof(m) * (1 + 0.6 * np.exp(-t * 18))
    return np.sin(2 * np.pi * np.cumsum(f) / ga.SR) * env_exp(d, 9)

def crash(d=1.6):
    return hp(noise(d), 4000) * env_exp(d, 2.2) * .6

def riser(d):
    t = t_axis(d)
    return hp(noise(d), 2000) * (t / d) ** 2 * .5 + np.sin(2 * np.pi * np.cumsum(200 + 1800 * (t / d) ** 2) / ga.SR) * (t / d) ** 3 * .2

def score(name, bpm, key_roots, chords, hook, acid, dirt=1.0):
    bars = 16
    L = {k: Seq(bpm, bars) for k in ("explore", "combat", "combo", "danger")}
    s = L["explore"]; B = s.beat * 4; st = s.step
    for bar in range(bars):
        ci = (bar // 2) % 4
        r = key_roots[ci]; ch = chords[ci]; t0 = bar * B
        # ---- explore: the pulse you can always hear
        for b in range(4):
            L["explore"].add(lp(kick(.3, .8), 900), t0 + b * s.beat, .55)
        L["explore"].add(rim(), t0 + s.beat, .25); L["explore"].add(rim(), t0 + 3 * s.beat, .25)
        for k in range(8):
            L["explore"].add(bass_note(r, st * 1.6, 450 + 150 * (k % 2), 1.6), t0 + k * st * 2 + st, .4)
        if bar % 2 == 0:
            L["explore"].add(pad_chord(ch, B * 2, 1300), t0, .55)
        for k in range(16):
            L["explore"].add(hat(.02), t0 + k * st, .03 + .03 * (k % 4 == 2))
        # ---- combat: full kit + arpeggio
        for b in range(4):
            L["combat"].add(sat(kick(.4, 1.15), 1.2 + .4 * dirt), t0 + b * s.beat, 1.0)
            L["combat"].add(hat(open_=True), t0 + b * s.beat + st * 2, .14)
        L["combat"].add(clap(), t0 + s.beat, .6); L["combat"].add(clap(), t0 + 3 * s.beat, .6)
        for k in range(16):
            L["combat"].add(hat(.035), t0 + k * st, .07 + .05 * (k % 2 == 0))
            m = ch[k % len(ch)] + 12 * (1 + (k // 4) % 2)
            L["combat"].add(pluck(m, st * 1.3, 2200 + 800 * dirt), t0 + k * st, .16)
        if bar % 4 == 3:
            for k in (12, 13, 14, 15):
                L["combat"].add(snare(.14), t0 + k * st, .28)
        # ---- combo: hook + acid
        if bar % 2 == 0:
            for beat, m, ln in hook:
                L["combo"].add(lead(m, ln * st * 0.92), t0 + beat * st, .22)
        for k in range(16):
            if (k + bar) % 7 == 5:
                continue
            m = r + 12 + acid[(k + bar * 3) % 16]
            L["combo"].add(acid_note(m, st * 1.05, 280 + 120 * (bar % 4), 2400 + 600 * (k % 4 == 0), k % 4 == 0), t0 + k * st, .3)
        if bar % 4 == 0:
            L["combo"].add(crash(), t0, .5)
        # ---- danger: stabs, toms, riser
        for k in (0, 3, 6, 10, 12):
            L["danger"].add(sat(pad_chord([m_ + 12 for m_ in ch], st * 1.5, 5000, .018) * 4, 3), t0 + k * st, .24)
        if bar % 4 == 3:
            for i, k in enumerate((8, 10, 12, 14)):
                L["danger"].add(tom(50 - i * 3), t0 + k * st, .5)
            L["danger"].add(riser(B), t0, .5)
        for k in range(8):
            L["danger"].add(hat(.1), t0 + k * st * 2, .1)
    render_ogg(name + "_explore", master(reverb(L["explore"].buf, .25), .75))
    render_ogg(name + "_combat", master(L["combat"].buf, .8))
    render_ogg(name + "_combo", master(delay(reverb(L["combo"].buf, .2), s.beat * .75, .35, .28), .72))
    render_ogg(name + "_danger", master(reverb(L["danger"].buf, .3), .62))

if __name__ == "__main__":
    # "Checkout Time": E minor, i - VI - III - VII (Em C G D), neon and rain
    score("level_checkout", 120, [40, 36, 43, 38],
          [[52, 55, 59], [48, 52, 55], [55, 59, 62], [50, 54, 57]],
          [(0, 76, 3), (3, 74, 1), (4, 71, 4), (8, 72, 2), (10, 71, 2), (12, 67, 3), (15, 69, 1)],
          [0, 12, 0, 0, 3, 0, 15, 0, 0, 12, 7, 0, 10, 0, 12, 7])
    # "Dog Days": C# phrygian, darker and dirtier, a snarling hook
    score("level_yard", 126, [37, 38, 37, 40],
          [[49, 52, 56], [50, 53, 57], [49, 52, 56], [52, 56, 59]],
          [(0, 73, 2), (2, 74, 2), (4, 73, 2), (6, 68, 2), (8, 71, 3), (11, 74, 1), (12, 73, 4)],
          [0, 0, 12, 0, 1, 0, 13, 0, 0, 12, 0, 7, 1, 0, 12, 0], dirt=1.6)
