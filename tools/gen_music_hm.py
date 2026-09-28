#!/usr/bin/env python3
"""
HOTSHOT CALIFORNIA - the level and boss scores, second pass: punchier,
dirtier, catchier. Late-80s drum machine through a cheap mixer, a gritty
bass that drives in 8ths, a hook you can hum after one listen, everything
glued by the kick pumping the mix. Replaces the stems the game already
loads (same file names, same layering):

  <level>_explore  bass, pads, hats, the arp          (intensity 0)
  <level>_combat   + drums, chord stabs                (1)
  <level>_combo    + the lead hook                     (2)
  <level>_danger   + the hook doubled an octave up, distorted; toms, risers (3)

  boss_* : a full main mix, plus the level's second layer (see data/music.json)

  python tools/gen_music_hm.py [track ...]      (needs ffmpeg on PATH)
"""
import os, sys, subprocess, wave
import numpy as np
from scipy.signal import butter, lfilter

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUS = os.path.join(ROOT, "music")
rng = np.random.default_rng(1987)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_music_dream import space   # the hall + chorus finishing chain

# ------------------------------------------------------------------ dsp
def t_ax(d): return np.arange(int(d * SR)) / SR
def mtof(m): return 440.0 * 2 ** ((m - 69) / 12.0)
def lp(x, fc, o=2):
    b, a = butter(o, min(fc, SR * 0.45) / (SR / 2), "low"); return lfilter(b, a, x)
def hp(x, fc, o=2):
    b, a = butter(o, fc / (SR / 2), "high"); return lfilter(b, a, x)
def bp(x, lo, hi, o=2):
    b, a = butter(o, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band"); return lfilter(b, a, x)
def sat(x, d=2.0): return np.tanh(x * d) / np.tanh(d)
def noise(d): return rng.uniform(-1, 1, int(d * SR))
def env(n, a, dcy, s, r):
    e = np.full(n, s, dtype=float)
    a, dcy, r = int(a * SR), int(dcy * SR), int(r * SR)
    if a: e[:min(a, n)] = np.linspace(0, 1, a)[:min(a, n)]
    if dcy and a < n:
        seg = np.linspace(1, s, dcy)[:max(0, min(dcy, n - a))]; e[a:a + len(seg)] = seg
    if r: e[-min(r, n):] *= np.linspace(1, 0, min(r, n))
    return e
def saw(f, d, ph=0.0):
    t = t_ax(d); return 2.0 * ((t * f + ph) % 1.0) - 1.0
def sqr(f, d, pw=0.5):
    t = t_ax(d); return np.where((t * f) % 1.0 < pw, 1.0, -1.0)
def crush(x, bits=10, keep=3):
    """bit and rate reduction: the cheap-sampler grit"""
    q = 2 ** (bits - 1)
    y = np.round(x * q) / q
    y = np.repeat(y[::keep], keep)[:len(x)]
    return y

# ------------------------------------------------------------------ instruments
def kick(d=0.42):
    t = t_ax(d)
    f = 48 + 170 * np.exp(-t * 32)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7.5)
    click = hp(noise(d), 3000) * np.exp(-t * 180) * 0.5
    return sat(body * 1.6 + click, 4.5)

def snare(d=0.45):
    t = t_ax(d)
    tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 28) * 0.7
    n = bp(noise(d), 900, 7000) * np.exp(-t * 16)
    x = tone + n
    # 80s gated reverb: a dense tail cut dead at ~0.28s
    tail = lp(noise(d), 5000) * np.exp(-t * 4) * 0.35 * (t < 0.28)
    return sat(x + tail, 2.0)

def clap(d=0.3):
    t = t_ax(d)
    n = bp(noise(d), 1100, 4500)
    e = np.zeros_like(t)
    for o in (0.0, 0.011, 0.022):
        e += np.exp(-np.maximum(t - o, 0) * 60) * (t >= o)
    e += np.exp(-np.maximum(t - 0.03, 0) * 14) * 0.6 * (t >= 0.03)
    return n * e * 0.8

def hat(d=0.05, open_=False):
    d = 0.3 if open_ else d
    t = t_ax(d)
    return hp(noise(d), 7500) * np.exp(-t * (9 if open_ else 70)) * 0.5

def tom(m, d=0.32):
    t = t_ax(d)
    f = mtof(m) * (1 + 0.6 * np.exp(-t * 18))
    return sat(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9), 1.8)

def crash(d=1.6):
    t = t_ax(d); return hp(noise(d), 4500) * np.exp(-t * 2.2) * 0.45

def riser(d):
    t = t_ax(d)
    f = 300 + 2400 * (t / d) ** 2
    return (bp(noise(d), 800, 9000) * (t / d) ** 2 * 0.35 + np.sin(2 * np.pi * np.cumsum(f) / SR) * (t / d) * 0.12)

def gritbass(m, d, cut=900, drive=3.2):
    f = mtof(m)
    # reese: two saws beating against each other, a sub square under them
    x = saw(f * 0.993, d) * 0.6 + saw(f * 1.007, d, 0.3) * 0.6 + sqr(f / 2, d, 0.5) * 0.45
    n = len(x)
    fe = cut * (0.35 + 0.65 * np.exp(-t_ax(d) * 14))
    y = np.zeros(n)
    # cheap time-varying low-pass: blocks of 256 samples
    for i in range(0, n, 256):
        y[i:i + 256] = lp(x[i:i + 256], float(fe[i]))
    return sat(y * env(n, 0.003, 0.08, 0.75, 0.02), drive) * 0.9

def hook_lead(m, d, bend_from=None):
    """square lead with vibrato fading in, a little glide into the note"""
    t = t_ax(d)
    f0 = mtof(m)
    f = np.full_like(t, f0)
    if bend_from is not None:
        g = np.exp(-t * 40)
        f = f0 + (mtof(bend_from) - f0) * g
    f *= 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.25, 0, 1)
    ph = np.cumsum(f) / SR
    x = (2 * (ph % 1.0) - 1) * 0.45 + (2 * (ph * 1.009 % 1.0) - 1) * 0.35 + (2 * (ph * 0.5 % 1.0) - 1) * 0.3
    return sat(lp(x, 2400), 2.2) * env(len(t), 0.006, 0.12, 0.8, 0.08)

def stab(notes, d):
    x = sum(saw(mtof(n), d, i * 0.17) + saw(mtof(n) * 1.01, d) for i, n in enumerate(notes)) / (2 * len(notes))
    return sat(lp(x, 2200) * env(len(x), 0.002, 0.12, 0.25, 0.05) * 2.6, 2.4)

def pad(notes, d):
    x = sum(saw(mtof(n), d, i * 0.31) + saw(mtof(n) * 1.006, d, 0.5) + saw(mtof(n) * 0.994, d, 0.8) for i, n in enumerate(notes)) / (3 * len(notes))
    return lp(x, 1100) * env(len(x), 0.4, 0.3, 0.8, 0.5)

def arp_note(m, d):
    x = sqr(mtof(m), d, 0.25) * 0.5 + np.sin(2 * np.pi * mtof(m) * t_ax(d)) * 0.5
    return lp(x, 1500) * np.exp(-t_ax(d) * 11)

# ------------------------------------------------------------------ mix bus
class Bus:
    def __init__(self, bpm, bars):
        self.beat = 60.0 / bpm
        self.step = self.beat / 4
        self.bar = self.beat * 4
        self.n = int(round(self.bar * bars * SR))
        self.L = np.zeros(self.n)
        self.R = np.zeros(self.n)
    def add(self, x, at, g=1.0, pan=0.0):
        # declick: every note eases in and out over 3 ms (hard onsets crackled)
        x = np.array(x, dtype=np.float64)
        f = min(len(x) // 2, int(0.003 * SR))
        if f > 1:
            ramp = np.linspace(0.0, 1.0, f)
            x[:f] *= ramp
            x[-f:] *= ramp[::-1]
        s = int(at * SR) % self.n
        l = np.cos((pan + 1) * np.pi / 4) * 1.414
        r = np.sin((pan + 1) * np.pi / 4) * 1.414
        e = min(self.n, s + len(x))
        self.L[s:e] += x[:e - s] * g * l
        self.R[s:e] += x[:e - s] * g * r
        rest = x[e - s:]
        if len(rest):   # wrap the tail round for a seamless loop
            m = min(len(rest), self.n)
            self.L[:m] += rest[:m] * g * l
            self.R[:m] += rest[:m] * g * r
    def pump(self, kicks, depth=0.6):
        """sidechain: duck under every kick"""
        g = np.ones(self.n)
        rel = int(self.beat * 0.8 * SR)
        shape = 1 - depth * np.exp(-np.linspace(0, 5, rel))
        for at in kicks:
            s = int(at * SR) % self.n
            e = min(self.n, s + rel)
            g[s:e] = np.minimum(g[s:e], shape[:e - s])
        self.L *= g
        self.R *= g
    def delay(self, secs, fb=0.35, mix=0.3):
        d = int(secs * SR)
        for ch_src, ch_dst in ((self.L.copy(), "R"), (self.R.copy(), "L")):
            wet = np.zeros(self.n)
            y = ch_src.copy()
            for k in range(1, 5):
                y = np.roll(y, d) * fb
                wet += y
            setattr(self, ch_dst, getattr(self, ch_dst) + lp(wet, 4000) * mix)
    def stereo(self):
        return np.stack([self.L, self.R], axis=1)

def master(x, drive=1.6, peak=0.9):
    """Clean master: high-pass, normalise, and a soft knee only on the very
    top 15% of the peaks (the old 'tape' drive squashed everything into
    distortion and crackle). `drive` is kept for callers, unused."""
    x = np.stack([hp(x[:, 0], 28), hp(x[:, 1], 28)], axis=1)
    x = x / (np.max(np.abs(x)) + 1e-9)
    knee = 0.85
    a = np.abs(x)
    over = a > knee
    x[over] = np.sign(x[over]) * (knee + (1 - knee) * np.tanh((a[over] - knee) / (1 - knee)))
    return x / (np.max(np.abs(x)) + 1e-9) * min(peak, 0.84)

def write_ogg(name, x, q=4):
    tmp = os.path.join(MUS, name + ".tmp.wav")
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-ar", "32000", "-c:a", "libvorbis", "-q:a", str(q), os.path.join(MUS, name + ".ogg")], check=True)
    os.remove(tmp)
    print("music", name, f"{len(x) / SR:.1f}s")

# ------------------------------------------------------------------ the composer
MINOR = [0, 2, 3, 5, 7, 8, 10]
def chord(root, kind="m"):
    return [root, root + (4 if kind == "M" else 3), root + (6 if kind == "d" else 7)]

def compose(name, bpm, prog, hook, bass_style="octaves", drums="four", lead_oct=0, dirt=1.0, bars=48, danger_hook=True, layout=(0, 1, 2, 3, 4, 5)):
    """prog: 8 [root(midi, around 40-52), kind] one per bar (the loop repeats
    4x across 32 bars with sections). hook: 2-bar phrase [(step16, midi, len16), ...]
    for bars 1-2 of every 4; the answer (bars 3-4) is the hook shifted to the
    chord. Returns nothing; writes the four stems."""
    stems = {k: Bus(bpm, bars) for k in ("explore", "combat", "combo", "danger")}
    b = stems["explore"]
    beat, st, B = b.beat, b.step, b.bar
    kicks = []
    K, S, C = kick(), snare(), clap()
    for bar in range(bars):
        t0 = bar * B
        # six sections of eight bars:
        #   0 intro   - the bed, filtered; the hook's first notes tease at the end
        #   1 call    - drums in, the hook in fragments
        #   2 chorus  - the whole hook and its answer
        #   3 break   - drums out, the hook slow and low, a snare roll into...
        #   4 lift    - the chorus again a whole tone up, with a counter-line
        #   5 turn    - the answer alone, varied, back round to the top
        sec = layout[(bar // 8) % len(layout)]
        lift = 2 if sec == 4 else 0
        root, kind = prog[bar % len(prog)]
        root += lift
        ch = chord(root + 12, kind)
        # ---- explore: bass, pad, hats, arp
        for s16 in range(16):
            at = t0 + s16 * st
            if sec == 3:
                if s16 == 0:
                    stems["explore"].add(gritbass(root - 12, B * 0.95, 400, 1.8), at, 0.5)
            elif bass_style == "octaves" and s16 % 2 == 0:
                m = root - 12 + (12 if (s16 // 2) % 2 else 0)
                stems["explore"].add(gritbass(m, st * 1.8, 700 + 500 * dirt, 2.6 + dirt), at, 0.55)
            elif bass_style == "gallop" and s16 % 4 in (0, 2, 3):
                stems["explore"].add(gritbass(root - 12, st * 0.95, 900, 3.0 + dirt), at, 0.55)
            elif bass_style == "ostinato":
                # the hypnotic 16th-note figure under it all
                fig = [0, 0, 12, 0, 7, 0, 12, 3][s16 % 8]
                stems["explore"].add(gritbass(root - 12 + fig, st * 0.9, 1100, 2.4 + dirt * 0.6), at, 0.4 if s16 % 4 == 0 else 0.3)
            elif bass_style == "drone" and s16 % 8 == 0:
                stems["explore"].add(gritbass(root - 12, st * 7.5, 500, 2.0 + dirt), at, 0.6)
            stems["explore"].add(hat(), at + (st * 0.12 if s16 % 2 else 0.0), 0.16 if s16 % 4 == 2 else 0.08, 0.3 if s16 % 2 else -0.3)
            # arp: chord tones up and down, an octave up
            a = [ch[0], ch[2], ch[1], ch[0] + 12, ch[2], ch[1], ch[0], ch[2] - 12][s16 % 8]
            stems["explore"].add(arp_note(a, st * 0.9), at, 0.09 if sec != 1 else 0.13, 0.45 if s16 % 2 else -0.45)
        if bar % 2 == 0:
            stems["explore"].add(pad(ch, B * 2), t0, 0.12)
        # ---- combat: drums and stabs
        quiet = sec == 0 or sec == 3
        if sec == 3:
            stems["combat"].add(K, t0, 0.7)
            kicks.append(t0)
            if bar % 8 == 7:
                for r in range(16):
                    stems["combat"].add(S, t0 + r * st, 0.12 + 0.03 * r)
        if sec in (1, 3) and bar % 8 == 7:
            # a reversed swell into the next section
            sw = hp(noise(B * 0.5), 2500) * np.linspace(0, 1, int(B * 0.5 * SR)) ** 3 * 0.6
            stems["combat"].add(sw, t0 + B * 0.5, 0.5)
        for b4 in range(4):
            at = t0 + b4 * beat
            if quiet:
                break
            if drums == "four" or (drums == "half" and b4 in (0, 2)) or (drums == "break" and b4 in (0,)):
                stems["combat"].add(K, at, 0.95)
                kicks.append(at)
            if drums == "break" and b4 == 2:
                stems["combat"].add(K, at + st * 2, 0.9)
                kicks.append(at + st * 2)
            if b4 in (1, 3) and drums != "half":
                stems["combat"].add(S, at, 0.55)
                stems["combat"].add(C, at, 0.3, 0.15)
            if drums == "half" and b4 == 2:
                stems["combat"].add(S, at, 0.6)
            stems["combat"].add(hat(open_=True), at + beat * 0.5, 0.12, 0.4)
        for s16 in (0, 3, 6, 10, 12):
            if quiet:
                break
            if sec in (2, 4) or s16 in (0, 6):
                stab_ch = [ch[0], ch[0] + 7, ch[0] + 12]      # power chords: grit, no sweetness
                stems["combat"].add(stab(stab_ch, st * 2), t0 + s16 * st, 0.2, -0.1)
        if bar % 8 == 7:
            for i, m in enumerate((50, 47, 45, 43)):
                stems["danger"].add(tom(m + (root % 12) - 4), t0 + (12 + i) * st, 0.45, -0.4 + i * 0.25)
        if bar % 8 == 0 and sec in (1, 2, 4, 5):
            stems["combat"].add(crash(), t0, 0.45 if sec in (2, 4) else 0.3)
        # ---- combo: the hook, answered on the next chord
        answer = [(s2, m + (root - lift - prog[0][0]), l) for (s2, m, l) in hook]
        phrase = None
        if sec == 0 and bar % 8 == 7:
            phrase = [x for x in hook if x[0] < 8]                 # the tease
        elif sec == 1 and bar % 4 < 2:
            phrase = hook if bar % 4 == 0 else []                   # the call, half of it
        elif sec in (2, 4):
            phrase = hook if (bar % 4) < 2 else answer
        elif sec == 5:
            # the answer alone, its last note held and bent down a step
            phrase = [(s2, m - (2 if i == len(answer) - 1 else 0), l) for i, (s2, m, l) in enumerate(answer)]
        if phrase:
            half = (bar % 2) * 16 if sec != 0 else 0
            prev = None
            for (s2, m, l) in phrase:
                if half <= s2 < half + 16:
                    mm = m + 12 * lead_oct + lift
                    stems["combo"].add(hook_lead(mm, st * l * 0.95, prev), t0 + (s2 - half) * st, 0.3, 0.05)
                    if sec == 4:
                        # the counter-line: a sixth below, answering in the other ear
                        stems["combo"].add(hook_lead(mm - 9, st * l * 0.9), t0 + (s2 - half) * st + st * 0.5, 0.12, -0.5)
                    prev = mm
        if sec == 3 and bar % 2 == 0:
            # the break: the hook's opening, twice as slow and an octave down
            for (s2, m, l) in [x for x in hook if x[0] < 8]:
                stems["combo"].add(lp(hook_lead(m - 12 + 12 * lead_oct, st * l * 1.9), 1400), t0 + s2 * 2 * st, 0.28, 0.0)
        # ---- danger: the hook an octave up, crushed and driven
        if danger_hook and (bar % 4) < 2 and sec in (2, 4, 5):
            half = (bar % 2) * 16
            for (s, m, l) in hook:
                if half <= s < half + 16:
                    x = sat(crush(hook_lead(m + 12 * (lead_oct + 1), st * l * 0.9), 9, 2) * 1.8, 2.5)
                    stems["danger"].add(x, t0 + (s - half) * st, 0.14, -0.2)
        if bar % 8 == 6:
            stems["danger"].add(riser(B * 2), t0, 0.5)
        for b4 in range(4):
            g = sat(bp(noise(st * 1.5), 150, 2500) * np.exp(-t_ax(st * 1.5) * 18) * 3.0, 3.0)
            stems["danger"].add(g, t0 + (b4 + 0.5) * beat, 0.16, 0.3 if b4 % 2 else -0.3)
        stems["danger"].add(gritbass(root - 24, B * 0.98, 300, 5.0), t0, 0.22)
    # glue: everything but the drums pumps under the kick
    for k in ("explore", "combo", "danger"):
        stems[k].pump(kicks, 0.55 if k == "explore" else 0.4)
    stems["combo"].delay(beat * 0.75, 0.35, 0.28)
    stems["explore"].delay(beat * 0.75, 0.25, 0.12)
    peaks = {"explore": 0.72, "combat": 0.8, "combo": 0.62, "danger": 0.55}
    wets = {"explore": 0.3, "combat": 0.1, "combo": 0.28, "danger": 0.18}
    for k, bus in stems.items():
        L, R = space(bus.L, bus.R, wets[k], 2.2)
        write_ogg(f"{name}_{k}", master(np.stack([L, R], axis=1), 1.3 + 0.3 * dirt, peaks[k]))

def boss(name, bpm, prog, hook, alt=None, dirt=1.4, bars=24):
    """A full boss mix (all four layers summed) and, if `alt` is given, a
    second full variant ('dark': drums and bass only, crushed; 'fire': the
    hook doubled and driven) for data/music.json's second layer."""
    # a fight doesn't get an intro: chorus, the lift, the chorus again
    compose(name + "__tmp", bpm, prog, hook, "gallop", "four", 0, dirt, bars, True, (2, 4, 2))
    parts = {}
    for k in ("explore", "combat", "combo", "danger"):
        p = os.path.join(MUS, f"{name}__tmp_{k}.ogg")
        wav = p.replace(".ogg", ".wav")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", p, "-ar", str(SR), wav], check=True)
        with wave.open(wav, "rb") as w:
            parts[k] = np.frombuffer(w.readframes(w.getnframes()), np.int16).reshape(-1, 2) / 32767.0
        os.remove(wav)
        os.remove(p)
    full = parts["explore"] * 0.8 + parts["combat"] + parts["combo"] + parts["danger"] * 0.6
    write_ogg(name, master(full, 1.4, 0.9))
    if alt == "dark":
        x = parts["combat"] * 1.1 + parts["explore"] * 0.5
        x = np.stack([crush(lp(x[:, 0], 2400), 8, 3), crush(lp(x[:, 1], 2400), 8, 3)], axis=1)
        write_ogg(name + "_dark", master(x, 1.8, 0.85))
    elif alt == "fire":
        write_ogg(name + "_fire", master(parts["danger"] * 1.4 + parts["combo"] * 0.6, 2.0, 0.8))

# ------------------------------------------------------------------ the scores
def E(n): return n
TRACKS = {
    # Checkout Time - E phrygian, 118: rain on the lot, a riff that keeps
    # falling back onto the same bad note
    "level_checkout": dict(bpm=118, prog=[(40, "m"), (40, "m"), (41, "M"), (40, "m"), (36, "M"), (35, "M"), (40, "m"), (41, "M")],
        hook=[(0, 64, 2), (2, 67, 2), (4, 65, 2), (6, 64, 2), (8, 71, 4), (12, 70, 2), (14, 67, 2), (16, 64, 2), (18, 67, 2), (20, 65, 2), (22, 64, 2), (24, 59, 6), (30, 63, 2)],
        bass_style="ostinato", drums="four", dirt=1.6),
    # Dog Days - C# minor, 124: heat and chain-link, a galloping reese
    "level_yard": dict(bpm=124, prog=[(37, "m"), (37, "m"), (38, "M"), (37, "m"), (45, "M"), (44, "M"), (37, "m"), (44, "M")],
        hook=[(0, 61, 3), (3, 64, 3), (6, 62, 2), (8, 61, 2), (10, 68, 4), (14, 67, 2), (16, 61, 3), (19, 64, 3), (22, 62, 2), (24, 60, 8)],
        bass_style="gallop", drums="four", dirt=2.0),
    # Prime Time - F# minor, 128: the game-show sting played in a morgue
    "level_primetime": dict(bpm=128, prog=[(42, "m"), (43, "M"), (42, "m"), (38, "M"), (47, "m"), (37, "M"), (42, "m"), (37, "M")],
        hook=[(0, 66, 2), (2, 66, 1), (3, 69, 3), (6, 67, 2), (8, 66, 4), (12, 61, 4), (16, 66, 2), (18, 73, 2), (20, 72, 2), (22, 69, 2), (24, 67, 4), (28, 65, 4)],
        bass_style="ostinato", drums="break", dirt=1.8),
    # Sweet Dreams - D minor, 96: a lullaby dragged underwater, half-time
    "level_nightmare": dict(bpm=96, prog=[(38, "m"), (39, "M"), (38, "m"), (34, "M"), (43, "m"), (45, "M"), (38, "m"), (37, "d")],
        hook=[(0, 62, 4), (4, 63, 4), (8, 62, 2), (10, 58, 2), (12, 57, 4), (16, 62, 4), (20, 69, 4), (24, 68, 4), (28, 65, 4)],
        bass_style="drone", drums="half", dirt=2.4),
}
BOSSES = {
    "boss_night_manager": dict(bpm=138, prog=[(37, "m"), (38, "M"), (37, "m"), (44, "M")] * 2,
        hook=[(0, 61, 2), (2, 61, 1), (3, 62, 3), (6, 61, 2), (8, 68, 4), (12, 67, 4), (16, 64, 2), (18, 62, 2), (20, 61, 4), (24, 56, 8)], alt="dark"),
    "boss_fireman": dict(bpm=148, prog=[(42, "m"), (43, "M"), (42, "m"), (37, "M")] * 2,
        hook=[(0, 66, 2), (2, 69, 2), (4, 66, 2), (6, 67, 4), (10, 66, 2), (12, 61, 4), (16, 66, 2), (18, 64, 2), (20, 66, 4), (24, 60, 8)], alt="fire"),
    "boss_nightmare": dict(bpm=132, prog=[(38, "m"), (39, "M"), (38, "m"), (37, "d")] * 2,
        hook=[(0, 62, 3), (3, 63, 3), (6, 62, 2), (8, 60, 4), (12, 59, 4), (16, 62, 2), (18, 65, 2), (20, 63, 4), (24, 62, 8)], alt=None),
}

# ------------------------------------------------------------------ the teaser
# the cold open's cut list, in beats at 128 bpm (scripts/ui/intro.gd uses
# the same numbers so every cut lands on the music)
TEASER_BPM = 128
TEASER_CUTS = [2, 4, 2, 4, 4, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 4]   # then the logo

def teaser():
    b = Bus(TEASER_BPM, 12)
    beat, st = b.beat, b.step
    cuts = np.cumsum([0] + TEASER_CUTS)       # beat index of every cut; last = logo
    logo = cuts[-1]
    boom = cuts[3]                             # the explosion
    kicks = []
    root = 40                                  # E: the same key as the motel
    # a drone under all of it, the reese creeping in
    b.add(pad([root, root + 7, root + 12], logo * beat), 0.0, 0.18)
    b.add(gritbass(root - 12, logo * beat * 0.98, 260, 2.5), 0.0, 0.35)
    for i in range(int(logo)):
        at = i * beat
        if i < boom:
            # before the fire: a heartbeat and a tick
            if i % 2 == 0:
                b.add(kick(), at, 0.45); kicks.append(at)
            b.add(hat(), at + beat * 0.5, 0.06)
        elif i < cuts[5]:
            b.add(hat(), at, 0.05)
        elif i < cuts[-2]:
            # the drive: four on the floor, the reese in 8ths, snare 2 and 4
            b.add(kick(), at, 0.95); kicks.append(at)
            if i % 2 == 1:
                b.add(snare(), at, 0.5); b.add(clap(), at, 0.25)
            for h in range(2):
                b.add(gritbass(root - 12 + (12 if h else 0), st * 1.8, 900, 4.0), at + h * beat * 0.5, 0.5)
            b.add(hat(open_=True), at + beat * 0.5, 0.1)
        # the last four one-beat cuts: a snare roll into the silence
        if cuts[13] <= i < cuts[17]:
            for r in range(4):
                b.add(snare(0.2), at + r * st, 0.18 + 0.1 * (i - cuts[13]))
    # a stab on every cut from the Sunset Palms on
    for c in cuts[5:-1]:
        b.add(stab([root + 12, root + 19, root + 24], st * 3), c * beat, 0.3)
    b.add(riser(beat * 4), (cuts[13]) * beat, 0.6)
    # the fire: a sub drop and a crash, then a ringing hole
    at = boom * beat
    b.add(sat(sweep(160, 28, 3.0, 5) * np.exp(-t_ax(3.0) * 1.4), 2.0), at, 1.0)
    b.add(crash(2.5), at, 0.6)
    b.add(lp(noise(2.0), 500) * np.exp(-t_ax(2.0) * 2.0), at, 0.5)
    # the hook, once, quiet, over the mirror
    for (s16, m, l) in [(0, 64, 4), (4, 67, 4), (8, 65, 4), (12, 64, 8)]:
        b.add(hook_lead(m, st * l * 0.95), cuts[4] * beat + s16 * st, 0.18)
    # the logo: everything at once, then it rings out
    at = logo * beat
    for n in (root, root + 7, root + 12, root + 15, root + 19):
        b.add(saw(mtof(n), 3.5) * np.exp(-t_ax(3.5) * 1.1) * 0.3, at, 0.5)
    b.add(kick(0.8), at, 1.2); b.add(crash(3.0), at, 0.8)
    b.add(sat(sweep(120, 30, 3.5, 4) * np.exp(-t_ax(3.5) * 1.2), 2.0), at, 1.0)
    b.add(gritbass(root - 24, 3.0, 400, 5.0), at, 0.6)
    b.pump(kicks, 0.35)
    x = b.stereo()
    x[: int(0.01 * SR)] *= np.linspace(0, 1, int(0.01 * SR))[:, None]
    # no wrap-around: the teaser plays once
    write_ogg("intro_teaser", master(x, 1.6, 0.92))

def sweep(f0, f1, d, rate):
    t = t_ax(d)
    f = f1 + (f0 - f1) * np.exp(-t * rate)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)

def single(name, bpm, prog, hook, bass_style="octaves", drums="four", dirt=1.2, bars=32, mix=(0.85, 0.9, 1.0, 0.45)):
    """one finished mix (no stems): the four layers summed"""
    compose(name + "__tmp", bpm, prog, hook, bass_style, drums, 0, dirt, bars)
    parts = []
    for k in ("explore", "combat", "combo", "danger"):
        p = os.path.join(MUS, f"{name}__tmp_{k}.ogg")
        wav = p.replace(".ogg", ".wav")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", p, "-ar", str(SR), wav], check=True)
        with wave.open(wav, "rb") as w:
            parts.append(np.frombuffer(w.readframes(w.getnframes()), np.int16).reshape(-1, 2) / 32767.0)
        os.remove(wav)
        os.remove(p)
    full = sum(pt * g for pt, g in zip(parts, mix))
    write_ogg(name, master(full, 1.35, 0.9))

# The title: "Neon Vigil", E minor, 104. The hook opens on the studio
# chime's own interval (B up to E, then G) and walks home down the scale -
# the one melody the whole game hangs on.
TITLE = dict(bpm=104, prog=[(40, "m"), (36, "M"), (43, "M"), (38, "M"), (40, "m"), (36, "M"), (45, "m"), (47, "M")],
    hook=[(0, 71, 3), (3, 76, 3), (6, 79, 6), (12, 78, 2), (14, 76, 2), (16, 74, 4), (20, 76, 4), (24, 71, 8)],
    bass_style="octaves", drums="four", dirt=1.1, bars=32)

if __name__ == "__main__":
    if "intro_teaser" in sys.argv[1:]:
        teaser()
        sys.exit(0)
    if "title" in sys.argv[1:]:
        single("title_neon_vigil", **TITLE)
        sys.exit(0)
    want = sys.argv[1:]
    for k, v in TRACKS.items():
        if not want or k in want:
            compose(k, **v)
    for k, v in BOSSES.items():
        if not want or k in want:
            boss(k, **v)
