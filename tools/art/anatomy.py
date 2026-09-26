"""
Bodies for the painted shots: hands with real fingers, arms with volume,
and full figures with proper proportions. Everything is lit the same way
as face(): a warm key from one side, a cool fill from the other, a rim of
light along the edge that faces the key.
"""
import math
import numpy as np
from paint import *

INK = "0b0614"

def _rot(v, a):
    c, s = math.cos(a), math.sin(a)
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c)

def _lit_paint(L, m, base, light_col, fill_col, lx, ly, cx, cy, span, key=0.22, dark=0.45):
    """Fill mask m with base colour shaded across the shape: lit toward
    (lx, ly), in fill colour away from it."""
    d = ((L.xx - cx) * lx + (L.yy - cy) * ly) / max(span, 1.0)
    t = np.clip(d * 0.5 + 0.5, 0, 1)[..., None]
    lit = mix(base, light_col, key)
    shade = mix(base, fill_col, 0.35) * np.array([1 - dark, 1 - dark, 1 - dark * 0.8, 1])
    c = shade * (1 - t) + lit * t
    c[..., 3] = 1
    L.paint(m, c)

def limb(L, pts, w0, w1, color, light_col="ffd0a0", fill_col="3a2a6a", light=(1, -0.4), rimc=None):
    """A tapered limb (upper arm / forearm / leg) along pts, width w0 -> w1."""
    left, right = [], []
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        t = i / max(1, n - 1)
        w = (w0 * (1 - t) + w1 * t) * 0.5
        if i < n - 1:
            dx, dy = pts[i + 1][0] - x, pts[i + 1][1] - y
        else:
            dx, dy = x - pts[i - 1][0], y - pts[i - 1][1]
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / ln, dx / ln
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    m = poly(L, left + right[::-1])
    cx = sum(p[0] for p in pts) / n
    cy = sum(p[1] for p in pts) / n
    _lit_paint(L, m, color, light_col, fill_col, light[0], light[1], cx, cy, max(w0, w1))
    if rimc:
        L.paint(rim(m, int(np.sign(light[0])), int(np.sign(light[1])), 1), rimc, 0.8)
    return m

def hand(L, x, y, s, angle, pose="relaxed", skin="d8a080", light=(1, -0.4), light_col="ffd0a0",
         fill_col="3a2a6a", rimc=None, nails=None, tape=False):
    """A hand at wrist (x, y). s ~ palm length in px, angle = direction the
    fingers point (radians). Poses: relaxed, open, fist, grip (round an
    object), pinch (thumb + index, holding a brush / cigarette), point."""
    P = lambda vx, vy: (x + _rot((vx * s, vy * s), angle)[0], y + _rot((vx * s, vy * s), angle)[1])
    masks = []
    # palm: a rounded trapezoid from the wrist to the knuckles
    palm = spoly(L, [P(0.0, -0.32), P(0.55, -0.42), P(0.95, -0.38), P(1.0, 0.0), P(0.95, 0.4), P(0.55, 0.42), P(0.0, 0.3)])
    masks.append(palm)
    knuckles = [(-0.3, 0.05), (-0.1, 0.03), (0.1, 0.0), (0.3, -0.05)]   # index..pinky across the palm
    bend = {"relaxed": (0.35, 0.45), "open": (0.0, 0.05), "fist": (1.4, 1.5), "grip": (1.05, 1.1),
            "pinch": (0.9, 1.2), "point": (1.4, 1.5)}.get(pose, (0.35, 0.45))
    lengths = [0.62, 0.7, 0.66, 0.5]
    for i, (oy, ox) in enumerate(knuckles):
        b0, b1 = bend
        if pose == "point" and i == 0:
            b0, b1 = 0.0, 0.05
        if pose == "pinch" and i == 0:
            b0, b1 = 0.55, 0.6
        spread = (i - 1.5) * (0.14 if pose == "open" else 0.05)
        base = P(0.95 + ox, oy * 1.25)
        a0 = angle + spread + b0 * 0.9
        ln = lengths[i] * s
        mid = (base[0] + math.cos(a0) * ln * 0.55, base[1] + math.sin(a0) * ln * 0.55)
        a1 = a0 + b1 * 0.9
        tip = (mid[0] + math.cos(a1) * ln * 0.45, mid[1] + math.sin(a1) * ln * 0.45)
        fw = s * (0.2 if i < 3 else 0.17)
        f = np.clip(line(L, [base, mid, tip], fw), 0, 1)
        masks.append(f)
        if nails and b1 < 0.8:
            L.paint(ellipse(L, tip[0] - math.cos(a1) * fw * 0.3, tip[1] - math.sin(a1) * fw * 0.3, fw * 0.35, fw * 0.35), nails, 0.9)
    # thumb: out of the side of the palm near the wrist, along the fingers;
    # in a fist or grip it folds across the front of the fingers
    tb = P(0.25, -0.38)
    if pose in ("fist", "grip"):
        ta, ta2, l1, l2 = angle - 0.35, angle + 0.9, 0.42, 0.3
    elif pose == "pinch":
        ta, ta2, l1, l2 = angle - 0.45, angle + 0.25, 0.45, 0.35
    elif pose == "open":
        ta, ta2, l1, l2 = angle - 0.95, angle - 0.7, 0.42, 0.32
    else:
        ta, ta2, l1, l2 = angle - 0.6, angle - 0.2, 0.42, 0.32
    tm = (tb[0] + math.cos(ta) * s * l1, tb[1] + math.sin(ta) * s * l1)
    tt = (tm[0] + math.cos(ta2) * s * l2, tm[1] + math.sin(ta2) * s * l2)
    masks.append(np.clip(line(L, [tb, tm, tt], s * 0.25), 0, 1))
    m = np.clip(sum(masks), 0, 1)
    _lit_paint(L, m, skin, light_col, fill_col, light[0], light[1], x + math.cos(angle) * s * 0.6, y + math.sin(angle) * s * 0.6, s)
    # knuckle creases and the gaps between fingers
    for i in range(1, 4):
        a = P(0.95, -0.4 + i * 0.27)
        L.paint(line(L, [a, (a[0] + math.cos(angle) * s * 0.18, a[1] + math.sin(angle) * s * 0.18)], max(1, s * 0.04)), mix(skin, INK, 0.55), 0.5)
    L.paint(rim(m, int(np.sign(light[0])), int(np.sign(light[1])), 1), rimc or light_col, 0.5)
    if tape:
        L.paint(line(L, [P(0.8, -0.4), P(0.8, 0.4)], s * 0.18), "e8e0d0", 0.9)
    return m

def arm(L, shoulder, elbow, wrist, s, sleeve, skin="d8a080", pose="relaxed", light=(1, -0.4),
        light_col="ffd0a0", fill_col="3a2a6a", rimc=None, sleeve_to=0.85, hand_angle=None, nails=None, tape=False):
    """Shoulder -> elbow -> wrist, sleeved up to `sleeve_to` of the forearm,
    ending in a hand. s = upper-arm width."""
    limb(L, [shoulder, elbow], s, s * 0.85, sleeve, light_col, fill_col, light, rimc)
    cuff = (elbow[0] + (wrist[0] - elbow[0]) * sleeve_to, elbow[1] + (wrist[1] - elbow[1]) * sleeve_to)
    limb(L, [elbow, cuff], s * 0.85, s * 0.72, sleeve, light_col, fill_col, light, rimc)
    if sleeve_to < 1.0:
        limb(L, [cuff, wrist], s * 0.5, s * 0.45, skin, light_col, fill_col, light, rimc)
    L.paint(line(L, [(cuff[0] - (wrist[1] - elbow[1]) * 0.08, cuff[1] + (wrist[0] - elbow[0]) * 0.08),
                     (cuff[0] + (wrist[1] - elbow[1]) * 0.08, cuff[1] - (wrist[0] - elbow[0]) * 0.08)], max(1, s * 0.12)), mix(sleeve, INK, 0.4), 0.7)
    ang = hand_angle if hand_angle is not None else math.atan2(wrist[1] - elbow[1], wrist[0] - elbow[0])
    return hand(L, wrist[0], wrist[1], s * 0.95, ang, pose, skin, light, light_col, fill_col, rimc, nails, tape)

def figure(L, x, y, h, jacket, pants="1a1a22", skin="c89070", hair="1a1210", light=(1, -0.3), light_col="ffb080",
           fill_col="2a1a4a", facing=1, pose="stand", hair_style="short", coat=False, cap=None, holding=None, shadow=True):
    """A standing person, feet at (x, y), height h. Proportioned (~7.5 heads),
    lit and rimmed; arms and hands in a pose: stand, hands_pockets, gun,
    point, phone, cross, wave. facing = +1 looks right, -1 left."""
    s = h / 100.0
    f = facing
    lc, fc = light_col, fill_col
    X = lambda v: x + v * s * f
    Y = lambda v: y - v * s
    if shadow:
        L.multiply(blur(ellipse(L, x, y, 16 * s, 3.5 * s), 2), "000000", 0.6)
    # legs and shoes
    for side in (-1, 1):
        hip = (X(side * 4.5), Y(50))
        knee = (X(side * 5.2 + 1), Y(27))
        ankle = (X(side * 5.5), Y(4))
        limb(L, [hip, knee, ankle], 7.5 * s, 5.5 * s, pants, lc, fc, light)
        L.paint(spoly(L, [(X(side * 5.5 - 3), Y(5)), (X(side * 5.5 + 4.5), Y(4)), (X(side * 5.5 + 5), Y(0)), (X(side * 5.5 - 3.5), Y(0))]), "0e0a0c")
    # torso: jacket with a little shape at the waist, coat hangs lower
    bottom = 32 if coat else 48
    torso = spoly(L, [(X(-10), Y(82)), (X(10), Y(82)), (X(9.5), Y(66)), (X(7.5), Y(52)), (X(8.5), Y(bottom)),
                      (X(-8.5), Y(bottom)), (X(-7.5), Y(52)), (X(-9.5), Y(66))])
    _lit_paint(L, torso, jacket, lc, fc, light[0], light[1], x, Y(65), 12 * s)
    L.paint(line(L, [(X(0.5), Y(80)), (X(0), Y(bottom + 2))], max(1, s * 0.6)), mix(jacket, INK, 0.5), 0.6)
    L.paint(poly(L, [(X(-3), Y(82)), (X(3), Y(82)), (X(0), Y(72))]), mix(jacket, "ffffff", 0.5), 0.5)   # shirt at the collar
    # arms
    sh_l, sh_r = (X(-9), Y(80)), (X(9), Y(80))
    arm_s = 4.8 * s
    if pose == "gun":
        arm(L, sh_r, (X(19), Y(74)), (X(31), Y(73)), arm_s, jacket, skin, "grip", light, lc, fc)
        arm(L, sh_l, (X(6), Y(70)), (X(29), Y(71)), arm_s, jacket, skin, "grip", light, lc, fc)
        L.paint(rect(L, min(X(30), X(42)), Y(75), 12 * s, 3.2 * s), "141418")
    elif pose == "hands_pockets":
        for sh, sd in ((sh_l, -1), (sh_r, 1)):
            limb(L, [sh, (X(sd * 11.5), Y(64)), (X(sd * 8.5), Y(50))], arm_s, arm_s * 0.8, jacket, lc, fc, light)
    elif pose == "point":
        arm(L, sh_r, (X(20), Y(80)), (X(33), Y(84)), arm_s, jacket, skin, "point", light, lc, fc)
        arm(L, sh_l, (X(-12), Y(64)), (X(-11), Y(50)), arm_s, jacket, skin, "relaxed", light, lc, fc, hand_angle=math.pi / 2)
    elif pose == "phone":
        arm(L, sh_r, (X(12), Y(66)), (X(5), Y(87)), arm_s, jacket, skin, "grip", light, lc, fc, hand_angle=-math.pi / 2 * f)
        arm(L, sh_l, (X(-12), Y(64)), (X(-11), Y(50)), arm_s, jacket, skin, "relaxed", light, lc, fc, hand_angle=math.pi / 2)
    elif pose == "cross":
        arm(L, sh_l, (X(-11), Y(66)), (X(6), Y(68)), arm_s, jacket, skin, "fist", light, lc, fc, hand_angle=0 if f > 0 else math.pi)
        arm(L, sh_r, (X(11), Y(66)), (X(-5), Y(70)), arm_s, jacket, skin, "fist", light, lc, fc, hand_angle=math.pi if f > 0 else 0)
    else:
        for sh, sd in ((sh_l, -1), (sh_r, 1)):
            arm(L, sh, (X(sd * 12), Y(64)), (X(sd * 11.5), Y(49)), arm_s, jacket, skin, "relaxed", light, lc, fc, hand_angle=math.pi / 2)
    # neck and head: jaw, ear, nose on the facing side, hair
    L.paint(rect(L, X(-2.2) if f > 0 else X(2.2) - 4.4 * s, Y(87), 4.4 * s, 6 * s), mix(skin, INK, 0.3))
    hx, hy = X(1), Y(93)
    head = spoly(L, [(hx - 6 * s, hy - 7 * s), (hx + 6 * s, hy - 7 * s), (hx + 6.5 * s * (1 if f > 0 else 0.85), hy + 1 * s),
                     (hx + 3 * s * f, hy + 6.5 * s), (hx - 3 * s * f, hy + 6.5 * s), (hx - 6.3 * s, hy + 1 * s)])
    _lit_paint(L, head, skin, lc, fc, light[0], light[1], hx, hy, 6 * s)
    L.paint(ellipse(L, hx + 7 * s * f, hy + 0.5 * s, 1.3 * s, 2.2 * s), mix(skin, INK, 0.3))      # nose in profile-ish
    L.paint(ellipse(L, hx - 4.5 * s * f, hy + 0.5 * s, 1.5 * s, 2 * s), mix(skin, INK, 0.25))    # ear
    L.paint(line(L, [(hx + 2 * s * f, hy - 1 * s), (hx + 4.5 * s * f, hy - 1.3 * s)], max(1, s * 0.6)), INK, 0.8)   # eye
    if hair_style == "long":
        hm = spoly(L, [(hx - 7 * s, hy + 12 * s), (hx - 7.5 * s, hy - 5 * s), (hx, hy - 9.5 * s), (hx + 6.5 * s, hy - 6 * s), (hx + 4 * s * f, hy - 4 * s), (hx - 2 * s, hy - 3 * s), (hx - 3 * s, hy + 11 * s)])
    elif hair_style == "bald":
        hm = np.zeros((L.h, L.w), np.float32)
    else:
        hm = spoly(L, [(hx - 6.5 * s, hy + 1 * s), (hx - 6.5 * s, hy - 5 * s), (hx, hy - 8.5 * s), (hx + 6.5 * s, hy - 5.5 * s), (hx + 5 * s * f, hy - 4 * s), (hx - 3 * s, hy - 4 * s)])
    if hm.any():
        L.paint(hm, hair)
    if cap:
        L.paint(spoly(L, [(hx - 7 * s, hy - 3 * s), (hx - 6 * s, hy - 8.5 * s), (hx + 5 * s, hy - 8.5 * s), (hx + 7 * s, hy - 3 * s)]), cap)
        L.paint(poly(L, [(hx + 5 * s * f, hy - 3.5 * s), (hx + 11 * s * f, hy - 2.5 * s), (hx + 5 * s * f, hy - 2 * s)]), mix(cap, INK, 0.3))
    whole = np.clip(torso + head + hm, 0, 1)
    L.paint(rim(whole, int(np.sign(light[0])), 0, 1), lc, 0.75)
    return whole
