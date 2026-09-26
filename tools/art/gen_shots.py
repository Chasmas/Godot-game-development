#!/usr/bin/env python3
"""
Illustrated story shots for HOTSHOT CALIFORNIA's cutscenes, intro and
chapter covers. Each shot is 2-3 parallax layers (bg / mid / fg) painted
from code; the game animates them (camera drift, parallax, rain, fire,
flicker...) - see scripts/narrative/story_shot.gd.

  python3 tools/art/gen_shots.py [shot ...]   -> assets/art/shots/<shot>/<layer>.png

Canvas is 544x306 (the 480x270 frame plus room for camera moves), shown
at 2x with nearest filtering so it sits with the game's pixel art.
"""
import os, sys, math
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from paint import *
from props import *

W, H = 544, 306
ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "assets", "art", "shots")

SHOTS = {}
def shot(fn):
    SHOTS[fn.__name__] = fn
    return fn

def out(name, layer, L, levels=20):
    d = os.path.join(OUT, name)
    os.makedirs(d, exist_ok=True)
    grain(L, 0.018, hash(name + layer) % 1000)
    save(L, os.path.join(d, layer + ".png"), True, levels)

# ================================================================ PROLOGUE
@shot
def desert_road():
    """Route 58, 1987. The crew's light towers, the red Cadillac, the road."""
    bg = Layer(W, H)
    bg.vgrad([(0, "07030f"), (0.45, "1a0a2a"), (0.72, "5a1a40"), (0.8, "b04a50")], 0, H * 0.62)
    stars(bg, 180, 0.5, 11)
    bg.radial(W * 0.72, H * 0.6, 240, "ff6a50", 1.6, 0.35, 0.5)   # glow of a town past the hills
    ridge(bg, H * 0.6, 34, 3, "1a0c1c", 90, "ff7a70")
    ridge(bg, H * 0.63, 14, 7, "120812", 40)
    out("desert_road", "bg", bg)

    mid = Layer(W, H)
    ground = rect(mid, 0, H * 0.62, W, H)
    mid.vgrad([(0, "2a1418"), (1, "0c0608")], H * 0.62, H, mask=ground)
    sand = value_noise(W, H, 6, 21, 3)
    mid.multiply(ground * (sand > 0.62), "503040", 0.35)
    # road to the vanishing point
    vp = (W * 0.52, H * 0.625)
    road = poly(mid, [(vp[0] - 3, vp[1]), (vp[0] + 3, vp[1]), (W * 0.95, H), (W * 0.1, H)])
    mid.vgrad([(0, "241a24"), (1, "121016")], vp[1], H, mask=road)
    for i in range(14):
        t0 = (i / 14) ** 2
        t1 = t0 + 0.02 + t0 * 0.03
        y0, y1 = vp[1] + (H - vp[1]) * t0, vp[1] + (H - vp[1]) * t1
        x0, x1 = vp[0] + (W * 0.525 - vp[0]) * t0, vp[0] + (W * 0.525 - vp[0]) * t1
        wd0, wd1 = 0.5 + t0 * 4, 0.5 + t1 * 4
        mid.paint(poly(mid, [(x0 - wd0, y0), (x0 + wd0, y0), (x1 + wd1, y1), (x1 - wd1, y1)]), "e0c050", 0.85)
    # light towers of the film crew, left
    for tx, th in ((W * 0.16, 120), (W * 0.3, 96)):
        mid.paint(line(mid, [(tx, H * 0.64), (tx, H * 0.64 - th)], 2), "0a060c")
        mid.paint(line(mid, [(tx - 10, H * 0.64), (tx, H * 0.64 - th * 0.4), (tx + 10, H * 0.64)], 1.5), "0a060c")
        for k in range(3):
            lx_, ly_ = tx - 8 + k * 8, H * 0.64 - th
            mid.paint(rect(mid, lx_ - 3, ly_ - 4, 6, 5), "1a1418")
            mid.radial(lx_, ly_, 16, "fff0d0", 1.8, 1.0)
        light_cone(mid, (tx, H * 0.64 - th), (W * 0.42, H * 0.86), (W * 0.62, H * 0.74), "fff0c8", 0.18, 8)
    # the car on the road
    car_side(mid, W * 0.44, H * 0.8, 120, "b01020", rimc="ff9090", lights_on=True)
    # crew silhouettes by the camera
    for i, (px, ph) in enumerate(((W * 0.2, 44), (W * 0.24, 40), (W * 0.27, 46))):
        person(mid, px, H * 0.8, ph, "08040a", rimc="ffb080", rim_dir=(1, 0))
    # camera on a tripod
    mid.paint(rect(mid, W * 0.31, H * 0.8 - 36, 18, 11), "08040a")
    mid.paint(line(mid, [(W * 0.31 + 9, H * 0.8 - 26), (W * 0.31, H * 0.8)], 2) + line(mid, [(W * 0.31 + 9, H * 0.8 - 26), (W * 0.31 + 18, H * 0.8)], 2), "08040a")
    mid.paint(rim(rect(mid, W * 0.31, H * 0.8 - 36, 18, 11), 1, -1, 1), "ffb080", 0.8)
    out("desert_road", "mid", mid)

    fg = Layer(W, H)
    # scrub and a fence post close to lens
    fm = poly(fg, [(0, H), (0, H * 0.86), (40, H * 0.84), (90, H * 0.9), (140, H * 0.93), (160, H)])
    fg.paint(fm, "060306")
    for i in range(30):
        rng = np.random.default_rng(i)
        bx = rng.uniform(0, 150); by = H * 0.9 + rng.uniform(-4, 10)
        fg.paint(line(fg, [(bx, by), (bx + rng.uniform(-10, 10), by - rng.uniform(8, 22))], 1.2), "060306")
    fg.paint(rect(fg, W * 0.9, H * 0.55, 8, H * 0.5), "060306")
    fg.paint(rim(rect(fg, W * 0.9, H * 0.55, 8, H * 0.5), -1, 0, 1), "ff7a70", 0.5)
    out("desert_road", "fg", fg)

@shot
def cass_close():
    """Cass on set, 1987: half-lit by the crew lights, the desert behind."""
    bg = Layer(W, H)
    bg.vgrad([(0, "0a0418"), (0.6, "2a0c30"), (1, "702040")], 0, H)
    stars(bg, 90, 0.45, 5, 0.8)
    bg.radial(W * 0.85, H * 0.3, 160, "fff0d0", 1.8, 0.5)
    for i in range(3):
        bg.radial(W * (0.78 + i * 0.06), H * 0.22, 8, "ffffff", 1.5, 0.9)
    ridge(bg, H * 0.78, 18, 9, "140814", 70, "ff8070")
    out("cass_close", "bg", bg)
    fg = Layer(W, H)
    face(fg, W * 0.42, H * 0.34, 40, "e6a888", "5a1612", jacket="7a1420", light=(1, -0.3),
         light_col="ffd0a0", fill_col="4030a0", hair_style="long", look=(0.7, 0), brows=0.3, shirt="d8d0c8",
         grime=0.4, earring=True)
    out("cass_close", "fg", fg)


@shot
def tommy_car():
    """Tommy at the wheel: dash glow, the crew lights through the glass."""
    bg = Layer(W, H)
    bg.vgrad([(0, "0a0418"), (0.7, "3a1030"), (1, "802a40")], 0, H)
    stars(bg, 60, 0.5, 21, 0.7)
    for i in range(4):
        bg.radial(W * (0.1 + i * 0.07), H * 0.28, 7, "fff4e0", 1.5, 1.0)
    bg.radial(W * 0.2, H * 0.3, 140, "fff0d0", 2.0, 0.35)
    ridge(bg, H * 0.62, 16, 31, "180a18", 60, "ff8070")
    out("tommy_car", "bg", bg)
    mid = Layer(W, H)
    face(mid, W * 0.6, H * 0.35, 38, "dca080", "2a140c", jacket="23386a", light=(-1, -0.2), light_col="80d0ff",
         fill_col="ff4060", hair_style="short", look=(-0.6, 0.1), brows=-0.2, mouth=0.4, stubble=True, shirt="c8c0b0", collar="lapel")
    out("tommy_car", "mid", mid)
    fg = Layer(W, H)
    # car interior frame: A-pillar, roof, dash, wheel
    fg.paint(poly(fg, [(0, 0), (W, 0), (W, 22), (0, 30)]), "08060c")
    fg.paint(poly(fg, [(W * 0.05, 0), (W * 0.14, 0), (W * 0.02, H), (0, H), (0, 40)]), "08060c")
    dash = poly(fg, [(0, H * 0.66), (W * 0.35, H * 0.62), (W, H * 0.68), (W, H), (0, H)])
    fg.vgrad([(0, "1a1420"), (1, "060408")], H * 0.62, H, mask=dash)
    fg.radial(W * 0.3, H * 0.66, 60, "40e0ff", 1.8, 0.35, 0.4)
    for i in range(3):
        fg.paint(ellipse(fg, W * (0.22 + i * 0.07), H * 0.69, 9, 7), "0a1418")
        fg.paint(line(fg, [(W * (0.22 + i * 0.07), H * 0.69), (W * (0.22 + i * 0.07) + 5, H * 0.67)], 1), "ff4040")
    wheel = ellipse(fg, W * 0.62, H * 0.66, 70, 26) - ellipse(fg, W * 0.62, H * 0.66, 62, 20)
    fg.paint(np.clip(wheel, 0, 1), "0c0a10")
    fg.paint(rim(np.clip(wheel, 0, 1), 0, -1, 1), "80d0ff", 0.6)
    hand = spoly(fg, [(W * 0.5, H * 0.56), (W * 0.54, H * 0.54), (W * 0.56, H * 0.59), (W * 0.51, H * 0.61)])
    fg.paint(hand, "b07860")
    out("tommy_car", "fg", fg)

@shot
def clapper():
    """HOTSHOT, scene forty, take one."""
    bg = Layer(W, H)
    bg.vgrad([(0, "0a0418"), (0.6, "2a0c2a"), (1, "601a30")], 0, H)
    bg.radial(W * 0.5, H * 0.55, 220, "b01020", 2, 0.25)
    car_side(bg, W * 0.18, H * 0.86, 360, "6a0a14", rimc="ff9090")
    bg.a[..., :3] *= 0.55
    out("clapper", "bg", bg)
    fg = Layer(W, H)
    body = rect(fg, W * 0.3, H * 0.32, W * 0.4, H * 0.5)
    fg.paint(body, "141218")
    fg.paint(rim(body, 1, -1, 1), "fff0d0", 0.7)
    for r in range(4):
        fg.paint(line(fg, [(W * 0.31, H * (0.45 + r * 0.09)), (W * 0.69, H * (0.45 + r * 0.09))], 1.2), "d8d0c8", 0.8)
    fg.paint(line(fg, [(W * 0.5, H * 0.45), (W * 0.5, H * 0.72)], 1.2), "d8d0c8", 0.8)
    for txt, x, y, sz in (("HOTSHOT", 0.33, 0.36, 22), ("SCENE", 0.33, 0.47, 10), ("40", 0.4, 0.55, 22),
                          ("TAKE", 0.52, 0.47, 10), ("1", 0.6, 0.55, 22), ("DIR.  M. KESSEL", 0.33, 0.74, 10), ("ROUTE 58  -  NIGHT", 0.33, 0.66, 10)):
        m = text_mask(fg, W * x, H * y, txt, sz, F_MONO)
        fg.paint(m, "e8e0d0", 0.9)
    out("clapper", "fg", fg)
    # the striped stick is its own layer so it can snap shut
    arm = Layer(W, H)
    bar = poly(arm, [(W * 0.3, H * 0.26), (W * 0.7, H * 0.26), (W * 0.7, H * 0.31), (W * 0.3, H * 0.31)])
    arm.paint(bar, "e8e0d0")
    for i in range(7):
        x0 = W * 0.3 + i * W * 0.06
        arm.paint(poly(arm, [(x0, H * 0.26), (x0 + W * 0.03, H * 0.26), (x0 + W * 0.05, H * 0.31), (x0 + W * 0.02, H * 0.31)]) * bar, "141218")
    out("clapper", "arm", arm)

@shot
def explosion():
    """Action. The Cadillac goes up."""
    bg = Layer(W, H)
    bg.vgrad([(0, "1a0610"), (0.5, "702018"), (0.8, "e06020")], 0, H * 0.7)
    ridge(bg, H * 0.66, 20, 3, "200a0a", 80, "ffb060")
    ground = rect(bg, 0, H * 0.66, W, H)
    bg.vgrad([(0, "6a2a14"), (1, "1a0806")], H * 0.66, H, mask=ground)
    out("explosion", "bg", bg)
    mid = Layer(W, H)
    car_side(mid, W * 0.3, H * 0.84, 220, "3a0808", rimc="ffd080")
    # fireball: stacked noise-edged blobs, hot core
    n = value_noise(W, H, 18, 7, 4)
    cx, cy = W * 0.5, H * 0.6
    d = np.sqrt((mid.xx - cx) ** 2 + ((mid.yy - cy) * 1.3) ** 2) / 150.0 + (n - 0.5) * 0.5
    for thr, c_, a_ in ((1.0, "501008", 0.9), (0.8, "c02810", 1.0), (0.6, "ff7020", 1.0), (0.4, "ffc050", 1.0), (0.22, "fff4c0", 1.0)):
        mid.paint(np.clip((thr - d) * 8, 0, 1), c_, a_)
    up = np.clip((cy - 10 - mid.yy) / 60.0, 0, 1)
    smoke = np.clip((1.3 - (np.sqrt((mid.xx - cx) ** 2 + ((mid.yy - cy + 90) * 1.1) ** 2) / 170.0 + (n - 0.5) * 0.7)) * 3, 0, 1) * up
    mid.paint(smoke, "1a0c0c", 0.85)
    # the fireball's hot core again, over the smoke's foot
    mid.paint(np.clip((0.5 - d) * 8, 0, 1), "ffb040", 0.9)
    mid.radial(cx, cy, 260, "ff8030", 1.4, 0.5)
    out("explosion", "mid", mid)
    fg = Layer(W, H)
    for i, (px, ph) in enumerate(((W * 0.08, 92), (W * 0.14, 84))):
        person(fg, px, H * 0.98, ph, "0a0406", rimc="ffb050", rim_dir=(1, 0), pose="stand")
    out("explosion", "fg", fg)

@shot
def wreck():
    """...and that's a wrap. The shell burns out."""
    bg = Layer(W, H)
    bg.vgrad([(0, "05020a"), (0.6, "1a0814"), (1, "3a1414")], 0, H)
    stars(bg, 120, 0.5, 44, 0.6)
    ridge(bg, H * 0.64, 22, 45, "0c0608", 80)
    out("wreck", "bg", bg)
    mid = Layer(W, H)
    ground = rect(mid, 0, H * 0.64, W, H)
    mid.vgrad([(0, "281010"), (1, "0a0406")], H * 0.64, H, mask=ground)
    m = car_side(mid, W * 0.3, H * 0.84, 220, "1a0c0c")
    mid.multiply(m * value_noise(W, H, 5, 9, 3), "301010", 0.8)
    mid.radial(W * 0.52, H * 0.76, 120, "ff5010", 1.8, 0.6, 0.5)
    # low flames licking out of the gutted shell
    n = value_noise(W, H, 6, 17, 3)
    fl = np.clip((n - 0.5) * 6, 0, 1) * np.clip(1 - np.abs(mid.xx - W * 0.52) / 90, 0, 1) * np.clip(1 - np.abs(mid.yy - H * 0.72) / 16, 0, 1)
    mid.add(blur(fl, 2), col("ff7020"), 1.0)
    mid.add(fl, col("ffe0a0"), 0.6)
    out("wreck", "mid", mid)

# ================================================================ VAN NUYS
def apartment_room(dark=1.0):
    bg = Layer(W, H)
    bg.vgrad([(0, "140a1c"), (1, "08040c")], 0, H)
    wall_n = value_noise(W, H, 40, 3, 3)
    bg.multiply(wall_n > 0.6, "403050", 0.2)
    # window with blinds and neon outside
    wx, wy, ww, wh = W * 0.56, H * 0.1, W * 0.32, H * 0.46
    win = rect(bg, wx, wy, ww, wh)
    bg.vgrad([(0, "3a0a40"), (0.6, "c0206a"), (1, "ff5080")], wy, wy + wh, mask=win)
    glow_text(bg, wx + ww * 0.5, wy + wh * 0.55, "MOTEL", 22, F_BOLD, "ff3d7f", 1.0, "mm")
    for i in range(18):
        y = wy + i * wh / 18
        bg.paint(rect(bg, wx, y, ww, wh / 36), "1a0a18")
    bg.paint(np.clip(rect(bg, wx - 4, wy - 4, ww + 8, wh + 8) - win, 0, 1), "2a1a28")
    bg.radial(wx + ww * 0.5, wy + wh * 0.5, 200, "ff3d7f", 1.6, 0.25)
    # slatted light across floor
    for i in range(6):
        y0 = H * 0.7 + i * 9
        bg.add(blur(poly(bg, [(wx - 60, y0), (wx + ww - 40, y0), (wx + ww - 90, y0 + 4), (wx - 120, y0 + 4)]), 1.5), col("ff3d7f"), 0.12)
    # floor
    fl = rect(bg, 0, H * 0.68, W, H)
    bg.vgrad([(0, "1a0e18"), (1, "0a0408")], H * 0.68, H, mask=fl)
    return bg

@shot
def apartment():
    """Van Nuys, 9:12 PM. Cass on the couch, the machine blinking."""
    bg = apartment_room()
    out("apartment", "bg", bg)
    mid = Layer(W, H)
    # couch
    couch = spoly(mid, [(W * 0.04, H * 0.62), (W * 0.42, H * 0.6), (W * 0.46, H * 0.9), (W * 0.02, H * 0.92)])
    mid.vgrad([(0, "3a2040"), (1, "140a18")], H * 0.6, H * 0.92, mask=couch)
    mid.paint(rim(couch, 1, -1, 1), "ff5a9a", 0.5)
    # Cass sitting, silhouette with pink rim
    # sitting forward, elbows on knees, face turned to the machine
    head = ellipse(mid, W * 0.25, H * 0.46, 9, 11)
    hairm = spoly(mid, [(W * 0.225, H * 0.41), (W * 0.26, H * 0.4), (W * 0.27, H * 0.47), (W * 0.24, H * 0.58), (W * 0.215, H * 0.5)])
    body = spoly(mid, [(W * 0.2, H * 0.54), (W * 0.27, H * 0.52), (W * 0.3, H * 0.6), (W * 0.29, H * 0.68), (W * 0.2, H * 0.7)])
    arm = line(mid, [(W * 0.27, H * 0.55), (W * 0.31, H * 0.64), (W * 0.27, H * 0.62)], 5)
    legs = line(mid, [(W * 0.22, H * 0.69), (W * 0.33, H * 0.7), (W * 0.33, H * 0.86)], 9)
    fig = np.clip(head + hairm + body + arm + legs, 0, 1)
    mid.paint(fig, "0c0610")
    mid.paint(rim(fig, 1, 0, 1), "ff5a9a", 0.9)
    mid.paint(rim(fig, 0, -1, 1), "ff5a9a", 0.4)
    # side table with answering machine and the package
    tbl = rect(mid, W * 0.44, H * 0.66, W * 0.2, 6)
    mid.paint(tbl, "2a1810")
    mid.paint(rect(mid, W * 0.46, H * 0.66, 4, H * 0.2) + rect(mid, W * 0.62, H * 0.66, 4, H * 0.2), "1a0e0a")
    am = rect(mid, W * 0.46, H * 0.61, 40, 14)
    mid.paint(am, "181820")
    mid.paint(rim(am, 1, -1, 1), "ff5a9a", 0.5)
    pk = rect(mid, W * 0.55, H * 0.585, 30, 22)
    mid.vgrad([(0, "a07848"), (1, "5a4028")], H * 0.585, H * 0.66, mask=pk)
    mid.paint(rect(mid, W * 0.55 + 13, H * 0.585, 4, 22), "d0b040")
    # lamp off, phone cord
    mid.paint(line(mid, [(W * 0.49, H * 0.66), (W * 0.47, H * 0.78), (W * 0.52, H * 0.88)], 1), "0a0a10")
    out("apartment", "mid", mid)
    fg = Layer(W, H)
    # the LED is a separate layer so it can blink
    fg.radial(W * 0.46 + 32, H * 0.61 + 5, 6, "ff2020", 1.2, 1.0)
    out("apartment", "led", fg)

@shot
def machine():
    """Close on the answering machine: tape, red light, the voice."""
    bg = Layer(W, H)
    bg.vgrad([(0, "0c0610"), (1, "1a0c18")], 0, H)
    bg.radial(W * 0.8, H * 0.1, 260, "ff3d7f", 1.8, 0.3)
    top = rect(bg, 0, H * 0.72, W, H)
    bg.vgrad([(0, "3a2418"), (1, "140a08")], H * 0.72, H, mask=top)
    bg.multiply(top * value_noise(W, H, 3, 5, 3), "5a3a28", 0.4)
    out("machine", "bg", bg)
    mid = Layer(W, H)
    body = spoly(mid, [(W * 0.14, H * 0.38), (W * 0.86, H * 0.36), (W * 0.9, H * 0.8), (W * 0.1, H * 0.82)])
    mid.vgrad([(0, "3a3a44"), (0.2, "24242c"), (1, "0e0e14")], H * 0.36, H * 0.82, mask=body)
    mid.paint(rim(body, 0, -1, 1), "ff8ab0", 0.7)
    win = rect(mid, W * 0.3, H * 0.44, W * 0.4, H * 0.2)
    mid.paint(win, "0a0a10")
    mid.paint(rim(win, 0, 1, 1), "606070", 0.6)
    mid.paint(rect(mid, W * 0.34, H * 0.47, W * 0.32, H * 0.14), "3a2a20")
    mid.paint(rect(mid, W * 0.4, H * 0.5, W * 0.2, H * 0.08), "d8d0c0")
    m = text_mask(mid, W * 0.5, H * 0.54, "TOMMY 87", 9, F_MONO, "mm")
    mid.paint(m, "303040")
    for bx in range(5):
        b = rect(mid, W * (0.22 + bx * 0.1), H * 0.7, W * 0.07, H * 0.05)
        mid.paint(b, "18181e")
        mid.paint(rim(b, 0, -1, 1), "8080a0", 0.6)
    glow_text(mid, W * 0.24, H * 0.42, "MESSAGES  1", 9, F_MONO, "ff3040", 0.7)
    out("machine", "mid", mid)
    reels = Layer(W, H)
    for rx in (W * 0.38, W * 0.62):
        r = ellipse(reels, rx, H * 0.54, 14, 14)
        reels.paint(r, "1a1418")
        reels.paint(ellipse(reels, rx, H * 0.54, 5, 5), "d8d0c0")
        for k in range(3):
            a = k * math.tau / 3
            reels.paint(line(reels, [(rx, H * 0.54), (rx + math.cos(a) * 11, H * 0.54 + math.sin(a) * 11)], 2), "d8d0c0", 0.8)
    out("machine", "reels", reels)
    led = Layer(W, H)
    led.radial(W * 0.8, H * 0.44, 9, "ff2020", 1.1, 1.0)
    led.paint(ellipse(led, W * 0.8, H * 0.44, 3, 3), "ffd0d0")
    out("machine", "led", led)

@shot
def package():
    """Gold greasepaint, the key to 204, a Polaroid of Tommy smiling."""
    bg = Layer(W, H)
    bg.vgrad([(0, "2a1810"), (1, "140a06")], 0, H)
    wood = value_noise(W, H, 60, 12, 3)
    for i in range(12):
        bg.multiply(np.abs(np.sin((bg.yy + wood * 30) * 0.18 + i)) > 0.97, "1a0c06", 0.3)
    bg.radial(W * 0.45, H * 0.45, 280, "ffb070", 1.5, 0.35)
    out("package", "bg", bg)
    mid = Layer(W, H)
    # box, open flaps
    box = poly(mid, [(W * 0.06, H * 0.14), (W * 0.42, H * 0.1), (W * 0.46, H * 0.72), (W * 0.1, H * 0.78)])
    mid.vgrad([(0, "b08858"), (1, "6a4a2a")], H * 0.1, H * 0.78, mask=box)
    inner = poly(mid, [(W * 0.09, H * 0.2), (W * 0.4, H * 0.17), (W * 0.43, H * 0.68), (W * 0.12, H * 0.72)])
    mid.paint(inner, "3a2410")
    mid.paint(rect(mid, W * 0.24, H * 0.1, 10, H * 0.68) * box * (1 - inner), "d0b040")
    # greasepaint tin (gold)
    tin = ellipse(mid, W * 0.26, H * 0.44, 34, 28)
    mid.vgrad([(0, "fff0a0"), (0.5, "d8a428"), (1, "7a5a10")], H * 0.44 - 28, H * 0.44 + 28, mask=tin)
    mid.paint(rim(tin, -1, -1, 1), "ffffff", 0.7)
    mid.paint(poly(mid, star_pts(W * 0.26, H * 0.44, 16, 7)), "7a4a08", 0.8)
    mid.paint(text_mask(mid, W * 0.26, H * 0.6, "STAR GOLD", 8, F_BOLD, "mm"), "3a2a08", 0.8)
    # key with a motel tag
    kx, ky = W * 0.56, H * 0.66
    mid.paint(line(mid, [(kx, ky), (kx + 50, ky - 10)], 4), "c8b070")
    mid.paint(ellipse(mid, kx - 6, ky + 1, 9, 9) - ellipse(mid, kx - 6, ky + 1, 4, 4), "c8b070")
    tag = poly(mid, [(kx + 46, ky - 30), (kx + 90, ky - 40), (kx + 100, ky - 14), (kx + 56, ky - 4)])
    mid.paint(tag, "b01830")
    mid.paint(text_mask(mid, kx + 73, ky - 22, "204", 14, F_BOLD, "mm", 12), "fff0e0")
    # the polaroid
    pol = poly(mid, [(W * 0.6, H * 0.12), (W * 0.9, H * 0.16), (W * 0.86, H * 0.58), (W * 0.56, H * 0.53)])
    mid.paint(pol, "ece6d8")
    mid.paint(rim(pol, -1, -1, 1), "ffffff", 0.6)
    ph = poly(mid, [(W * 0.62, H * 0.16), (W * 0.87, H * 0.195), (W * 0.845, H * 0.45), (W * 0.595, H * 0.415)])
    photo = Layer(W, H)
    photo.vgrad([(0, "e0a060"), (1, "704030")], H * 0.16, H * 0.45)
    face(photo, W * 0.73, H * 0.3, 20, "e0a888", "2a140c", jacket="2f4f8f", light=(1, -0.3), light_col="ffe0b0",
         fill_col="905040", hair_style="short", mouth=1.0, shirt="e0d8c8", collar="lapel")
    mid.paint(ph, photo.a)
    mid.paint(text_mask(mid, W * 0.62, H * 0.5, "A.V.  '87", 10, F_SCRIPT, "la", -8), "303048", 0.85)
    out("package", "mid", mid)

@shot
def mirror():
    """She paints the star on. It goes on easier than it should."""
    bg = Layer(W, H)
    bg.vgrad([(0, "10141c"), (1, "06080c")], 0, H)
    tiles = ((np.mod(bg.xx, 22) < 1) | (np.mod(bg.yy, 22) < 1)).astype(np.float32)
    bg.multiply(tiles, "000000", 0.5)
    bg.radial(W * 0.5, H * 0.05, 220, "e0f0ff", 1.8, 0.3)
    out("mirror", "bg", bg)
    mid = Layer(W, H)
    frame = rect(mid, W * 0.18, H * 0.06, W * 0.64, H * 0.8)
    glass = rect(mid, W * 0.2, H * 0.09, W * 0.6, H * 0.74)
    mid.paint(frame, "2a2830")
    refl = Layer(W, H)
    refl.vgrad([(0, "1a2030"), (1, "0a0c14")], 0, H)
    refl.radial(W * 0.5, H * 0.1, 200, "e8f4ff", 1.6, 0.25)
    face(refl, W * 0.5, H * 0.34, 40, "e6a888", "5a1612", jacket="7a1420", light=(-1, -0.4), light_col="f0f4ff",
         fill_col="4a2a70", hair_style="ponytail", star=True, look=(0.0, 0.0), brows=0.1, shirt="d8d0c8", grime=0.2)
    # a hand with the brush up to the star
    refl.paint(spoly(refl, [(W * 0.28, H * 0.9), (W * 0.31, H * 0.45), (W * 0.37, H * 0.3), (W * 0.41, H * 0.32), (W * 0.37, H * 0.5), (W * 0.35, H * 0.9)]), "c88868")
    refl.paint(line(refl, [(W * 0.39, H * 0.31), (W * 0.435, H * 0.275)], 2), "402818")
    refl.paint(ellipse(refl, W * 0.44, H * 0.27, 2.5, 2.5), "e8b830")
    mid.paint(glass, refl.a)
    # streaks on the glass
    for i in range(5):
        mid.add(glass * blur(line(mid, [(W * (0.25 + i * 0.12), H * 0.1), (W * (0.18 + i * 0.12), H * 0.8)], 6), 5), col("ffffff"), 0.05)
    out("mirror", "mid", mid)
    fg = Layer(W, H)
    sink = spoly(fg, [(W * 0.1, H * 0.86), (W * 0.9, H * 0.86), (W * 0.95, H), (W * 0.05, H)])
    fg.vgrad([(0, "d8dce0"), (1, "7a8088")], H * 0.86, H, mask=sink)
    tin = ellipse(fg, W * 0.72, H * 0.88, 16, 6)
    fg.paint(tin, "d8a428")
    fg.paint(rim(tin, 0, -1, 1), "fff0a0", 0.8)
    out("mirror", "fg", fg)

# ================================================================ KHSC 9
@shot
def tv_news():
    """Channel 9 on the set in a dark room."""
    bg = Layer(W, H)
    bg.vgrad([(0, "06060a"), (1, "0c0a10")], 0, H)
    bg.radial(W * 0.5, H * 0.45, 300, "3060c0", 1.6, 0.3)
    out("tv_news", "bg", bg)
    mid = Layer(W, H)
    cab = spoly(mid, [(W * 0.14, H * 0.08), (W * 0.86, H * 0.08), (W * 0.88, H * 0.9), (W * 0.12, H * 0.9)])
    mid.vgrad([(0, "3a2a1e"), (1, "1a100a")], 0, H, mask=cab)
    wood = value_noise(W, H, 50, 2, 3)
    mid.multiply(cab * (np.abs(np.sin(mid.xx * 0.05 + wood * 10)) > 0.9), "140a06", 0.4)
    scr = spoly(mid, [(W * 0.2, H * 0.14), (W * 0.72, H * 0.13), (W * 0.73, H * 0.8), (W * 0.19, H * 0.81)])
    tv = Layer(W, H)
    tv.vgrad([(0, "18306a"), (1, "0c1838")], 0, H)
    tv.radial(W * 0.62, H * 0.35, 90, "ffd23f", 1.4, 0.3)
    m = poly(tv, star_pts(W * 0.62, H * 0.3, 30, 12))
    tv.paint(m, "ffd23f")
    tv.paint(rim(m, 1, -1, 1), "ffffff", 0.7)
    face(tv, W * 0.37, H * 0.34, 30, "e6b494", "c8a060", jacket="203060", light=(1, -0.3), light_col="ffffff",
         fill_col="4060c0", hair_style="helmet", mouth=0.6, shirt="e8e8f0", tie="a01828", collar="lapel")
    lower = rect(tv, W * 0.2, H * 0.53, W * 0.53, H * 0.08)
    tv.paint(lower, "c01020")
    tv.paint(text_mask(tv, W * 0.22, H * 0.57, "LIVE  BARSTOW MOTEL MASSACRE", 11, F_BOLD, "lm"), "ffffff")
    tv.paint(text_mask(tv, W * 0.67, H * 0.2, "9", 20, F_DISPLAY, "mm"), "ffffff", 0.85)
    mid.paint(scr, tv.a)
    mid.add(scr * blur(scr, 1), col("a0c0ff"), 0.08)
    mid.paint(rim(scr, 0, -1, 1), "000000", 0.8)
    for k in range(2):
        mid.paint(ellipse(mid, W * 0.8, H * (0.3 + k * 0.14), 10, 10), "8a7a60")
        mid.paint(line(mid, [(W * 0.8, H * (0.3 + k * 0.14)), (W * 0.8 + 7, H * (0.3 + k * 0.14) - 5)], 1.5), "2a2010")
    for k in range(6):
        mid.paint(rect(mid, W * 0.77, H * (0.6 + k * 0.03), W * 0.07, 2), "0a0806")
    out("tv_news", "mid", mid)

def motel_building(L, lit=True):
    # two-storey motel block, balcony, doors, VACANCY sign
    L.paint(rect(L, W * 0.06, H * 0.34, W * 0.72, H * 0.42), "2a1a2a")
    L.vgrad([(0, "3a2438"), (1, "1a0e1a")], H * 0.34, H * 0.76, mask=rect(L, W * 0.06, H * 0.34, W * 0.72, H * 0.42))
    L.paint(rect(L, W * 0.05, H * 0.53, W * 0.74, 4), "5a3a50")
    L.paint(rect(L, W * 0.05, H * 0.32, W * 0.74, 5), "1a0e18")
    for i in range(8):
        for row, y in ((0, H * 0.38), (1, H * 0.58)):
            x = W * (0.09 + i * 0.086)
            d = rect(L, x, y, 14, 26 if row else 22)
            L.paint(d, "140a14")
            L.paint(rect(L, x + 18, y + 4, 16, 10), "ffcf80" if (i * 3 + row) % 5 in (1, 3) and lit else "10080c")
            if (i * 3 + row) % 5 in (1, 3) and lit:
                L.radial(x + 26, y + 9, 16, "ffcf80", 1.5, 0.35)
            L.paint(text_mask(L, x + 7, y - 3, str(101 + i + row * 100), 6, F_MONO, "mm"), "c8a0b0", 0.7)
    # sign
    L.paint(rect(L, W * 0.84, H * 0.24, 4, H * 0.5), "140a14")
    s = rect(L, W * 0.79, H * 0.1, W * 0.17, H * 0.16)
    L.paint(s, "1a0a18")
    glow_text(L, W * 0.875, H * 0.15, "SUNSET", 11, F_DISPLAY, "ff9040", 0.8, "mm")
    glow_text(L, W * 0.875, H * 0.21, "PALMS", 11, F_DISPLAY, "ff3d7f", 0.8, "mm")

@shot
def motel_night():
    """Sunset Palms Motel, Barstow. Midnight."""
    bg = Layer(W, H)
    bg.vgrad([(0, "08031a"), (0.55, "2a0a3a"), (0.75, "8a2a50")], 0, H * 0.78)
    stars(bg, 140, 0.4, 61)
    bg.radial(W * 0.2, H * 0.12, 26, "fff0e0", 2.0, 0.9)
    ridge(bg, H * 0.5, 16, 62, "1a0c24", 60)
    out("motel_night", "bg", bg)
    mid = Layer(W, H)
    motel_building(mid)
    lot = rect(mid, 0, H * 0.76, W, H)
    mid.vgrad([(0, "241824"), (1, "0c080c")], H * 0.76, H, mask=lot)
    for i in range(6):
        mid.paint(line(mid, [(W * (0.1 + i * 0.14), H * 0.8), (W * (0.06 + i * 0.14), H * 0.98)], 1.5), "d8c890", 0.5)
    car_side(mid, W * 0.52, H * 0.94, 150, "b01020", rimc="ff90a0")
    mid.radial(W * 0.875, H * 0.18, 70, "ff3d7f", 1.5, 0.35)
    out("motel_night", "mid", mid)
    fg = Layer(W, H)
    palm(fg, W * 0.02, H * 1.02, 250, "06030a", 0.05, 4, "ff5a9a")
    palm(fg, W * 0.97, H * 1.02, 210, "06030a", -0.06, 5, "ff5a9a")
    vac = Layer(W, H)
    glow_text(vac, W * 0.875, H * 0.285, "VACANCY", 8, F_BOLD, "40e0ff", 0.9, "mm")
    out("motel_night", "fg", fg)
    out("motel_night", "sign", vac)

@shot
def motel_crime():
    """The morning after: tape, cruisers, a gold star on 204."""
    bg = Layer(W, H)
    bg.vgrad([(0, "0a0818"), (0.6, "1a1030"), (1, "302040")], 0, H * 0.78)
    ridge(bg, H * 0.5, 16, 62, "140a1c", 60)
    out("motel_crime", "bg", bg)
    mid = Layer(W, H)
    motel_building(mid, lit=False)
    # star painted on door 204
    x = W * (0.09 + 3 * 0.086)
    m = poly(mid, star_pts(x + 7, H * 0.435, 10, 4))
    mid.paint(m, "e8b830")
    mid.add(blur(m, 3), col("ffc040"), 0.4)
    lot = rect(mid, 0, H * 0.76, W, H)
    mid.vgrad([(0, "201820"), (1, "0a080a")], H * 0.76, H, mask=lot)
    for i, cx in enumerate((W * 0.08, W * 0.5)):
        car_side(mid, cx, H * 0.94, 170, "d8d8e0", glass="10141c", rimc="c0c8ff")
        mid.paint(rect(mid, cx + 60, H * 0.94 - 50, 50, 5), "101018")
    tape = line(mid, [(0, H * 0.72), (W * 0.3, H * 0.74), (W * 0.62, H * 0.71), (W, H * 0.73)], 3)
    mid.paint(tape, "f0d020")
    for i in range(10):
        mid.paint(text_mask(mid, W * (0.03 + i * 0.1), H * 0.728, "POLICE", 4, F_BOLD, "lm") * tape, "101010")
    for px in (W * 0.3, W * 0.36, W * 0.72):
        person(mid, px, H * 0.9, 50, "0a0a14", rimc="80a0ff", coat=True)
    out("motel_crime", "mid", mid)
    red = Layer(W, H)
    for cx in (W * 0.08, W * 0.5):
        red.radial(cx + 72, H * 0.94 - 52, 40, "ff2030", 1.3, 0.9)
    out("motel_crime", "red", red)
    blue = Layer(W, H)
    for cx in (W * 0.08, W * 0.5):
        blue.radial(cx + 98, H * 0.94 - 52, 40, "2050ff", 1.3, 0.9)
    out("motel_crime", "blue", blue)

@shot
def marv():
    """Marv Kessel: 'She doesn't even know she's on.'"""
    bg = Layer(W, H)
    bg.vgrad([(0, "1a0818"), (1, "3a0a20")], 0, H)
    for i in range(14):
        a = i / 14 * math.pi
        bg.add(blur(poly(bg, [(W * 0.5, H * 1.1), (W * 0.5 + math.cos(a) * W, H * 1.1 - math.sin(a) * W), (W * 0.5 + math.cos(a + 0.1) * W, H * 1.1 - math.sin(a + 0.1) * W)]), 3), col("ffd23f" if i % 2 else "ff3d7f"), 0.12)
    glow_text(bg, W * 0.5, H * 0.16, "HOTSHOT", 44, F_DISPLAY, "ff3d7f", 0.8, "mm")
    glow_text(bg, W * 0.8, H * 0.3, "California", 20, F_SCRIPT, "ffd23f", 0.8, "mm", 6)
    for i in range(20):
        bg.radial(W * (0.02 + i * 0.05), H * 0.04, 5, "fff0c0", 1.5, 0.8)
    out("marv", "bg", bg)
    mid = Layer(W, H)
    face(mid, W * 0.5, H * 0.4, 42, "e0b090", "1e1e24", jacket="7a1030", light=(1, -0.4), light_col="ffe8a0",
         fill_col="ff3d7f", hair_style="slick", mouth=1.6, brows=0.5, look=(0.0, 0.0), shirt="f0e8e0", tie="ffd23f", collar="lapel")
    # microphone
    mid.paint(line(mid, [(W * 0.66, H), (W * 0.61, H * 0.6)], 5), "18181e")
    mic = ellipse(mid, W * 0.605, H * 0.57, 11, 14)
    mid.vgrad([(0, "c0c0d0"), (1, "404050")], H * 0.52, H * 0.62, mask=mic)
    out("marv", "mid", mid)

@shot
def polaroid():
    """'A.V.' Tommy and his stunt coordinator, 1986."""
    bg = Layer(W, H)
    bg.vgrad([(0, "1a1210"), (1, "0a0806")], 0, H)
    bg.radial(W * 0.5, H * 0.45, 260, "ffb080", 1.6, 0.35)
    out("polaroid", "bg", bg)
    mid = Layer(W, H)
    pol = poly(mid, [(W * 0.26, H * 0.08), (W * 0.76, H * 0.1), (W * 0.74, H * 0.94), (W * 0.24, H * 0.92)])
    mid.paint(pol, "ece4d4")
    mid.paint(rim(pol, -1, -1, 1), "ffffff", 0.5)
    ph = poly(mid, [(W * 0.29, H * 0.13), (W * 0.73, H * 0.15), (W * 0.72, H * 0.72), (W * 0.28, H * 0.7)])
    photo = Layer(W, H)
    photo.vgrad([(0, "f0c080"), (0.6, "d08050"), (1, "7a4028")], H * 0.13, H * 0.72)
    ridge(photo, H * 0.52, 12, 81, "a05040", 60)
    face(photo, W * 0.4, H * 0.42, 34, "e0a888", "2a140c", jacket="2f4f8f", light=(1, -0.3), light_col="fff0c0",
         fill_col="905040", hair_style="short", mouth=1.2, shirt="e0d8c8", collar="lapel")
    face(photo, W * 0.61, H * 0.44, 34, "c89070", "5a5a50", jacket="3a4a2a", light=(1, -0.3), light_col="fff0c0",
         fill_col="905040", hair_style="balding", mouth=0.5, stubble=True, collar="popped", glasses=True)
    # fade and warm tint like an old print
    photo.a[..., :3] = photo.a[..., :3] * 0.85 + np.array([0.12, 0.07, 0.02])
    mid.paint(ph, photo.a)
    mid.paint(text_mask(mid, W * 0.3, H * 0.83, "T & A.V.  -  Yermo, '86", 15, F_SCRIPT, "lm", 2), "2a2a48", 0.9)
    out("polaroid", "mid", mid)

@shot
def salvage_yard():
    """Yermo Salvage & K-9. The dogs eat better than the crew did."""
    bg = Layer(W, H)
    bg.vgrad([(0, "05060c"), (0.6, "141a24"), (1, "2a2a30")], 0, H * 0.7)
    stars(bg, 90, 0.4, 91, 0.7)
    bg.radial(W * 0.75, H * 0.14, 20, "e0f0ff", 2.0, 0.8)
    # car-pile silhouettes
    rng = np.random.default_rng(92)
    for i in range(14):
        x = rng.uniform(0, W); y = H * 0.62; w_ = rng.uniform(40, 90); h_ = rng.uniform(20, 60)
        bg.paint(spoly(bg, [(x - w_, y), (x - w_ * 0.6, y - h_), (x + w_ * 0.4, y - h_ * 1.1), (x + w_, y)]), "0c0e14")
    out("salvage_yard", "bg", bg)
    mid = Layer(W, H)
    ground = rect(mid, 0, H * 0.62, W, H)
    mid.vgrad([(0, "2a2620"), (1, "0c0a08")], H * 0.62, H, mask=ground)
    mid.multiply(ground * (value_noise(W, H, 5, 3, 3) > 0.6), "403020", 0.4)
    # floodlight on a pole
    mid.paint(line(mid, [(W * 0.62, H * 0.64), (W * 0.62, H * 0.12)], 3), "08080c")
    mid.paint(rect(mid, W * 0.6, H * 0.1, 18, 8), "181818")
    light_cone(mid, (W * 0.63, H * 0.12), (W * 0.35, H * 0.9), (W * 0.8, H * 0.9), "e0f0d0", 0.22, 6)
    mid.radial(W * 0.63, H * 0.12, 14, "ffffff", 1.4, 1.0)
    # crushed car and a kennel
    car_side(mid, W * 0.05, H * 0.8, 150, "4a5a3a", rimc="c0e0b0")
    mid.multiply(value_noise(W, H, 4, 99, 3) > 0.55, "3a2010", 0.25)
    ken = poly(mid, [(W * 0.7, H * 0.8), (W * 0.7, H * 0.66), (W * 0.78, H * 0.6), (W * 0.86, H * 0.66), (W * 0.86, H * 0.8)])
    mid.paint(ken, "2a2018")
    mid.paint(rect(mid, W * 0.755, H * 0.7, 18, 16), "05040a")
    out("salvage_yard", "mid", mid)
    fg = Layer(W, H)
    # chain-link fence close to camera
    for i in range(-20, 60):
        fg.paint(line(fg, [(i * 12, 0), (i * 12 + H * 0.5, H)], 1), "8a90a0", 0.35)
        fg.paint(line(fg, [(i * 12, 0), (i * 12 - H * 0.5, H)], 1), "8a90a0", 0.35)
    fg.paint(rect(fg, W * 0.94, 0, 6, H), "303038")
    fg.paint(line(fg, [(0, H * 0.04), (W, H * 0.06)], 2), "404048")
    # a dog shape in the dark behind the fence
    # a German Shepherd, head up, watching: pointed ears, long snout, bushy tail
    X = lambda x: W * 0.3 + x * 1.6
    Y = lambda y: H * 0.84 - y * 1.6
    dog = poly(fg, [(X(0), Y(0)), (X(2), Y(14)), (X(4), Y(22)), (X(9), Y(30)), (X(8), Y(38)), (X(10), Y(44)), (X(12), Y(40)),
                    (X(14), Y(45)), (X(16), Y(40)), (X(24), Y(37)), (X(24), Y(34)), (X(16), Y(31)), (X(17), Y(24)),
                    (X(34), Y(24)), (X(42), Y(20)), (X(50), Y(26)), (X(46), Y(16)), (X(40), Y(12)), (X(40), Y(0)), (X(36), Y(0)),
                    (X(34), Y(10)), (X(18), Y(12)), (X(16), Y(0)), (X(12), Y(0)), (X(12), Y(12)), (X(6), Y(14)), (X(5), Y(0))])
    fg.paint(dog, "07060a")
    fg.paint(rim(dog, 1, -1, 1), "c0e0b0", 0.4)
    out("salvage_yard", "fg", fg)
    eyes = Layer(W, H)
    for ex, ey in ((W * 0.3 + 13 * 1.6, H * 0.84 - 38 * 1.6), (W * 0.3 + 17 * 1.6, H * 0.84 - 37.5 * 1.6), (W * 0.785, H * 0.735), (W * 0.8, H * 0.735)):
        eyes.radial(ex, ey, 4, "ff1020", 1.2, 1.0)
        eyes.paint(ellipse(eyes, ex, ey, 1, 1), "ffb0b0")
    out("salvage_yard", "eyes", eyes)

# ================================================================ TEASERS
@shot
def galaxy_palace():
    """1990. The Galaxy Palace arcade. 'The Fool' holds the high score."""
    bg = Layer(W, H)
    bg.vgrad([(0, "05020c"), (1, "1a0830")], 0, H)
    grid = ((np.mod(bg.xx + (bg.yy - H * 0.6) * 0.8 * (bg.xx - W / 2) / W, 30) < 1.2) | (np.mod(bg.yy, 14) < 1)) * (bg.yy > H * 0.6)
    bg.add(grid.astype(np.float32), col("b040ff"), 0.4)
    glow_text(bg, W * 0.5, H * 0.14, "GALAXY PALACE", 30, F_DISPLAY, "b040ff", 1.0, "mm")
    out("galaxy_palace", "bg", bg)
    mid = Layer(W, H)
    for i in range(6):
        x = W * (0.06 + i * 0.16)
        cab = poly(mid, [(x, H * 0.9), (x, H * 0.36), (x + 24, H * 0.3), (x + 56, H * 0.3), (x + 60, H * 0.44), (x + 56, H * 0.9)])
        mid.paint(cab, "140a1e")
        scr = rect(mid, x + 10, H * 0.38, 38, 30)
        c_ = ["ff3d7f", "35e0ff", "ffd23f", "5dff7a", "ff8a20", "b040ff"][i]
        mid.paint(scr, mix(c_, INK, 0.5))
        mid.radial(x + 29, H * 0.45, 40, c_, 1.5, 0.4)
        mid.paint(rim(cab, 0, -1, 1), c_, 0.7)
    person(mid, W * 0.5, H * 0.98, 110, "07040c", rimc="b040ff", rim_dir=(1, -1), pose="hands_hips")
    out("galaxy_palace", "mid", mid)

@shot
def barstow_pd():
    """1991. Barstow PD. Officer Dana Pruitt still can't sleep."""
    bg = Layer(W, H)
    bg.vgrad([(0, "05060c"), (1, "141c28")], 0, H)
    bg.radial(W * 0.5, H * 0.3, 240, "80a0c0", 1.6, 0.2)
    out("barstow_pd", "bg", bg)
    mid = Layer(W, H)
    st = rect(mid, W * 0.08, H * 0.3, W * 0.84, H * 0.5)
    mid.vgrad([(0, "3a3a44"), (1, "1a1a22")], H * 0.3, H * 0.8, mask=st)
    glow_text(mid, W * 0.5, H * 0.38, "BARSTOW  POLICE  DEPT.", 16, F_BOLD, "e0e8ff", 0.4, "mm")
    for i in range(6):
        mid.paint(rect(mid, W * (0.14 + i * 0.13), H * 0.5, 34, 30), "ffe0a0" if i in (2, 4) else "0c0c14")
    lot = rect(mid, 0, H * 0.8, W, H)
    mid.vgrad([(0, "18181e"), (1, "08080a")], H * 0.8, H, mask=lot)
    car_side(mid, W * 0.55, H * 0.97, 170, "d0d0d8", glass="10141c", rimc="a0c0ff")
    person(mid, W * 0.3, H * 0.97, 96, "0a0c14", rimc="ff4050", rim_dir=(-1, 0), coat=True, pose="stand")
    out("barstow_pd", "mid", mid)
    red = Layer(W, H)
    red.radial(W * 0.55 + 90, H * 0.97 - 52, 60, "ff2030", 1.3, 0.8)
    out("barstow_pd", "red", red)

@shot
def hills_fire():
    """1992. The hills are on fire."""
    bg = Layer(W, H)
    bg.vgrad([(0, "1a0608"), (0.5, "702010"), (0.8, "e06a20"), (1, "ffb050")], 0, H * 0.7)
    n = value_noise(W, H, 30, 5, 4)
    bg.paint(np.clip((n - 0.45) * 3, 0, 1) * (bg.yy < H * 0.55), "2a0c0a", 0.6)
    out("hills_fire", "bg", bg)
    mid = Layer(W, H)
    hm = ridge(mid, H * 0.58, 70, 111, "140606", 100)
    flames = rim(hm, 0, -1, 2)
    mid.add(blur(flames, 3), col("ff8020"), 1.2)
    mid.add(flames, col("fff0a0"), 1.0)
    glow_text(mid, W * 0.4, H * 0.52, "HOLLYWOOD", 18, F_BOLD, "fff0e0", 0.3, "mm", 3)
    city = rect(mid, 0, H * 0.8, W, H)
    mid.paint(city, "07040a")
    rng = np.random.default_rng(3)
    for i in range(260):
        x, y = rng.uniform(0, W), rng.uniform(H * 0.8, H)
        mid.paint(rect(mid, x, y, 1.5, 1), ["ffd080", "ff9060", "ffffff"][i % 3], 0.8)
    out("hills_fire", "mid", mid)
    fg = Layer(W, H)
    palm(fg, W * 0.9, H * 1.05, 260, "080304", -0.05, 12, "ff8040")
    out("hills_fire", "fg", fg)

if __name__ == "__main__":
    names = sys.argv[1:] or list(SHOTS)
    for n in names:
        SHOTS[n]()
        print("shot", n)
