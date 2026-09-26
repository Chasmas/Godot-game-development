"""
Locations with people standing in them, drawn in perspective: a ground
plane that recedes to a horizon, cars and people scaled by how far away
they stand, feet on the ground, and the busy part of the frame kept above
the dialogue box (the bottom third).

Imported by gen_shots.py.
"""
import math
import numpy as np
from paint import *
from props import *
from anatomy import *

def register(shot, out, W, H, motel_building):

    HOR = H * 0.5          # where the lot meets the building line

    def depth_scale(y):
        """How big something standing with its feet at y is (1 at the horizon
        line ~ building base, growing toward the camera)."""
        return 0.55 + (y - HOR) / (H - HOR) * 1.6

    def lot(L, vp, top, col0, col1, lines="d8c890", wet=True):
        g = rect(L, 0, top, W, H - top)
        L.vgrad([(0, col0), (1, col1)], top, H, mask=g)
        n = value_noise(W, H, 4, 13, 3)
        L.multiply(g * blur(np.clip((n - 0.5) * 2, 0, 1), 2), "000000", 0.12)   # patched asphalt
        for k in range(-7, 9):
            x_far = vp[0] + k * 26
            x_near = vp[0] + k * 150
            L.paint(line(L, [(x_far, top + 2), (x_near, H + 40)], 1.2) * g, lines, 0.28)
        L.paint(line(L, [(0, top + 20), (W, top + 20)], 1.2), lines, 0.22)
        if wet:
            puddles = blur(np.clip((value_noise(W, H, 30, 5, 1) - 0.66) * 6, 0, 1), 3) * g * (L.yy > top + 30)
            L.add(puddles, col("283048"), 0.18)
        return g

    def cruiser(L, x, y, w, facing=1, lightbar=True):
        """Police car: white with a black stripe, lightbar, pushbar, door star."""
        car_side(L, x, y, w, "e0e0e8", glass="10141c", rimc="c0c8ff")
        s = w / 200.0
        L.paint(rect(L, x + 4 * s, y - 24 * s, 192 * s, 6 * s), "121418")
        L.paint(poly(L, star_pts(x + 118 * s, y - 16 * s, 6 * s, 2.5 * s)), "d8b040")
        L.paint(text_mask(L, x + 70 * s, y - 13 * s, "POLICE", max(4, int(9 * s)), F_BOLD, "mm"), "121418")
        if lightbar:
            L.paint(rect(L, x + 90 * s, y - 58 * s, 40 * s, 6 * s), "18181e")
            L.paint(rect(L, x + 91 * s, y - 57 * s, 18 * s, 4 * s), "a01020")
            L.paint(rect(L, x + 111 * s, y - 57 * s, 18 * s, 4 * s), "1030a0")
        L.paint(rect(L, x + (196 * s if facing > 0 else -8 * s), y - 22 * s, 8 * s, 14 * s), "18181e")   # pushbar

    def sawhorse(L, x, y, s):
        for dx in (-10, 10):
            L.paint(line(L, [(x + dx * s, y), (x + dx * s * 0.7, y - 16 * s)], 2 * s), "3a3a40")
        b = rect(L, x - 14 * s, y - 20 * s, 28 * s, 5 * s)
        L.paint(b, "f0f0f0")
        for k in range(4):
            L.paint(poly(L, [(x - 14 * s + k * 7 * s, y - 20 * s), (x - 11 * s + k * 7 * s, y - 20 * s), (x - 14 * s + k * 7 * s + 4 * s, y - 15 * s), (x - 17 * s + k * 7 * s + 4 * s, y - 15 * s)]) * b, "e04010")

    # ------------------------------------------------------------ SUNSET PALMS, AFTER
    @shot
    def motel_crime():
        """The morning after: cruisers in the lot, tape, officers, a gold star on 204."""
        bg = Layer(W, H)
        bg.vgrad([(0, "0e1224"), (0.5, "2a2a4a"), (0.75, "8a5a70"), (1, "c08070")], 0, HOR)
        bg.radial(W * 0.2, HOR, 200, "ffb090", 1.6, 0.25, 0.5)
        ridge(bg, H * 0.3, 14, 62, "1a1428", 60)
        out("motel_crime", "bg", bg)

        mid = Layer(W, H)
        motel_building(mid, lit=False, oy=-0.26, sign=False)
        # the star painted on 204 (upstairs, fourth door)
        x = W * (0.09 + 3 * 0.086)
        st = poly(mid, star_pts(x + 7, H * (0.38 - 0.26) + 11, 10, 4))
        mid.paint(st, "e8b830")
        mid.add(blur(st, 3), col("ffc040"), 0.45)
        # a Sunset Palms sign on its pole at the right, the lot in perspective
        mid.paint(rect(mid, W * 0.88, H * 0.1, 4, HOR - H * 0.1), "140a14")
        sg = rect(mid, W * 0.82, H * 0.02, W * 0.15, H * 0.12)
        mid.paint(sg, "1a0a18")
        mid.paint(text_mask(mid, W * 0.895, H * 0.06, "SUNSET", 9, F_DISPLAY, "mm"), "8a4a30")
        mid.paint(text_mask(mid, W * 0.895, H * 0.11, "PALMS", 9, F_DISPLAY, "mm"), "8a2a4a")
        vp = (W * 0.46, HOR)
        lot(mid, vp, HOR, "2a2830", "0c0a0e")
        # cruisers: one parked at the building, one nosed in closer
        cruiser(mid, W * 0.05, H * 0.6, 125)
        cruiser(mid, W * 0.54, H * 0.66, 165, facing=-1)
        # crime tape between the sign pole and a sawhorse, sagging
        sawhorse(mid, W * 0.44, H * 0.63, 0.9)
        tape = line(mid, smooth([(W * 0.0, H * 0.55), (W * 0.2, H * 0.575), (W * 0.44, H * 0.565), (W * 0.7, H * 0.58), (W * 0.89, H * 0.56)], 8, False), 2.5)
        mid.paint(tape, "f0d020")
        for i in range(10):
            mid.paint(text_mask(mid, W * (0.02 + i * 0.09), H * (0.566 + 0.006 * math.sin(i)), "POLICE LINE", 3, F_BOLD, "lm") * tape, "101010")
        # officers standing in the lot, feet on the asphalt, scaled by distance
        for fx_, fy, pose, cap, facing, coat, jacket in (
                (W * 0.3, H * 0.62, "hands_pockets", "1a2440", 1, False, "1a2440"),
                (W * 0.37, H * 0.64, "cross", "1a2440", -1, False, "1a2440"),
                (W * 0.78, H * 0.63, "hands_pockets", None, -1, True, "4a4238")):
            h = 48 * depth_scale(fy)
            figure(mid, fx_, fy, h, jacket, skin="c09070", light=(-1, -0.3), light_col="a0b0ff", fill_col="ff3040",
                   pose=pose, cap=cap, coat=coat, facing=facing)
        # a flashlight beam from the detective toward 204
        light_cone(mid, (W * 0.75, H * 0.5), (W * 0.33, H * 0.1), (W * 0.4, H * 0.2), "fff4d0", 0.12, 4)
        out("motel_crime", "mid", mid)
        # the lightbars' glow: on the cars, washing the wall, and in the puddles
        for layer, c, dx in (("red", "ff2030", 0), ("blue", "2050ff", 20)):
            L = Layer(W, H)
            for cx_, cy_, w in ((W * 0.05, H * 0.6, 125), (W * 0.54, H * 0.66, 165)):
                s = w / 200.0
                lx = cx_ + (100 + dx) * s
                ly = cy_ - 55 * s
                L.radial(lx, ly, 34 * s * 2, c, 1.4, 0.9)
                L.radial(lx, ly - 20, 150, c, 2.0, 0.18, 0.6)                 # on the building
                L.radial(lx, cy_ + 20 * s, 60, c, 1.6, 0.25, 0.25)            # reflection on the wet lot
            out("motel_crime", layer, L)

    # ------------------------------------------------------------ BARSTOW PD
    @shot
    def barstow_pd():
        """1991. Barstow PD at night. Officer Dana Pruitt, smoking by the steps."""
        bg = Layer(W, H)
        bg.vgrad([(0, "05060e"), (0.6, "121a2a"), (1, "2a3040")], 0, HOR)
        stars(bg, 60, 0.3, 17, 0.6)
        bg.radial(W * 0.82, H * 0.08, 14, "e8f0ff", 2.0, 0.9)
        ridge(bg, H * 0.3, 10, 23, "0c1018", 70)
        # telephone poles and wires across the sky
        for px in (W * 0.03, W * 0.97):
            bg.paint(line(bg, [(px, HOR), (px, H * 0.03)], 3), "07080c")
            bg.paint(line(bg, [(px - 12, H * 0.07), (px + 12, H * 0.07)], 2), "07080c")
        for k in range(3):
            bg.paint(line(bg, smooth([(W * 0.03, H * (0.07 + k * 0.012)), (W * 0.5, H * (0.14 + k * 0.012)), (W * 0.97, H * (0.07 + k * 0.012))], 8, False), 1), "07080c", 0.8)
        out("barstow_pd", "bg", bg)

        mid = Layer(W, H)
        # the station: stucco two storeys, flat roof with a parapet, a canopy
        bx0, bx1, by0, by1 = W * 0.1, W * 0.9, H * 0.12, HOR
        body = rect(mid, bx0, by0, bx1 - bx0, by1 - by0)
        mid.vgrad([(0, "5a5a62"), (1, "2a2a32")], by0, by1, mask=body)
        stucco = value_noise(W, H, 2, 31, 1)
        mid.multiply(body * (stucco > 0.7), "4a4a54", 0.12)
        stains = blur(np.clip((value_noise(W, H, 24, 8, 2) - 0.6) * 3, 0, 1), 2) * np.clip((mid.yy - by0) / 60.0, 0, 1)
        mid.multiply(body * stains, "2a2420", 0.18)   # water stains running down
        mid.paint(rect(mid, bx0 - 4, by0 - 5, bx1 - bx0 + 8, 6), "3a3a42")                                       # parapet
        mid.paint(rect(mid, bx0 - 4, by0 - 5, bx1 - bx0 + 8, 1.5), "8a8a98")
        # windows: two rows, a few lit (the night shift), blinds half down
        for row, wy in ((0, by0 + 12), (1, by0 + 50)):
            for k in range(8):
                if 3 <= k <= 4 and row == 1:
                    continue      # the entrance
                wx = bx0 + 16 + k * (bx1 - bx0 - 32) / 7.6
                w_ = rect(mid, wx, wy, 26, 22)
                lit = (k * 3 + row) % 4 == 1
                mid.paint(w_, "ffe0a0" if lit else "10141c")
                if lit:
                    for b in range(5):
                        mid.paint(rect(mid, wx, wy + b * 3, 26, 1.5), "b89a60")
                    mid.radial(wx + 13, wy + 11, 22, "ffd890", 1.5, 0.3)
                mid.paint(np.clip(rect(mid, wx - 2, wy - 2, 30, 26) - w_, 0, 1), "1a1a20")
                mid.paint(rect(mid, wx - 2, wy + 22, 30, 2), "6a6a74")                 # sill
        # entrance: canopy with the lettering, glass doors lit from inside, globes
        ex = W * 0.5
        mid.paint(rect(mid, ex - 44, by0 + 44, 88, 6), "1a1a22")
        glow_text(mid, ex, by0 + 38, "BARSTOW  POLICE  DEPT.", 10, F_BOLD, "e8eeff", 0.35, "mm")
        door = rect(mid, ex - 30, by0 + 52, 60, by1 - by0 - 58)
        mid.vgrad([(0, "c8e0ff"), (1, "5a7aa0")], by0 + 52, by1, mask=door)
        mid.paint(rect(mid, ex - 1, by0 + 52, 2, by1 - by0 - 58), "1a1a22")
        mid.paint(rect(mid, ex - 30, by0 + 80, 60, 2), "8a8a98")
        mid.radial(ex, by1 - 10, 110, "a0c8ff", 1.6, 0.25, 0.5)
        for gx in (ex - 44, ex + 44):
            mid.paint(rect(mid, gx - 1, by0 + 56, 2, 16), "18181e")
            mid.paint(ellipse(mid, gx, by0 + 54, 6, 6), "4060ff")
            mid.radial(gx, by0 + 54, 20, "4060ff", 1.4, 0.7)
            mid.paint(text_mask(mid, gx, by0 + 54, "P", 5, F_BOLD, "mm"), "e8eeff")
        # steps and the sidewalk
        for k in range(3):
            mid.paint(rect(mid, ex - 40 - k * 6, by1 + k * 3, 80 + k * 12, 3), ["8a8a94", "7a7a84", "6a6a74"][k])
        # flagpole and a limp flag
        mid.paint(line(mid, [(W * 0.2, by1), (W * 0.2, H * 0.02)], 1.5), "a0a0a8")
        flag = spoly(mid, [(W * 0.2, H * 0.03), (W * 0.26, H * 0.04), (W * 0.255, H * 0.08), (W * 0.2, H * 0.09)])
        mid.paint(flag, "7a2030")
        for k in range(3):
            mid.paint(line(mid, [(W * 0.2, H * (0.045 + k * 0.016)), (W * 0.257, H * (0.052 + k * 0.014))], 1) * flag, "e8e0d8", 0.8)
        mid.paint(rect(mid, W * 0.2, H * 0.03, W * 0.025, H * 0.028) * flag, "1a2a5a")
        # palms either side of the building
        palm(mid, W * 0.06, HOR + 4, 150, "080a10", 0.04, 12, "8090b0")
        palm(mid, W * 0.95, HOR + 4, 130, "080a10", -0.05, 13, "8090b0")
        # the lot in perspective, a street lamp, cruisers parked in rows
        vp = (W * 0.5, HOR)
        lot(mid, vp, HOR + 10, "22242c", "08080c")
        mid.paint(rect(mid, 0, HOR + 8, W, 3), "6a6a74")                                           # curb
        mid.paint(line(mid, [(W * 0.72, H * 0.72), (W * 0.72, H * 0.2)], 2.5), "0a0a10")
        mid.paint(line(mid, [(W * 0.72, H * 0.2), (W * 0.66, H * 0.19)], 2), "0a0a10")
        mid.radial(W * 0.66, H * 0.2, 10, "ffd8a0", 1.4, 1.0)
        light_cone(mid, (W * 0.66, H * 0.2), (W * 0.52, H * 0.72), (W * 0.8, H * 0.72), "ffd8a0", 0.2, 5)
        cruiser(mid, W * 0.04, H * 0.63, 130, lightbar=True)
        cruiser(mid, W * 0.58, H * 0.66, 150, facing=-1)
        # Dana by the steps: long coat, hands in pockets, cigarette smoke rising
        fy = H * 0.62
        figure(mid, W * 0.38, fy, 52 * depth_scale(fy), "4a4034", pants="1a1a22", skin="e0a888", hair="6a4a2a",
               light=(1, -0.3), light_col="ffd8a0", fill_col="ff3040", pose="hands_pockets", coat=True,
               hair_style="long", facing=1)
        out("barstow_pd", "mid", mid)
        red = Layer(W, H)
        s = 150 / 200.0
        red.radial(W * 0.58 + 100 * s, H * 0.66 - 55 * s, 50, "ff2030", 1.3, 0.8)
        red.radial(W * 0.58 + 100 * s, H * 0.55, 180, "ff2030", 2.0, 0.15, 0.6)
        red.radial(W * 0.58 + 100 * s, H * 0.72, 70, "ff2030", 1.6, 0.25, 0.25)
        out("barstow_pd", "red", red)
