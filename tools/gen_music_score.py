#!/usr/bin/env python3
"""
Cinematic synthwave level scores (v3) for HOTSHOT CALIFORNIA.

Each score is a 32-bar piece in six sections that loops seamlessly:

  INTRO (4)  filtered pads, a heartbeat kick, the city humming
  VERSE (8)  the groove: gated snare, octave bass, e-piano counter-melody
  PRE   (4)  climbing chords, snare roll building, a riser
  CHORUS(8)  the hook, brass answers, open hats, crash on the one
  BREAK (4)  half-time: pads and a bell arp, the bass drops to a sub
  TURN  (4)  back into the groove with a tom fill into the top

rendered in stereo as four stems that always play in sync, so the game's
alert/combo intensity (data/music.json) only changes how much you hear:

  explore  drums, bass, pads, e-piano, atmosphere - already a full song
  combat   16th hats, claps, shaker, the ping-pong arp, snare builds, fills
  combo    the lead: hook, counter-lines, brass stabs, harmony
  danger   reese bass, acid, tom rolls, 32nd hats, risers - intense

  python3 tools/gen_music_score.py
"""
import os, sys, subprocess, wave
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
import gen_audio as ga
from gen_audio import (kick, snare, clap, hat, sat, lp, hp, bp, noise, env_exp, sine, mtof, t_axis, saw, sq, adsr, acid_note)
from gen_music_rhythm import (tom, crash, reverse_cymbal, riser, gated_snare, supersaw, epiano, hero_lead, pulse_bass, arp_note, stab, pump)

SR = ga.SR
MUS_DIR = ga.MUS_DIR
rng = np.random.default_rng(1984)

# ------------------------------------------------------------ stereo plumbing
class Stereo:
    def __init__(self, bpm, bars):
        self.beat = 60.0 / bpm; self.step = self.beat / 4; self.bar = self.beat * 4
        self.n = int(round(self.bar * bars * SR))
        self.buf = np.zeros((self.n, 2))
    def add(self, x, at, gain=1.0, pan=0.0):
        """Mono x at time `at`, equal-power pan -1..1; tails wrap for the loop."""
        if x.ndim == 1:
            l = np.cos((pan + 1) * np.pi / 4); r = np.sin((pan + 1) * np.pi / 4)
            x = np.stack([x * l * 1.414, x * r * 1.414], axis=1)
        s = int(at * SR) % self.n
        e = min(self.n, s + len(x))
        self.buf[s:e] += x[:e - s] * gain
        rest = x[e - s:]
        while len(rest):
            m = min(len(rest), self.n)
            self.buf[:m] += rest[:m] * gain
            rest = rest[m:]

def st_reverb(x, mix=0.25, size=1.0):
    return np.stack([ga.reverb(x[:, 0], mix, size), ga.reverb(x[:, 1], mix, size * 1.07)], axis=1)

def pingpong(x, secs, fb=0.4, mix=0.35):
    """Stereo ping-pong echo: repeats alternate right / left."""
    d = int(secs * SR)
    mono = x.mean(axis=1)
    out = x.copy()
    g = mix
    for k in range(1, 6):
        sh = np.zeros_like(mono); sh[d * k:] = mono[:len(mono) - d * k] if d * k < len(mono) else 0
        ch = 1 if k % 2 else 0
        out[:, ch] += lp(sh, 4500) * g
        g *= fb
    return out

def wide(make, *a, **k):
    """Render an instrument twice (independent phases) for a wide L/R image."""
    return np.stack([make(*a, **k), make(*a, **k)], axis=1)

def st_master(x, peak=0.85):
    x = np.stack([hp(x[:, 0], 30), hp(x[:, 1], 30)], axis=1)
    x = sat(x * 1.15, 1.25)
    return x / (np.max(np.abs(x)) + 1e-9) * peak

def render(name, x, q=1, rate=32000):
    tmp = os.path.join(MUS_DIR, name + ".tmp.wav")
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-ar", str(rate), "-c:a", "libvorbis", "-q:a", str(q),
                    os.path.join(MUS_DIR, name + ".ogg")], check=True)
    os.remove(tmp)
    print("music", name, f"{len(x) / SR:.1f}s")

# ------------------------------------------------------------ extra voices
def brass(ms, d):
    """OB-X style brass stab: detuned saws with a fast filter blip."""
    x = np.zeros(int(d * SR))
    for m in ms:
        for det in (-0.006, 0.0, 0.007):
            x += saw(mtof(m) * (1 + det), d, rng.uniform(0, 1))
    tt = t_axis(d)
    # the "blip": a bright attack crossfading into a darker sustain
    k = np.exp(-tt * 9)
    y = lp(x, 3800) * k + lp(x, 1000) * (1 - k)
    return y * adsr(len(y), .006, .12, .55, .08) / (len(ms) * 3) * 1.6

def reese(m, d, drive=2.5):
    f = mtof(m)
    x = saw(f, d, 0.0) + saw(f * 1.012, d, 0.3) + saw(f * 0.994, d, 0.6) + sine(f / 2, d) * 1.2
    return sat(lp(x, 520) * adsr(int(d * SR), .005, .1, .8, .03), drive)

def sub(m, d):
    return sine(mtof(m), d) * adsr(int(d * SR), .02, .2, .9, .2)

def shaker(d=0.06):
    return bp(noise(d), 5000, 11000) * np.sin(np.linspace(0, np.pi, int(d * SR))) ** 2

def drone(m, d):
    tt = t_axis(d)
    x = saw(mtof(m), d) * .5 + saw(mtof(m) * 1.003, d) * .5 + saw(mtof(m + 7), d) * .3
    return lp(x, 380) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.15 * tt)) * .35

def bell(m, d):
    tt = t_axis(d); f = mtof(m)
    x = np.sin(2 * np.pi * f * tt + 3.0 * np.exp(-tt * 3) * np.sin(2 * np.pi * f * 3.5 * tt))
    return x * np.exp(-tt * 2.6)

def downlifter(d):
    tt = t_axis(d)
    return hp(noise(d), 1200) * np.exp(-tt * 2.5) * .5 + np.sin(2 * np.pi * np.cumsum(1400 * np.exp(-tt * 3) + 80) / SR) * np.exp(-tt * 3) * .15

# ------------------------------------------------------------ harmony
QUAL = {"m": [0, 3, 7], "M": [0, 4, 7], "m9": [0, 3, 7, 14], "M7": [0, 4, 7, 11], "sus": [0, 5, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10]}

def voicing(root, q, lo=52):
    notes = [root + i for i in QUAL[q]]
    while min(notes) < lo:
        notes = [n + 12 for n in notes]
    while min(notes) >= lo + 12:
        notes = [n - 12 for n in notes]
    return notes

SECTIONS = ["INTRO"] * 4 + ["VERSE"] * 8 + ["PRE"] * 4 + ["CHORUS"] * 8 + ["BREAK"] * 4 + ["TURN"] * 4

def nearest_in(scale, m):
    best = min(scale, key=lambda s: min(abs((m - s) % 12), 12 - abs((m - s) % 12)))
    base = m - ((m - best) % 12 if (m - best) % 12 <= 6 else (m - best) % 12 - 12)
    return base

# ------------------------------------------------------------ the composer
def score(name, bpm, key, prog, hook, counter, pre_line, scale, dirt=1.0):
    """prog: 32 (root, quality) per bar. hook: 8 one-bar phrases (step, midi,
    len) for the chorus. counter: 2-bar e-piano phrase for the verse.
    pre_line: 4 one-bar phrases, the climbing pre-chorus lead."""
    bars = 32
    L = {k: Stereo(bpm, bars) for k in ("explore", "combat", "combo", "danger")}
    P = {k: Stereo(bpm, bars) for k in ("explore", "combat", "combo", "danger")}   # pumped (sidechained)
    s = L["explore"]; beat, st, B = s.beat, s.step, s.bar
    kick_soft = lp(kick(.42, 1.1), 1200) * .9
    kick_hard = sat(kick(.42, 1.15), 1.5)
    gsn = gated_snare()
    for bar in range(bars):
        sec = SECTIONS[bar]; t0 = bar * B
        root, q = prog[bar]; ch = voicing(root, q); r = root % 12 + 36
        in_sec = bar - SECTIONS.index(sec)          # bar index inside section
        last_of_phrase = (bar % 4) == 3
        nxt = SECTIONS[(bar + 1) % bars]
        # ================================================= EXPLORE
        E, EP = L["explore"], P["explore"]
        # drums
        if sec == "INTRO":
            for b in (0, 2):
                E.add(kick_soft, t0 + b * beat, .5)
            if in_sec >= 2:
                E.add(gsn, t0 + 3 * beat, .25, .1)
        elif sec == "BREAK":
            E.add(kick_soft, t0, .6); E.add(kick_soft, t0 + 2.5 * beat, .45)
            E.add(gsn, t0 + 2 * beat, .3, .1)
        else:
            for b in range(4):
                E.add(kick_soft if sec != "CHORUS" else kick_hard * .8, t0 + b * beat, .62)
            E.add(gsn, t0 + beat, .38, .1); E.add(gsn, t0 + 3 * beat, .38, .1)
            if sec == "TURN" and in_sec == 3:
                for i, k in enumerate((12, 13, 14, 15)):
                    E.add(tom(50 - i * 3), t0 + k * st, .35, -0.5 + i * 0.33)
        if sec != "INTRO" or in_sec >= 1:
            for k in range(8):
                jit = rng.uniform(-0.004, 0.004)
                E.add(hat(.03), t0 + k * st * 2 + jit, (.04 + .035 * (k % 2)) * rng.uniform(.8, 1.1), .35)
        # bass: a different figure per section
        if sec == "INTRO":
            EP.add(sub(r, B * .95), t0, .35)
        elif sec == "BREAK":
            EP.add(sub(r, B * .95), t0, .45)
        elif sec == "CHORUS":
            for s_, oct_, ln in ((0, 0, 1.5), (3, 12, 1), (4, 0, 1.5), (7, 12, 1), (8, 0, 1.5), (10, 0, 1), (11, 12, 1), (14, 0, 1), (15, 12, 1)):
                EP.add(pulse_bass(r + oct_, st * ln, 760), t0 + s_ * st, .42)
        else:
            for k in range(8):
                EP.add(pulse_bass(r + 12 * (k % 2), st * 1.8, 560 + 90 * (sec == "PRE")), t0 + k * st * 2, .42)
        # pads: filter opens through the intro and the pre-chorus
        if sec == "INTRO":
            cut = 700 + in_sec * 380
        elif sec == "PRE":
            cut = 1600 + in_sec * 450
        elif sec == "CHORUS":
            cut = 2600
        elif sec == "BREAK":
            cut = 1300
        else:
            cut = 1700
        pad = wide(supersaw, ch, B, cut)
        EP.add(pad, t0, .42 if sec != "BREAK" else .55)
        # e-piano counter-melody in the verse (and the turnaround)
        if sec in ("VERSE", "TURN") and in_sec % 2 == 0:
            for s_, m, ln in counter:
                EP.add(epiano(m, ln * st + .6), t0 + s_ * st, .15, -0.25)
        # bell arp in the breakdown
        if sec == "BREAK":
            for k in range(8):
                m = ch[k % len(ch)] + 24 - (12 if k % 4 == 3 else 0)
                EP.add(bell(m, st * 3), t0 + k * st * 2, .09, 0.6 if k % 2 else -0.6)
        # atmosphere: a low drone in the intro, a downlifter into the loop
        if sec == "INTRO" and in_sec == 0:
            E.add(wide(drone, r + 12, B * 4), t0, .5)
        if bar == bars - 1:
            E.add(downlifter(B), t0 + 2 * beat, .35)
        if nxt == "CHORUS" and sec != "CHORUS":
            E.add(reverse_cymbal(B), t0, .35)
        # ================================================= COMBAT
        C, CP = L["combat"], P["combat"]
        if sec not in ("INTRO", "BREAK"):
            for k in range(16):
                C.add(hat(.028), t0 + k * st + rng.uniform(-0.003, 0.003), (.045 + .05 * (k % 2 == 0)) * rng.uniform(.8, 1.1), .45)
                C.add(shaker(), t0 + k * st + st * .5, .05 * rng.uniform(.7, 1.0), -.55)
            for b in range(4):
                C.add(hat(open_=True), t0 + b * beat + st * 2, .1, .3)
            C.add(clap(), t0 + beat, .38, -.1); C.add(clap(), t0 + 3 * beat, .38, .1)
            for b in range(4):
                C.add(kick_hard, t0 + b * beat, .5)
        if sec == "PRE":
            # snare roll: quarters -> eighths -> sixteenths -> thirty-seconds
            div = [4, 8, 16, 32][in_sec]
            for k in range(div):
                v = .12 + .22 * (in_sec / 3) * (k / div)
                C.add(snare(.09), t0 + k * B / div, v, rng.uniform(-.2, .2))
            C.add(riser(B), t0, .25 * (in_sec + 1) / 4)
        if last_of_phrase and sec not in ("PRE", "INTRO") and nxt != "CHORUS":
            pats = [(10, 12, 14), (12, 13, 14, 15), (8, 10, 12, 13, 14, 15)]
            pat = pats[(bar // 4) % 3]
            for i, k in enumerate(pat):
                C.add(tom(52 - i * 2), t0 + k * st, .34, -0.6 + 1.2 * i / max(1, len(pat) - 1))
        if in_sec == 0 and sec in ("VERSE", "CHORUS", "TURN"):
            C.add(crash(), t0, .3, -.3)
        # the arp: climbs the chord, pattern changes per section, ping-pong
        if sec != "INTRO":
            up = ch + [n + 12 for n in ch]
            pats = {"VERSE": [0, 2, 1, 3, 2, 4, 3, 5, 4, 3, 2, 1, 2, 3, 4, 5], "PRE": [0, 1, 2, 3, 4, 5, 4, 5, 3, 4, 5, 4, 5, 5, 4, 5],
                    "CHORUS": [0, 1, 2, 3, 4, 5, 4, 3, 2, 3, 4, 5, 4, 3, 2, 1], "BREAK": [0, 2, 4, 2, 0, 2, 4, 5, 0, 2, 4, 2, 1, 3, 5, 3],
                    "TURN": [0, 2, 1, 3, 2, 4, 3, 5, 4, 3, 2, 1, 2, 3, 4, 5]}
            pat = pats[sec]
            for k in range(16):
                if sec == "BREAK" and k % 2:
                    continue
                idx = pat[k] % len(up)
                CP.add(arp_note(up[idx] + 12, st * 1.4, 2400 + 900 * dirt + (600 if sec == "CHORUS" else 0)), t0 + k * st, .12, 0.5 if k % 2 else -0.5)
        if sec in ("VERSE", "CHORUS", "TURN"):
            for k in range(16):
                m = r + (12 if k % 4 == 2 else 0) + (12 if k % 8 == 7 else 0)
                CP.add(pulse_bass(m, st * .8, 900 + 450 * dirt), t0 + k * st, .18)
        # ================================================= COMBO: the lead
        K, KP = L["combo"], P["combo"]
        if sec == "CHORUS":
            for s_, m, ln in hook[in_sec]:
                KP.add(hero_lead(m, ln * st * .95), t0 + s_ * st, .24)
                KP.add(hero_lead(m - 12, ln * st * .95), t0 + s_ * st, .06)
                if in_sec >= 4:   # second half: a harmony a third above
                    KP.add(hero_lead(nearest_in(scale, m + 4), ln * st * .95), t0 + s_ * st, .08, .35)
            # brass answers at the end of each bar
            KP.add(brass([n + 12 for n in ch], st * 1.5), t0 + 14 * st, .22, -.4 if in_sec % 2 else .4)
            if in_sec % 2 == 1:
                KP.add(brass([n + 12 for n in ch], st * 1.2), t0 + 11 * st, .16, .4)
        elif sec == "PRE":
            for s_, m, ln in pre_line[in_sec]:
                KP.add(hero_lead(m, ln * st * .95), t0 + s_ * st, .2)
            KP.add(brass([n + 12 for n in ch], st * 2), t0, .18)
        elif sec == "VERSE" and in_sec % 2 == 0:
            # the counter-melody taken up by the lead, an octave up
            for s_, m, ln in counter:
                KP.add(hero_lead(m + 12, ln * st * .9), t0 + s_ * st, .17, .15)
        elif sec == "TURN" and in_sec < 2:
            # a quote of the hook to pull you back round
            for s_, m, ln in hook[in_sec]:
                KP.add(hero_lead(m, ln * st * .95), t0 + s_ * st, .18)
        elif sec == "BREAK" and in_sec % 2 == 0:
            KP.add(hero_lead(ch[-1] + 12, B * 1.8), t0, .15)
        if in_sec == 0 and sec == "CHORUS":
            K.add(crash(), t0, .3, .3)
        # ================================================= DANGER
        D, DP = L["danger"], P["danger"]
        if sec != "INTRO":
            for k in range(16):
                DP.add(reese(r + (12 if k % 8 in (3, 6) else 0), st * .95, 2.0 + dirt), t0 + k * st, .22)
            for k in range(16):
                if (k + bar) % 5 == 4:
                    continue
                m = r + 24 + [0, 0, 12, 0, 7, 0, 12, 10][k % 8]
                DP.add(acid_note(m, st * 1.05, 280 + 90 * (bar % 4), 2400 + 900 * (k % 4 == 0), k % 4 == 0), t0 + k * st, .11, .25)
            for k in range(32):
                D.add(hat(.018), t0 + k * st / 2, .03 + .03 * (k % 4 == 0), -.4)
            for k in (0, 3, 6, 10, 12):
                DP.add(stab(ch, st * 1.3, 2.2 + dirt), t0 + k * st, .14, -.3 if k % 2 else .3)
        if last_of_phrase:
            D.add(riser(B), t0, .4)
            for k in range(8, 16):
                D.add(tom(56 - (k - 8) * 2, .22), t0 + k * st, .32, -0.7 + (k - 8) * 0.2)
    # ---- mix: sidechain pump on the synth busses, space, echoes
    n = s.n
    pm = pump(n, beat)[:, None]; pm_soft = pump(n, beat, .45)[:, None]
    ex = L["explore"].buf + st_reverb(P["explore"].buf * pm, .22)
    cb = L["combat"].buf + pingpong(P["combat"].buf * pm, st * 3, .45, .3)
    co = L["combo"].buf + pingpong(st_reverb(P["combo"].buf * pm_soft, .25, 1.3), st * 3, .4, .28)
    dg = st_reverb(L["danger"].buf, .12) + P["danger"].buf * pm
    render(name + "_explore", st_master(ex, .8))
    render(name + "_combat", st_master(cb, .78))
    render(name + "_combo", st_master(co, .8))
    render(name + "_danger", st_master(dg, .55))

def expand(sections):
    """{"INTRO": [(root, q)...] per bar, ...} -> 32-bar progression."""
    out = []
    for sec in ("INTRO", "VERSE", "PRE", "CHORUS", "BREAK", "TURN"):
        out += sections[sec]
    assert len(out) == 32
    return out

if __name__ == "__main__":
    E_MIN = [4, 6, 7, 9, 11, 0, 2]
    # "Checkout Time": E minor, 120 bpm - neon, rain, a motel at midnight
    prog = expand({
        "INTRO": [(40, "m9"), (40, "m9"), (36, "M7"), (36, "M7")],
        "VERSE": [(40, "m"), (36, "M"), (43, "M"), (38, "M"), (40, "m"), (36, "M"), (45, "m"), (47, "sus")],
        "PRE": [(45, "m"), (47, "m"), (48, "M"), (50, "M")],
        "CHORUS": [(48, "M"), (50, "M"), (40, "m"), (40, "m"), (48, "M"), (50, "M"), (47, "M"), (47, "7")],
        "BREAK": [(45, "m7"), (45, "m7"), (40, "m9"), (40, "m9")],
        "TURN": [(48, "M7"), (50, "M"), (40, "m"), (47, "7")],
    })
    hook = [
        [(0, 76, 3), (3, 79, 3), (6, 76, 2), (8, 74, 4), (12, 72, 4)],
        [(0, 74, 3), (3, 78, 3), (6, 74, 2), (8, 72, 4), (12, 71, 4)],
        [(0, 71, 3), (3, 74, 3), (6, 76, 4), (10, 79, 6)],
        [(0, 79, 2), (2, 78, 2), (4, 76, 4), (8, 74, 4), (12, 76, 4)],
        [(0, 76, 3), (3, 79, 3), (6, 76, 2), (8, 74, 4), (12, 72, 4)],
        [(0, 74, 3), (3, 78, 3), (6, 74, 2), (8, 72, 4), (12, 71, 4)],
        [(0, 75, 4), (4, 78, 4), (8, 83, 8)],
        [(0, 81, 4), (4, 78, 4), (8, 75, 4), (12, 71, 4)],
    ]
    counter = [(2, 67, 2), (4, 71, 2), (6, 74, 4), (12, 72, 2), (14, 71, 2), (18, 69, 2), (20, 67, 4), (26, 66, 2), (28, 64, 4)]
    pre_line = [[(0, 69, 4), (4, 72, 4), (8, 76, 8)], [(0, 71, 4), (4, 74, 4), (8, 78, 8)],
                [(0, 72, 4), (4, 76, 4), (8, 79, 8)], [(0, 74, 2), (2, 76, 2), (4, 78, 2), (6, 79, 2), (8, 81, 4), (12, 83, 4)]]
    score("level_checkout", 120, 40, prog, hook, counter, pre_line, E_MIN)

    CS_MIN = [1, 2, 4, 6, 8, 9, 11]   # C# phrygian flavour (the D)
    # "Dog Days": C# minor, 126 bpm - dust, dogs, sodium lights
    prog = expand({
        "INTRO": [(37, "m9"), (37, "m9"), (38, "M7"), (38, "M7")],
        "VERSE": [(37, "m"), (45, "M"), (40, "M"), (38, "M"), (37, "m"), (45, "M"), (42, "m"), (44, "sus")],
        "PRE": [(42, "m"), (44, "m"), (45, "M"), (47, "M")],
        "CHORUS": [(45, "M"), (47, "M"), (37, "m"), (37, "m"), (45, "M"), (47, "M"), (38, "M"), (38, "M")],
        "BREAK": [(42, "m7"), (42, "m7"), (37, "m9"), (37, "m9")],
        "TURN": [(45, "M7"), (47, "M"), (37, "m"), (44, "7")],
    })
    hook = [
        [(0, 76, 2), (2, 76, 1), (3, 78, 3), (6, 76, 2), (8, 73, 4), (12, 76, 4)],
        [(0, 78, 2), (2, 78, 1), (3, 80, 3), (6, 78, 2), (8, 75, 4), (12, 71, 4)],
        [(0, 80, 6), (6, 78, 2), (8, 76, 4), (12, 73, 4)],
        [(0, 76, 2), (2, 74, 2), (4, 73, 8), (12, 68, 4)],
        [(0, 76, 2), (2, 76, 1), (3, 78, 3), (6, 76, 2), (8, 73, 4), (12, 76, 4)],
        [(0, 78, 2), (2, 78, 1), (3, 80, 3), (6, 78, 2), (8, 75, 4), (12, 71, 4)],
        [(0, 74, 4), (4, 78, 4), (8, 81, 8)],
        [(0, 81, 2), (2, 78, 2), (4, 74, 4), (8, 73, 8)],
    ]
    counter = [(0, 68, 2), (2, 71, 2), (4, 73, 4), (10, 74, 2), (12, 73, 4), (16, 71, 2), (18, 68, 2), (20, 66, 4), (26, 64, 2), (28, 61, 4)]
    pre_line = [[(0, 66, 4), (4, 69, 4), (8, 73, 8)], [(0, 68, 4), (4, 71, 4), (8, 75, 8)],
                [(0, 69, 4), (4, 73, 4), (8, 76, 8)], [(0, 71, 2), (2, 73, 2), (4, 75, 2), (6, 76, 2), (8, 78, 4), (12, 80, 4)]]
    score("level_yard", 126, 37, prog, hook, counter, pre_line, CS_MIN, dirt=1.5)
