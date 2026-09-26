#!/usr/bin/env python3
"""
Synthwave level scores for HOTSHOT CALIFORNIA's beat-synced combat.

Every stem sits on the same grid, loops in 16 bars (an 8-bar verse and an
8-bar chorus) and the pulse is audible at every intensity, so you can play
to it. The synths are side-chained to the kick - that 80s pump.

  explore  - (always on) four-on-the-floor kick, gated 80s snare on 2 and 4,
             octave-pulse bass, a pumping supersaw pad and an FM e-piano
             teasing the hook. Already a song, just a quiet one.
  combat   - (an alerted enemy has spotted you) the full kit: claps, 16th
             hats, open hats on the off-beat, a driving 16th octave bass and
             a delayed arpeggio climbing the chords, tom fills.
  combo    - (combo 3+) the hook: a big detuned saw lead with octave
             doubles, crash on every phrase, a reverse cymbal into the chorus.
  danger   - (combo 6+ / swarmed) distorted stabs, acid line, gated tom
             rolls, a riser into every 4 bars. Loud.

Two scores, same stem layout (see data/music.json):
  "Checkout Time" (motel, 120 bpm, E minor, Barstow neon)
  "Dog Days"      (salvage yard, 126 bpm, C# minor/phrygian, harder)

  python3 tools/gen_music_rhythm.py
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
import gen_audio as ga
from gen_audio import (Seq, kick, snare, clap, hat, acid_note, sat, lp, hp, bp, noise, env_exp,
                       sine, reverb, delay, master, render_ogg, mtof, t_axis, saw, sq, adsr)

SR = ga.SR
rng = np.random.default_rng(1986)

# ------------------------------------------------------------- instruments
def rim(d=0.08):
    return bp(noise(d), 1500, 6000) * env_exp(d, 60) + sine(820, d) * env_exp(d, 50) * .4

def tom(m, d=0.35):
    t = t_axis(d); f = mtof(m) * (1 + 0.7 * np.exp(-t * 20))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(d, 8) + bp(noise(d), 200, 2000) * env_exp(d, 30) * .15
    return sat(x, 1.6)

def crash(d=1.8):
    return hp(noise(d), 4000) * env_exp(d, 2.0) * .6

def reverse_cymbal(d):
    return (hp(noise(d), 5000) * np.exp(-t_axis(d) * 3.0))[::-1] * .5

def riser(d):
    t = t_axis(d)
    return hp(noise(d), 2000) * (t / d) ** 2 * .5 + np.sin(2 * np.pi * np.cumsum(200 + 1800 * (t / d) ** 2) / SR) * (t / d) ** 3 * .2

def gated_snare(d=0.42):
    """The 80s snare: big room, chopped off hard."""
    s = np.concatenate([snare(.3) * 1.2 + clap(.3) * .35, np.zeros(int(.12 * SR))])
    s = reverb(s, .75, 1.4)[:int(d * SR)]
    gate = np.ones(len(s)); k = int(.24 * SR)
    gate[k:] = np.exp(-np.arange(len(s) - k) / SR * 90)
    return s * gate

def punch_kick(soft=False):
    k = kick(.42, 1.1)
    return lp(k, 1100) * .8 if soft else sat(k, 1.4)

def supersaw(ms, d, cutoff=2400, det=0.011, voices=5, att=.25, rel=.4):
    x = np.zeros(int(d * SR))
    for m in ms:
        f = mtof(m)
        for v in range(voices):
            k = (v - (voices - 1) / 2) / ((voices - 1) / 2)
            x += saw(f * (1 + k * det), d, rng.uniform(0, 1))
    x = lp(x, cutoff) * adsr(len(x), att, .4, .85, rel)
    return x / (len(ms) * voices) * 1.6

def epiano(m, d):
    """FM tine e-piano / bell - the DX7 sound."""
    t = t_axis(d); f = mtof(m)
    idx = 2.2 * np.exp(-t * 5)
    x = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * t))
    x += np.sin(2 * np.pi * f * 14 * t) * np.exp(-t * 40) * .25
    return x * np.exp(-t * 2.2) * adsr(len(t), .002, .1, 1, .05)

def hero_lead(m, d):
    """Detuned saw lead with a square sub-octave; vibrato fades in."""
    t = t_axis(d); vib = 1 + 0.006 * np.clip((t - .15) * 4, 0, 1) * np.sin(2 * np.pi * 5.8 * t)
    f = mtof(m) * vib; ph = np.cumsum(f) / SR
    x = (2 * (ph % 1) - 1) + (2 * ((ph * 1.009) % 1) - 1) * .8 + (2 * ((ph * .991) % 1) - 1) * .8
    x += np.sign(np.sin(2 * np.pi * ph * .5)) * .35
    x = lp(x, 4200) * adsr(len(t), .012, .15, .8, .08)
    return sat(x * .5, 1.3)

def pulse_bass(m, d, cutoff=700):
    f = mtof(m)
    x = saw(f, d) + saw(f * 1.004, d) * .7 + sq(f / 2, d, .5) * .5
    x = lp(x, cutoff) * adsr(len(x), .002, .08, .6, .02)
    return sat(x, 1.8)

def arp_note(m, d, cutoff=3200):
    f = mtof(m)
    x = sq(f, d, .3) + saw(f * 2.004, d) * .25
    return lp(x, cutoff) * env_exp(d, 11)

def stab(ms, d, drive=3.0):
    return sat(supersaw([m + 12 for m in ms], d, 6000, .02, 5, .003, .05) * 3.5, drive)

def pump(n, beat, depth=.72, rec=.55):
    """Sidechain envelope: duck on every kick, breathe back up."""
    t = np.arange(n) / SR
    ph = (t % beat) / beat
    return 1 - depth * np.exp(-ph / (rec * .25))

# ------------------------------------------------------------------- score
def score(name, bpm, chords, hook_a, hook_b, bass_roots, dirt=1.0):
    """chords: 16 per-bar chords (midi lists); hook_a: 2-bar phrase (32
    steps) played through the verse; hook_b: 8 one-bar phrases for the
    chorus; bass_roots: 16 per-bar root notes."""
    bars = 16
    D = {k: Seq(bpm, bars) for k in ("explore", "combat", "combo", "danger")}   # drums, dry
    S = {k: Seq(bpm, bars) for k in ("explore", "combat", "combo", "danger")}   # synths, pumped
    beat = D["explore"].beat; st = beat / 4; B = beat * 4
    k_soft = punch_kick(True); k_hard = punch_kick(False); gsn = gated_snare()
    for bar in range(bars):
        t0 = bar * B; ch = chords[bar]; r = bass_roots[bar]; chorus = bar >= 8
        # ---------------- explore
        for b in range(4):
            D["explore"].add(k_soft, t0 + b * beat, .6)
        D["explore"].add(gsn, t0 + beat, .38); D["explore"].add(gsn, t0 + 3 * beat, .38)
        for k in range(8):
            D["explore"].add(hat(.03), t0 + k * st * 2, .05 + .04 * (k % 2))
        for k in range(8):
            S["explore"].add(pulse_bass(r + 12 * (k % 2), st * 1.8, 520 + 120 * chorus), t0 + k * st * 2, .42)
        if chorus:
            S["explore"].add(supersaw(ch, B, 2200), t0, .42)
        elif bar % 2 == 0:
            S["explore"].add(supersaw(ch, B * 2, 1500), t0, .5)
        # the e-piano teases the hook an octave down, sparse
        if not chorus and bar % 2 == 0:
            for s_, m, ln in hook_a:
                if s_ < 16:
                    S["explore"].add(epiano(m - 12, ln * st + .5), t0 + s_ * st, .16)
        if chorus and bar % 2 == 0:
            for s_, m, ln in hook_b[bar - 8]:
                S["explore"].add(epiano(m - 12, ln * st + .5), t0 + s_ * st, .13)
        # ---------------- combat
        for b in range(4):
            D["combat"].add(k_hard, t0 + b * beat, .95)
            D["combat"].add(hat(open_=True), t0 + b * beat + st * 2, .12)
        D["combat"].add(clap(), t0 + beat, .45); D["combat"].add(clap(), t0 + 3 * beat, .45)
        for k in range(16):
            D["combat"].add(hat(.03), t0 + k * st, .05 + .05 * (k % 2 == 0) + .03 * (k % 4 == 2))
        for k in range(16):
            m = r + (12 if k % 4 == 2 else 0) + (12 if k % 8 == 7 else 0)
            S["combat"].add(pulse_bass(m, st * .9, 900 + 500 * dirt), t0 + k * st, .35)
        up = ch + [n + 12 for n in ch]
        pat = [0, 1, 2, 3, 4, 5, 4, 3, 2, 3, 4, 5, 4, 3, 2, 1]
        for k in range(16):
            S["combat"].add(arp_note(up[pat[k]] + 12, st * 1.4, 2600 + 900 * dirt), t0 + k * st, .13)
        if bar % 4 == 3:
            for i, k in enumerate((10, 12, 13, 14, 15)):
                D["combat"].add(tom(52 - i * 3), t0 + k * st, .4)
        # ---------------- combo: the hook
        if not chorus:
            if bar % 2 == 0:
                for s_, m, ln in hook_a:
                    S["combo"].add(hero_lead(m, ln * st * .95), t0 + s_ * st, .24)
                    S["combo"].add(hero_lead(m + 12, ln * st * .95), t0 + s_ * st, .06)
        else:
            for s_, m, ln in hook_b[bar - 8]:
                S["combo"].add(hero_lead(m, ln * st * .95), t0 + s_ * st, .26)
                S["combo"].add(hero_lead(m + 12, ln * st * .95), t0 + s_ * st, .08)
                S["combo"].add(hero_lead(m - 12, ln * st * .95), t0 + s_ * st, .07)
        if bar % 4 == 0:
            D["combo"].add(crash(), t0, .22)
        if bar == 7:
            D["combo"].add(reverse_cymbal(B), t0, .6)
        for b in range(4):
            D["combo"].add(rim(), t0 + b * beat + st * 3, .07)
        # ---------------- danger
        for k in (0, 3, 6, 10, 12):
            S["danger"].add(stab(ch, st * 1.4, 2.4 + dirt), t0 + k * st, .2)
        for k in range(16):
            if (k + bar) % 5 == 4:
                continue
            m = r + 24 + [0, 0, 12, 0, 7, 0, 12, 10][k % 8]
            S["danger"].add(acid_note(m, st * 1.05, 300 + 90 * (bar % 4), 2600 + 900 * (k % 4 == 0), k % 4 == 0), t0 + k * st, .16)
        if bar % 4 == 3:
            D["danger"].add(riser(B), t0, .5)
            for k in range(8, 16):
                D["danger"].add(tom(55 - (k - 8) * 2, .25), t0 + k * st, .45)
        else:
            for k in (14, 15):
                D["danger"].add(snare(.12), t0 + k * st, .3)
        for b in range(4):
            D["danger"].add(sat(sine(mtof(r - 12), beat * .9) * env_exp(beat * .9, 3), 3), t0 + b * beat, .3)
    n = D["explore"].n
    pm = pump(n, beat)
    pm_soft = pump(n, beat, .5)
    ex = D["explore"].buf + reverb(S["explore"].buf * pm, .22)
    cb = D["combat"].buf + delay(S["combat"].buf * pm, st * 3, .35, .25)
    co = D["combo"].buf + delay(reverb(S["combo"].buf * pm_soft, .28, 1.3), st * 3, .38, .3)
    dg = reverb(D["danger"].buf, .15) + S["danger"].buf * pm
    render_ogg(name + "_explore", master(ex, .8), 2)
    render_ogg(name + "_combat", master(cb, .8), 2)
    render_ogg(name + "_combo", master(co, .8), 2)
    render_ogg(name + "_danger", master(dg, .52), 2)

def tri(root, minor=True):
    return [root, root + (3 if minor else 4), root + 7]

if __name__ == "__main__":
    # "Checkout Time": E minor. Verse Em C G D (2 bars each); chorus
    # C D Em Em C D B B - the B major lifts it back to the top
    Em, C, G, Dm, B = tri(52), tri(48, False), tri(55, False), tri(50, False), tri(47, False)
    chords = [Em, Em, C, C, G, G, Dm, Dm, C, Dm, Em, Em, C, Dm, B, B]
    roots = [40, 40, 36, 36, 43, 43, 38, 38, 36, 38, 40, 40, 36, 38, 35, 35]
    hook_a = [(0, 71, 3), (3, 74, 3), (6, 76, 2), (8, 74, 2), (10, 71, 2), (12, 69, 4),
              (16, 67, 3), (19, 69, 3), (22, 71, 6), (28, 74, 2), (30, 71, 2)]
    hook_b = [
        [(0, 76, 3), (3, 79, 3), (6, 76, 2), (8, 74, 4), (12, 72, 4)],
        [(0, 74, 3), (3, 78, 3), (6, 74, 2), (8, 72, 4), (12, 71, 4)],
        [(0, 71, 3), (3, 74, 3), (6, 76, 4), (10, 79, 6)],
        [(0, 79, 2), (2, 78, 2), (4, 76, 4), (8, 74, 4), (12, 76, 4)],
        [(0, 76, 3), (3, 79, 3), (6, 76, 2), (8, 74, 4), (12, 72, 4)],
        [(0, 74, 3), (3, 78, 3), (6, 74, 2), (8, 72, 4), (12, 71, 4)],
        [(0, 75, 4), (4, 78, 4), (8, 83, 8)],
        [(0, 81, 4), (4, 78, 4), (8, 75, 4), (12, 71, 4)],
    ]
    score("level_checkout", 120, chords, hook_a, hook_b, roots)

    # "Dog Days": C# minor with a phrygian D. Verse C#m A E D; chorus
    # A B C#m C#m A B D D - meaner, faster, dirtier
    Csm, A, E, D, Bm = tri(49), tri(45, False), tri(52, False), tri(50, False), tri(47, False)
    chords = [Csm, Csm, A, A, E, E, D, D, A, Bm, Csm, Csm, A, Bm, D, D]
    roots = [37, 37, 33, 33, 40, 40, 38, 38, 33, 35, 37, 37, 33, 35, 38, 38]
    hook_a = [(0, 73, 2), (2, 73, 1), (4, 76, 2), (6, 73, 2), (8, 74, 4), (12, 73, 2), (14, 71, 2),
              (16, 68, 2), (18, 68, 1), (20, 71, 2), (22, 68, 2), (24, 69, 4), (28, 68, 4)]
    hook_b = [
        [(0, 76, 2), (2, 76, 1), (3, 78, 3), (6, 76, 2), (8, 73, 4), (12, 76, 4)],
        [(0, 78, 2), (2, 78, 1), (3, 80, 3), (6, 78, 2), (8, 75, 4), (12, 71, 4)],
        [(0, 80, 6), (6, 78, 2), (8, 76, 4), (12, 73, 4)],
        [(0, 76, 2), (2, 74, 2), (4, 73, 8), (12, 68, 4)],
        [(0, 76, 2), (2, 76, 1), (3, 78, 3), (6, 76, 2), (8, 73, 4), (12, 76, 4)],
        [(0, 78, 2), (2, 78, 1), (3, 80, 3), (6, 78, 2), (8, 75, 4), (12, 71, 4)],
        [(0, 74, 4), (4, 78, 4), (8, 81, 8)],
        [(0, 81, 2), (2, 78, 2), (4, 74, 4), (8, 73, 8)],
    ]
    score("level_yard", 126, chords, hook_a, hook_b, roots, dirt=1.6)
