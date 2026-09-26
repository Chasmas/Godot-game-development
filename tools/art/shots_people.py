"""
The close shots with people in them, v3: 80s poster style. Flat cel colour,
ink outlines, twin neon rims, synthwave skies - and no hands or arms, the
characters read from their silhouettes (see retro.py for the cast).

Every close-up is still painted three times (rest / _blink / _talk) so the
game can blink the eyes and move the mouth while that character speaks
(see StoryShot "face").

Imported by gen_shots.py; each @shot here replaces the older version.
"""
import math
import numpy as np
from paint import *
from props import *
from retro import *

def register(shot, out, W, H):
    """Define the shots against gen_shots' registry and canvas."""

    def faces(name, layer, paint_fn):
        for suffix, kw in (("", {}), ("_blink", {"blink": True}), ("_talk", {"talk": True})):
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

    def sunset_bg(L, sun_x, sun_y, sun_r, horizon, seed=1, grid=True, palms=True):
        synth_sky(L, 0, horizon)
        stars(L, 90, horizon / H * 0.8, seed, 0.7)
        synth_sun(L, sun_x, sun_y, sun_r)
        ridge(L, horizon, 14, seed + 3, "2a0a3a", 80, PINK)
        if grid:
            synth_grid(L, horizon, sun_x)
        if palms:
            palm(L, W * 0.06, horizon + 6, 120, "0a0412", -0.15, seed, PINK)
            palm(L, W * 0.95, horizon + 10, 150, "0a0412", 0.2, seed + 1, CYAN)

    # ------------------------------------------------------------ PROLOGUE
    @shot
    def cass_close():
        """Cass on set, 1987: aviators on, the big hair, the red leather,
        a synthwave sunset on the backdrop behind her."""
        bg = Layer(W, H)
        sunset_bg(bg, W * 0.66, H * 0.52, 78, H * 0.68, 3)
        bokeh(bg, 16, 3, ["fff0d0", "ffb080", "ff6a9a"], H * 0.02, H * 0.4, 4, 14, 0.25)
        out("cass_close", "bg", bg)

        def paint(**kw):
            L = Layer(W, H)
            bust(L, W * 0.36, H * 0.38, 44, CAST["cass"], aviators=True, lx=1.0, **kw)
            return L
        faces("cass_close", "fg", paint)
        fx = Layer(W, H)
        flare(fx, W * 0.66, H * 0.42, "ffd8b0", 300, 0.35)
        fx.add(blur(poly(fx, [(W, 0), (W, H * 0.5), (W * 0.7, 0)]), 20), col("ff6a4a"), 0.18)   # light leak
        out("cass_close", "flare", fx)

    @shot
    def tommy_car():
        """Tommy at the wheel, seen from the passenger seat: he looks ahead
        down the road (screen left), the desert night slides by in the
        window behind him, the dash lights his face cyan."""
        bg = Layer(W, H)
        hz = H * 0.62
        synth_sky(bg, 0, hz, "05021a", "2a0848", "a0206a", "ff7040")
        stars(bg, 90, 0.5, 21, 0.8)
        synth_sun(bg, W * 0.72, hz - 8, 46, 6)
        ridge(bg, hz, 18, 31, "1a0626", 70, PINK)
        bg.vgrad([(0, "1a0820"), (1, "060208")], hz, H, mask=(bg.yy >= hz).astype(np.float32))
        # telephone poles streaking past
        for i, px in enumerate((0.3, 0.55, 0.88)):
            bg.paint(line(bg, [(W * px, hz + 4), (W * px, hz - 70 - i * 6)], 3), "0a0410")
            bg.paint(line(bg, [(W * px - 12, hz - 62 - i * 6), (W * px + 12, hz - 62 - i * 6)], 2), "0a0410")
        bg.paint(line(bg, [(0, hz - 58), (W * 0.3, hz - 64), (W * 0.55, hz - 62), (W * 0.88, hz - 70), (W, hz - 66)], 1), "0a0410", 0.8)
        out("tommy_car", "bg", bg)

        cx, cy, s = W * 0.56, H * 0.4, 40
        def paint(**kw):
            L = Layer(W, H)
            c = dict(CAST["tommy"], turn=-0.82)
            bust(L, cx, cy, s, c, lx=-1.0, **kw)
            return L
        faces("tommy_car", "mid", paint)

        fg = Layer(W, H)
        # the cabin frames him: windshield on the left, roof, B-pillar behind
        # him, the door and window sill along the bottom
        roof = poly(fg, [(0, 0), (W, 0), (W, 26), (W * 0.3, 30), (0, 22)])
        fg.paint(roof, "0c0610")
        fg.paint(rim(roof, 0, 1, 1), CYAN, 0.35)
        wsh = poly(fg, [(0, 22), (W * 0.2, 28), (W * 0.1, H * 0.7), (0, H * 0.72)])
        fg.paint(wsh, "35e0ff", 0.06)                                          # windshield glass
        apil = poly(fg, [(W * 0.18, 26), (W * 0.24, 28), (W * 0.14, H * 0.72), (W * 0.08, H * 0.72)])
        fg.paint(apil, "0c0610")
        fg.paint(rim(apil, 1, 0, 1), PINK, 0.5)
        bpil = poly(fg, [(W * 0.86, 26), (W * 0.94, 26), (W * 0.97, H * 0.72), (W * 0.9, H * 0.72)])
        fg.paint(bpil, "0c0610")
        fg.paint(rim(bpil, -1, 0, 1), CYAN, 0.5)
        fg.paint(poly(fg, [(W * 0.94, 26), (W, 26), (W, H), (W * 0.97, H)]), "120a18")
        door = poly(fg, [(W * 0.08, H * 0.72), (W, H * 0.7), (W, H), (0, H), (0, H * 0.73)])
        fg.vgrad([(0, "2a1830"), (1, "0a060c")], H * 0.7, H, mask=door)
        fg.paint(rim(door, 0, -1, 1), PINK, 0.6)
        fg.paint(line(fg, [(W * 0.3, H * 0.82), (W * 0.8, H * 0.8)], 2), "3a2a44")      # door trim
        # the top of the wheel in front of him (hands below frame), dash glow
        wc = (W * 0.36, H * 1.08)
        ring = np.clip(ellipse(fg, wc[0], wc[1], 44, 62) - ellipse(fg, wc[0], wc[1], 37, 55), 0, 1) * (fg.yy < H * 0.99)
        fg.paint(ring, "120c16")
        fg.paint(rim(ring, 1, -1, 1), CYAN, 0.8)
        fg.radial(W * 0.2, H * 0.95, 170, CYAN, 1.8, 0.3)
        # rear-view mirror up on the windshield
        rv = spoly(fg, [(W * 0.2, H * 0.1), (W * 0.33, H * 0.095), (W * 0.33, H * 0.16), (W * 0.2, H * 0.165)])
        fg.paint(rv, "1a1820")
        fg.paint(spoly(fg, [(W * 0.21, H * 0.11), (W * 0.32, H * 0.105), (W * 0.32, H * 0.15), (W * 0.21, H * 0.155)]), "3a1a4a")
        fg.add(ellipse(fg, W * 0.23, H * 0.125, 3, 2, blur=1), col("ff80c0"), 0.8)
        fg.paint(line(fg, [(W * 0.265, 20), (W * 0.265, H * 0.1)], 2), "0c0610")
        out("tommy_car", "fg", fg)
        # the air freshener: a little gold star on a string
        ch = Layer(W, H)
        ch.paint(line(ch, [(W * 0.265, H * 0.165), (W * 0.265, H * 0.27)], 1), "d8d0c0")
        st = poly(ch, star_pts(W * 0.265, H * 0.3, 9, 4))
        ch.paint(st, "e8b830")
        ch.paint(rim(st, -1, -1, 1), "fff0a0", 0.8)
        out("tommy_car", "charm", ch)

    # ------------------------------------------------------------ VAN NUYS
    @shot
    def mirror():
        """The gold star on her cheek, ponytail up, vanity bulbs - and a
        message in lipstick on the glass."""
        bg = Layer(W, H)
        bg.vgrad([(0, "2a0a3a"), (1, "0a0414")], 0, H)
        tiles = ((np.mod(bg.xx, 18) < 1) | (np.mod(bg.yy, 18) < 1)).astype(np.float32)
        bg.add(tiles, col(CYAN), 0.08)
        bg.radial(W * 0.5, H * 0.02, 280, "ff80c0", 1.7, 0.25)
        out("mirror", "bg", bg)

        cx, cy, s = W * 0.5, H * 0.42, 40
        def paint(**kw):
            L = Layer(W, H)
            frame = rect(L, W * 0.16, H * 0.1, W * 0.68, H * 0.8)
            glass = rect(L, W * 0.18, H * 0.13, W * 0.64, H * 0.74)
            L.vgrad([(0, "f0d0e8"), (1, "6a4a7a")], H * 0.1, H * 0.9, mask=frame)
            L.paint(rim(frame, 0, -1, 1), "ffffff", 0.6)
            refl = Layer(W, H)
            refl.vgrad([(0, "3a1450"), (0.7, "a02a6a"), (1, "ff6a5a")], H * 0.13, H * 0.87)
            # a neon sign behind her, reversed in the glass
            glow_text(refl, W * 0.7, H * 0.25, "NUYS", 18, F_DISPLAY, CYAN, 0.8, "mm")
            refl.paint(rect(refl, W * 0.22, H * 0.28, W * 0.1, H * 0.03), "e0c0e0")
            refl.paint(rect(refl, W * 0.23, H * 0.3, W * 0.08, H * 0.16), "c01830")
            bust(refl, cx, cy, s, CAST["cass"], hair_style="ponytail", star=True, lx=-1.0, **kw)
            L.paint(glass, refl.a)
            # steam at the edges, streaks on the glass
            d = np.minimum(np.minimum(L.xx - W * 0.18, W * 0.82 - L.xx), np.minimum(L.yy - H * 0.13, H * 0.87 - L.yy))
            steam = np.clip(1 - d / 26.0, 0, 1) * glass * (0.6 + 0.4 * value_noise(W, H, 10, 3, 3))
            L.add(steam, col("f0d0ff"), 0.35)
            for i in range(4):
                L.add(glass * blur(line(L, [(W * (0.25 + i * 0.16), H * 0.14), (W * (0.19 + i * 0.16), H * 0.86)], 5), 5), col("ffffff"), 0.06)
            # lipstick on the mirror
            L.paint(text_mask(L, W * 0.2, H * 0.66, "break a leg", 18, F_SCRIPT, "lm", 10) * glass, "e0203a", 0.9)
            return L
        faces("mirror", "mid", paint)
        fg = Layer(W, H)
        sink = spoly(fg, [(W * 0.08, H * 0.88), (W * 0.92, H * 0.88), (W * 0.97, H), (W * 0.03, H)])
        fg.vgrad([(0, "f0e0f0"), (1, "7a6a88")], H * 0.88, H, mask=sink)
        fg.paint(rim(sink, 0, -1, 1), "ffffff", 0.7)
        fg.paint(outline(sink, 1.0), INK, 0.8)
        tin = ellipse(fg, W * 0.74, H * 0.91, 17, 6)
        fg.paint(tin, "c89420")
        fg.paint(ellipse(fg, W * 0.74, H * 0.905, 13, 4.5), "f0c040")
        fg.paint(rim(tin, 0, -1, 1), "fff0a0", 0.8)
        lip = rect(fg, W * 0.3, H * 0.84, 7, 18)
        fg.paint(lip, "d8b060")
        fg.paint(rect(fg, W * 0.3 + 1, H * 0.8, 5, 8), "e0203a")
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
        """Van Nuys, 9:12 PM. Cass on the couch behind the coffee table, head
        turned to the blinking machine, her own movie poster on the wall,
        pink neon through the blinds."""
        bg = Layer(W, H)
        bg.vgrad([(0, "1e0c2a"), (1, "0a0512")], 0, H)
        stripes = (np.mod(bg.xx, 12) < 6).astype(np.float32) * (bg.yy < H * 0.62)
        bg.add(stripes, col("5a1a6a"), 0.06)                                   # wallpaper
        # window with blinds, neon outside
        wx, wy, ww, wh = W * 0.62, H * 0.08, W * 0.3, H * 0.44
        win = rect(bg, wx, wy, ww, wh)
        bg.vgrad([(0, "3a0a50"), (0.6, "c0206a"), (1, "ff7040")], wy, wy + wh, mask=win)
        glow_text(bg, wx + ww * 0.5, wy + wh * 0.55, "MOTEL", 20, F_BOLD, PINK, 1.0, "mm")
        for i in range(18):
            bg.paint(rect(bg, wx, wy + i * wh / 18, ww, wh / 36), "1a0a20")
        bg.paint(np.clip(rect(bg, wx - 4, wy - 4, ww + 8, wh + 8) - win, 0, 1), "2a1a30")
        bg.radial(wx + ww * 0.5, wy + wh * 0.5, 220, PINK, 1.6, 0.25)
        # the HOTSHOT poster: synthwave sun, her car, her name
        px, py, pw, ph = W * 0.05, H * 0.07, W * 0.17, H * 0.42
        pr = rect(bg, px, py, pw, ph)
        poster = Layer(W, H)
        poster.vgrad([(0, "1a0630"), (0.6, "a01860"), (1, "ff9040")], py, py + ph)
        synth_sun(poster, px + pw * 0.5, py + ph * 0.55, pw * 0.34, 5)
        glow_text(poster, px + pw * 0.5, py + ph * 0.14, "HOTSHOT", 14, F_DISPLAY, GOLD, 0.6, "mm")
        car_side(poster, px + pw * 0.12, py + ph * 0.8, pw * 0.76, "b01020")
        poster.paint(text_mask(poster, px + pw * 0.5, py + ph * 0.93, "C. MORENO", 6, F_MONO, "mm"), "fff0e0", 0.8)
        bg.paint(pr, poster.a)
        bg.paint(outline(pr, 1), INK, 0.9)
        # floor lamp, warm, low
        bg.paint(line(bg, [(W * 0.55, H * 0.64), (W * 0.55, H * 0.26)], 2), "100a0c")
        shade = poly(bg, [(W * 0.525, H * 0.26), (W * 0.575, H * 0.26), (W * 0.585, H * 0.18), (W * 0.515, H * 0.18)])
        bg.paint(shade, "e0a070")
        light_cone(bg, (W * 0.55, H * 0.25), (W * 0.45, H * 0.64), (W * 0.66, H * 0.64), "ffc080", 0.16, 6)
        fl = rect(bg, 0, H * 0.62, W, H)
        bg.vgrad([(0, "2a1030"), (1, "0a0410")], H * 0.62, H, mask=fl)
        out("apartment", "bg", bg)

        def paint(**kw):
            mid = Layer(W, H)
            # couch back behind her
            back = spoly(mid, [(W * 0.1, H * 0.44), (W * 0.56, H * 0.42), (W * 0.58, H * 0.7), (W * 0.08, H * 0.72)])
            mid.vgrad([(0, "6a2a7a"), (1, "2a0e36")], H * 0.42, H * 0.72, mask=back)
            mid.paint(rim(back, 1, -1, 1), PINK, 0.7)
            mid.paint(outline(back, 1), INK, 0.9)
            bust(mid, W * 0.33, H * 0.36, 30, dict(CAST["cass"], turn=0.55), lx=1.0, aviators_up=True, **kw)
            # coffee table in front: ashtray, bottles, the package
            tbl = spoly(mid, [(W * 0.08, H * 0.74), (W * 0.62, H * 0.73), (W * 0.66, H * 0.84), (W * 0.05, H * 0.85)])
            mid.vgrad([(0, "5a3020"), (1, "1a0c08")], H * 0.73, H * 0.85, mask=tbl)
            mid.paint(rim(tbl, 0, -1, 1), "ffb070", 0.6)
            mid.paint(outline(tbl, 1), INK, 0.9)
            mid.paint(rect(mid, W * 0.1, H * 0.85, 6, H * 0.15) + rect(mid, W * 0.6, H * 0.84, 6, H * 0.16), "1a0c08")
            mid.paint(ellipse(mid, W * 0.18, H * 0.745, 13, 4), "6a6a74")
            mid.paint(line(mid, [(W * 0.17, H * 0.74), (W * 0.2, H * 0.735)], 1.2), "e8e0d0")
            mid.radial(W * 0.2, H * 0.735, 3, "ff6020", 1.2, 1.0)
            for i, (bx, c) in enumerate(((0.26, "2a8a4a"), (0.29, "8a5a20"))):
                b = rect(mid, W * bx, H * 0.66, 7, 20)
                mid.paint(b, c)
                mid.paint(rect(mid, W * bx + 2, H * 0.63, 3, 7), c)
                mid.paint(rim(b, 1, -1, 1), "ffb0d0", 0.7)
                mid.paint(outline(b, 0.8), INK, 0.8)
            pk = rect(mid, W * 0.44, H * 0.65, 38, 24)
            mid.vgrad([(0, "c09050"), (1, "6a4a2a")], H * 0.65, H * 0.73, mask=pk)
            mid.paint(rect(mid, W * 0.44 + 17, H * 0.65, 4, 24), GOLD)
            mid.paint(outline(pk, 0.8), INK, 0.8)
            # side table with the answering machine
            mid.paint(rect(mid, W * 0.64, H * 0.6, W * 0.13, 5), "3a2018")
            mid.paint(rect(mid, W * 0.65, H * 0.61, 3, H * 0.22) + rect(mid, W * 0.76, H * 0.61, 3, H * 0.22), "1a0e0a")
            am = spoly(mid, [(W * 0.655, H * 0.565), (W * 0.745, H * 0.565), (W * 0.75, H * 0.6), (W * 0.65, H * 0.6)])
            mid.paint(am, "1a1a22")
            mid.paint(rim(am, 1, -1, 1), PINK, 0.6)
            return mid
        faces("apartment", "mid", paint)
        led = Layer(W, H)
        led.radial(W * 0.735, H * 0.58, 6, "ff2020", 1.2, 1.0)
        out("apartment", "led", led)
        # the ceiling fan: three frames of the blades turning
        for f in range(3):
            fan = Layer(W, H)
            hub = (W * 0.4, H * 0.05)
            fan.paint(line(fan, [(hub[0], 0), hub], 2), "0a060c")
            for k in range(4):
                a = f * (math.pi / 6) + k * math.pi / 2
                dx, dy = math.cos(a), math.sin(a) * 0.22
                tip = (hub[0] + dx * 70, hub[1] + dy * 70)
                bl = poly(fan, [(hub[0] + dy * 20, hub[1] - dx * 3), tip, (tip[0] + dy * 18, tip[1] + 4), (hub[0] - dy * 10, hub[1] + 3)])
                fan.paint(bl, "120a10")
                fan.paint(rim(bl, 0, 1, 1), PINK, 0.4)
            fan.paint(ellipse(fan, hub[0], hub[1], 9, 4), "1a1216")
            out("apartment", "fan_%d" % f, fan)

    @shot
    def package():
        """The package on the table: gold greasepaint, the key to 204, the Polaroid."""
        bg = Layer(W, H)
        bg.vgrad([(0, "3a1830"), (1, "140818")], 0, H)
        wood = value_noise(W, H, 60, 12, 3)
        for i in range(14):
            bg.multiply(np.abs(np.sin((bg.yy + wood * 30) * 0.18 + i)) > 0.97, "1a0c16", 0.3)
        bg.radial(W * 0.45, H * 0.4, 300, "ff9070", 1.5, 0.4)
        bg.radial(W * 0.95, H * 0.1, 200, CYAN, 1.8, 0.2)
        bg.paint(np.clip(ellipse(bg, W * 0.86, H * 0.8, 20, 18) - ellipse(bg, W * 0.86, H * 0.8, 17, 15), 0, 1), "140804", 0.6)
        out("package", "bg", bg)
        mid = Layer(W, H)
        box = poly(mid, [(W * 0.08, H * 0.12), (W * 0.46, H * 0.08), (W * 0.49, H * 0.74), (W * 0.11, H * 0.78)])
        mid.vgrad([(0, "c89858"), (1, "7a5030")], H * 0.08, H * 0.78, mask=box)
        mid.paint(outline(box, 1), INK, 0.9)
        inner = poly(mid, [(W * 0.11, H * 0.18), (W * 0.44, H * 0.15), (W * 0.46, H * 0.7), (W * 0.14, H * 0.73)])
        crumple = blur(value_noise(W, H, 16, 21, 2), 1.5)
        mid.paint(inner, "b0a8a0", 0.95)
        paper = inner * np.clip((crumple - 0.35) * 2, 0, 1)
        mid.paint(paper, "d0c8c0", 0.9)
        mid.paint(inner * np.clip((crumple - 0.62) * 4, 0, 1), "f0e8e0", 0.8)
        mid.multiply(inner * np.clip((0.45 - crumple) * 4, 0, 1), "4a3050", 0.6)
        mid.paint(rect(mid, W * 0.26, H * 0.08, 10, H * 0.7) * box * (1 - inner), GOLD)
        tin = ellipse(mid, W * 0.28, H * 0.42, 34, 28)
        mid.vgrad([(0, "fff0a0"), (0.5, "e0a828"), (1, "8a5a10")], H * 0.42 - 28, H * 0.42 + 28, mask=tin)
        mid.paint(rim(tin, -1, -1, 1), "ffffff", 0.7)
        mid.paint(outline(tin, 1), INK, 0.9)
        mid.paint(poly(mid, star_pts(W * 0.28, H * 0.42, 16, 7)), "7a4a08", 0.8)
        mid.paint(text_mask(mid, W * 0.28, H * 0.58, "STAR GOLD", 8, F_BOLD, "mm"), "3a2a08", 0.8)
        kx, ky = W * 0.56, H * 0.66
        mid.paint(line(mid, [(kx, ky), (kx + 50, ky - 10)], 4), "d8c070")
        mid.paint(np.clip(ellipse(mid, kx - 6, ky + 1, 9, 9) - ellipse(mid, kx - 6, ky + 1, 4, 4), 0, 1), "d8c070")
        for t in range(4):
            mid.paint(rect(mid, kx + 38 + t * 3, ky - 8 + (t % 2) * 2, 2, 5), "d8c070")
        tag = poly(mid, [(kx + 46, ky - 30), (kx + 90, ky - 40), (kx + 100, ky - 14), (kx + 56, ky - 4)])
        mid.paint(tag, "c01830")
        mid.paint(outline(tag, 0.8), INK, 0.8)
        mid.paint(text_mask(mid, kx + 73, ky - 22, "204", 14, F_BOLD, "mm", 12), "fff0e0")
        # the Polaroid: Tommy under a synthwave sky
        pol = poly(mid, [(W * 0.6, H * 0.1), (W * 0.9, H * 0.14), (W * 0.86, H * 0.56), (W * 0.56, H * 0.51)])
        mid.paint(pol, "f4eee4")
        mid.paint(outline(pol, 1), INK, 0.7)
        ph = poly(mid, [(W * 0.62, H * 0.14), (W * 0.87, H * 0.175), (W * 0.845, H * 0.43), (W * 0.595, H * 0.395)])
        photo = Layer(W, H)
        synth_sky(photo, H * 0.14, H * 0.43)
        synth_sun(photo, W * 0.8, H * 0.36, 22, 4)
        bust(photo, W * 0.72, H * 0.27, 17, dict(CAST["tommy"], cig=False, turn=0.2), talk=True, rim_a=0.6, out_w=0.9)
        mid.paint(ph, photo.a)
        mid.paint(text_mask(mid, W * 0.62, H * 0.48, "A.V.  '87", 10, F_SCRIPT, "la", -8), "303048", 0.85)
        out("package", "mid", mid)

    # ------------------------------------------------------------ KHSC 9
    @shot
    def tv_news():
        """Channel 9 in a dark room: the anchor at his desk, the gold star
        graphic, the red LIVE bar."""
        bg = Layer(W, H)
        bg.vgrad([(0, "08040e"), (1, "10081a")], 0, H)
        bg.radial(W * 0.5, H * 0.45, 320, "3060c0", 1.6, 0.3)
        bg.paint(line(bg, [(W * 0.93, H), (W * 0.93, H * 0.4)], 2), "050507")
        bg.paint(poly(bg, [(W * 0.9, H * 0.4), (W * 0.96, H * 0.4), (W * 0.95, H * 0.33), (W * 0.91, H * 0.33)]), "050507")
        out("tv_news", "bg", bg)

        def paint(**kw):
            mid = Layer(W, H)
            cab = spoly(mid, [(W * 0.14, H * 0.06), (W * 0.86, H * 0.06), (W * 0.88, H * 0.92), (W * 0.12, H * 0.93)])
            mid.vgrad([(0, "4a2a1e"), (1, "1a100a")], 0, H, mask=cab)
            wood = value_noise(W, H, 50, 2, 3)
            mid.multiply(cab * (np.abs(np.sin(mid.xx * 0.05 + wood * 10)) > 0.9), "140a06", 0.4)
            mid.paint(outline(cab, 1.2), INK, 0.9)
            scr = spoly(mid, [(W * 0.2, H * 0.12), (W * 0.72, H * 0.11), (W * 0.73, H * 0.8), (W * 0.19, H * 0.81)])
            tv = Layer(W, H)
            tv.vgrad([(0, "1a2a7a"), (0.7, "3a1a6a"), (1, "a0206a")], H * 0.1, H * 0.8)
            for i in range(8):
                tv.add(line(tv, [(W * 0.19, H * (0.45 + i * 0.02)), (W * 0.73, H * (0.45 + i * 0.02))], 1), col(CYAN), 0.08)
            tv.radial(W * 0.62, H * 0.3, 90, GOLD, 1.4, 0.3)
            m = poly(tv, star_pts(W * 0.62, H * 0.3, 30, 12))
            tv.paint(m, GOLD)
            tv.paint(rim(m, 1, -1, 1), "ffffff", 0.7)
            tv.paint(outline(m, 1), INK, 0.8)
            glow_text(tv, W * 0.62, H * 0.47, "THE STAR KILLER?", 8, F_BOLD, "ffffff", 0.2, "mm")
            bust(tv, W * 0.37, H * 0.32, 26, CAST["anchor"], lx=1.0, **kw)
            desk = poly(tv, [(W * 0.19, H * 0.5), (W * 0.56, H * 0.49), (W * 0.57, H * 0.62), (W * 0.19, H * 0.63)])
            tv.vgrad([(0, "6a7ab0"), (1, "2a3460")], H * 0.49, H * 0.62, mask=desk)
            tv.paint(rim(desk, 0, -1, 1), CYAN, 0.8)
            tv.paint(outline(desk, 0.8), INK, 0.8)
            tv.paint(poly(tv, [(W * 0.3, H * 0.47), (W * 0.45, H * 0.465), (W * 0.46, H * 0.5), (W * 0.29, H * 0.505)]), "f0f0f0")
            lower = rect(tv, W * 0.19, H * 0.62, W * 0.54, H * 0.07)
            tv.paint(lower, "d01020")
            tv.paint(text_mask(tv, W * 0.21, H * 0.655, "LIVE  BARSTOW MOTEL MASSACRE", 10, F_BOLD, "lm"), "ffffff")
            tv.paint(text_mask(tv, W * 0.67, H * 0.19, "9", 20, F_DISPLAY, "mm"), "ffffff", 0.85)
            mid.paint(scr, tv.a)
            mid.add(scr * blur(scr, 1), col("a0c0ff"), 0.08)
            mid.paint(outline(scr, 1.2), INK, 0.9)
            for k in range(2):
                mid.paint(ellipse(mid, W * 0.8, H * (0.3 + k * 0.14), 10, 10), "a08a60")
                mid.paint(line(mid, [(W * 0.8, H * (0.3 + k * 0.14)), (W * 0.8 + 7, H * (0.3 + k * 0.14) - 5)], 1.5), "2a2010")
            for k in range(6):
                mid.paint(rect(mid, W * 0.77, H * (0.6 + k * 0.03), W * 0.07, 2), "0a0806")
            for a in (-0.5, 0.4):
                mid.paint(line(mid, [(W * 0.5, H * 0.06), (W * 0.5 + math.sin(a) * 80, H * 0.06 - math.cos(a) * 60)], 1.5), "c0c0c8")
            return mid
        faces("tv_news", "mid", paint)

    @shot
    def marv():
        """Marv Kessel at the stand mic, spotlight rays and the HOTSHOT neon:
        'She doesn't even know she's on.'"""
        bg = Layer(W, H)
        bg.vgrad([(0, "1a0624"), (1, "4a0a3a")], 0, H)
        for i in range(14):
            a = i / 14 * math.pi
            bg.add(blur(poly(bg, [(W * 0.5, H * 1.1), (W * 0.5 + math.cos(a) * W, H * 1.1 - math.sin(a) * W), (W * 0.5 + math.cos(a + 0.1) * W, H * 1.1 - math.sin(a + 0.1) * W)]), 3), col(GOLD if i % 2 else PINK), 0.12)
        glow_text(bg, W * 0.5, H * 0.13, "HOTSHOT", 44, F_DISPLAY, PINK, 0.8, "mm")
        glow_text(bg, W * 0.8, H * 0.27, "California", 20, F_SCRIPT, GOLD, 0.8, "mm", 6)
        for i in range(22):
            bg.radial(W * (0.02 + i * 0.047), H * 0.035, 5, "fff0c0", 1.5, 0.8)
        synth_grid(bg, H * 0.84, W * 0.5, CYAN, 6, 30, 0.5)
        out("marv", "bg", bg)
        cx, cy, s = W * 0.47, H * 0.42, 40
        def paint(**kw):
            L = Layer(W, H)
            bust(L, cx, cy, s, CAST["marv"], lx=1.0, **kw)
            # the stand mic in front of him: chrome capsule, stand to the floor
            mx, my = cx + 1.05 * s, cy + 1.2 * s
            stand = line(L, [(mx, my + 10), (mx + 4, H)], 3)
            L.paint(stand, "b0b0c0")
            L.paint(rim(stand, 1, 0, 1), "ffffff", 0.7)
            L.paint(outline(stand, 0.8), INK, 0.9)
            capsule = spoly(L, [(mx - 9, my - 12), (mx + 9, my - 12), (mx + 10, my + 6), (mx, my + 13), (mx - 10, my + 6)])
            L.vgrad([(0, "f0f0ff"), (0.5, "8080a0"), (1, "30304a")], my - 12, my + 13, mask=capsule)
            for k in range(4):
                L.paint(line(L, [(mx - 8, my - 8 + k * 5), (mx + 8, my - 8 + k * 5)], 1) * capsule, "30304a", 0.6)
            L.paint(rim(capsule, 1, -1, 1), GOLD, 0.8)
            L.paint(outline(capsule, 1), INK, 0.95)
            return L
        faces("marv", "mid", paint)

    @shot
    def polaroid():
        """'A.V.' Tommy and his stunt coordinator Arlo, 1986, in front of the
        car, a sunset behind them."""
        bg = Layer(W, H)
        bg.vgrad([(0, "2a1420"), (1, "0a0608")], 0, H)
        bg.radial(W * 0.5, H * 0.45, 260, "ff9080", 1.6, 0.35)
        out("polaroid", "bg", bg)
        mid = Layer(W, H)
        pol = poly(mid, [(W * 0.26, H * 0.08), (W * 0.76, H * 0.1), (W * 0.74, H * 0.94), (W * 0.24, H * 0.92)])
        mid.paint(pol, "f2ece0")
        mid.paint(outline(pol, 1.2), INK, 0.7)
        ph = poly(mid, [(W * 0.29, H * 0.13), (W * 0.73, H * 0.15), (W * 0.72, H * 0.72), (W * 0.28, H * 0.7)])
        photo = Layer(W, H)
        synth_sky(photo, H * 0.13, H * 0.56, "3a1a5a", "c04a7a", "ff8a50", "ffd070")
        synth_sun(photo, W * 0.5, H * 0.5, 44, 5)
        ridge(photo, H * 0.56, 10, 81, "6a2a4a", 60)
        photo.vgrad([(0, "c07a50"), (1, "6a3a2a")], H * 0.56, H * 0.72, mask=(photo.yy >= H * 0.56).astype(np.float32))
        car_side(photo, W * 0.3, H * 0.7, 150, "c01020")
        bust(photo, W * 0.41, H * 0.39, 28, dict(CAST["tommy"], cig=False, turn=0.3), talk=True, rim_a=0.5)
        bust(photo, W * 0.61, H * 0.41, 28, dict(CAST["arlo"], turn=-0.3, grin=True), rim_a=0.5)
        photo.a[..., :3] = photo.a[..., :3] * 0.86 + np.array([0.12, 0.06, 0.03])     # faded print
        mid.paint(ph, photo.a)
        mid.paint(text_mask(mid, W * 0.3, H * 0.83, "T & A.V.  -  Yermo, '86", 15, F_SCRIPT, "lm", 2), "2a2a48", 0.9)
        out("polaroid", "mid", mid)
