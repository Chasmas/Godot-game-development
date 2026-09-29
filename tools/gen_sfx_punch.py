#!/usr/bin/env python3
"""
HOTSHOT CALIFORNIA - combat sound pass: every gun, blow, body and gadget
rebuilt in layers so they hit like they mean it.

  gun  = click (hammer/bolt) + transient crack + low body thump with a pitch
         drop + mechanical rattle + a short room tail, glued with saturation
  blow = cloth whoosh into a fleshy thud, knuckle/bone snap on top
  mech = metal parts: mag slides, springs, brass that rings as it bounces

Writes assets/audio/sfx/<name>.wav (mono, 44.1 kHz, 16-bit), same names the
game already plays.   python tools/gen_sfx_punch.py [name ...]
"""
import os, sys, wave
import numpy as np
from scipy.signal import butter, lfilter

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio", "sfx")
rng = np.random.default_rng(88)

def T(d): return np.arange(int(d * SR)) / SR
def N(d): return rng.uniform(-1, 1, int(d * SR))
def lp(x, f, o=2):
    b, a = butter(o, min(f, SR * 0.45) / (SR / 2), "low"); return lfilter(b, a, x)
def hp(x, f, o=2):
    b, a = butter(o, f / (SR / 2), "high"); return lfilter(b, a, x)
def bp(x, lo, hi, o=2):
    b, a = butter(o, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band"); return lfilter(b, a, x)
def sat(x, d=2.0): return np.tanh(x * d) / np.tanh(d)
def pad(x, n):
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])[:n] if len(x) < n else x
def mix(*parts):
    n = max(len(p[1]) + int(p[0] * SR) for p in parts)
    y = np.zeros(n)
    for at, x, g in parts:
        s = int(at * SR)
        y[s:s + len(x)] += x * g
    return y
def sweep(f0, f1, d, rate):
    t = T(d)
    f = f1 + (f0 - f1) * np.exp(-t * rate)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)
def room(x, size=0.35, damp=3500, wet=0.3):
    """short convolution tail from decaying filtered noise"""
    ir = lp(N(size), damp) * np.exp(-T(size) * (7.0 / size))
    ir[0] = 1.0 / wet
    y = np.convolve(x, ir)[: len(x) + len(ir) - 1] * wet
    return y
def fade(x, ms=6):
    n = int(SR * ms / 1000)
    if n and len(x) > n:
        x[-n:] *= np.linspace(1, 0, n)
    return x
def write(name, x, peak=0.95):
    x = np.asarray(x, dtype=float)
    if name not in ("tv_hum", "siren_loop", "room_tone", "car_idle"):   # loops keep their seam
        x = fade(x)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print("sfx", name, f"{len(x) / SR:.2f}s")

# ------------------------------------------------------------------ layers
def click(d=0.012, f=5200):
    return bp(N(d), f * 0.6, f * 1.6) * np.exp(-T(d) * 500)
def crack(d, lo, hi, decay):
    return bp(N(d), lo, hi) * np.exp(-T(d) * decay)
def thump(d, f0, f1, rate, decay):
    return sweep(f0, f1, d, rate) * np.exp(-T(d) * decay)
def rattle(d, f=2600, n=3, gap=0.018):
    y = np.zeros(int(d * SR))
    for i in range(n):
        c = click(0.02, f * (1 + 0.15 * rng.standard_normal()))
        s = int((0.004 + i * gap * (0.8 + 0.4 * rng.random())) * SR)
        y[s:s + len(c)] += c[: len(y) - s] * (0.7 ** i)
    return y
def ring(f, d, decay, partials=(1, 2.76, 5.4)):
    t = T(d)
    return sum(np.sin(2 * np.pi * f * p * t) / (1 + i) for i, p in enumerate(partials)) * np.exp(-t * decay)

def gun(body_f=(160, 55), body_d=0.35, crack_band=(900, 9000), crack_decay=38, mech=0.25, tail=0.45, drive=3.0, sub=0.8):
    x = mix((0.0, click(), 0.6),
            (0.001, crack(0.25, *crack_band, crack_decay), 1.0),
            (0.0, thump(body_d, body_f[0] * 2.2, body_f[1], 40, 9), sub),
            (0.0, lp(N(0.12), 600) * np.exp(-T(0.12) * 30), 0.6),
            (0.03, rattle(0.12), mech))
    x = sat(x * 1.2, drive)
    return room(x, tail, 3000, 0.35)

# ------------------------------------------------------------------ the sounds
def make():
    S = {}
    S["pistol"] = gun((170, 60), 0.3, (1100, 9500), 42, 0.25, 0.45)
    S["suppressed"] = room(sat(mix((0, click(0.01, 3000), 0.8), (0, crack(0.12, 300, 2200, 45), 1.0),
                                    (0, thump(0.15, 220, 90, 60, 22), 0.5), (0.025, rattle(0.1, 3000, 2), 0.45)), 1.5), 0.2, 2000, 0.2)
    S["revolver"] = gun((130, 45), 0.5, (800, 8000), 26, 0.12, 0.8, 3.6, 1.0)
    S["rifle"] = gun((180, 50), 0.35, (1400, 11000), 34, 0.3, 0.6, 3.4)
    S["smg"] = gun((210, 80), 0.18, (1500, 9000), 60, 0.2, 0.3, 2.6, 0.6)
    S["shotgun"] = gun((110, 38), 0.6, (500, 7500), 18, 0.0, 0.9, 4.0, 1.2)
    S["sniper"] = gun((120, 35), 0.7, (1600, 12000), 20, 0.1, 1.2, 4.2, 1.1)
    # mechanics
    S["empty"] = mix((0, click(0.015, 3800), 1.0), (0.005, ring(3200, 0.05, 90), 0.2))
    S["mag_out"] = mix((0, click(0.02, 2400), 0.8), (0.01, bp(N(0.14), 1500, 6000) * np.exp(-T(0.14) * 25), 0.5), (0.05, ring(1900, 0.1, 50), 0.15))
    S["mag_in"] = sat(mix((0, bp(N(0.05), 800, 5000) * np.exp(-T(0.05) * 70), 0.9), (0.03, click(0.02, 1800), 1.0), (0.03, thump(0.06, 400, 180, 80, 60), 0.5)), 1.8)
    S["reload"] = mix((0, S["mag_out"], 0.8), (0.35, S["mag_in"], 1.0))
    S["slide_rack"] = sat(mix((0, bp(N(0.08), 1200, 7000) * np.exp(-T(0.08) * 35), 0.8), (0.07, click(0.02, 2600), 1.0),
                              (0.12, bp(N(0.06), 1500, 8000) * np.exp(-T(0.06) * 40), 0.7), (0.17, click(0.02, 3200), 1.2),
                              (0.17, thump(0.07, 500, 200, 80, 50), 0.4)), 1.8)
    S["shell_insert"] = mix((0, bp(N(0.05), 900, 5000) * np.exp(-T(0.05) * 60), 0.7), (0.035, click(0.02, 2000), 1.0), (0.035, thump(0.05, 300, 150, 90, 70), 0.4))
    shell = np.zeros(int(0.5 * SR))
    for i, (at, g) in enumerate([(0.0, 1.0), (0.11, 0.55), (0.19, 0.35), (0.25, 0.2)]):
        r = ring(4300 + 300 * i, 0.12, 45, (1, 2.3, 3.9)) * g
        s = int(at * SR)
        shell[s:s + len(r)] += r[: len(shell) - s]
    S["shell"] = shell
    # blows
    whoosh = lambda d, lo, hi: bp(N(d), lo, hi) * np.sin(np.linspace(0, np.pi, int(d * SR))) ** 2
    S["swing"] = whoosh(0.18, 500, 3500)
    S["swing_heavy"] = mix((0, whoosh(0.28, 250, 2200), 1.0), (0, lp(N(0.28), 300) * np.sin(np.linspace(0, np.pi, int(0.28 * SR))), 0.4))
    S["whoosh"] = whoosh(0.22, 700, 5000)
    flesh = lambda d=0.14: lp(N(d), 1200) * np.exp(-T(d) * 30)
    S["punch"] = sat(mix((0, whoosh(0.05, 800, 4000), 0.3), (0.04, thump(0.16, 260, 70, 40, 22), 1.0), (0.04, flesh(), 0.9),
                         (0.04, crack(0.03, 1500, 6000, 120), 0.6)), 2.4)
    S["hit_blunt"] = sat(mix((0, thump(0.25, 200, 50, 30, 14), 1.0), (0, flesh(0.2), 0.8), (0.0, crack(0.04, 800, 4000, 90), 0.7),
                             (0.01, crack(0.02, 2000, 7000, 200), 0.5)), 2.6)
    S["hit_blade"] = sat(mix((0, bp(N(0.12), 2500, 10000) * np.exp(-T(0.12) * 35), 0.6), (0.01, flesh(0.16), 1.0),
                             (0.01, lp(N(0.25), 800) * np.exp(-T(0.25) * 12) * (1 + 0.5 * np.sin(T(0.25) * 90)), 0.5)), 1.8)
    S["hit_flesh"] = sat(mix((0, flesh(0.18), 1.0), (0, thump(0.12, 180, 70, 40, 30), 0.6), (0.02, bp(N(0.2), 300, 1500) * np.exp(-T(0.2) * 16), 0.5)), 2.0)
    wet = lambda d: lp(N(d), 1800) * (np.abs(np.sin(T(d) * 70)) ** 3) * np.exp(-T(d) * 10)
    S["splat"] = sat(mix((0, flesh(0.1), 1.0), (0.02, wet(0.35), 0.8)), 2.0)
    S["gore"] = sat(mix((0, thump(0.2, 150, 50, 30, 18), 0.8), (0, flesh(0.25), 1.0), (0.03, wet(0.5), 0.9),
                        (0.05, crack(0.03, 1200, 5000, 150), 0.6), (0.12, crack(0.03, 1000, 4500, 150), 0.4)), 2.2)
    S["neck_snap"] = sat(mix((0, crack(0.03, 1200, 7000, 220), 1.0), (0.012, crack(0.03, 900, 5000, 200), 0.8), (0.0, thump(0.1, 200, 90, 60, 40), 0.5)), 2.5)
    S["execute"] = sat(mix((0, S["hit_blunt"], 0.9), (0.05, wet(0.4), 0.8), (0.03, S["neck_snap"], 0.6)), 1.6)
    S["body_fall"] = room(sat(mix((0, thump(0.3, 140, 45, 25, 12), 1.0), (0, lp(N(0.3), 700) * np.exp(-T(0.3) * 14), 0.8),
                                  (0.09, thump(0.2, 110, 50, 30, 18), 0.5), (0.09, lp(N(0.15), 900) * np.exp(-T(0.15) * 25), 0.4)), 2.0), 0.3, 1800, 0.2)
    # doors, glass, objects
    S["door_kick"] = room(sat(mix((0, thump(0.35, 170, 50, 25, 10), 1.0), (0, bp(N(0.3), 200, 3000) * np.exp(-T(0.3) * 14), 0.9),
                                  (0.005, crack(0.05, 1500, 6000, 80), 0.6), (0.06, rattle(0.2, 1800, 4, 0.03), 0.4)), 2.4), 0.5, 2500, 0.35)
    S["door_break"] = room(sat(mix((0, S["door_kick"], 0.8),
                                   *[(0.02 + 0.03 * i, crack(0.08, 600, 5000, 45), 0.6 - i * 0.08) for i in range(6)]), 2.0), 0.6, 2500, 0.4)
    gl = np.zeros(int(0.9 * SR))
    for i in range(26):
        r = ring(rng.uniform(2500, 7500), 0.2, rng.uniform(25, 60), (1, 2.1, 3.3)) * rng.uniform(0.2, 0.8)
        s = int(rng.uniform(0, 0.5) ** 1.8 * SR)
        gl[s:s + len(r)] += r[: len(gl) - s]
    S["glass"] = sat(mix((0, crack(0.12, 2000, 12000, 30), 1.2), (0, gl, 0.5), (0, thump(0.1, 250, 100, 60, 40), 0.4)), 1.6)
    S["bottle_break"] = sat(mix((0, crack(0.1, 1500, 10000, 40), 1.0), (0.005, gl[: int(0.6 * SR)], 0.6), (0.0, ring(900, 0.1, 40), 0.3)), 1.6)
    S["metal_clang"] = room(mix((0, ring(620, 1.2, 4.5, (1, 2.4, 3.9, 5.2)), 1.0), (0, click(0.02, 3000), 0.8)), 0.4, 5000, 0.3)
    S["ricochet"] = mix((0, click(0.01, 5000), 0.8), (0.005, np.sin(2 * np.pi * np.cumsum(np.linspace(4200, 1400, int(0.4 * SR))) / SR) * np.exp(-T(0.4) * 7), 0.45))
    # explosion: sub drop, crack, rolling rumble, debris rain
    deb = np.zeros(int(2.2 * SR))
    for i in range(40):
        c = click(0.03, rng.uniform(1500, 5000)) * rng.uniform(0.1, 0.5)
        s = int(rng.uniform(0.15, 1.8) * SR)
        deb[s:s + len(c)] += c[: len(deb) - s]
    S["explosion"] = sat(mix((0, thump(2.2, 90, 25, 6, 2.2), 1.3),
                             (0, crack(0.3, 300, 8000, 12), 1.2),
                             (0, lp(N(2.2), 400) * np.exp(-T(2.2) * 2.0), 1.0),
                             (0, deb, 0.5)), 3.0)
    S["throw"] = whoosh(0.2, 400, 3000)
    S["pickup"] = sat(mix((0, click(0.02, 2200), 1.0), (0.02, thump(0.06, 400, 200, 60, 50), 0.6), (0.05, rattle(0.08, 2600, 2), 0.5)), 1.6)
    S["dash"] = mix((0, whoosh(0.2, 300, 2500), 1.0), (0, lp(N(0.2), 200) * np.sin(np.linspace(0, np.pi, int(0.2 * SR))), 0.5))
    S["armor_break"] = room(sat(mix((0, S["metal_clang"][: int(0.6 * SR)], 0.8), (0, crack(0.1, 1500, 9000, 30), 1.0), (0, thump(0.2, 200, 70, 40, 18), 0.6)), 2.0), 0.3, 5000, 0.25)
    S.update(make_world(S))
    return S

def tone(f, d, decay=8.0, kind="sin"):
    t = T(d)
    ph = f * t
    x = np.sin(2 * np.pi * ph) if kind == "sin" else (2 * (ph % 1.0) - 1 if kind == "saw" else np.sign(np.sin(2 * np.pi * ph)))
    return x * np.exp(-t * decay)

def make_world(C):
    """UI, foley, gadgets and the tape/TV sounds the cutscenes use"""
    S = {}
    # UI: short, warm, a bit of analogue synth - never shrill
    S["ui_move"] = lp(tone(880, 0.06, 60, "sqr") * 0.5 + tone(1320, 0.06, 80), 3500)
    S["ui_select"] = sat(mix((0, lp(tone(660, 0.12, 25, "saw"), 2800), 0.8), (0.05, lp(tone(990, 0.16, 20, "saw"), 3000), 0.8), (0, click(0.01, 3000), 0.4)), 1.4)
    S["ui_back"] = mix((0, lp(tone(740, 0.08, 40, "saw"), 2500), 0.8), (0.05, lp(tone(494, 0.12, 30, "saw"), 2200), 0.8))
    S["blip"] = lp(tone(1560, 0.05, 70, "sqr"), 4000)
    S["collect"] = mix(*[(i * 0.05, lp(tone(f, 0.18, 18, "sqr"), 4500) * 0.6, 1.0) for i, f in enumerate((784, 988, 1175, 1568))])
    S["upgrade"] = room(mix(*[(i * 0.07, lp(tone(f, 0.4, 7, "saw") + tone(f * 1.005, 0.4, 7, "saw"), 3200) * 0.4, 1.0) for i, f in enumerate((523, 659, 784, 1047, 1319))]), 0.8, 4000, 0.4)
    S["combo"] = sat(mix((0, lp(tone(1175, 0.1, 30, "sqr"), 5000), 0.7), (0.04, lp(tone(1760, 0.14, 25, "sqr"), 5000), 0.7), (0, click(0.01, 4000), 0.5)), 1.3)
    S["rank_stamp"] = room(sat(mix((0, thump(0.35, 180, 45, 25, 10), 1.2), (0, crack(0.06, 500, 5000, 60), 1.0), (0, lp(N(0.3), 500) * np.exp(-T(0.3) * 12), 0.6)), 2.6), 0.6, 3000, 0.4)
    S["power_up"] = sat(lp(np.sin(2 * np.pi * np.cumsum(np.linspace(110, 880, int(0.6 * SR))) / SR) * np.linspace(0.3, 1, int(0.6 * SR)), 2500), 1.6)
    S["power_down"] = room(sat(mix((0, lp(np.sin(2 * np.pi * np.cumsum(np.linspace(520, 38, int(1.1 * SR))) / SR) * np.exp(-T(1.1) * 1.5), 1800), 1.0), (0, thump(0.3, 150, 40, 20, 10), 0.8)), 2.0), 0.5, 2000, 0.3)
    S["slowmo_in"] = room(lp(np.sin(2 * np.pi * np.cumsum(np.linspace(300, 60, int(0.7 * SR))) / SR) * np.exp(-T(0.7) * 3) + lp(N(0.7), 600) * np.exp(-T(0.7) * 4) * 0.5, 1500), 0.8, 1500, 0.5)
    S["slowmo_out"] = room(lp(np.sin(2 * np.pi * np.cumsum(np.linspace(60, 380, int(0.5 * SR))) / SR) * np.linspace(0.2, 1, int(0.5 * SR)) ** 2, 2500), 0.4, 2000, 0.3)
    S["heartbeat"] = mix((0, thump(0.18, 90, 40, 30, 20), 1.0), (0.22, thump(0.2, 80, 38, 30, 16), 0.8))
    S["beat_tick"] = mix((0, click(0.015, 2400), 1.0), (0, tone(1200, 0.04, 90), 0.4))
    # foley
    for i in range(3):
        S[f"step{i}"] = sat(mix((0, lp(N(0.07), 700 + 200 * i) * np.exp(-T(0.07) * 60), 1.0), (0.005, thump(0.06, 160 + 20 * i, 70, 80, 60), 0.6),
                                (0.02, bp(N(0.04), 1500, 5000) * np.exp(-T(0.04) * 90), 0.25)), 1.6)
    S["door_open"] = mix((0, click(0.02, 1600), 0.8), (0.03, bp(N(0.45), 400, 2500) * np.exp(-T(0.45) * 5) * (1 + 0.6 * np.sin(T(0.45) * 38)), 0.35),
                         (0.02, np.sin(2 * np.pi * np.cumsum(np.linspace(900, 700, int(0.35 * SR))) / SR) * np.exp(-T(0.35) * 6), 0.12))
    S["door_slam"] = room(sat(mix((0, thump(0.3, 160, 50, 30, 12), 1.0), (0, crack(0.06, 700, 5000, 60), 0.8), (0.02, rattle(0.15, 1500, 3, 0.04), 0.4)), 2.2), 0.6, 2500, 0.4)
    S["light_switch"] = mix((0, click(0.012, 2800), 1.0), (0.01, thump(0.03, 500, 300, 100, 120), 0.4))
    S["spark"] = mix(*[(rng.uniform(0, 0.25), crack(0.03, 3000, 12000, 150), rng.uniform(0.3, 1.0)) for _ in range(9)])
    S["buzz"] = lp(np.sign(np.sin(2 * np.pi * 120 * T(0.8))) * 0.4 + np.sin(2 * np.pi * 240 * T(0.8)) * 0.3, 1800) * (0.7 + 0.3 * np.sin(T(0.8) * 9))
    # "alarm" stays gen_audio.py's siren (the players liked it)
    S["alert"] = sat(mix((0, lp(tone(1320, 0.12, 20, "sqr"), 4000), 0.8), (0.07, lp(tone(1760, 0.2, 14, "sqr"), 4000), 0.8)), 1.3)
    S["camera_break"] = sat(mix((0, C["glass"][: int(0.5 * SR)], 0.7), (0, crack(0.1, 1500, 9000, 30), 0.8), (0.03, C["spark"] if "spark" in C else S["spark"], 0.5)), 1.6)
    S["tv_break"] = room(sat(mix((0, crack(0.15, 800, 10000, 20), 1.0), (0, thump(0.25, 150, 45, 25, 12), 0.8), (0.02, lp(N(0.6), 5000) * np.exp(-T(0.6) * 6), 0.4),
                                 (0.05, S["spark"], 0.5)), 2.0), 0.5, 3500, 0.35)
    S["car_pass"] = room(lp(N(3.0), 700) * np.exp(-((T(3.0) - 1.3) / 0.6) ** 2) + lp(np.sin(2 * np.pi * np.cumsum(np.linspace(95, 70, int(3 * SR))) / SR), 400) * np.exp(-((T(3.0) - 1.3) / 0.7) ** 2) * 0.4, 0.3, 1500, 0.2)
    # tape and TV (cutscenes)
    S["vhs_static"] = hp(N(0.6), 900) * (0.6 + 0.4 * (rng.random(int(0.6 * SR)) > 0.97)) * np.minimum(1, (0.6 - T(0.6)) * 8) * 0.6 + lp(np.sin(2 * np.pi * 59.94 * T(0.6)), 400) * 0.1
    S["tape_insert"] = sat(mix((0, bp(N(0.15), 400, 3000) * np.exp(-T(0.15) * 20), 0.7), (0.12, thump(0.1, 260, 100, 60, 40), 0.9), (0.12, click(0.02, 2000), 0.9),
                               (0.25, click(0.02, 1500), 0.6), (0.3, lp(N(0.4), 900) * np.linspace(0.2, 1, int(0.4 * SR)) * np.exp(-T(0.4) * 2), 0.3)), 1.6)
    rw = lp(N(1.2), 3500) * (0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(np.linspace(30, 90, int(1.2 * SR))) / SR)) * np.minimum(1, T(1.2) * 6) * np.minimum(1, (1.2 - T(1.2)) * 6) * 0.5
    S["tape_rewind"] = mix((0, rw, 1.0), (1.2, click(0.03, 1500), 1.0))
    S["rec_beep"] = mix((0, lp(tone(1900, 0.09, 8, "sqr"), 4000), 0.7), (0.14, lp(tone(1900, 0.09, 8, "sqr"), 4000), 0.7))
    S["type_clack"] = sat(mix((0, click(0.012, 2500), 1.0), (0.003, thump(0.03, 700, 400, 100, 120), 0.5)), 1.5)
    S["on_air_buzz"] = room(lp(np.sign(np.sin(2 * np.pi * 110 * T(0.7))) * 0.5 + (2 * ((T(0.7) * 220) % 1) - 1) * 0.3, 1400) * np.minimum(1, (0.7 - T(0.7)) * 10), 0.5, 2000, 0.3)
    S["intercom"] = room(bp(mix((0, tone(1000, 0.18, 4, "sqr"), 0.6), (0.2, tone(800, 0.3, 4, "sqr"), 0.6)), 500, 3000), 0.4, 3000, 0.4)
    # cutscene beds (looped by StoryShot) and the fireworks over Van Nuys
    S["tv_hum"] = loopify(lp(np.sin(2 * np.pi * 15734 / 4 * T(4.0)) * 0.05 + np.sin(2 * np.pi * 60 * T(4.0)) * 0.25 + np.sin(2 * np.pi * 120 * T(4.0)) * 0.12, 5000) + hp(N(4.0), 3000) * 0.04)
    wail = np.sin(2 * np.pi * np.cumsum(700 + 350 * np.sin(2 * np.pi * T(6.0) / 3.0)) / SR)
    S["siren_loop"] = loopify(room(lp(wail * 0.4, 1800), 0.8, 1500, 0.6)[: int(6.0 * SR)])
    S["room_tone"] = loopify(lp(N(5.0), 260) * 0.6 + np.sin(2 * np.pi * 50 * T(5.0)) * 0.05)
    S["firework_pop"] = room(mix((0, thump(0.5, 120, 40, 20, 8), 0.8), (0, crack(0.08, 300, 4000, 40), 1.0),
                                 *[(0.15 + rng.uniform(0, 0.5), crack(0.02, 2000, 8000, 180), rng.uniform(0.1, 0.35)) for _ in range(14)]), 1.2, 1200, 0.6)
    S["studio_chime"] = studio_chime()
    # the lobby doors going up: sub drop, a cracking front, the doors
    # splintering, glass raining for a second and a half, the lot echoing it back
    boom = mix((0, thump(3.0, 70, 22, 5, 1.6), 1.5), (0, crack(0.4, 250, 9000, 9), 1.4),
               (0.02, C["door_break"], 0.9), (0.1, C["glass"], 0.8), (0.35, C["glass"][: int(0.6 * SR)], 0.4),
               (0, lp(N(3.0), 350) * np.exp(-T(3.0) * 1.4), 1.0),
               (0.5, lp(crack(0.6, 200, 3000, 6), 1200), 0.35), (0.95, lp(crack(0.6, 200, 2400, 6), 1000), 0.2))
    deb = np.zeros(int(2.6 * SR))
    for i in range(70):
        c = click(0.03, rng.uniform(900, 4500)) * rng.uniform(0.1, 0.5)
        st = int(rng.uniform(0.2, 2.4) ** 1.3 * SR * 0.8)
        deb[st:st + len(c)] += c[: len(deb) - st]
    S["breach_boom"] = room(sat(mix((0, boom, 1.0), (0, deb, 0.6)), 3.2), 1.4, 2500, 0.35)
    # the Cadillac: a big V8 arriving, the door, the tyres leaving
    def v8(d, f0, f1, amp_in=0.3):
        t = T(d)
        f = f0 + (f1 - f0) * (t / d)
        ph = np.cumsum(f) / SR
        x = np.sign(np.sin(2 * np.pi * ph)) * 0.5 + np.sin(2 * np.pi * ph * 0.5) * 0.6 + lp(N(d), 300) * 0.4
        x *= 0.7 + 0.3 * np.sin(2 * np.pi * ph * 0.25)
        return lp(sat(x, 2.0), 900)
    arrive = v8(2.6, 60, 34) * np.minimum(1, T(2.6) / 1.2) * np.minimum(1, (2.6 - T(2.6)) / 0.4)
    squeal = bp(N(0.5), 1800, 3800) * np.sin(np.linspace(0, np.pi, int(0.5 * SR))) * 0.3
    S["car_arrive"] = room(mix((0, arrive, 1.0), (1.9, squeal, 0.6), (2.4, thump(0.2, 90, 40, 20, 12), 0.4)), 0.4, 1500, 0.2)
    S["car_door"] = room(sat(mix((0, click(0.02, 1400), 0.8), (0.02, thump(0.2, 160, 60, 30, 16), 1.0), (0.02, bp(N(0.1), 600, 3000) * np.exp(-T(0.1) * 30), 0.5), (0.05, rattle(0.1, 1600, 2, 0.03), 0.3)), 1.8), 0.3, 2000, 0.25)
    screech = bp(N(1.4), 1500, 4200) * (0.6 + 0.4 * np.sin(T(1.4) * 40)) * np.minimum(1, T(1.4) / 0.05) * np.exp(-T(1.4) * 1.2)
    idle = v8(3.0, 26, 26)
    S["car_idle"] = loopify(idle * 0.7)
    S["tire_skid"] = bp(N(0.6), 1400, 4200) * (0.6 + 0.4 * np.sin(T(0.6) * 55)) * np.sin(np.linspace(0, np.pi, int(0.6 * SR))) ** 0.5
    S["car_brake"] = mix((0, bp(N(0.45), 2200, 5200) * np.sin(np.linspace(0, np.pi, int(0.45 * SR))) * 0.6, 1.0), (0.3, thump(0.15, 120, 60, 30, 20), 0.4))
    S["car_peel"] = room(mix((0, v8(2.4, 40, 110) * np.minimum(1, T(2.4) / 0.15) * np.exp(-T(2.4) * 0.6), 1.0), (0.05, screech, 0.7)), 0.5, 1800, 0.25)
    # a VHS box slid off a video-store shelf: plastic scrape, a soft knock
    S["tape_slide"] = sat(mix((0, bp(N(0.14), 900, 6000) * np.sin(np.linspace(0, np.pi, int(0.14 * SR))) ** 2, 0.5),
                              (0.12, thump(0.06, 380, 180, 90, 60), 0.8), (0.12, click(0.015, 2200), 0.6)), 1.4)
    return S

def fm_bell(f, d, index=2.2, ratio=3.5, decay=2.2):
    t = T(d)
    mod = index * np.exp(-t * 3.0) * np.sin(2 * np.pi * f * ratio * t)
    return np.sin(2 * np.pi * f * t + mod) * np.exp(-t * decay) * np.minimum(1, t / 0.002)

def studio_chime():
    """INVERTED INDEX: three bell notes climb as the triangle's sides draw
    (0.0 / 0.3 / 0.6 s, the file starts with the first stroke), then the
    same motif turned upside down lands as one chord at 0.9 s over a warm
    sub - up, and back down again. Five seconds with its tail."""
    mt = lambda m: 440.0 * 2 ** ((m - 69) / 12.0)
    x = np.zeros(int(5.0 * SR))
    for i, m in enumerate((71, 76, 80)):                  # B4 E5 G#5, rising
        b = fm_bell(mt(m), 2.2, 1.8, 3.5, 2.6) * (0.5 + 0.1 * i)
        s = int(i * 0.3 * SR)
        x[s:s + len(b)] += b
    at = int(0.9 * SR)
    for m, g in ((88, 0.35), (83, 0.45), (76, 0.6), (64, 0.5)):   # the motif inverted: down from E6 to E4
        b = fm_bell(mt(m), 4.0, 1.4, 2.0, 1.1) * g
        x[at:at + len(b)] += b[: len(x) - at]
    pad = sum(np.sin(2 * np.pi * mt(m) * T(4.0)) for m in (52, 59, 64)) / 3
    pad *= np.minimum(1, T(4.0) / 0.05) * np.exp(-T(4.0) * 0.9)
    x[at:at + len(pad)] += lp(pad, 900) * 0.5
    sub = np.sin(2 * np.pi * mt(40) * T(3.0)) * np.exp(-T(3.0) * 1.3) * np.minimum(1, T(3.0) / 0.01)
    x[at:at + len(sub)] += sub * 0.6
    # a reversed shimmer swelling into the chord
    sw = hp(N(0.9), 5000) * np.linspace(0, 1, int(0.9 * SR)) ** 3 * 0.12
    x[:len(sw)] += sw
    return room(sat(x, 1.1), 1.8, 5000, 0.35)[: int(5.0 * SR)]

def loopify(x, xf=0.25):
    """crossfade the tail into the head so the bed loops without a seam"""
    n = int(xf * SR)
    y = x[:-n].copy()
    y[:n] = y[:n] * np.linspace(0, 1, n) + x[-n:] * np.linspace(1, 0, n)
    return y

if __name__ == "__main__":
    want = sys.argv[1:]
    for k, x in make().items():
        if not want or k in want:
            write(k, x)
