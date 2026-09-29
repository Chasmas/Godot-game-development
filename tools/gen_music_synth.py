#!/usr/bin/env python3
"""
HOTSHOT CALIFORNIA - the level scores, third pass: catchy 80s synth songs.

Each level gets a real song - intro, verse, pre-chorus, chorus, verse,
chorus, bridge, last chorus, turnaround - about two minutes before it
loops, so it doesn't wear thin. The tune is in the base layer: you hear it
from the moment you walk in, not only mid-combo.

Stems (same names and layering as data/music.json expects):
  <level>_explore  the song: melody, bass, pads, a light beat   (intensity 0)
  <level>_combat   + the full kit, fills, brass stabs, arps      (1)
  <level>_combo    + the bell doubling the melody, a counter-line (2)
  <level>_danger   + the melody an octave up, toms, risers, sub   (3)

  python tools/gen_music_synth.py [track ...]      (needs ffmpeg on PATH)
"""
import os, sys, subprocess, wave
import numpy as np
from scipy.signal import butter, lfilter

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUS = os.path.join(ROOT, "music")
rng = np.random.default_rng(1988)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_music_dream import space   # hall + chorus

# ------------------------------------------------------------------ dsp
def t_ax(d): return np.arange(max(1, int(d * SR))) / SR
def mtof(m): return 440.0 * 2 ** ((m - 69) / 12.0)
def lp(x, fc, o=2):
    b, a = butter(o, min(fc, SR * 0.45) / (SR / 2), "low"); return lfilter(b, a, x)
def hp(x, fc, o=2):
    b, a = butter(o, fc / (SR / 2), "high"); return lfilter(b, a, x)
def bp(x, lo, hi, o=2):
    b, a = butter(o, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band"); return lfilter(b, a, x)
def soft(x, d=1.5): return np.tanh(x * d) / np.tanh(d)
def noise(d): return rng.uniform(-1, 1, max(1, int(d * SR)))
def adsr(n, a, d, s, r):
    e = np.full(n, s, dtype=float)
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    if a:
        k = min(a, n); e[:k] = np.linspace(0, 1, a)[:k]
    if d and a < n:
        seg = np.linspace(1, s, d)[:max(0, min(d, n - a))]; e[a:a + len(seg)] = seg
    if r:
        k = min(r, n); e[-k:] *= np.linspace(1, 0, k)
    return e
def saw_ph(ph): return 2.0 * (ph % 1.0) - 1.0
def phase(f, d):
    f = np.broadcast_to(np.asarray(f, dtype=float), (len(t_ax(d)),))
    return np.cumsum(f) / SR
def sweep_filter(x, lo, hi, k):
    """a filter envelope without zipper noise: a crossfade from a bright
    copy to a dark one along the decay"""
    e = np.exp(-np.arange(len(x)) / SR * k)
    return lp(x, hi) * e + lp(x, lo) * (1 - e)

# ------------------------------------------------------------------ drums
def kick(d=0.38):
    t = t_ax(d)
    f = 44 + 120 * np.exp(-t * 28)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
    click = hp(noise(d), 2500) * np.exp(-t * 260) * 0.35
    return soft(body * 1.2 + click, 1.8)

def snare(d=0.5):
    """LinnDrum-ish snare into a gated plate: the 1985 crack"""
    t = t_ax(d)
    tone = (np.sin(2 * np.pi * 190 * t) + 0.5 * np.sin(2 * np.pi * 330 * t)) * np.exp(-t * 26) * 0.55
    n = bp(noise(d), 1200, 8000) * np.exp(-t * 20)
    gate = (t < 0.26).astype(float) * np.clip((0.26 - t) / 0.02, 0, 1)
    tail = lp(bp(noise(d), 500, 7000), 6000) * np.exp(-t * 3.5) * 0.4 * gate
    return soft(tone + n + tail, 1.4)

def clap(d=0.32):
    t = t_ax(d)
    n = bp(noise(d), 1000, 5000)
    e = np.zeros_like(t)
    for o in (0.0, 0.009, 0.019):
        e += np.exp(-np.maximum(t - o, 0) * 70) * (t >= o)
    e += np.exp(-np.maximum(t - 0.028, 0) * 12) * 0.5 * (t >= 0.028)
    return n * e * 0.7

def hat(open_=False):
    d = 0.28 if open_ else 0.06
    t = t_ax(d)
    x = hp(noise(d), 8000) + hp(np.sign(np.sin(2 * np.pi * 7400 * t)) * 0.2, 6000)
    return x * np.exp(-t * (10 if open_ else 80)) * 0.45

def tom(m, d=0.36):
    t = t_ax(d)
    f = mtof(m) * (1 + 0.5 * np.exp(-t * 16))
    return soft(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 8) + lp(noise(d), 1500) * np.exp(-t * 40) * 0.2, 1.3)

def crash(d=1.8):
    t = t_ax(d); return hp(noise(d), 4000) * np.exp(-t * 2.0) * 0.4

def riser(d):
    t = t_ax(d)
    f = 250 + 3000 * (t / d) ** 2
    return bp(noise(d), 700, 9000) * (t / d) ** 2 * 0.3 + np.sin(2 * np.pi * np.cumsum(f) / SR) * (t / d) * 0.08

# ------------------------------------------------------------------ synths
def bass(m, d, bright=1800, pluck=18.0):
    """synthwave bass: two saws a hair apart and a square an octave down,
    plucked open and closing down"""
    f = mtof(m)
    x = saw_ph(phase(f * 0.997, d)) * 0.5 + saw_ph(phase(f * 1.003, d) + 0.3) * 0.5 + np.sign(np.sin(2 * np.pi * phase(f / 2, d))) * 0.35
    y = sweep_filter(x, 260, bright, pluck)
    return soft(y * adsr(len(y), 0.003, 0.1, 0.8, 0.03), 1.4) * 0.8

def pad(notes, d, cut=2400):
    """Juno strings: three detuned saws per note, slow in, slow out"""
    n = len(t_ax(d))
    x = np.zeros(n)
    for i, m in enumerate(notes):
        f = mtof(m)
        for det, ph in ((1.0, 0.0), (1.0045, 0.33), (0.9955, 0.66)):
            x += saw_ph(phase(f * det, d) + ph + i * 0.21)
    x /= 3 * len(notes)
    return lp(x, cut) * adsr(n, 0.35, 0.4, 0.85, 0.45)

def lead(m, d, glide_from=None, bright=4200):
    """the hook: two detuned saws and a square an octave down, a little
    glide into the note, vibrato that fades in on long notes"""
    t = t_ax(d)
    f0 = mtof(m)
    f = np.full_like(t, f0)
    if glide_from is not None and glide_from != m:
        f = f0 + (mtof(glide_from) - f0) * np.exp(-t * 55)
    f = f * (1 + 0.007 * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - 0.18) * 4, 0, 1))
    ph = np.cumsum(f) / SR
    x = saw_ph(ph) * 0.5 + saw_ph(ph * 1.006 + 0.4) * 0.4 + np.sign(np.sin(2 * np.pi * ph * 0.5)) * 0.25
    x = sweep_filter(x, bright * 0.55, bright, 6.0)
    return soft(x * adsr(len(t), 0.008, 0.18, 0.75, 0.07) * 0.8, 1.2)

def bell(m, d):
    """DX7 bell / tine: the sparkle over the hook"""
    t = t_ax(d); f = mtof(m)
    idx = 1.6 * np.exp(-t * 7)
    x = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * 2.0 * t))
    return x * np.exp(-t * 2.6) * adsr(len(t), 0.002, 0.05, 1.0, 0.05) * 0.6

def pluck(m, d):
    """the arpeggio: a short square pluck"""
    t = t_ax(d); f = mtof(m)
    x = np.sign(np.sin(2 * np.pi * f * t)) * 0.4 + saw_ph(f * t * 1.002) * 0.4
    return lp(x, 3000) * np.exp(-t * 14)

def brass(notes, d):
    """a brassy stab: saws with a fast filter swell and fall"""
    n = len(t_ax(d))
    x = np.zeros(n)
    for m in notes:
        x += saw_ph(phase(mtof(m), d)) + saw_ph(phase(mtof(m) * 1.008, d) + 0.5)
    x /= 2 * len(notes)
    return soft(sweep_filter(x, 900, 3800, 10.0) * adsr(n, 0.01, 0.12, 0.5, 0.06) * 1.6, 1.3)

def sub(m, d):
    t = t_ax(d)
    return np.sin(2 * np.pi * mtof(m) * t) * adsr(len(t), 0.02, 0.1, 0.9, 0.1)

# ------------------------------------------------------------------ mixing
class Bus:
    def __init__(self, n):
        self.n = n
        self.L = np.zeros(n)
        self.R = np.zeros(n)
    def add(self, x, at, g=1.0, pan=0.0):
        x = np.array(x, dtype=np.float64)
        f = min(len(x) // 2, int(0.004 * SR))
        if f > 1:
            ramp = np.linspace(0.0, 1.0, f)
            x[:f] *= ramp
            x[-f:] *= ramp[::-1]
        s = int(round(at * SR)) % self.n
        l = np.cos((pan + 1) * np.pi / 4) * 1.414 * g
        r = np.sin((pan + 1) * np.pi / 4) * 1.414 * g
        e = min(self.n, s + len(x))
        self.L[s:e] += x[:e - s] * l
        self.R[s:e] += x[:e - s] * r
        rest = x[e - s:]
        if len(rest):   # the tail wraps round: the loop is seamless
            m = min(len(rest), self.n)
            self.L[:m] += rest[:m] * l
            self.R[:m] += rest[:m] * r
    def pump(self, kicks, depth, beat):
        g = np.ones(self.n)
        rel = int(beat * 0.7 * SR)
        shape = 1 - depth * np.exp(-np.linspace(0, 5, rel))
        for at in kicks:
            s = int(at * SR) % self.n
            e = min(self.n, s + rel)
            g[s:e] = np.minimum(g[s:e], shape[:e - s])
        self.L *= g
        self.R *= g
    def delay(self, secs, fb=0.3, mix=0.25):
        d = int(secs * SR)
        L0, R0 = self.L.copy(), self.R.copy()
        wl, wr = np.zeros(self.n), np.zeros(self.n)
        yl, yr = R0.copy(), L0.copy()      # ping-pong
        for k in range(4):
            yl = np.roll(yl, d) * fb
            yr = np.roll(yr, d) * fb
            wl += yl if k % 2 == 0 else yr
            wr += yr if k % 2 == 0 else yl
        self.L += lp(wl, 5000) * mix
        self.R += lp(wr, 5000) * mix

def master(L, R, peak):
    x = np.stack([hp(L, 30), hp(R, 30)], axis=1)
    x = x / (np.max(np.abs(x)) + 1e-9)
    knee = 0.8
    a = np.abs(x)
    over = a > knee
    x[over] = np.sign(x[over]) * (knee + (1 - knee) * np.tanh((a[over] - knee) / (1 - knee)))
    return x / (np.max(np.abs(x)) + 1e-9) * peak

def write_ogg(name, x, q=5):
    tmp = os.path.join(MUS, name + ".tmp.wav")
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-ar", "44100", "-c:a", "libvorbis", "-q:a", str(q), os.path.join(MUS, name + ".ogg")], check=True)
    os.remove(tmp)
    print("music", name, f"{len(x) / SR:.1f}s")

# ------------------------------------------------------------------ harmony
def triad(root, kind):
    third = 4 if kind == "M" else 3
    fifth = 6 if kind == "d" else 7
    return [root, root + third, root + fifth]

# ------------------------------------------------------------------ the song
# Form (bars): intro 4 · verse 8 · pre 4 · chorus 8 · verse 8 · pre 4 ·
# chorus 8 · bridge 8 · chorus (big) 8 · turnaround 4  = 64 bars
FORM = [("intro", 4), ("verse", 8), ("pre", 4), ("chorus", 8), ("verse", 8), ("pre", 4),
        ("chorus", 8), ("bridge", 8), ("chorus2", 8), ("turn", 4)]

def song(name, bpm, prog, verse, chorus, bridge, pre=None, bass_style="octaves", kit="four", feel=1.0):
    """prog: {section: [(root, kind), ...] one per bar, looped over the
    section}. verse: [phrase_a, phrase_b, phrase_a, phrase_b_end], each
    2 bars of (step16 0..31, midi, len16). chorus: [first 4 bars, second
    4 bars] of (step16 0..63, midi, len16). bridge: 8 bars (0..127)."""
    beat = 60.0 / bpm
    st = beat / 4
    B = beat * 4
    bars = sum(n for _, n in FORM)
    N = int(round(B * bars * SR))
    stems = {k: Bus(N) for k in ("explore", "combat", "combo", "danger")}
    ex, cb, co, dg = stems["explore"], stems["combat"], stems["combo"], stems["danger"]
    kicks = []
    K, S, C = kick(), snare(), clap()
    HC, HO = hat(), hat(True)
    bar = 0
    prev_note = [None]

    def melody(bus, notes, t0, g, pan=0.0, octave=0, synth="lead"):
        for (s, m, l) in notes:
            mm = m + 12 * octave
            d = st * l * 0.94
            if synth == "lead":
                bus.add(lead(mm, d, prev_note[0]), t0 + s * st, g, pan)
                prev_note[0] = mm
            elif synth == "bell":
                bus.add(bell(mm, max(d, st * 3)), t0 + s * st, g, pan)
            elif synth == "grit":
                bus.add(soft(lead(mm, d, None, 5200) * 2.0, 2.0), t0 + s * st, g, pan)

    for sec, nb in FORM:
        chords = prog[sec if sec in prog else ("chorus" if sec == "chorus2" else "verse")]
        for i in range(nb):
            t0 = bar * B
            root, kind = chords[i % len(chords)]
            ch = triad(root + 12, kind)
            br = root       # the bass lives in A1..G#2
            while br > 44:
                br -= 12
            while br < 33:
                br += 12
            # ---------------- explore: the song itself
            # bass
            for s16 in range(16):
                at = t0 + s16 * st
                if sec == "intro" and i < 2:
                    if s16 == 0:
                        ex.add(bass(br, B * 0.9, 700, 3.0), at, 0.45)
                    continue
                if bass_style == "octaves" and s16 % 2 == 0:
                    m = br + (12 if s16 % 4 == 2 else 0)
                    ex.add(bass(m, st * 1.7), at, 0.5)
                elif bass_style == "gallop" and s16 % 4 in (0, 2, 3):
                    ex.add(bass(br + (12 if s16 % 8 == 6 else 0), st * 0.95, 2200, 22.0), at, 0.5)
                elif bass_style == "funk":
                    pat = {0: 0, 3: 12, 4: 0, 6: 10, 7: 12, 10: 0, 11: 7, 12: 12, 14: 10}
                    if s16 in pat:
                        ex.add(bass(br + pat[s16], st * (1.6 if s16 in (0, 4, 12) else 0.9), 2600, 24.0), at, 0.5)
                elif bass_style == "pulse" and s16 % 2 == 0:
                    ex.add(bass(br, st * 1.8, 1200, 10.0), at, 0.48)
            # pads: every bar, softer in verses, open in choruses
            ex.add(pad(ch, B * 1.02, 3200 if "chorus" in sec else 2000), t0, 0.16 if "chorus" in sec else 0.12)
            # light beat: kick on 1 and 3 (four in the chorus), closed hats
            if sec != "intro" or i >= 2:
                for b4 in range(4):
                    if b4 in (0, 2) or ("chorus" in sec and kit == "four"):
                        ex.add(K, t0 + b4 * beat, 0.55)
                        kicks.append(t0 + b4 * beat)
                for s16 in range(0, 16, 2):
                    sw = st * 0.1 * feel if s16 % 4 == 2 else 0.0
                    ex.add(HC, t0 + s16 * st + sw, 0.1 if s16 % 4 else 0.14, 0.25)
            # the tune
            if sec == "verse":
                ph = verse[(i // 2) % 4]
                part = [(s - (i % 2) * 16, m, l) for (s, m, l) in ph if (i % 2) * 16 <= s < (i % 2) * 16 + 16]
                melody(ex, part, t0, 0.3, 0.05)
            elif sec in ("chorus", "chorus2"):
                half = chorus[(i // 4) % 2]
                off = (i % 4) * 16
                part = [(s - off, m, l) for (s, m, l) in half if off <= s < off + 16]
                melody(ex, part, t0, 0.34, 0.0)
            elif sec == "bridge":
                off = i * 16
                part = [(s - off, m, l) for (s, m, l) in bridge if off <= s < off + 16]
                melody(ex, part, t0, 0.28, 0.0)
            elif sec == "pre" and pre:
                off = (i % 4) * 16
                part = [(s - off, m, l) for (s, m, l) in pre if off <= s < off + 16]
                melody(ex, part, t0, 0.26, 0.1)
            elif sec == "intro" and i >= 2:
                # the chorus hook's first bar, as a tease on the bell
                part = [(s, m, l) for (s, m, l) in chorus[0] if s < 16] if i == 3 else []
                melody(ex, part, t0, 0.22, 0.0, 0, "bell")
            # ---------------- combat: the full kit, fills, stabs, arps
            if sec != "intro":
                for b4 in range(4):
                    at = t0 + b4 * beat
                    if b4 in (1, 3):
                        cb.add(S, at, 0.5)
                        cb.add(C, at, 0.22, 0.2)
                    if kit == "four" and b4 in (1, 3):
                        cb.add(K, at, 0.5)
                        kicks.append(at)
                    if kit == "half" and b4 == 2:
                        cb.add(S, at, 0.25)
                    cb.add(HO, at + beat * 0.5, 0.1, -0.3)
                for s16 in range(1, 16, 2):
                    cb.add(HC, t0 + s16 * st + st * 0.1 * feel, 0.07, -0.25)
                if i == nb - 1:
                    # the fill into the next section
                    for k, m in enumerate((52, 50, 47, 45, 43, 40)):
                        cb.add(tom(m), t0 + (10 + k) * st, 0.34, -0.5 + k * 0.2)
                if i == 0 and sec in ("verse", "chorus", "chorus2", "bridge"):
                    cb.add(crash(), t0, 0.35)
                # brass stabs on the offbeats in choruses, arps elsewhere
                if "chorus" in sec:
                    for s16 in (0, 6, 10):
                        cb.add(brass(ch, st * 2), t0 + s16 * st, 0.16, -0.15)
                arp = [ch[0], ch[1], ch[2], ch[0] + 12, ch[2], ch[1]]
                for s16 in range(16):
                    cb.add(pluck(arp[s16 % 6] + 12, st * 0.9), t0 + s16 * st, 0.05, 0.5 if s16 % 2 else -0.5)
            # ---------------- combo: the bell doubling the tune, a counter-line
            if sec in ("chorus", "chorus2"):
                half = chorus[(i // 4) % 2]
                off = (i % 4) * 16
                part = [(s - off, m, l) for (s, m, l) in half if off <= s < off + 16]
                melody(co, part, t0, 0.2, -0.3, 0, "bell")
                # counter-line: long chord tones above the tune
                co.add(lead(ch[2] + 12, B * 0.95, None, 3000), t0, 0.08, 0.45)
            elif sec == "verse":
                for s16 in (0, 8):
                    co.add(bell(ch[(s16 // 8) + 1], st * 6), t0 + s16 * st, 0.12, 0.4 if s16 else -0.4)
            elif sec == "bridge":
                co.add(pad([ch[0] + 12, ch[2] + 12], B * 1.02, 4200), t0, 0.12)
            # ---------------- danger: the tune an octave up with bite, toms, sub, risers
            if sec in ("chorus", "chorus2", "bridge"):
                src = chorus[(i // 4) % 2] if sec != "bridge" else bridge
                off = ((i % 4) * 16) if sec != "bridge" else i * 16
                part = [(s - off, m, l) for (s, m, l) in src if off <= s < off + 16]
                melody(dg, part, t0, 0.1, 0.35, 1, "grit")
            dg.add(sub(br - 12, B * 0.98), t0, 0.3)
            if i == nb - 2:
                dg.add(riser(B * 2), t0, 0.4)
            for b4 in range(4):
                dg.add(tom(40 + (root % 12), 0.2), t0 + (b4 + 0.75) * beat, 0.12, 0.3 if b4 % 2 else -0.3)
            bar += 1
    # glue: the song breathes with the kick
    ex.pump(kicks, 0.3, beat)
    co.pump(kicks, 0.25, beat)
    dg.pump(kicks, 0.35, beat)
    ex.delay(beat * 0.75, 0.28, 0.14)
    co.delay(beat * 0.75, 0.32, 0.25)
    peaks = {"explore": 0.8, "combat": 0.72, "combo": 0.55, "danger": 0.5}
    wets = {"explore": 0.26, "combat": 0.12, "combo": 0.32, "danger": 0.2}
    out = {}
    for k, bus in stems.items():
        L, R = space(bus.L, bus.R, wets[k], 2.4)
        out[k] = master(L, R, peaks[k])
    # the game plays the layers on top of each other: all four together
    # must never pass full scale (that was the in-game crackle)
    full = sum(out.values())
    top = np.max(np.abs(full))
    k_all = min(1.0, 0.92 / top)
    for k, x in out.items():
        write_ogg(f"{name}_{k}", x * k_all)

# ------------------------------------------------------------------ the songs
A = 57; B_ = 59; C_ = 48; D = 50; E = 52; F = 53; G = 55
SONGS = {
    # Checkout Time - A minor, 112: neon on wet asphalt, a tune for driving
    # past the motel at 3 AM
    "level_checkout": dict(bpm=112, bass_style="octaves", kit="four", feel=0.6,
        prog={"intro": [(45, "m"), (41, "M"), (48, "M"), (43, "M")],
              "verse": [(45, "m"), (41, "M"), (48, "M"), (43, "M")],
              "pre": [(38, "m"), (40, "m"), (41, "M"), (40, "M")],
              "chorus": [(41, "M"), (43, "M"), (40, "m"), (45, "m"), (41, "M"), (43, "M"), (48, "M"), (40, "M")],
              "bridge": [(38, "m"), (45, "m"), (38, "m"), (40, "M")],
              "turn": [(45, "m"), (41, "M"), (43, "M"), (40, "M")]},
        verse=[[(0, 76, 3), (3, 74, 1), (4, 72, 2), (6, 74, 2), (8, 76, 4), (12, 69, 4), (16, 72, 3), (19, 71, 1), (20, 69, 2), (22, 71, 2), (24, 72, 6), (30, 74, 2)],
               [(0, 76, 3), (3, 74, 1), (4, 72, 2), (6, 74, 2), (8, 79, 4), (12, 76, 4), (16, 74, 3), (19, 72, 1), (20, 71, 2), (22, 72, 2), (24, 74, 8)],
               [(0, 76, 3), (3, 74, 1), (4, 72, 2), (6, 74, 2), (8, 76, 4), (12, 69, 4), (16, 72, 3), (19, 71, 1), (20, 69, 2), (22, 71, 2), (24, 72, 6), (30, 74, 2)],
               [(0, 76, 3), (3, 74, 1), (4, 72, 2), (6, 74, 2), (8, 79, 4), (12, 76, 4), (16, 74, 3), (19, 72, 1), (20, 71, 2), (22, 74, 2), (24, 69, 8)]],
        pre=[(0, 74, 4), (4, 77, 4), (8, 76, 4), (12, 72, 4), (16, 76, 4), (20, 79, 4), (24, 77, 4), (28, 76, 4),
             (32, 77, 4), (36, 81, 4), (40, 79, 4), (44, 77, 4), (48, 76, 8), (56, 80, 8)],
        chorus=[[(0, 81, 2), (2, 81, 2), (4, 79, 2), (6, 81, 2), (8, 84, 4), (12, 81, 4), (16, 79, 2), (18, 79, 2), (20, 77, 2), (22, 79, 2), (24, 83, 4), (28, 79, 4),
                 (32, 79, 2), (34, 79, 2), (36, 77, 2), (38, 76, 2), (40, 74, 4), (44, 76, 4), (48, 72, 6), (54, 71, 2), (56, 69, 8)],
                [(0, 81, 2), (2, 81, 2), (4, 79, 2), (6, 81, 2), (8, 84, 4), (12, 81, 4), (16, 79, 2), (18, 79, 2), (20, 77, 2), (22, 79, 2), (24, 83, 4), (28, 79, 4),
                 (32, 79, 2), (34, 79, 2), (36, 77, 2), (38, 79, 2), (40, 84, 4), (44, 83, 4), (48, 76, 4), (52, 80, 4), (56, 83, 8)]],
        bridge=[(0, 74, 8), (8, 77, 8), (16, 76, 12), (28, 72, 4), (32, 74, 8), (40, 77, 4), (44, 81, 4), (48, 80, 16),
                (64, 74, 6), (70, 72, 2), (72, 74, 8), (80, 72, 4), (84, 76, 4), (88, 81, 8), (96, 77, 8), (104, 76, 4), (108, 74, 4), (112, 76, 8), (120, 80, 8)]),
    # Dog Days - E minor, 126: heat haze over the salvage yard, a galloping
    # bass and a tune that sounds like somebody winning
    "level_yard": dict(bpm=126, bass_style="gallop", kit="four", feel=0.3,
        prog={"intro": [(40, "m"), (36, "M"), (38, "M"), (40, "m")],
              "verse": [(40, "m"), (36, "M"), (38, "M"), (40, "m"), (40, "m"), (36, "M"), (38, "M"), (47, "M")],
              "pre": [(45, "m"), (43, "M"), (45, "m"), (47, "M")],
              "chorus": [(36, "M"), (38, "M"), (40, "m"), (40, "m"), (36, "M"), (38, "M"), (47, "M"), (47, "M")],
              "bridge": [(45, "m"), (40, "m"), (45, "m"), (47, "M")],
              "turn": [(40, "m"), (36, "M"), (38, "M"), (47, "M")]},
        verse=[[(0, 71, 2), (2, 74, 2), (4, 76, 4), (8, 74, 2), (10, 76, 2), (12, 79, 4), (16, 76, 2), (18, 74, 2), (20, 72, 4), (24, 71, 6), (30, 67, 2)],
               [(0, 69, 2), (2, 71, 2), (4, 74, 4), (8, 78, 2), (10, 76, 2), (12, 74, 4), (16, 76, 8), (24, 71, 8)],
               [(0, 71, 2), (2, 74, 2), (4, 76, 4), (8, 74, 2), (10, 76, 2), (12, 79, 4), (16, 76, 2), (18, 74, 2), (20, 72, 4), (24, 71, 6), (30, 67, 2)],
               [(0, 69, 2), (2, 71, 2), (4, 74, 4), (8, 78, 2), (10, 76, 2), (12, 74, 4), (16, 75, 8), (24, 71, 8)]],
        pre=[(0, 72, 2), (2, 76, 2), (4, 79, 4), (8, 76, 4), (12, 72, 4), (16, 71, 2), (18, 74, 2), (20, 79, 4), (24, 78, 8),
             (32, 72, 2), (34, 76, 2), (36, 79, 4), (40, 81, 4), (44, 79, 4), (48, 78, 8), (56, 75, 8)],
        chorus=[[(0, 79, 4), (4, 76, 2), (6, 79, 2), (8, 84, 6), (14, 83, 2), (16, 81, 4), (20, 78, 2), (22, 81, 2), (24, 86, 6), (30, 84, 2),
                 (32, 83, 6), (38, 81, 2), (40, 79, 4), (44, 78, 4), (48, 76, 12), (60, 78, 4)],
                [(0, 79, 4), (4, 76, 2), (6, 79, 2), (8, 84, 6), (14, 83, 2), (16, 81, 4), (20, 78, 2), (22, 81, 2), (24, 86, 6), (30, 84, 2),
                 (32, 83, 6), (38, 81, 2), (40, 78, 4), (44, 75, 4), (48, 78, 12), (60, 71, 4)]],
        bridge=[(0, 72, 6), (6, 71, 2), (8, 69, 8), (16, 67, 6), (22, 69, 2), (24, 71, 8), (32, 72, 6), (38, 74, 2), (40, 76, 8), (48, 75, 16),
                (64, 76, 6), (70, 74, 2), (72, 72, 8), (80, 71, 6), (86, 72, 2), (88, 74, 8), (96, 76, 4), (100, 79, 4), (104, 81, 8), (112, 78, 8), (120, 75, 8)]),
    # Prime Time - F# minor into A major, 128: the game show at midnight -
    # funky bass, brass hits, a chorus that grins too wide
    "level_primetime": dict(bpm=128, bass_style="funk", kit="four", feel=0.8,
        prog={"intro": [(42, "m"), (38, "M"), (45, "M"), (40, "M")],
              "verse": [(42, "m"), (38, "M"), (45, "M"), (40, "M"), (42, "m"), (38, "M"), (47, "m"), (49, "M")],
              "pre": [(47, "m"), (49, "m"), (38, "M"), (40, "M")],
              "chorus": [(38, "M"), (40, "M"), (49, "m"), (42, "m"), (38, "M"), (40, "M"), (45, "M"), (45, "M")],
              "bridge": [(47, "m"), (49, "m"), (38, "M"), (40, "M")],
              "turn": [(42, "m"), (38, "M"), (40, "M"), (49, "M")]},
        verse=[[(0, 73, 1), (2, 76, 1), (4, 78, 2), (6, 76, 2), (8, 78, 2), (10, 81, 4), (14, 78, 2), (16, 78, 2), (18, 74, 2), (20, 76, 2), (22, 78, 2), (24, 81, 4), (28, 78, 4)],
               [(0, 76, 2), (2, 73, 2), (4, 76, 2), (6, 81, 2), (8, 80, 4), (12, 76, 4), (16, 71, 2), (18, 73, 2), (20, 76, 2), (22, 80, 2), (24, 83, 8)],
               [(0, 73, 1), (2, 76, 1), (4, 78, 2), (6, 76, 2), (8, 78, 2), (10, 81, 4), (14, 78, 2), (16, 78, 2), (18, 74, 2), (20, 76, 2), (22, 78, 2), (24, 81, 4), (28, 78, 4)],
               [(0, 74, 2), (2, 78, 2), (4, 81, 2), (6, 78, 2), (8, 74, 4), (12, 78, 4), (16, 77, 2), (18, 80, 2), (20, 85, 4), (24, 80, 8)]],
        pre=[(0, 74, 2), (2, 78, 2), (4, 83, 4), (8, 81, 4), (12, 78, 4), (16, 76, 2), (18, 80, 2), (20, 85, 4), (24, 83, 8),
             (32, 81, 2), (34, 78, 2), (36, 81, 4), (40, 86, 8), (48, 83, 4), (52, 85, 4), (56, 88, 8)],
        chorus=[[(0, 81, 2), (2, 81, 1), (3, 83, 1), (4, 85, 4), (8, 81, 2), (10, 78, 2), (12, 81, 4), (16, 83, 2), (18, 83, 1), (19, 85, 1), (20, 86, 4), (24, 83, 2), (26, 80, 2), (28, 83, 4),
                 (32, 85, 3), (35, 83, 1), (36, 80, 4), (40, 76, 4), (44, 80, 4), (48, 78, 12), (60, 73, 4)],
                [(0, 81, 2), (2, 81, 1), (3, 83, 1), (4, 85, 4), (8, 81, 2), (10, 78, 2), (12, 81, 4), (16, 83, 2), (18, 83, 1), (19, 85, 1), (20, 86, 4), (24, 83, 2), (26, 80, 2), (28, 83, 4),
                 (32, 85, 3), (35, 83, 1), (36, 81, 4), (40, 80, 2), (42, 81, 2), (44, 85, 4), (48, 81, 16)]],
        bridge=[(0, 74, 4), (4, 78, 4), (8, 83, 8), (16, 76, 4), (20, 80, 4), (24, 85, 8), (32, 78, 4), (36, 81, 4), (40, 86, 8), (48, 83, 8), (56, 80, 8),
                (64, 83, 4), (68, 81, 4), (72, 78, 8), (80, 80, 4), (84, 83, 4), (88, 85, 8), (96, 86, 6), (102, 85, 2), (104, 83, 8), (112, 80, 8), (120, 85, 8)]),
    # Sweet Dreams - D minor, 100, half-time: a music-box lullaby played on
    # a synth in an empty ballroom; pretty, and wrong
    "level_nightmare": dict(bpm=100, bass_style="pulse", kit="half", feel=0.0,
        prog={"intro": [(38, "m"), (46, "M"), (41, "M"), (48, "M")],
              "verse": [(38, "m"), (46, "M"), (41, "M"), (48, "M"), (38, "m"), (46, "M"), (43, "m"), (45, "M")],
              "pre": [(43, "m"), (45, "M"), (43, "m"), (45, "M")],
              "chorus": [(46, "M"), (48, "M"), (38, "m"), (38, "m"), (43, "m"), (45, "M"), (38, "m"), (38, "m")],
              "bridge": [(43, "m"), (38, "m"), (39, "M"), (45, "M")],
              "turn": [(38, "m"), (46, "M"), (43, "m"), (45, "M")]},
        verse=[[(0, 81, 4), (4, 77, 4), (8, 76, 2), (10, 77, 2), (12, 74, 4), (16, 74, 4), (20, 77, 4), (24, 72, 8)],
               [(0, 72, 4), (4, 77, 4), (8, 81, 4), (12, 79, 4), (16, 76, 6), (22, 74, 2), (24, 72, 8)],
               [(0, 81, 4), (4, 77, 4), (8, 76, 2), (10, 77, 2), (12, 74, 4), (16, 74, 4), (20, 77, 4), (24, 72, 8)],
               [(0, 70, 4), (4, 74, 4), (8, 79, 4), (12, 77, 4), (16, 76, 6), (22, 73, 2), (24, 76, 8)]],
        pre=[(0, 79, 6), (6, 77, 2), (8, 74, 8), (16, 76, 6), (22, 73, 2), (24, 69, 8), (32, 79, 6), (38, 81, 2), (40, 82, 8), (48, 81, 8), (56, 76, 8)],
        chorus=[[(0, 77, 6), (6, 79, 2), (8, 81, 8), (16, 79, 6), (22, 77, 2), (24, 76, 8), (32, 74, 4), (36, 77, 4), (40, 81, 4), (44, 84, 4), (48, 82, 8), (56, 81, 8)],
                [(0, 79, 6), (6, 77, 2), (8, 74, 8), (16, 76, 6), (22, 77, 2), (24, 79, 8), (32, 77, 4), (36, 76, 4), (40, 74, 8), (48, 74, 16)]],
        bridge=[(0, 82, 8), (8, 81, 8), (16, 79, 8), (24, 77, 8), (32, 79, 6), (38, 77, 2), (40, 75, 8), (48, 73, 16),
                (64, 74, 8), (72, 77, 8), (80, 81, 8), (88, 79, 8), (96, 79, 6), (102, 77, 2), (104, 75, 8), (112, 76, 16)]),
}

if __name__ == "__main__":
    want = sys.argv[1:] or list(SONGS)
    for k in want:
        song(k, **SONGS[k])
