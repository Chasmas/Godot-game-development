"""
The close shots with people in them, v2: real arms and hands, more set
dressing, and faces that live - every close-up is painted three times
(rest / _blink / _talk) so the game can blink the eyes and move the mouth
while that character speaks (see StoryShot "face").

Imported by gen_shots.py; each @shot here replaces the older version.
"""
import math
import numpy as np
from paint import *
from props import *
from anatomy import *

def register(shot, out, W, H):
    """Define the shots against gen_shots' registry and canvas."""

    def faces(name, layer, paint_fn):
        for suffix, kw in (("", {}), ("_blink", {"blink": True}), ("_talk", {"open_": 1.0})):
            out(name, layer + suffix, paint_fn(**kw))

    def bokeh(L, n, seed, cols, y0, y1, r0, r1, a=0.35):
        rng = np.random.default_rng(seed)
        for i in range(n):
            x, y = rng.uniform(0, W), rng.uniform(y0, y1)
            r = rng.uniform(r0, r1)
            c = cols[i % len(cols)]
            L.add(ellipse(L, x, y, r, r, blur=1.2), col(c), a * rng.uniform(0.5, 1.0))
            L.add(rim(ellipse(L, x, y, r, r), 1, 1, 1), col(c), a * 0.6)

    def flare(L, x, y, colr, length=260, amount=0.5):
        L.add(blur(rect(L, x - length, y - 0.8, length * 2, 1.6), 1.2), col(colr), amount)
        L.radial(x, y, 30, colr, 1.4, amount * 1.4)
        for k, (dx, rr) in enumerate(((-90, 8), (-160, 5), (70, 11))):
            L.add(ellipse(L, x + dx, y + dx * 0.15, rr, rr, blur=1), col(colr), amount * 0.25)

    # ------------------------------------------------------------ PROLOGUE
    @shot
    def cass_close():
        """Cass on set, 1987: aviators in her hand, the crew lights behind."""
        bg = Layer(W, H)
        bg.vgrad([(0, "07030f"), (0.55, "22082a"), (0.85, "6a1a3a"), (1, "a03040")], 0, H)
        stars(bg, 110, 0.45, 5, 0.8)
        bokeh(bg, 22, 3, ["fff0d0", "ffb080", "ff6a9a"], H * 0.05, H * 0.6, 4, 16, 0.3)
        for i in range(3):
            bg.radial(W * (0.74 + i * 0.07), H * 0.2, 9, "ffffff", 1.4, 1.0)
        bg.radial(W * 0.82, H * 0.22, 190, "fff0d0", 1.8, 0.45)
        ridge(bg, H * 0.8, 18, 9, "140814", 70, "ff8070")
        out("cass_close", "bg", bg)

        def paint(**kw):
            L = Layer(W, H)
            cx, cy, s = W * 0.4, H * 0.33, 38
            face(L, cx, cy, s, "e6a888", "5a1612", jacket="7a1420", light=(1, -0.3), light_col="ffd0a0",
                 fill_col="4030a0", hair_style="long", look=(0.7, 0), brows=0.3, shirt="d8d0c8", grime=0.25,
                 earring=True, **kw)
            # her hand up by her jaw, aviators hooked on a finger
            arm(L, (cx + 2.8 * s, cy + 2.5 * s), (cx + 3.3 * s, cy + 4.6 * s), (cx + 1.7 * s, cy + 1.5 * s), 0.72 * s,
                "6a1020", "e0a080", "pinch", (1, -0.3), "ffd0a0", "4030a0", "ffc090", hand_angle=-1.9, nails="a02030", tape=True)
            gx, gy = cx + 1.55 * s, cy + 0.35 * s
            for ox in (-0.32, 0.32):
                g = spoly(L, [(gx + ox * s - 0.28 * s, gy - 0.12 * s), (gx + ox * s + 0.28 * s, gy - 0.12 * s),
                              (gx + ox * s + 0.22 * s, gy + 0.2 * s), (gx + ox * s - 0.22 * s, gy + 0.2 * s)])
                L.paint(g, "0c0a14", 0.92)
                L.paint(rim(g, 1, -1, 1), "ffe0a0", 0.9)
                L.add(blur(ellipse(L, gx + ox * s + 0.08 * s, gy - 0.04 * s, 0.1 * s, 0.05 * s), 1), col("ffb0d0"), 0.7)
            L.paint(line(L, [(gx - 0.05 * s, gy - 0.05 * s), (gx + 0.05 * s, gy - 0.05 * s)], 1), "d8b050")
            return L
        faces("cass_close", "fg", paint)
        fx = Layer(W, H)
        flare(fx, W * 0.82, H * 0.2, "ffd8b0", 300, 0.35)
        fx.add(blur(poly(fx, [(W, 0), (W, H * 0.5), (W * 0.7, 0)]), 20), col("ff6a4a"), 0.18)   # light leak
        out("cass_close", "flare", fx)

    @shot
    def tommy_car():
        """Tommy at the wheel: both hands on it, cigarette, the lights outside."""
        bg = Layer(W, H)
        bg.vgrad([(0, "0a0418"), (0.6, "2a0a2a"), (1, "802a40")], 0, H)
        stars(bg, 70, 0.5, 21, 0.7)
        bokeh(bg, 16, 8, ["fff4e0", "ffd0a0"], H * 0.15, H * 0.45, 5, 14, 0.35)
        for i in range(4):
            bg.radial(W * (0.08 + i * 0.07), H * 0.27, 7, "fff4e0", 1.5, 1.0)
        bg.radial(W * 0.2, H * 0.3, 150, "fff0d0", 2.0, 0.35)
        ridge(bg, H * 0.6, 16, 31, "180a18", 60, "ff8070")
        # the road and a light tower out there
        bg.paint(poly(bg, [(W * 0.3, H * 0.6), (W * 0.34, H * 0.6), (W * 0.6, H), (W * 0.0, H)]), "140c14")
        out("tommy_car", "bg", bg)

        cx, cy, s = W * 0.6, H * 0.3, 34
        def paint(**kw):
            L = Layer(W, H)
            face(L, cx, cy, s, "dca080", "2a140c", jacket="23386a", light=(-1, -0.2), light_col="80d0ff",
                 fill_col="ff4060", hair_style="short", look=(-0.6, 0.1), brows=-0.2, mouth=0.4, stubble=True,
                 shirt="c8c0b0", collar="lapel", cig=True, **kw)
            return L
        faces("tommy_car", "mid", paint)
        fg = Layer(W, H)
        # cabin: roof, A-pillar with a sheen, sun visor
        fg.paint(poly(fg, [(0, 0), (W, 0), (W, 20), (0, 28)]), "08060c")
        pillar = poly(fg, [(W * 0.05, 0), (W * 0.15, 0), (W * 0.03, H), (0, H), (0, 40)])
        fg.paint(pillar, "0a080e")
        fg.paint(rim(pillar, 1, 0, 1), "80d0ff", 0.5)
        fg.paint(poly(fg, [(W * 0.3, 18), (W * 0.52, 16), (W * 0.51, 34), (W * 0.31, 36)]), "141018")
        # rear-view mirror (the charm hangs from it - own layer so it swings)
        rv = spoly(fg, [(W * 0.33, H * 0.1), (W * 0.47, H * 0.095), (W * 0.47, H * 0.16), (W * 0.33, H * 0.165)])
        fg.paint(rv, "1a1820")
        fg.paint(spoly(fg, [(W * 0.34, H * 0.11), (W * 0.46, H * 0.105), (W * 0.46, H * 0.15), (W * 0.34, H * 0.155)]), "3a2a40")
        fg.add(ellipse(fg, W * 0.36, H * 0.125, 3, 2, blur=1), col("fff0d0"), 0.8)
        fg.paint(line(fg, [(W * 0.4, 0), (W * 0.4, H * 0.1)], 2), "0a080e")
        # dashboard with glowing gauges and needles
        dash = poly(fg, [(0, H * 0.62), (W * 0.35, H * 0.56), (W, H * 0.62), (W, H), (0, H)])
        fg.vgrad([(0, "1e1822"), (1, "060408")], H * 0.56, H, mask=dash)
        fg.paint(rim(dash, 0, -1, 1), "80d0ff", 0.35)
        for i, gx in enumerate((0.44, 0.52, 0.6)):
            gc = (W * gx, H * 0.66)
            fg.paint(ellipse(fg, gc[0], gc[1], 13, 11), "0a1418")
            fg.add(rim(ellipse(fg, gc[0], gc[1], 13, 11), 0, -1, 1), col("40e0ff"), 0.6)
            for k in range(7):
                a = math.pi * (0.8 + k / 6 * 1.4)
                fg.paint(line(fg, [(gc[0] + math.cos(a) * 9, gc[1] + math.sin(a) * 8), (gc[0] + math.cos(a) * 11, gc[1] + math.sin(a) * 10)], 1), "40e0ff", 0.8)
            na = math.pi * (1.1 + i * 0.35)
            fg.paint(line(fg, [gc, (gc[0] + math.cos(na) * 10, gc[1] + math.sin(na) * 9)], 1.2), "ff4040")
        fg.radial(W * 0.52, H * 0.66, 70, "40e0ff", 1.8, 0.25, 0.5)
        # the wheel, and his hands on it at ten and two
        wc = (W * 0.6, H * 0.68)
        ring = np.clip(ellipse(fg, wc[0], wc[1], 96, 40) - ellipse(fg, wc[0], wc[1], 86, 33), 0, 1)
        fg.paint(ring, "0e0c12")
        fg.paint(rim(ring, 0, -1, 1), "80d0ff", 0.55)
        fg.paint(line(fg, [(wc[0] - 30, wc[1] + 8), (wc[0], wc[1]), (wc[0] + 30, wc[1] + 8)], 6), "0e0c12")
        fg.paint(ellipse(fg, wc[0], wc[1], 12, 7), "1a1620")
        for side in (-1, 1):
            sh = (cx + side * 2.6 * s, cy + 2.4 * s)
            wrist = (wc[0] + side * 70, wc[1] - 30)
            el = (cx + side * 3.6 * s, cy + 3.9 * s)
            arm(fg, sh, el, wrist, 0.62 * s, "23386a", "d09878", "grip", (-1, -0.2), "80d0ff", "ff4060", "a0e0ff",
                hand_angle=math.atan2(wc[1] - wrist[1], wc[0] - wrist[0]) + side * 0.4)
        out("tommy_car", "fg", fg)
        # the air freshener: a little gold star on a string
        ch = Layer(W, H)
        ch.paint(line(ch, [(W * 0.4, H * 0.165), (W * 0.4, H * 0.27)], 1), "d8d0c0")
        st = poly(ch, star_pts(W * 0.4, H * 0.3, 9, 4))
        ch.paint(st, "e8b830")
        ch.paint(rim(st, -1, -1, 1), "fff0a0", 0.8)
        out("tommy_car", "charm", ch)

    # ------------------------------------------------------------ VAN NUYS
    @shot
    def mirror():
        """She paints the star on - brush in hand, bulbs round the mirror."""
        bg = Layer(W, H)
        bg.vgrad([(0, "0e1a1e"), (1, "060a0c")], 0, H)
        tiles = ((np.mod(bg.xx, 16) < 1) | (np.mod(bg.yy, 16) < 1)).astype(np.float32)
        bg.multiply(tiles, "000000", 0.55)
        n = value_noise(W, H, 6, 44, 3)
        bg.multiply(np.clip((n - 0.55) * 3, 0, 1), "3a4a2a", 0.35)            # grime in the grout
        bg.paint(line(bg, [(W * 0.08, H * 0.2), (W * 0.1, H * 0.35), (W * 0.07, H * 0.5)], 1), "000000", 0.5)   # a crack
        bg.radial(W * 0.5, H * 0.02, 260, "e0f4ff", 1.7, 0.3)
        out("mirror", "bg", bg)

        cx, cy, s = W * 0.5, H * 0.34, 36
        def paint(**kw):
            L = Layer(W, H)
            frame = rect(L, W * 0.16, H * 0.1, W * 0.68, H * 0.8)
            glass = rect(L, W * 0.18, H * 0.13, W * 0.64, H * 0.74)
            L.vgrad([(0, "c8ccd4"), (1, "5a5e68")], H * 0.1, H * 0.9, mask=frame)
            refl = Layer(W, H)
            refl.vgrad([(0, "1a2830"), (1, "0a1014")], 0, H)
            # the bathroom behind her, reversed: door, towel on a rail
            refl.paint(rect(refl, W * 0.62, H * 0.18, W * 0.16, H * 0.6), "10181c")
            refl.paint(rect(refl, W * 0.64, H * 0.2, W * 0.12, H * 0.56), "18242a")
            refl.paint(rect(refl, W * 0.22, H * 0.28, W * 0.1, H * 0.03), "8a8e98")
            refl.paint(rect(refl, W * 0.23, H * 0.3, W * 0.08, H * 0.16), "7a1a30")
            refl.radial(W * 0.5, H * 0.05, 220, "f0f8ff", 1.6, 0.3)
            face(refl, cx, cy, s, "e6a888", "5a1612", jacket="7a1420", light=(-1, -0.4), light_col="f0f4ff",
                 fill_col="4a2a70", hair_style="ponytail", star=True, look=(0.0, 0.0), brows=0.1, shirt="d8d0c8",
                 grime=0.2, bruise=True, **kw)
            # her arm up, brush between finger and thumb, touching up the star
            sx, sy = cx - 0.4 * s, cy - 0.27 * s
            wrist = (cx - 1.55 * s, cy + 0.55 * s)
            arm(refl, (cx - 2.7 * s, cy + 2.4 * s), (cx - 3.3 * s, cy + 4.4 * s), wrist, 0.7 * s, "d8d0c8", "e0a080",
                "pinch", (-1, -0.4), "f0f4ff", "4a2a70", "ffffff", sleeve_to=0.35, hand_angle=-0.85, nails="c82030")
            tip = (sx - 0.1 * s, sy + 0.12 * s)
            base = (wrist[0] + 0.55 * s, wrist[1] - 0.55 * s)
            refl.paint(line(refl, [base, tip], 1.6), "3a2418")
            refl.paint(ellipse(refl, tip[0], tip[1], 2.2, 2.2), "e8b830")
            L.paint(glass, refl.a)
            # steam creeping in from the edges, streaks on the glass
            d = np.minimum(np.minimum(L.xx - W * 0.18, W * 0.82 - L.xx), np.minimum(L.yy - H * 0.13, H * 0.87 - L.yy))
            steam = np.clip(1 - d / 28.0, 0, 1) * glass * (0.6 + 0.4 * value_noise(W, H, 10, 3, 3))
            L.add(steam, col("c0d0d8"), 0.45)
            for i in range(5):
                L.add(glass * blur(line(L, [(W * (0.25 + i * 0.12), H * 0.14), (W * (0.19 + i * 0.12), H * 0.86)], 5), 5), col("ffffff"), 0.05)
            return L
        faces("mirror", "mid", paint)
        fg = Layer(W, H)
        sink = spoly(fg, [(W * 0.08, H * 0.86), (W * 0.92, H * 0.86), (W * 0.97, H), (W * 0.03, H)])
        fg.vgrad([(0, "e0e4e8"), (1, "7a8088")], H * 0.86, H, mask=sink)
        fg.paint(rim(sink, 0, -1, 1), "ffffff", 0.7)
        fau = spoly(fg, [(W * 0.47, H * 0.87), (W * 0.47, H * 0.8), (W * 0.53, H * 0.79), (W * 0.54, H * 0.83), (W * 0.51, H * 0.83), (W * 0.51, H * 0.87)])
        fg.vgrad([(0, "ffffff"), (1, "6a7078")], H * 0.78, H * 0.88, mask=fau)
        tin = ellipse(fg, W * 0.74, H * 0.89, 17, 6)
        fg.paint(tin, "c89420")
        fg.paint(ellipse(fg, W * 0.74, H * 0.885, 13, 4.5), "f0c040")
        fg.paint(rim(tin, 0, -1, 1), "fff0a0", 0.8)
        cup = rect(fg, W * 0.24, H * 0.78, 18, 26)
        fg.vgrad([(0, "a0d8e0"), (1, "40707a")], H * 0.78, H * 0.88, mask=cup)
        for i, c in enumerate(("ff3d7f", "35e0ff")):
            fg.paint(line(fg, [(W * 0.24 + 5 + i * 7, H * 0.8), (W * 0.24 + 2 + i * 9, H * 0.68)], 2), c)
        out("mirror", "fg", fg)
        # vanity bulbs above the mirror (own layer: they buzz and one flickers)
        bl = Layer(W, H)
        for i in range(6):
            bx = W * (0.2 + i * 0.12)
            bl.add(ellipse(bl, bx, H * 0.08, 16, 16, blur=6), col("fff0c8"), 0.35)
            bl.paint(ellipse(bl, bx, H * 0.08, 7, 7), "fff8e0")
            bl.paint(ellipse(bl, bx - 2, H * 0.075, 2.5, 2.5), "ffffff")
        out("mirror", "bulbs", bl)

    @shot
    def apartment():
        """Van Nuys, 9:12 PM. Cass hunched on the couch, the machine blinking,
        the fan turning, her own movie poster on the wall."""
        W_, H_ = W, H
        bg = Layer(W, H)
        bg.vgrad([(0, "160c1e"), (1, "0a050e")], 0, H)
        stripes = (np.mod(bg.xx, 12) < 6).astype(np.float32) * (bg.yy < H * 0.68)
        bg.multiply(stripes, "2a1a30", 0.18)                                   # wallpaper
        bg.multiply(np.clip((value_noise(W, H, 30, 3, 3) - 0.5) * 3, 0, 1), "302030", 0.3)
        # window with blinds, neon outside and rain on it
        wx, wy, ww, wh = W * 0.6, H * 0.08, W * 0.3, H * 0.46
        win = rect(bg, wx, wy, ww, wh)
        bg.vgrad([(0, "3a0a40"), (0.6, "c0206a"), (1, "ff5080")], wy, wy + wh, mask=win)
        glow_text(bg, wx + ww * 0.5, wy + wh * 0.55, "MOTEL", 20, F_BOLD, "ff3d7f", 1.0, "mm")
        for i in range(18):
            bg.paint(rect(bg, wx, wy + i * wh / 18, ww, wh / 36), "1a0a18")
        bg.paint(np.clip(rect(bg, wx - 4, wy - 4, ww + 8, wh + 8) - win, 0, 1), "2a1a28")
        bg.radial(wx + ww * 0.5, wy + wh * 0.5, 220, "ff3d7f", 1.6, 0.25)
        # the HOTSHOT poster: her car, her name small at the bottom
        px, py, pw, ph = W * 0.08, H * 0.08, W * 0.17, H * 0.4
        pr = rect(bg, px, py, pw, ph)
        bg.vgrad([(0, "2a0818"), (0.7, "a01838"), (1, "ff7040")], py, py + ph, mask=pr)
        glow_text(bg, px + pw * 0.5, py + ph * 0.16, "HOTSHOT", 14, F_DISPLAY, "ffd23f", 0.6, "mm")
        car_side(bg, px + pw * 0.12, py + ph * 0.72, pw * 0.76, "b01020")
        bg.paint(text_mask(bg, px + pw * 0.5, py + ph * 0.9, "C. MORENO", 6, F_MONO, "mm"), "fff0e0", 0.8)
        bg.paint(rim(pr, 1, 1, 1), "000000", 0.6)
        bg.paint(ellipse(bg, px + pw * 0.5, py + 2, 2, 2), "c0c0c8")              # pin
        # floor lamp, warm, low
        bg.paint(line(bg, [(W * 0.53, H * 0.66), (W * 0.53, H * 0.28)], 2), "100a0c")
        shade = poly(bg, [(W * 0.505, H * 0.28), (W * 0.555, H * 0.28), (W * 0.565, H * 0.2), (W * 0.495, H * 0.2)])
        bg.paint(shade, "c89060")
        light_cone(bg, (W * 0.53, H * 0.27), (W * 0.42, H * 0.68), (W * 0.64, H * 0.68), "ffc080", 0.18, 6)
        # floor, rug, slatted neon on it
        fl = rect(bg, 0, H * 0.66, W, H)
        bg.vgrad([(0, "1e1018"), (1, "0a0408")], H * 0.66, H, mask=fl)
        bg.paint(ellipse(bg, W * 0.33, H * 0.86, 150, 26), "3a1a2a", 0.9)
        for i in range(6):
            y0 = H * 0.7 + i * 9
            bg.add(blur(poly(bg, [(wx - 60, y0), (wx + ww - 40, y0), (wx + ww - 90, y0 + 4), (wx - 120, y0 + 4)]), 1.5), col("ff3d7f"), 0.12)
        out("apartment", "bg", bg)

        mid = Layer(W, H)
        # couch
        back = spoly(mid, [(W * 0.03, H * 0.46), (W * 0.46, H * 0.44), (W * 0.47, H * 0.62), (W * 0.02, H * 0.64)])
        mid.vgrad([(0, "4a2450"), (1, "241030")], H * 0.44, H * 0.64, mask=back)
        seat = spoly(mid, [(W * 0.02, H * 0.6), (W * 0.48, H * 0.58), (W * 0.5, H * 0.74), (W * 0.0, H * 0.76)])
        mid.vgrad([(0, "5a2c60"), (1, "1a0a20")], H * 0.58, H * 0.76, mask=seat)
        for i in range(1, 3):
            mid.paint(line(mid, [(W * (0.02 + i * 0.155), H * 0.47), (W * (0.02 + i * 0.155), H * 0.73)], 1), "1a0a20", 0.8)
        mid.paint(rim(np.clip(back + seat, 0, 1), 1, -1, 1), "ff5a9a", 0.5)
        # Cass, sitting forward, elbows on knees, hands clasped, head turned to the machine
        hip = (W * 0.24, H * 0.62)
        knee = (W * 0.32, H * 0.63)
        foot = (W * 0.33, H * 0.84)
        for dx in (0, 7):
            limb(mid, [(hip[0] + dx, hip[1]), (knee[0] + dx, knee[1]), (foot[0] + dx, foot[1])], 13, 9, "1e2a4a", "ff8ab0", "2a1a4a", (1, -0.3), "ff5a9a")
            mid.paint(spoly(mid, [(foot[0] + dx - 5, foot[1] - 2), (foot[0] + dx + 9, foot[1] - 1), (foot[0] + dx + 9, foot[1] + 4), (foot[0] + dx - 5, foot[1] + 4)]), "0e0a0c")
        torso = spoly(mid, [(W * 0.215, H * 0.37), (W * 0.27, H * 0.36), (W * 0.3, H * 0.47), (W * 0.27, H * 0.62), (W * 0.21, H * 0.62), (W * 0.2, H * 0.47)])
        mid.vgrad([(0, "8a1628"), (1, "3a0812")], H * 0.36, H * 0.62, mask=torso)
        mid.paint(rim(torso, 1, -1, 1), "ff5a9a", 0.8)
        for dx, c in ((0, "7a1420"), (6, "8a1628")):
            arm(mid, (W * 0.25 + dx, H * 0.39), (W * 0.305 + dx * 0.5, H * 0.56), (W * 0.33, H * 0.5), 9, c, "e0a080", "relaxed",
                (1, -0.3), "ff8ab0", "2a1a4a", "ff5a9a", hand_angle=-0.4)
        head = ellipse(mid, W * 0.265, H * 0.3, 11, 13)
        mid.paint(head, "b07868")
        mid.paint(rim(head, 1, 0, 1), "ff8ab0", 0.9)
        hair = spoly(mid, [(W * 0.235, H * 0.28), (W * 0.26, H * 0.24), (W * 0.29, H * 0.26), (W * 0.28, H * 0.3), (W * 0.25, H * 0.45), (W * 0.225, H * 0.38)])
        mid.vgrad([(0, "6a1a14"), (1, "2a0806")], H * 0.24, H * 0.45, mask=hair)
        mid.paint(rim(hair, 1, -1, 1), "ff5a9a", 0.6)
        # coffee table: ashtray, bottles, the package
        tbl = spoly(mid, [(W * 0.36, H * 0.7), (W * 0.58, H * 0.69), (W * 0.6, H * 0.74), (W * 0.35, H * 0.75)])
        mid.vgrad([(0, "4a2a18"), (1, "1a0e08")], H * 0.69, H * 0.75, mask=tbl)
        mid.paint(rect(mid, W * 0.37, H * 0.75, 4, H * 0.12) + rect(mid, W * 0.57, H * 0.75, 4, H * 0.12), "1a0e08")
        mid.paint(ellipse(mid, W * 0.41, H * 0.705, 11, 3.5), "5a5a64")
        mid.paint(line(mid, [(W * 0.405, H * 0.7), (W * 0.425, H * 0.695)], 1.2), "e8e0d0")
        mid.radial(W * 0.425, H * 0.695, 3, "ff6020", 1.2, 1.0)
        for i, (bx, c) in enumerate(((0.47, "2a6a3a"), (0.5, "5a3a18"))):
            b = rect(mid, W * bx, H * 0.63, 6, 18)
            mid.paint(b, c)
            mid.paint(rect(mid, W * bx + 1.5, H * 0.6, 3, 6), c)
            mid.paint(rim(b, 1, -1, 1), "ff8ab0", 0.6)
        pk = rect(mid, W * 0.53, H * 0.62, 32, 20)
        mid.vgrad([(0, "a07848"), (1, "5a4028")], H * 0.62, H * 0.69, mask=pk)
        mid.paint(rect(mid, W * 0.53 + 14, H * 0.62, 4, 20), "d0b040")
        # side table with the answering machine
        mid.paint(rect(mid, W * 0.63, H * 0.6, W * 0.13, 5), "2a1810")
        mid.paint(rect(mid, W * 0.64, H * 0.61, 3, H * 0.2) + rect(mid, W * 0.75, H * 0.61, 3, H * 0.2), "1a0e0a")
        am = spoly(mid, [(W * 0.645, H * 0.565), (W * 0.735, H * 0.565), (W * 0.74, H * 0.6), (W * 0.64, H * 0.6)])
        mid.paint(am, "1a1a22")
        mid.paint(rim(am, 1, -1, 1), "ff5a9a", 0.5)
        mid.paint(line(mid, [(W * 0.66, H * 0.6), (W * 0.64, H * 0.72), (W * 0.68, H * 0.86)], 1), "0a0a10")
        out("apartment", "mid", mid)
        led = Layer(W, H)
        led.radial(W * 0.725, H * 0.58, 6, "ff2020", 1.2, 1.0)
        out("apartment", "led", led)
        # the ceiling fan: three frames of the blades turning
        for f in range(3):
            fan = Layer(W, H)
            hub = (W * 0.36, H * 0.05)
            fan.paint(line(fan, [(hub[0], 0), hub], 2), "0a060c")
            for k in range(4):
                a = f * (math.pi / 6) + k * math.pi / 2
                dx, dy = math.cos(a), math.sin(a) * 0.22
                tip = (hub[0] + dx * 70, hub[1] + dy * 70)
                bl = poly(fan, [(hub[0] + dy * 20, hub[1] - dx * 3), tip, (tip[0] + dy * 18, tip[1] + 4), (hub[0] - dy * 10, hub[1] + 3)])
                fan.paint(bl, "120a10")
                fan.paint(rim(bl, 0, 1, 1), "ff5a9a", 0.4)
            fan.paint(ellipse(fan, hub[0], hub[1], 9, 4), "1a1216")
            out("apartment", "fan_%d" % f, fan)

    @shot
    def package():
        """The package on the table: gold greasepaint, the key to 204, the Polaroid."""
        bg = Layer(W, H)
        bg.vgrad([(0, "2a1810"), (1, "140a06")], 0, H)
        wood = value_noise(W, H, 60, 12, 3)
        for i in range(14):
            bg.multiply(np.abs(np.sin((bg.yy + wood * 30) * 0.18 + i)) > 0.97, "1a0c06", 0.3)
        bg.radial(W * 0.45, H * 0.4, 300, "ffb070", 1.5, 0.4)
        # a coffee ring and cigarette burn on the table
        bg.paint(np.clip(ellipse(bg, W * 0.86, H * 0.8, 20, 18) - ellipse(bg, W * 0.86, H * 0.8, 17, 15), 0, 1), "140804", 0.6)
        out("package", "bg", bg)
        mid = Layer(W, H)
        box = poly(mid, [(W * 0.08, H * 0.12), (W * 0.46, H * 0.08), (W * 0.49, H * 0.74), (W * 0.11, H * 0.78)])
        mid.vgrad([(0, "b08858"), (1, "6a4a2a")], H * 0.08, H * 0.78, mask=box)
        inner = poly(mid, [(W * 0.11, H * 0.18), (W * 0.44, H * 0.15), (W * 0.46, H * 0.7), (W * 0.14, H * 0.73)])
        mid.paint(inner, "3a2410")
        # crumpled newspaper stuffing
        crumple = blur(value_noise(W, H, 16, 21, 2), 1.5)
        mid.paint(inner, "a8a090", 0.95)
        paper = inner * np.clip((crumple - 0.35) * 2, 0, 1)
        mid.paint(paper, "c0b8a8", 0.9)
        mid.paint(inner * np.clip((crumple - 0.62) * 4, 0, 1), "e0d8c8", 0.8)    # highlights on the folds
        mid.multiply(inner * np.clip((0.45 - crumple) * 4, 0, 1), "3a3028", 0.6)  # shadow in the creases
        for i in range(14):
            y = H * (0.2 + i * 0.035)
            mid.paint(line(mid, [(W * 0.13, y), (W * 0.2, y - 1)], 1) * paper, "404040", 0.6)
        mid.paint(rect(mid, W * 0.26, H * 0.08, 10, H * 0.7) * box * (1 - inner), "d0b040")
        tin = ellipse(mid, W * 0.28, H * 0.42, 34, 28)
        mid.vgrad([(0, "fff0a0"), (0.5, "d8a428"), (1, "7a5a10")], H * 0.42 - 28, H * 0.42 + 28, mask=tin)
        mid.paint(rim(tin, -1, -1, 1), "ffffff", 0.7)
        mid.paint(poly(mid, star_pts(W * 0.28, H * 0.42, 16, 7)), "7a4a08", 0.8)
        mid.paint(text_mask(mid, W * 0.28, H * 0.58, "STAR GOLD", 8, F_BOLD, "mm"), "3a2a08", 0.8)
        kx, ky = W * 0.56, H * 0.66
        mid.paint(line(mid, [(kx, ky), (kx + 50, ky - 10)], 4), "c8b070")
        mid.paint(np.clip(ellipse(mid, kx - 6, ky + 1, 9, 9) - ellipse(mid, kx - 6, ky + 1, 4, 4), 0, 1), "c8b070")
        for t in range(4):
            mid.paint(rect(mid, kx + 38 + t * 3, ky - 8 + (t % 2) * 2, 2, 5), "c8b070")
        tag = poly(mid, [(kx + 46, ky - 30), (kx + 90, ky - 40), (kx + 100, ky - 14), (kx + 56, ky - 4)])
        mid.paint(tag, "b01830")
        mid.paint(text_mask(mid, kx + 73, ky - 22, "204", 14, F_BOLD, "mm", 12), "fff0e0")
        # the Polaroid
        pol = poly(mid, [(W * 0.6, H * 0.1), (W * 0.9, H * 0.14), (W * 0.86, H * 0.56), (W * 0.56, H * 0.51)])
        mid.paint(pol, "ece6d8")
        mid.paint(rim(pol, -1, -1, 1), "ffffff", 0.6)
        ph = poly(mid, [(W * 0.62, H * 0.14), (W * 0.87, H * 0.175), (W * 0.845, H * 0.43), (W * 0.595, H * 0.395)])
        photo = Layer(W, H)
        photo.vgrad([(0, "e0a060"), (1, "704030")], H * 0.14, H * 0.43)
        face(photo, W * 0.73, H * 0.28, 20, "e0a888", "2a140c", jacket="2f4f8f", light=(1, -0.3), light_col="ffe0b0",
             fill_col="905040", hair_style="short", mouth=1.0, shirt="e0d8c8", collar="lapel")
        mid.paint(ph, photo.a)
        mid.paint(text_mask(mid, W * 0.62, H * 0.48, "A.V.  '87", 10, F_SCRIPT, "la", -8), "303048", 0.85)
        out("package", "mid", mid)

    # ------------------------------------------------------------ KHSC 9
    @shot
    def tv_news():
        """Channel 9 in a dark room: the anchor, hands folded on his papers."""
        bg = Layer(W, H)
        bg.vgrad([(0, "06060a"), (1, "0c0a10")], 0, H)
        bg.radial(W * 0.5, H * 0.45, 320, "3060c0", 1.6, 0.3)
        # a room lit only by the set: a lamp's silhouette, a plant
        bg.paint(line(bg, [(W * 0.93, H), (W * 0.93, H * 0.4)], 2), "050507")
        bg.paint(poly(bg, [(W * 0.9, H * 0.4), (W * 0.96, H * 0.4), (W * 0.95, H * 0.33), (W * 0.91, H * 0.33)]), "050507")
        out("tv_news", "bg", bg)

        def paint(**kw):
            mid = Layer(W, H)
            cab = spoly(mid, [(W * 0.14, H * 0.06), (W * 0.86, H * 0.06), (W * 0.88, H * 0.92), (W * 0.12, H * 0.93)])
            mid.vgrad([(0, "3a2a1e"), (1, "1a100a")], 0, H, mask=cab)
            wood = value_noise(W, H, 50, 2, 3)
            mid.multiply(cab * (np.abs(np.sin(mid.xx * 0.05 + wood * 10)) > 0.9), "140a06", 0.4)
            scr = spoly(mid, [(W * 0.2, H * 0.12), (W * 0.72, H * 0.11), (W * 0.73, H * 0.8), (W * 0.19, H * 0.81)])
            tv = Layer(W, H)
            tv.vgrad([(0, "18306a"), (1, "0c1838")], 0, H)
            tv.radial(W * 0.62, H * 0.3, 90, "ffd23f", 1.4, 0.3)
            m = poly(tv, star_pts(W * 0.62, H * 0.3, 30, 12))
            tv.paint(m, "ffd23f")
            tv.paint(rim(m, 1, -1, 1), "ffffff", 0.7)
            glow_text(tv, W * 0.62, H * 0.47, "THE STAR KILLER?", 8, F_BOLD, "ffffff", 0.2, "mm")
            face(tv, W * 0.37, H * 0.3, 28, "e6b494", "c8a060", jacket="203060", light=(1, -0.3), light_col="ffffff",
                 fill_col="4060c0", hair_style="helmet", mouth=0.6, shirt="e8e8f0", tie="a01828", collar="lapel", **kw)
            desk = poly(tv, [(W * 0.19, H * 0.5), (W * 0.55, H * 0.49), (W * 0.56, H * 0.6), (W * 0.19, H * 0.61)])
            tv.vgrad([(0, "5a6a90"), (1, "2a3450")], H * 0.49, H * 0.61, mask=desk)
            tv.paint(poly(tv, [(W * 0.3, H * 0.47), (W * 0.45, H * 0.465), (W * 0.46, H * 0.5), (W * 0.29, H * 0.505)]), "f0f0f0")
            for side in (-1, 1):
                hand(tv, W * 0.37 + side * 22, H * 0.475, 11, math.pi if side > 0 else 0.0, "relaxed", "e6b494",
                     (1, -0.3), "ffffff", "4060c0")
            lower = rect(tv, W * 0.19, H * 0.61, W * 0.54, H * 0.07)
            tv.paint(lower, "c01020")
            tv.paint(text_mask(tv, W * 0.21, H * 0.645, "LIVE  BARSTOW MOTEL MASSACRE", 10, F_BOLD, "lm"), "ffffff")
            tv.paint(text_mask(tv, W * 0.67, H * 0.19, "9", 20, F_DISPLAY, "mm"), "ffffff", 0.85)
            mid.paint(scr, tv.a)
            mid.add(scr * blur(scr, 1), col("a0c0ff"), 0.08)
            mid.paint(rim(scr, 0, -1, 1), "000000", 0.8)
            for k in range(2):
                mid.paint(ellipse(mid, W * 0.8, H * (0.3 + k * 0.14), 10, 10), "8a7a60")
                mid.paint(line(mid, [(W * 0.8, H * (0.3 + k * 0.14)), (W * 0.8 + 7, H * (0.3 + k * 0.14) - 5)], 1.5), "2a2010")
            for k in range(6):
                mid.paint(rect(mid, W * 0.77, H * (0.6 + k * 0.03), W * 0.07, 2), "0a0806")
            # rabbit ears on top
            for a in (-0.5, 0.4):
                mid.paint(line(mid, [(W * 0.5, H * 0.06), (W * 0.5 + math.sin(a) * 80, H * 0.06 - math.cos(a) * 60)], 1.5), "a0a0a8")
            return mid
        faces("tv_news", "mid", paint)

    @shot
    def marv():
        """Marv Kessel, mic in hand: 'She doesn't even know she's on.'"""
        bg = Layer(W, H)
        bg.vgrad([(0, "1a0818"), (1, "3a0a20")], 0, H)
        for i in range(14):
            a = i / 14 * math.pi
            bg.add(blur(poly(bg, [(W * 0.5, H * 1.1), (W * 0.5 + math.cos(a) * W, H * 1.1 - math.sin(a) * W), (W * 0.5 + math.cos(a + 0.1) * W, H * 1.1 - math.sin(a + 0.1) * W)]), 3), col("ffd23f" if i % 2 else "ff3d7f"), 0.12)
        glow_text(bg, W * 0.5, H * 0.14, "HOTSHOT", 44, F_DISPLAY, "ff3d7f", 0.8, "mm")
        glow_text(bg, W * 0.8, H * 0.28, "California", 20, F_SCRIPT, "ffd23f", 0.8, "mm", 6)
        for i in range(22):
            bg.radial(W * (0.02 + i * 0.047), H * 0.035, 5, "fff0c0", 1.5, 0.8)
        bokeh(bg, 30, 11, ["ffd23f", "ff3d7f", "ffffff"], H * 0.75, H * 1.0, 3, 9, 0.3)   # the audience's cameras
        out("marv", "bg", bg)
        cx, cy, s = W * 0.47, H * 0.36, 38
        def paint(**kw):
            L = Layer(W, H)
            face(L, cx, cy, s, "e0b090", "1e1e24", jacket="7a1030", light=(1, -0.4), light_col="ffe8a0",
                 fill_col="ff3d7f", hair_style="slick", mouth=1.6, brows=0.5, look=(0.0, 0.0), shirt="f0e8e0",
                 tie="ffd23f", collar="lapel", **kw)
            # right hand on the mic by his chin, left hand open to the audience
            mic_h = (cx + 1.5 * s, cy + 1.6 * s)
            L.paint(line(L, [mic_h, (cx + 0.75 * s, cy + 0.85 * s)], 6), "18181e")
            mic = ellipse(L, cx + 0.7 * s, cy + 0.8 * s, 7, 8)
            L.vgrad([(0, "d0d0e0"), (1, "404050")], cy + 0.6 * s, cy + s, mask=mic)
            L.paint(line(L, [mic_h, (mic_h[0] + 0.5 * s, mic_h[1] + 1.8 * s)], 1.5), "101014")   # the cord
            arm(L, (cx + 2.6 * s, cy + 2.4 * s), (cx + 2.9 * s, cy + 3.9 * s), (mic_h[0] + 0.15 * s, mic_h[1] + 0.25 * s), 0.7 * s,
                "7a1030", "e0b090", "grip", (1, -0.4), "ffe8a0", "ff3d7f", "fff0c0", hand_angle=-2.2)
            arm(L, (cx - 2.6 * s, cy + 2.4 * s), (cx - 3.6 * s, cy + 3.6 * s), (cx - 3.2 * s, cy + 1.9 * s), 0.7 * s,
                "7a1030", "e0b090", "open", (1, -0.4), "ffe8a0", "ff3d7f", "fff0c0", hand_angle=-2.0)
            L.radial(cx - 3.4 * s, cy + 1.2 * s, 6, "ffd23f", 1.2, 0.8)      # a ring catches the light
            return L
        faces("marv", "mid", paint)

    @shot
    def polaroid():
        """'A.V.' Tommy and his stunt coordinator, 1986 - Arlo's arm round him."""
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
        ridge(photo, H * 0.5, 12, 81, "a05040", 60)
        car_side(photo, W * 0.5, H * 0.66, 110, "b01020")
        face(photo, W * 0.4, H * 0.38, 32, "e0a888", "2a140c", jacket="2f4f8f", light=(1, -0.3), light_col="fff0c0",
             fill_col="905040", hair_style="short", mouth=1.2, shirt="e0d8c8", collar="lapel")
        face(photo, W * 0.61, H * 0.4, 32, "c89070", "5a5a50", jacket="3a4a2a", light=(1, -0.3), light_col="fff0c0",
             fill_col="905040", hair_style="balding", mouth=0.5, stubble=True, collar="popped", glasses=True)
        arm(photo, (W * 0.55, H * 0.6), (W * 0.49, H * 0.64), (W * 0.45, H * 0.56), 20, "3a4a2a", "c89070", "relaxed",
            (1, -0.3), "fff0c0", "905040", hand_angle=-2.6)
        photo.a[..., :3] = photo.a[..., :3] * 0.85 + np.array([0.12, 0.07, 0.02])
        mid.paint(ph, photo.a)
        mid.paint(text_mask(mid, W * 0.3, H * 0.83, "T & A.V.  -  Yermo, '86", 15, F_SCRIPT, "lm", 2), "2a2a48", 0.9)
        out("polaroid", "mid", mid)
