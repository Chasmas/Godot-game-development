#!/usr/bin/env python3
"""
HOTSHOT CALIFORNIA - procedural audio generator.

Generates every placeholder sound effect and the original synth soundtrack
(layered stems for dynamic music) from pure math. Nothing is sampled.

Usage:  python3 tools/gen_audio.py
Output: assets/audio/sfx/*.wav  and  music/*.ogg

Replace any file with a real recording/composition using the same name and
the game picks it up automatically.
"""
import os, subprocess, wave
import numpy as np
from scipy.signal import lfilter, butter

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUS_DIR = os.path.join(ROOT, "music")
rng = np.random.default_rng(1988)

# ----------------------------------------------------------------- helpers
def t_axis(dur): return np.arange(int(dur * SR)) / SR
def noise(dur): return rng.uniform(-1, 1, int(dur * SR))
def env_exp(dur, k): return np.exp(-k * t_axis(dur))
def adsr(n, a, d, s, r):
    a, d, r = int(a*SR), int(d*SR), int(r*SR)
    e = np.ones(n) * s
    if a > 0: e[:min(a, n)] = np.linspace(0, 1, a)[:min(a, n)]
    if d > 0 and a < n:
        seg = np.linspace(1, s, d); e[a:a+d] = seg[:max(0, min(d, n-a))]
    if r > 0: e[-min(r, n):] *= np.linspace(1, 0, min(r, n))
    return e
def lp(x, fc, order=2):
    b, a = butter(order, min(fc, SR*0.45) / (SR/2), 'low'); return lfilter(b, a, x)
def hp(x, fc, order=2):
    b, a = butter(order, fc / (SR/2), 'high'); return lfilter(b, a, x)
def bp(x, lo, hi, order=2):
    b, a = butter(order, [lo/(SR/2), min(hi, SR*0.45)/(SR/2)], 'band'); return lfilter(b, a, x)
def saw(freq, dur, phase=0.0):
    t = t_axis(dur); return 2.0 * ((t * freq + phase) % 1.0) - 1.0
def sq(freq, dur, pw=0.5):
    t = t_axis(dur); return np.where((t * freq) % 1.0 < pw, 1.0, -1.0)
def sine(freq, dur): return np.sin(2*np.pi*freq*t_axis(dur))
def sweep_sine(f0, f1, dur, k=30):
    t = t_axis(dur); f = f1 + (f0 - f1) * np.exp(-k * t)
    return np.sin(2*np.pi*np.cumsum(f)/SR)
def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1.0; return x / m * peak
def sat(x, drive=2.0): return np.tanh(x * drive) / np.tanh(drive)
def mtof(m): return 440.0 * 2 ** ((m - 69) / 12.0)

def reverb(x, mix=0.25, size=1.0):
    """Small Schroeder reverb (4 combs + 2 allpass)."""
    out = np.zeros_like(x)
    for d, g in [(1557, .84), (1617, .83), (1491, .85), (1422, .84)]:
        d = int(d * size); a = np.zeros(d + 1); a[0] = 1; a[d] = -g
        out += lfilter([1], a, x)
    out *= 0.25
    for d, g in [(225, .7), (556, .7)]:
        b = np.zeros(d + 1); b[0] = -g; b[d] = 1
        a = np.zeros(d + 1); a[0] = 1; a[d] = -g
        out = lfilter(b, a, out)
    return x * (1 - mix) + out * mix

def delay(x, secs, fb=0.35, mix=0.3):
    d = int(secs * SR); a = np.zeros(d + 1); a[0] = 1; a[d] = -fb
    wet = lfilter([1], a, np.concatenate([np.zeros(d), x])[:len(x)])
    return x + wet * mix

def write_wav(path, x, sr=SR):
    x = np.clip(x, -1, 1); data = (x * 32767).astype(np.int16)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes(data.tobytes())

def fade(x, fi=0.002, fo=0.01):
    x = x.copy(); a, b = int(fi*SR), int(fo*SR)
    if a: x[:a] *= np.linspace(0, 1, a)
    if b: x[-b:] *= np.linspace(1, 0, b)
    return x

def pad_to(x, n):
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])[:n]

# ---------------------------------------------------------------- SFX
def gun(body_f, crack, tail, dur, lowcut=80, dist=3.0):
    n = noise(dur)
    crack_part = hp(n, 2500) * env_exp(dur, 90) * crack
    body = lp(n, body_f) * env_exp(dur, 18) * 1.2
    thump = sweep_sine(180, 45, dur, 40) * env_exp(dur, 22)
    tail_part = lp(n, 900) * env_exp(dur, 6) * tail
    x = sat(crack_part + body + thump * 1.6 + tail_part, dist)
    x = norm(reverb(hp(x, lowcut), 0.18, 0.8))
    x = sat(x * 2.6, 2.2)          # glue/compress: guns must hit HARD
    return fade(norm(x, 0.95))

def mech_click(pitch=1.0, dur=0.05):
    x = bp(noise(dur), 2000*pitch, 7000) * env_exp(dur, 160)
    x += sine(1800*pitch, dur) * env_exp(dur, 200) * 0.3
    return x

def sfx():
    os.makedirs(SFX_DIR, exist_ok=True)
    S = {}
    S['pistol'] = gun(2600, 0.9, 0.3, 0.35)
    S['revolver'] = gun(1800, 1.1, 0.6, 0.6, dist=4)
    S['smg'] = gun(3400, 0.7, 0.15, 0.16, lowcut=150)
    S['shotgun'] = norm(gun(1200, 1.0, 1.0, 0.8, lowcut=40, dist=5) + np.pad(sweep_sine(90, 30, 0.8, 8)*env_exp(0.8, 6)*0.8, (0, 0)))
    S['rifle'] = gun(2200, 1.2, 0.5, 0.45, lowcut=60, dist=4)
    S['sniper'] = gun(1600, 1.3, 1.1, 1.0, lowcut=40, dist=5)
    # suppressed: thuck + mechanical slide
    d = 0.22; x = lp(noise(d), 1400) * env_exp(d, 40) + sweep_sine(300, 90, d, 50) * env_exp(d, 50) * 0.6
    x += pad_to(np.zeros(int(0.03*SR)), 0).sum() + pad_to(np.concatenate([np.zeros(int(0.04*SR)), mech_click(1.2, 0.06)]), len(x)) * 0.7
    S['suppressed'] = fade(norm(x, 0.7))
    S['empty'] = fade(norm(mech_click(0.8, 0.08), 0.6))
    # reload: mag out, mag in, slide
    parts = [mech_click(0.6, 0.07), np.zeros(int(.18*SR)), mech_click(0.9, 0.06)*1.3, np.zeros(int(.12*SR)),
             norm(bp(noise(0.09), 1500, 6000)*np.linspace(1, 0.2, int(.09*SR))), mech_click(1.4, .05)]
    S['reload'] = fade(norm(np.concatenate(parts), 0.7))
    S['shell'] = fade(norm(sum(sine(f, .12)*env_exp(.12, 40) for f in (4200, 5300, 6100)), 0.25))
    # melee
    d = 0.18; w = bp(noise(d), 400, 2500) * np.sin(np.linspace(0, np.pi, int(d*SR)))
    S['swing'] = fade(norm(w, 0.5))
    d = 0.35; S['swing_heavy'] = fade(norm(bp(noise(d), 200, 1500) * np.sin(np.linspace(0, np.pi, int(d*SR)))**2, 0.6))
    d = 0.25; S['hit_flesh'] = fade(norm(sat(lp(noise(d), 900)*env_exp(d, 25) + sweep_sine(140, 50, d, 30)*env_exp(d, 20), 3)))
    d = 0.3; S['hit_blunt'] = fade(norm(sat(lp(noise(d), 500)*env_exp(d, 30) + sweep_sine(110, 40, d, 25)*env_exp(d, 15)*1.3, 4)))
    d = 0.2; S['hit_blade'] = fade(norm(hp(noise(d), 1500)*env_exp(d, 30) + lp(noise(d), 700)*env_exp(d, 25)))
    d = 0.15; S['punch'] = fade(norm(sat(lp(noise(d), 1200)*env_exp(d, 40) + sweep_sine(160, 60, d, 40)*env_exp(d, 30), 3), .8))
    d = 0.5; S['metal_clang'] = fade(norm(sum(sine(f, d)*env_exp(d, k) for f, k in ((820, 8), (1370, 10), (2210, 14), (3100, 18))) + hp(noise(d), 3000)*env_exp(d, 60)))
    # glass
    d = 0.9; g = hp(noise(d), 3000) * env_exp(d, 7)
    for _ in range(26):
        s = int(rng.uniform(0, 0.6) * SR); f = rng.uniform(2500, 9000); ln = int(0.08 * SR)
        g[s:s+ln] += (np.sin(2*np.pi*f*np.arange(ln)/SR) * np.exp(-np.arange(ln)/SR*50))[:len(g[s:s+ln])] * rng.uniform(.2, .6)
    S['glass'] = fade(norm(g))
    d = 0.35; S['bottle_break'] = fade(norm(hp(noise(d), 2000)*env_exp(d, 16) + sine(2900, d)*env_exp(d, 30)*.4))
    # doors
    d = 0.35; S['door_open'] = fade(norm(lp(noise(d), 700)*env_exp(d, 14)*0.5 + sweep_sine(700, 400, d, 6)*env_exp(d, 10)*0.2, 0.5))
    d = 0.4; S['door_slam'] = fade(norm(sat(lp(noise(d), 600)*env_exp(d, 18) + sweep_sine(120, 50, d, 20)*env_exp(d, 12)*1.4, 4)))
    d = 0.5; S['door_break'] = fade(norm(sat(lp(noise(d), 2000)*env_exp(d, 8) + sweep_sine(100, 40, d, 10)*env_exp(d, 9), 3)))
    # footsteps (3 variants)
    for i in range(3):
        d = 0.07; S[f'step{i}'] = fade(norm(bp(noise(d), 300 + i*120, 2500)*env_exp(d, 70), 0.35))
    # explosion
    d = 2.2; e = lp(noise(d), 1200)*env_exp(d, 3) + lp(noise(d), 300)*env_exp(d, 1.8)*1.5 + sweep_sine(90, 25, d, 4)*env_exp(d, 2.5)*1.5
    S['explosion'] = fade(norm(reverb(sat(e, 3), .3, 1.3)), 0.001, 0.3)
    # body
    d = 0.3; S['body_fall'] = fade(norm(lp(noise(d), 400)*env_exp(d, 25) + sweep_sine(90, 40, d, 20)*env_exp(d, 18), .6))
    d = 0.4; S['death'] = fade(norm(sat(lp(noise(d), 1500)*env_exp(d, 12) + sweep_sine(200, 40, d, 12)*env_exp(d, 8), 3)))
    d = 0.3; S['splat'] = fade(norm(bp(noise(d), 200, 1800)*env_exp(d, 18), .6))
    # pickups / throw
    d = 0.12; S['pickup'] = fade(norm(np.concatenate([mech_click(1.0, .05), mech_click(1.5, .07)]), .6))
    d = 0.25; S['throw'] = fade(norm(bp(noise(d), 800, 4000)*np.sin(np.linspace(0, np.pi, int(d*SR))), .45))
    # UI
    S['ui_move'] = fade(norm(sq(880, .05, .3)*env_exp(.05, 60), .25))
    S['ui_select'] = fade(norm(np.concatenate([sq(660, .05)*env_exp(.05, 40), sq(1320, .09)*env_exp(.09, 30)]), .3))
    S['ui_back'] = fade(norm(np.concatenate([sq(660, .05)*env_exp(.05, 40), sq(330, .09)*env_exp(.09, 30)]), .3))
    S['blip'] = fade(norm(sq(520, .03, .25)*env_exp(.03, 80), .15))
    S['combo'] = fade(norm(sq(1046, .08, .5)*env_exp(.08, 25) + sq(1568, .08, .25)*env_exp(.08, 30)*.5, .3))
    d = 0.6; S['rank_stamp'] = fade(norm(reverb(sat(sweep_sine(220, 55, d, 12)*env_exp(d, 6) + lp(noise(d), 2000)*env_exp(d, 20), 3), .4)))
    # alarm, phone, heartbeat, vhs
    d = 1.2; t = t_axis(d); S['alarm'] = fade(norm(sq(1, d)*0 + np.sign(np.sin(2*np.pi*(700 + 250*np.sin(2*np.pi*2*t))*t)) * .5, .4))
    ring = sine(440, .05)*0 ; d = 2.0; t = t_axis(d)
    tone = (np.sin(2*np.pi*480*t) + np.sin(2*np.pi*620*t)) * (np.sin(2*np.pi*20*t) > 0) * ((t % 2.0) < 1.2)
    S['phone_ring'] = fade(norm(lp(tone, 3000), .4))
    d = 0.8; hb = np.zeros(int(d*SR))
    for off in (0.0, 0.22):
        s = int(off*SR); k = sweep_sine(70, 40, .18, 20)*env_exp(.18, 18); hb[s:s+len(k)] += k
    S['heartbeat'] = fade(norm(lp(hb, 200), .7))
    d = 1.0; S['vhs_static'] = fade(norm(bp(noise(d), 800, 9000)*(0.7 + 0.3*np.sin(2*np.pi*60*t_axis(d))), .35), .01, .2)
    d = 1.6; S['power_down'] = fade(norm(saw(1, d)*0 + np.sin(2*np.pi*np.cumsum(np.linspace(220, 20, int(d*SR)))/SR) * np.linspace(1, 0, int(d*SR)) + lp(noise(d), 500)*env_exp(d, 3)*.3, .7))
    d = 0.5; S['slowmo_in'] = fade(norm(reverb(np.sin(2*np.pi*np.cumsum(np.linspace(900, 120, int(d*SR)))/SR)*env_exp(d, 3), .5), .5))
    d = 0.4; S['slowmo_out'] = fade(norm(reverb(np.sin(2*np.pi*np.cumsum(np.linspace(150, 900, int(d*SR)))/SR)*env_exp(d, 4), .5), .4))
    d = 0.4; S['execute'] = fade(norm(sat(lp(noise(d), 1000)*env_exp(d, 14) + sweep_sine(90, 35, d, 12)*env_exp(d, 9)*1.6, 5)))
    d = 0.35; S['spark'] = fade(norm(hp(noise(d), 4000)*env_exp(d, 22) * (rng.uniform(0, 1, int(d*SR)) > .7), .5))
    d = 0.5; S['tv_break'] = fade(norm(hp(noise(d), 2500)*env_exp(d, 10) + sine(15700, d)*env_exp(d, 4)*.2 + lp(noise(d), 600)*env_exp(d, 20), .7))
    d = 0.2; S['collect'] = fade(norm(np.concatenate([sq(784, .07)*env_exp(.07, 20), sq(1175, .07)*env_exp(.07, 20), sq(1568, .15)*env_exp(.15, 12)]), .3))
    d = 0.3; S['shield_block'] = fade(norm(sum(sine(f, d)*env_exp(d, 20) for f in (600, 950, 1500)) + hp(noise(d), 2000)*env_exp(d, 50), .7))
    d = 0.2; S['dash'] = fade(norm(bp(noise(d), 600, 3500) * np.sin(np.linspace(0, np.pi, int(d*SR)))**0.5, .4))
    d = 0.25; S['ricochet'] = fade(norm(np.sin(2*np.pi*np.cumsum(np.linspace(3200, 1700, int(d*SR)))/SR)*env_exp(d, 12)*.5 + hp(noise(d), 3000)*env_exp(d, 60), .4))
    d = 0.3; S['alert'] = fade(norm(np.concatenate([sq(988, .06, .3), np.zeros(int(.03*SR)), sq(1318, .1, .3)]) * .6, .3))
    d = 0.6; S['intercom'] = fade(norm(bp(np.sign(np.sin(2*np.pi*740*t_axis(d))) * (t_axis(d) < .25) + np.sign(np.sin(2*np.pi*587*t_axis(d))) * (t_axis(d) >= .3), 400, 3000), .35))
    # weather: seamless rain bed (crossfaded loop) + rolling thunder
    d = 6.0; n = noise(d + 0.5)
    bed = lp(hp(n, 400), 7000) * 0.5 + lp(n, 700) * 0.4
    drops = np.zeros(len(bed))
    for _ in range(900):
        s0 = int(rng.uniform(0, len(bed) - 800)); ln = 600
        drops[s0:s0 + ln] += hp(noise(ln / SR), 2500) * np.exp(-np.arange(ln) / SR * 90) * rng.uniform(0.1, 0.5)
    bed = bed + drops
    L = int(d * SR); X = int(0.5 * SR)
    loop = bed[:L].copy(); loop[:X] = loop[:X] * np.linspace(0, 1, X) + bed[L:L + X] * np.linspace(1, 0, X)
    S['rain_loop'] = norm(loop, 0.6)
    d = 4.5; t = t_axis(d)
    rumble = lp(noise(d), 180) * (np.exp(-t * 0.9)) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.7 * t) ** 2)
    crack = hp(noise(d), 1500) * np.exp(-t * 9) * 0.5
    S['thunder'] = fade(norm(reverb(sat(rumble * 3 + crack, 2), 0.45, 1.6), 0.95), 0.005, 0.8)
    # --- dogs
    def bark_one(f0, d=0.16):
        t = t_axis(d)
        f = f0 * (1 + 0.5 * np.exp(-t * 30)) * (1 - 0.25 * t / d)
        tone = np.sign(np.sin(2*np.pi*np.cumsum(f)/SR)) * 0.4 + np.sin(2*np.pi*np.cumsum(f*2)/SR) * 0.3
        body = bp(tone + noise(d) * 0.6, 250, 2400) * np.exp(-t * 14) * np.minimum(1, t * 200)
        return sat(body, 3)
    S['bark'] = fade(norm(reverb(np.concatenate([bark_one(520), np.zeros(int(0.07*SR)), bark_one(470, 0.19)]), 0.18), 0.85))
    d = 0.9; t = t_axis(d)
    g = lp(noise(d), 260) * (0.6 + 0.4 * np.sin(2*np.pi*23*t)) + sine(85, d) * 0.3 * (0.5 + 0.5*np.sin(2*np.pi*31*t))
    S['growl'] = fade(norm(sat(g * np.minimum(1, t*6) * np.minimum(1, (d - t)*5), 2), 0.6), 0.02, 0.1)
    d = 0.35; t = t_axis(d)
    f = 1400 * np.exp(-t * 3) + 500
    S['yelp'] = fade(norm(bp(np.sin(2*np.pi*np.cumsum(f)/SR) + noise(d) * 0.2, 400, 4000) * np.exp(-t * 7) * np.minimum(1, t*100), 0.7))
    d = 0.18; S['dog_bite'] = fade(norm(sat(hp(noise(d), 1200) * env_exp(d, 40) + lp(noise(d), 500) * env_exp(d, 25) + mech_click(0.5, d) * 0.6, 3)))
    # --- gore
    d = 0.45; t = t_axis(d)
    sq_ = lp(noise(d), 700) * env_exp(d, 9) * (0.6 + 0.4 * np.sin(2*np.pi*14*t)) + bp(noise(d), 1500, 5000) * env_exp(d, 25) * 0.5
    S['gore'] = fade(norm(sat(sq_ + sweep_sine(120, 45, d, 18) * env_exp(d, 14) * 0.8, 3), 0.8))
    d = 0.2; crk = np.zeros(int(d*SR))
    for off in (0.0, 0.012, 0.03):
        st0 = int(off*SR); ln = int(0.02*SR); crk[st0:st0+ln] += hp(noise(0.02), 2000) * np.exp(-np.arange(ln)/SR*200)
    S['neck_snap'] = fade(norm(crk + lp(noise(d), 400) * env_exp(d, 40) * 0.4, 0.85))
    # --- power
    S['light_switch'] = fade(norm(np.concatenate([mech_click(1.6, .03), np.zeros(int(.02*SR)), mech_click(1.1, .04)]), .6))
    d = 0.5; t = t_axis(d)
    hum = (np.sin(2*np.pi*120*t) + 0.5*np.sign(np.sin(2*np.pi*240*t))) * (rng.uniform(0, 1, len(t)) > 0.3) * 0.5 + hp(noise(d), 3000) * 0.2
    S['buzz'] = fade(norm(lp(hum, 3000) * np.minimum(1, t*30) * np.minimum(1, (d-t)*10), .45))
    d = 1.2; S['power_up'] = fade(norm(np.sin(2*np.pi*np.cumsum(np.linspace(30, 240, int(d*SR)))/SR) * np.minimum(1, t_axis(d)*2) * np.exp(-t_axis(d)*1.2) + mech_click(0.7, d) * 0.5, .6))
    # --- upgrades / armour
    S['upgrade'] = fade(norm(np.concatenate([sq(523, .06)*env_exp(.06, 20), sq(784, .06)*env_exp(.06, 20), sq(1046, .06)*env_exp(.06, 20), sq(1568, .22, .3)*env_exp(.22, 9)]) , .35))
    d = 0.5; S['armor_break'] = fade(norm(sum(sine(f, d)*env_exp(d, k) for f, k in ((520, 10), (980, 14), (1730, 18))) * 0.6 + sat(lp(noise(d), 1200)*env_exp(d, 20), 3) + hp(noise(d), 4000)*env_exp(d, 30)*0.4, .85))
    # --- added in the polish pass (kept last so the seeded noise of every
    # earlier sound is unchanged)
    # boot into a door: a hard low thump, a woody crack on top, then the
    # frame rattling for a moment
    d = 0.55
    thump = sweep_sine(95, 38, d, 18) * env_exp(d, 10) * 1.6
    crack = bp(noise(d), 900, 3800) * env_exp(d, 55) * 0.9
    body = lp(noise(d), 420) * env_exp(d, 14) * 0.8
    rattle = bp(noise(d), 300, 1400) * (0.5 + 0.5 * np.sign(np.sin(2*np.pi*23*t_axis(d)))) * env_exp(d, 9) * 0.25
    S['door_kick'] = fade(norm(sat(thump + crack + body + rattle, 3.5)))
    # ambience beds: long, soft, seamless loops (the tail is crossfaded into
    # the head so the loop point is inaudible); a separate rng so nothing
    # above changes
    arng = np.random.default_rng(1989)
    def anoise(d): return arng.uniform(-1, 1, int(d * SR))
    def loopable(x, xf=1.5):
        n = int(xf * SR); head = x[:n].copy(); tail = x[-n:].copy()
        ramp = np.linspace(0, 1, n)
        x = x[:-n].copy(); x[:n] = tail * (1 - ramp) + head * ramp
        return x
    d = 18.0
    t = t_axis(d)
    # motel interior: AC unit hum, fluorescent buzz, faint air hiss
    hum = sine(60, d) * 0.35 + sine(120, d) * 0.18 + sine(180, d) * 0.05
    hum *= 0.85 + 0.15 * np.sin(2 * np.pi * 0.07 * t)
    air = lp(anoise(d), 700) * 0.35 * (0.8 + 0.2 * np.sin(2 * np.pi * 0.11 * t))
    buzz = bp(anoise(d), 2200, 3200) * 0.02
    S['amb_interior'] = norm(loopable(hum + air + buzz), 0.5)
    # exterior night: gusting wind, crickets, a distant highway rumble
    gust = 0.5 + 0.5 * np.sin(2 * np.pi * 0.05 * t + 1.3) * np.sin(2 * np.pi * 0.013 * t)
    wind = lp(anoise(d), 500) * gust * 0.8 + bp(anoise(d), 800, 1600) * gust * 0.08
    crick = np.zeros_like(t)
    for k in range(60):
        c0 = arng.uniform(0, d - 0.3); cf = arng.uniform(4200, 5200)
        m = (t > c0) & (t < c0 + 0.18)
        crick[m] += np.sin(2 * np.pi * cf * (t[m] - c0)) * (np.sin(2 * np.pi * 30 * (t[m] - c0)) > 0) * 0.06
    road = lp(anoise(d), 120) * 0.5
    S['amb_exterior'] = norm(loopable(wind + crick + road), 0.5)
    # industrial: machinery thump, transformer hum, metal creaks
    thump = np.zeros_like(t)
    for k in range(int(d / 1.1)):
        t0 = k * 1.1
        m = t >= t0
        thump[m] += np.sin(2 * np.pi * 48 * (t[m] - t0)) * np.exp(-9 * (t[m] - t0)) * 0.5
    xform = sine(50, d) * 0.2 + sine(100, d) * 0.12
    creak = np.zeros_like(t)
    for k in range(5):
        c0 = arng.uniform(0, d - 1); m = (t > c0) & (t < c0 + 0.8)
        creak[m] += bp(anoise(0.8), 300, 900)[:m.sum()] * np.linspace(0, 1, m.sum()) ** 2 * 0.15
    S['amb_industrial'] = norm(loopable(thump + xform + lp(anoise(d), 300) * 0.2 + creak), 0.5)
    # kennel: low hum, chain-link rattling in the wind, a dog shifting
    rattle = bp(anoise(d), 2500, 6000) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.3 * t)) ** 4 * 0.12
    S['amb_kennel'] = norm(loopable(sine(60, d) * 0.15 + lp(anoise(d), 400) * 0.3 + rattle), 0.45)
    # a car passing on the road outside (doppler sweep + tyre hiss)
    d = 3.2
    tt = t_axis(d)
    env = np.exp(-((tt - 1.6) / 0.6) ** 2)
    f = 90 - 30 * np.tanh((tt - 1.6) * 2.0)
    eng = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.4 + np.sin(2 * np.pi * np.cumsum(f * 2) / SR) * 0.15
    S['car_pass'] = fade(norm((eng + lp(anoise(d), 1400) * 0.6) * env, 0.6), 0.1, 0.3)
    for name, x in S.items():
        write_wav(os.path.join(SFX_DIR, name + ".wav"), x)
    print(f"{len(S)} sfx written")

# ---------------------------------------------------------------- MUSIC
class Seq:
    """Tiny sequencer rendering into a buffer of fixed bar length."""
    def __init__(self, bpm, bars):
        self.bpm = bpm; self.bars = bars
        self.beat = 60.0 / bpm; self.step = self.beat / 4
        self.n = int(round(self.beat * 4 * bars * SR))
        self.buf = np.zeros(self.n)
    def add(self, x, at_sec, gain=1.0):
        s = int(at_sec * SR)
        if s >= self.n: return
        e = min(self.n, s + len(x))
        self.buf[s:e] += x[:e - s] * gain
        # wrap tail for seamless loops
        if s + len(x) > self.n:
            rest = x[e - s:]; rest = rest[:self.n]; self.buf[:len(rest)] += rest * gain

def kick(d=0.45, punch=1.0):
    return sat(sweep_sine(160 * punch, 42, d, 28) * env_exp(d, 7) + lp(noise(d), 3000)*env_exp(d, 200)*.3, 1.5)
def snare(d=0.3, gated=False):
    body = sine(190, d) * env_exp(d, 25) * .6
    nz = bp(noise(d), 1200, 9000) * env_exp(d, 14 if not gated else 5)
    x = body + nz
    if gated: x *= (t_axis(d) < .22)
    return x
def clap(d=0.25):
    x = np.zeros(int(d*SR)); nz = bp(noise(d), 900, 6000)
    for o in (0, .011, .022):
        s = int(o*SR); x[s:] += nz[:len(x)-s] * np.exp(-np.arange(len(x)-s)/SR*45)
    return x
def hat(d=0.06, open_=False):
    d = 0.25 if open_ else d
    return hp(noise(d), 7000) * env_exp(d, 12 if open_ else 70)
def bass_note(m, d, cutoff=900, drive=2.0, shape='saw'):
    f = mtof(m)
    x = (saw(f, d) + saw(f*1.005, d)*.6) if shape == 'saw' else sq(f, d, .5)
    x = x + sine(f/2, d) * .5
    x = lp(x, cutoff) * adsr(len(x), .003, .1, .7, .03)
    return sat(x, drive)
def pad_chord(ms, d, cutoff=2200, det=0.006):
    x = np.zeros(int(d*SR))
    for m in ms:
        f = mtof(m)
        for k in (-1, 0, 1):
            x += saw(f * (1 + k*det), d, rng.uniform(0, 1))
    x = lp(x, cutoff) * adsr(len(x), .35, .5, .8, .6)
    return x / (len(ms) * 3)
def pluck(m, d, cutoff=3000, pw=.35):
    f = mtof(m); x = sq(f, d, pw) + saw(f*2.003, d)*.3
    return lp(x, cutoff) * env_exp(d, 9)
def acid_note(m, d, cut0, res_env, accent=False):
    """303-ish: saw through a swept 2-pole filter (block-wise)."""
    f = mtof(m); x = saw(f, d); n = len(x); out = np.zeros(n)
    blk = 128; zi = np.zeros(2)
    for i in range(0, n, blk):
        tt = i / SR; fc = cut0 + res_env * np.exp(-tt * (18 if not accent else 9))
        fc = max(80, min(fc, 12000)); w = 2*np.pi*fc/SR; q = 6.0 if accent else 4.0
        alpha = np.sin(w)/(2*q); cs = np.cos(w)
        b = np.array([(1-cs)/2, 1-cs, (1-cs)/2]); a = np.array([1+alpha, -2*cs, 1-alpha])
        seg, zi = lfilter(b/a[0], a/a[0], x[i:i+blk], zi=zi)
        out[i:i+blk] = seg
    return sat(out * adsr(n, .002, .05, .8, .02), 2.5 if accent else 1.8)
def lead(m, d, vib=0.004):
    t = t_axis(d); f = mtof(m) * (1 + vib*np.sin(2*np.pi*5.5*t))
    ph = np.cumsum(f)/SR; x = 2*(ph % 1)-1 + (2*((ph*1.007) % 1)-1)*.7
    return lp(x, 3500) * adsr(len(x), .01, .2, .7, .1)

def render_ogg(name, x, q=5):
    os.makedirs(MUS_DIR, exist_ok=True)
    wav = os.path.join(MUS_DIR, name + ".tmp.wav"); write_wav(wav, np.clip(x, -1, 1))
    ogg = os.path.join(MUS_DIR, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", str(q), ogg], check=True)
    os.remove(wav)
    print("music", name, f"{len(x)/SR:.1f}s")

def master(x, peak=0.85):
    x = hp(x, 30); x = sat(x * 1.2, 1.3); return norm(x, peak)

# --- Track 1: title "Neon Vigil" (dark synthwave, 90 bpm)
def track_title():
    s = Seq(90, 16); B = s.beat * 4
    prog = [[57, 60, 64], [53, 57, 60], [50, 53, 57], [52, 56, 59]]  # Am F Dm E
    roots = [45, 41, 38, 40]
    pads = Seq(90, 16); bass = Seq(90, 16); drums = Seq(90, 16); arp = Seq(90, 16); ld = Seq(90, 16)
    for bar in range(16):
        c = prog[(bar // 2) % 4]; r = roots[(bar // 2) % 4]; t0 = bar * B
        if bar % 2 == 0: pads.add(pad_chord(c + [c[0] + 12], B * 2, 1800), t0, .9)
        for st in range(8):
            bass.add(bass_note(r - 12 + (12 if st % 2 else 0), s.step * 1.8, 600, 1.5), t0 + st * s.step * 2, .5)
        for st in range(16):
            m = c[st % 3] + 12 * (1 + (st // 3) % 2)
            arp.add(pluck(m, s.step * 1.5, 2500), t0 + st * s.step, .18)
        if bar >= 4:
            drums.add(kick(), t0, .9); drums.add(kick(), t0 + 2*s.beat + (s.step*2 if bar % 2 else 0), .8)
            drums.add(snare(0.6, True), t0 + s.beat, .5); drums.add(snare(0.6, True), t0 + 3*s.beat, .5)
            for st in range(8): drums.add(hat(), t0 + st * s.step * 2 + s.step, .12)
    melody = [(0, 69, 2), (2, 72, 1), (3, 71, 1), (4, 69, 3), (8, 65, 2), (10, 64, 2), (12, 62, 3), (15, 64, 1)]
    for bar in (8, 12):
        for beat, m, ln in melody:
            ld.add(lead(m, ln * s.beat * 0.95), bar * B + beat * s.beat / 2 * 1, .25)
    mix = reverb(pads.buf, .45, 1.4) + bass.buf + reverb(drums.buf, .25) + delay(arp.buf, s.beat * .75, .4, .35) + delay(reverb(ld.buf, .4), s.beat*.5, .3, .3)
    render_ogg("title_neon_vigil", master(mix))

# --- Track 2: level stems "Checkout Time" (124 bpm acid/electro), 4 layers
def track_level():
    bpm, bars = 124, 16
    L = {k: Seq(bpm, bars) for k in ("explore", "combat", "combo", "danger")}
    s = L["explore"]; B = s.beat * 4
    roots = [40, 40, 43, 38]  # E E G D  (E phrygian-ish)
    acid_pat = [0, 12, 0, 0, 3, 0, 15, 0, 0, 12, 7, 0, 10, 0, 12, 13]
    acc = [1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0]
    for bar in range(bars):
        r = roots[(bar // 4) % 4]; t0 = bar * B
        # explore: pulsing bass + dark pad + shaker
        if bar % 4 == 0: L["explore"].add(pad_chord([r + 12, r + 15, r + 19, r + 22], B * 4, 1500), t0, .7)
        for st in range(16):
            if st % 2 == 1 or st in (0,):
                L["explore"].add(bass_note(r, s.step * .9, 700, 2.0), t0 + st * s.step, .45)
            L["explore"].add(hat(.03), t0 + st * s.step, .05 + .04 * (st % 2))
        # combat: four-on-floor, claps, open hats
        for b in range(4):
            L["combat"].add(kick(.4, 1.1), t0 + b * s.beat, 1.0)
            L["combat"].add(hat(open_=True), t0 + b * s.beat + s.step * 2, .15)
        L["combat"].add(clap(), t0 + s.beat, .55); L["combat"].add(clap(), t0 + 3 * s.beat, .55)
        if bar % 4 == 3:
            for st in (12, 13, 14, 15): L["combat"].add(snare(.15), t0 + st * s.step, .3)
        # combo: acid line
        for st in range(16):
            m = r + 12 + acid_pat[(st + bar * 3) % 16]
            if (st + bar) % 7 == 5: continue
            L["combo"].add(acid_note(m, s.step * 1.05, 300 + 150 * (bar % 4), 2600 + 700 * acc[st], bool(acc[st])), t0 + st * s.step, .35)
        # danger: detuned stabs + ride
        for st in (0, 3, 6, 10, 12):
            L["danger"].add(sat(pad_chord([r + 24, r + 27, r + 31], s.step * 1.5, 5000, .015) * 4, 3), t0 + st * s.step, .25)
        for st in range(8): L["danger"].add(hat(.1), t0 + st * s.step * 2, .1)
    render_ogg("level_checkout_explore", master(reverb(L["explore"].buf, .3), .75))
    render_ogg("level_checkout_combat", master(L["combat"].buf, .8))
    render_ogg("level_checkout_combo", master(delay(L["combo"].buf, s.beat * .75, .35, .3), .7))
    render_ogg("level_checkout_danger", master(reverb(L["danger"].buf, .3), .6))

# --- Track 3: boss "Night Manager" (140 bpm distorted EBM)
def track_boss():
    bpm, bars = 140, 16
    main = Seq(bpm, bars); dark = Seq(bpm, bars); B = main.beat * 4; st_ = main.step
    roots = [37, 37, 36, 39]  # C# C# C D#
    for bar in range(bars):
        r = roots[(bar // 4) % 4]; t0 = bar * B
        for b in range(4):
            main.add(sat(kick(.35, 1.3), 3), t0 + b * main.beat, 1.0)
        main.add(sat(snare(.25) * 2, 3), t0 + main.beat, .45); main.add(sat(snare(.25)*2, 3), t0 + 3 * main.beat, .45)
        for st in range(16):
            main.add(bass_note(r + (12 if st % 4 == 2 else 0), st_ * .8, 1400 + 400 * (st % 3), 5.0), t0 + st * st_, .5)
            main.add(hat(.04), t0 + st * st_, .07)
        if bar >= 8:
            for st in (0, 6, 12):
                main.add(lead(r + 36 + (3 if st == 6 else 0), st_ * 5, .01) * 1.0, t0 + st * st_, .22)
        # dark phase layer: drone + metallic hits
        if bar % 4 == 0: dark.add(pad_chord([r + 12, r + 13, r + 19], B * 4, 900, .02) * 1.5, t0, .9)
        dark.add(sat(bp(noise(.3), 300, 3000) * env_exp(.3, 10) * 3, 4), t0 + 2.5 * main.beat, .35)
    render_ogg("boss_night_manager", master(reverb(main.buf, .15), .85))
    render_ogg("boss_night_manager_dark", master(reverb(dark.buf, .5, 1.5), .7))

# --- Track 4: aftermath (ambient drone, 60 bpm)
def track_aftermath():
    s = Seq(60, 12); B = s.beat * 4
    for bar in range(0, 12, 4):
        base = [40, 47, 52, 55] if bar != 4 else [41, 48, 52, 57]
        s.add(pad_chord(base, B * 4, 900, .004), bar * B, 1.0)
    hiss = lp(noise(len(s.buf)/SR), 6000) * 0.02
    for bar in range(12):
        if bar % 3 == 1: s.add(pluck(76 + (bar % 2) * 3, 2.0, 1500) * 0.4, bar * B + 1.0)
    render_ogg("aftermath_static_heat", master(reverb(s.buf, .6, 1.6) + hiss, .6))

# --- Track 5: apartment / cutscene (slow electric-piano-ish, 76 bpm)
def track_apartment():
    s = Seq(76, 8); B = s.beat * 4
    prog = [[50, 53, 57, 60], [46, 50, 53, 57], [43, 46, 50, 53], [45, 49, 52, 55]]
    for bar in range(8):
        c = prog[bar % 4]; t0 = bar * B
        for i, m in enumerate(c):
            ep = (sine(mtof(m), 2.5) + sine(mtof(m)*2, 2.5)*.2*env_exp(2.5, 3)) * env_exp(2.5, 1.2)
            s.add(ep, t0 + i * 0.03, .18)
        s.add(bass_note(c[0] - 12, B * .9, 300, 1.0), t0, .35)
        s.add(kick(.3, .7), t0, .4); s.add(kick(.3, .7), t0 + 2.5 * s.beat, .3)
        s.add(snare(.2), t0 + s.beat, .18); s.add(snare(.2), t0 + 3 * s.beat, .18)
        for st in range(8): s.add(hat(.03), t0 + st * s.step * 2, .05)
    wob = 1 + 0.002 * np.sin(2*np.pi*0.5*np.arange(len(s.buf))/SR)
    render_ogg("apartment_answering_machine", master(reverb(s.buf, .35) * wob + lp(noise(len(s.buf)/SR), 5000) * .01, .6))

if __name__ == "__main__":
    import sys
    sfx()
    if "--sfx-only" not in sys.argv:
        track_title(); track_level(); track_boss(); track_aftermath(); track_apartment()
    print("done")
