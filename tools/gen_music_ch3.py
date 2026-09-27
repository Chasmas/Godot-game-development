#!/usr/bin/env python3
"""
Music for Chapter I-C and the nightmare (own script so the other scores'
random streams never shift). Needs ffmpeg on PATH.

  level_primetime_*   "Prime Time"  F# minor, 132 bpm, four stems like the
                      other levels: a TV-theme brass hook over the Santa Ana
  boss_fireman        "The Fireman" 150 bpm: four-on-the-floor, reese bass,
  boss_fireman_fire   supersaw stabs; the second layer is the stage on fire
                      (distorted brass, 32nd hats, risers)
  level_nightmare_*   "Sweet Dreams" D minor, 100 bpm: music box, detuned
                      organ, heartbeat kick; the stems get uglier, not louder
  boss_nightmare      "Top Billing" 140 bpm, choir pads and a burning lead

  python tools/gen_music_ch3.py
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
import gen_music_score as gms
from gen_music_score import Stereo, st_reverb, st_master, render, expand, score, reese, sub, drone, bell, voicing, wide
from gen_audio import kick, snare, clap, hat, sat, lp, hp, bp, noise, env_exp, sine, mtof, t_axis, saw, sq, adsr
from gen_music_rhythm import tom, crash, reverse_cymbal, riser, gated_snare, supersaw, hero_lead, stab, pump

SR = gms.SR
rng = np.random.default_rng(1988)


def prime_time():
    FS_MIN = [6, 8, 9, 11, 1, 2, 4]
    prog = expand({
        "INTRO": [(42, "m9"), (42, "m9"), (38, "M7"), (38, "M7")],
        "VERSE": [(42, "m"), (38, "M"), (45, "M"), (40, "M"), (42, "m"), (38, "M"), (47, "m"), (49, "sus")],
        "PRE": [(47, "m"), (49, "m"), (50, "M"), (52, "M")],
        "CHORUS": [(50, "M"), (52, "M"), (42, "m"), (42, "m"), (50, "M"), (52, "M"), (49, "M"), (49, "7")],
        "BREAK": [(47, "m7"), (47, "m7"), (42, "m9"), (42, "m9")],
        "TURN": [(50, "M7"), (52, "M"), (42, "m"), (49, "7")],
    })
    # a game-show fanfare turned sour
    hook = [
        [(0, 78, 2), (2, 81, 2), (4, 85, 4), (8, 83, 2), (10, 81, 2), (12, 78, 4)],
        [(0, 76, 2), (2, 80, 2), (4, 83, 4), (8, 81, 2), (10, 80, 2), (12, 76, 4)],
        [(0, 78, 3), (3, 81, 3), (6, 83, 2), (8, 85, 8)],
        [(0, 86, 2), (2, 85, 2), (4, 83, 4), (8, 81, 4), (12, 80, 4)],
        [(0, 78, 2), (2, 81, 2), (4, 85, 4), (8, 83, 2), (10, 81, 2), (12, 78, 4)],
        [(0, 76, 2), (2, 80, 2), (4, 83, 4), (8, 81, 2), (10, 80, 2), (12, 76, 4)],
        [(0, 81, 4), (4, 85, 4), (8, 90, 8)],
        [(0, 88, 4), (4, 85, 4), (8, 81, 4), (12, 77, 4)],
    ]
    counter = [(2, 73, 2), (4, 76, 2), (6, 78, 4), (12, 76, 2), (14, 73, 2), (18, 71, 2), (20, 69, 4), (26, 68, 2), (28, 66, 4)]
    pre_line = [[(0, 71, 4), (4, 74, 4), (8, 78, 8)], [(0, 73, 4), (4, 76, 4), (8, 80, 8)],
                [(0, 74, 4), (4, 78, 4), (8, 81, 8)], [(0, 76, 2), (2, 78, 2), (4, 80, 2), (6, 81, 2), (8, 83, 4), (12, 85, 4)]]
    score("level_primetime", 132, 42, prog, hook, counter, pre_line, FS_MIN, dirt=1.3)


def nightmare():
    D_MIN = [2, 4, 5, 7, 9, 10, 0]
    prog = expand({
        "INTRO": [(38, "m9"), (38, "m9"), (34, "M7"), (34, "M7")],
        "VERSE": [(38, "m"), (34, "M"), (41, "M"), (36, "M"), (38, "m"), (34, "M"), (43, "m"), (45, "7")],
        "PRE": [(43, "m"), (45, "m"), (46, "M"), (48, "M")],
        "CHORUS": [(46, "M"), (48, "M"), (38, "m"), (38, "m"), (46, "M"), (45, "7"), (38, "m"), (45, "7")],
        "BREAK": [(43, "m7"), (43, "m7"), (38, "m9"), (38, "m9")],
        "TURN": [(46, "M7"), (45, "7"), (38, "m"), (45, "7")],
    })
    # a lullaby, played wrong
    hook = [
        [(0, 74, 4), (4, 77, 4), (8, 76, 2), (10, 74, 2), (12, 73, 4)],
        [(0, 74, 4), (4, 81, 4), (8, 79, 4), (12, 77, 4)],
        [(0, 76, 4), (4, 77, 4), (8, 79, 8)],
        [(0, 81, 3), (3, 80, 3), (6, 77, 2), (8, 76, 8)],
        [(0, 74, 4), (4, 77, 4), (8, 76, 2), (10, 74, 2), (12, 73, 4)],
        [(0, 74, 4), (4, 81, 4), (8, 79, 4), (12, 77, 4)],
        [(0, 82, 4), (4, 81, 4), (8, 80, 8)],
        [(0, 77, 4), (4, 76, 4), (8, 74, 8)],
    ]
    counter = [(0, 69, 4), (4, 70, 4), (8, 69, 4), (12, 67, 4), (16, 65, 4), (20, 64, 4), (24, 62, 8)]
    pre_line = [[(0, 67, 4), (4, 70, 4), (8, 74, 8)], [(0, 69, 4), (4, 72, 4), (8, 76, 8)],
                [(0, 70, 4), (4, 74, 4), (8, 77, 8)], [(0, 72, 2), (2, 73, 2), (4, 76, 2), (6, 77, 2), (8, 79, 4), (12, 81, 4)]]
    score("level_nightmare", 100, 38, prog, hook, counter, pre_line, D_MIN, dirt=2.2)


def boss_fireman():
    bpm, bars = 150, 16
    main, fire = Stereo(bpm, bars), Stereo(bpm, bars)
    beat, st, B = main.beat, main.step, main.bar
    roots = [42, 42, 38, 40]          # F# F# D E
    lead = [(0, 85, 3), (3, 88, 3), (6, 85, 2), (8, 83, 4), (12, 81, 2), (14, 78, 2)]
    k = sat(kick(.4, 1.3), 2.5)
    for bar in range(bars):
        r = roots[(bar // 2) % 4]
        t0 = bar * B
        for b in range(4):
            main.add(k, t0 + b * beat, .95)
            main.add(hat(.05, open_=True), t0 + b * beat + beat / 2, .09, .3)
        main.add(sat(gated_snare() * 1.6, 2), t0 + beat, .5)
        main.add(sat(gated_snare() * 1.6, 2), t0 + 3 * beat, .5)
        for s in range(16):
            n = r - 12 + (12 if s % 8 == 6 else 0) + (7 if s % 16 == 14 else 0)
            main.add(reese(n, st * .9, 3.0), t0 + s * st, .32)
            main.add(hat(.03), t0 + s * st, .05, -0.3 if s % 2 else 0.3)
        ch = voicing(r + 12, "m")
        for s in (0, 3, 6, 10):
            main.add(wide(supersaw, [m + 12 for m in ch], st * 2.5), t0 + s * st, .16)
        if bar >= 4:
            for (s, m, L) in lead:
                main.add(hero_lead(m - (0 if bar % 4 < 2 else 2), st * L), t0 + s * st, .2, 0.1)
        if bar % 4 == 3:
            main.add(tom(r + 12, .3), t0 + 12 * st, .5, -0.4)
            main.add(tom(r + 7, .3), t0 + 14 * st, .5, 0.4)
        # the fire layer: brass blasts, 32nd hats, risers into every 4th bar
        for s in (0, 6, 12):
            fire.add(sat(stab([m + 12 for m in ch], st * 2, 4.0), 2.0), t0 + s * st, .35)
        for s in range(32):
            fire.add(hat(.02), t0 + s * st / 2, .05 + .03 * (s % 4 == 0), 0.5 if s % 2 else -0.5)
        if bar % 4 == 3:
            fire.add(riser(B), t0, .25)
        if bar % 4 == 0:
            fire.add(crash(), t0, .3)
            fire.add(drone(r - 12, B * 4) * 2.0, t0, .5)
    render("boss_fireman", st_master(st_reverb(main.buf, .12), .85))
    render("boss_fireman_fire", st_master(st_reverb(fire.buf, .25, 1.2), .7))


def boss_nightmare():
    bpm, bars = 140, 16
    main = Stereo(bpm, bars)
    beat, st, B = main.beat, main.step, main.bar
    roots = [38, 39, 36, 37]          # D Eb C C#: it never settles
    for bar in range(bars):
        r = roots[(bar // 2) % 4]
        t0 = bar * B
        for b in range(4):
            main.add(sat(kick(.5, 1.4), 3.0), t0 + b * beat, 1.0)
        main.add(sat(snare(.4, True) * 2, 3), t0 + beat, .45)
        main.add(sat(snare(.4, True) * 2, 3), t0 + 3 * beat, .45)
        for s in range(16):
            main.add(reese(r - 12 + (1 if s % 8 == 7 else 0), st * .95, 4.0), t0 + s * st, .3)
        if bar % 2 == 0:
            ch = [r + 12, r + 15, r + 18]    # diminished: a choir that can't agree
            main.add(wide(supersaw, ch, B * 2, 1400, .02, 5, 1.0, .8), t0, .22)
        for s in (0, 4, 8, 10, 12):
            main.add(bell(r + 36 + (6 if s == 10 else 0), st * 3), t0 + s * st, .12, 0.4 if s % 8 else -0.4)
        if bar >= 8:
            for (s, m, L) in [(0, 74, 4), (4, 75, 4), (8, 74, 2), (10, 72, 2), (12, 71, 4)]:
                main.add(hero_lead(m + r - 38, st * L), t0 + s * st, .2)
        if bar % 4 == 3:
            main.add(reverse_cymbal(B), t0, .3)
    render("boss_nightmare", st_master(st_reverb(main.buf, .3, 1.4), .85))


if __name__ == "__main__":
    which = sys.argv[1:] or ["prime_time", "boss_fireman", "nightmare", "boss_nightmare"]
    for w in which:
        globals()[w]()
