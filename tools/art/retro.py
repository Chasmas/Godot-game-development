"""
80s poster / anime-OVA character busts for the cutscenes and portraits.

Flat cel colours with one hard shadow, a dark outline, twin neon rim lights
(hot pink one side, cyan the other) and strong, simple silhouettes - the
character reads from the hair and the jacket before you see the face.
No hands, no arms: head, neck, shoulders.

    bust(L, cx, cy, s, CAST["cass"], talk=False, blink=False)

cx, cy: centre of the head; s: head half-height in pixels. `turn` in the
cast entry (-1..1) turns the face toward screen left/right (3/4 view).
"""
import math
import numpy as np
from paint import *

PINK, CYAN, GOLD, INK = "ff3d7f", "35e0ff", "ffd23f", "0b0710"

CAST = {
    # the stunt double turned star: big red 80s hair, red leather, aviators
    "cass": dict(jaw=0.92, chin=1.02, skin="f0c0a4", hair="c8281e", hair_hi="ff7a4a", jacket="c01830", jacket_hi="ff6070", jacket_kind="leather",
                 shirt="f4ece4", lips="d0203a", shadow_eye="a02a8a", eyes="3a6a4a", hair_style="big80s", turn=0.35,
                 fem=True, earring=True, pin=True),
    "tommy": dict(jaw=1.18, chin=1.02, skin="e2aa84", hair="2a1810", hair_hi="7a4a2a", jacket="3a5a9a", jacket_hi="8ab0e8", jacket_kind="denim",
                  shirt="f0ece0", lips="a0584a", eyes="4a3020", hair_style="mullet", turn=-0.35, stubble=True, cig=True),
    "marv": dict(jaw=1.05, chin=1.12, cheek=0.95, skin="eab690", hair="18161e", hair_hi="6a6a90", jacket="8a1034", jacket_hi="ff5a8a", jacket_kind="tux",
                 shirt="fff8f0", tie=GOLD, lips="b05a50", eyes="2a2030", hair_style="slick", turn=0.0, grin=True, temples="c8c8d0"),
    "anchor": dict(skin="efc09c", hair="e8c878", hair_hi="fff0b0", jacket="1e2e5a", jacket_hi="6a8ad0", jacket_kind="suit",
                   shirt="f0f0f8", tie="c01828", lips="b86a5a", eyes="3a4a6a", hair_style="helmet", turn=0.2, grin=True),
    "harcourt": dict(jaw=1.05, chin=1.06, skin="e8bc98", hair="e0dcd4", hair_hi="ffffff", jacket="ece0c4", jacket_hi="fff8e8", jacket_kind="suit",
                     shirt="fffaf0", tie="8a1030", lips="b06a5a", eyes="4a5a6a", hair_style="silver", turn=-0.25, glasses=True, grin=True),
    "earl": dict(jaw=1.25, chin=0.95, cheek=1.08, skin="eab494", hair="5a3a24", hair_hi="9a6a40", jacket="ff6ab0", jacket_hi="ffb0d8", jacket_kind="hawaiian",
                 shirt="fff0a0", lips="a8605a", eyes="3a2a1a", hair_style="balding", turn=0.3, stubble=True, sweat=True, chain=True),
    "guard": dict(jaw=1.2, skin="c89070", hair="1a1410", hair_hi="4a3a30", jacket="1f6a68", jacket_hi="6ae0d0", jacket_kind="uniform",
                  shirt="d8e0d8", lips="8a5040", eyes="2a2018", hair_style="cap", turn=0.3, stubble=True, scar=True, frown=True),
    "arlo": dict(jaw=1.15, skin="c89070", hair="3a3a34", hair_hi="7a7a70", jacket="4a5a2a", jacket_hi="9ab060", jacket_kind="army",
                 shirt="c8c0a8", lips="8a5040", eyes="2a2018", hair_style="buzz", turn=-0.3, beard=True, shades=True),
}

# ------------------------------------------------------------ helpers
def outline(mask, w=1.2):
    return np.clip(blur(mask, w) * 3.0 - mask * 3.0, 0, 1) * (1 - mask * 0.0)

def _shade(c, amt=0.42, tint="3a1a5a"):
    return mix(c, tint, amt)

def _pts(cx, cy, s, P):
    return [(cx + x * s, cy + y * s) for x, y in P]

def _turn_pts(P, d):
    """Rotate a front-view head outline toward d (3/4 view): the side the
    face turns to gets narrower, the chin and brow slide that way."""
    out = []
    for x, y in P:
        if x * d > 0:
            x *= 1 - 0.3 * abs(d)
        else:
            x *= 1 + 0.08 * abs(d)
        x += d * 0.18 * max(0.0, 1 - abs(y) * 0.6)
        out.append((x, y))
    return out

def cel(L, mask, base, lx, cx, s, bias=0.0, amount=1.0, tint="3a1a5a"):
    """Flat base colour + one hard shadow on the side away from the light."""
    L.paint(mask, base)
    u = (L.xx - cx) / s
    sh = np.clip(0.5 + (-lx * u - bias) * 6.0, 0, 1) * mask
    L.paint(sh, _shade(base, 0.42, tint), amount)

def rims(L, mask, lx, w=1, a=0.9, c1=PINK, c2=CYAN):
    L.paint(rim(mask, lx, -0.3, w), c1 if lx > 0 else c2, a)
    L.paint(rim(mask, -lx, -0.3, w), c2 if lx > 0 else c1, a * 0.7)

# ------------------------------------------------------------ the bust
def bust(L, cx, cy, s, c, talk=False, blink=False, lx=1.0, star=False, hair_style=None,
         aviators=False, aviators_up=False, body=True, rim_a=0.9, out_w=1.2):
    d = c.get("turn", 0.0)
    fx = d * 0.36                                      # face centre line (units)
    hs = hair_style or c["hair_style"]
    skin, hair, jk = c["skin"], c["hair"], c["jacket"]
    sil = np.zeros((L.h, L.w), np.float32)             # whole silhouette, for the outline

    def U(x, y):
        return (cx + x * s, cy + y * s)

    # ---- hair behind the head
    back = None
    if hs == "big80s":
        back = spoly(L, _pts(cx, cy, s, _turn_pts([(-1.55, -0.3), (-1.4, -1.15), (-0.7, -1.7), (0.3, -1.78), (1.2, -1.4),
                                                    (1.6, -0.5), (1.7, 0.5), (1.55, 1.45), (1.05, 2.0), (0.75, 1.2),
                                                    (-0.75, 1.2), (-1.1, 2.05), (-1.6, 1.5), (-1.75, 0.5)], d)))
    elif hs == "ponytail":
        back = spoly(L, _pts(cx, cy, s, _turn_pts([(-0.95, -0.3), (-0.85, -1.0), (0, -1.25), (0.85, -1.0), (0.95, -0.3),
                                                    (0.8, 0.2), (-0.8, 0.2)], d)))
        tail = spoly(L, _pts(cx, cy, s, [(-d * 0.9 - 0.25, -0.9), (-d * 1.5 - 0.1, -0.6), (-d * 1.7, 0.4), (-d * 1.3, 1.3), (-d * 1.1, 0.3), (-d * 0.9, -0.5)]))
        back = np.clip(back + tail, 0, 1)
    elif hs == "mullet":
        back = spoly(L, _pts(cx, cy, s, _turn_pts([(-0.5, 0.35), (0.5, 0.35), (0.6, 0.9), (0.52, 1.22), (0.25, 1.1), (-0.25, 1.1), (-0.52, 1.22), (-0.6, 0.9)], d)))
    elif hs == "helmet":
        back = spoly(L, _pts(cx, cy, s, _turn_pts([(-1.12, 0.1), (-1.1, -0.8), (-0.5, -1.3), (0.5, -1.3), (1.1, -0.8),
                                                    (1.12, 0.1), (1.0, 0.75), (-1.0, 0.75)], d)))
    if back is not None:
        cel(L, back, hair, lx, cx, s, 0.1)
        rims(L, back, lx, 1, rim_a)
        sil += back

    # ---- body: neck, padded shoulders, jacket
    if body:
        neck = poly(L, _pts(cx, cy, s, [(fx * 0.5 - 0.36, 0.55), (fx * 0.5 + 0.36, 0.55), (fx * 0.4 + 0.42, 1.55), (fx * 0.4 - 0.42, 1.55)]))
        cel(L, neck, skin, lx, cx, s, 0.05)
        L.paint(neck * np.clip((L.yy - (cy + 0.75 * s)) / (0.25 * s), 0, 1) * np.clip(((cy + 1.05 * s) - L.yy) / (0.3 * s), 0, 1), _shade(skin, 0.5), 0.8)
        sw = 2.05 if c.get("jacket_kind") in ("leather", "tux", "suit", "denim") else 1.85   # shoulder pads!
        by = 1.45
        torso = poly(L, _pts(cx, cy, s, [(fx * 0.3 - 0.55, by - 0.05), (fx * 0.3 + 0.55, by - 0.05),
                                         (sw, by + 0.35), (sw + 0.18, by + 0.75), (sw + 0.3, 4.5), (-sw - 0.3, 4.5),
                                         (-sw - 0.18, by + 0.75), (-sw, by + 0.35)]))
        L.paint(torso, jk)
        uu = (L.xx - cx) / s + 0.35 * ((L.yy - cy) / s - 1.6) * lx
        L.paint(torso * np.clip(0.5 + (-lx * uu - 1.0) * 5.0, 0, 1), _shade(jk, 0.42), 1.0)
        # V opening with the shirt
        vx = fx * 0.3
        vee = poly(L, _pts(cx, cy, s, [(vx - 0.5, by - 0.02), (vx + 0.5, by - 0.02), (vx + 0.12, by + 1.7), (vx - 0.12, by + 1.7)]))
        kind = c.get("jacket_kind")
        if kind == "hawaiian":
            vee = poly(L, _pts(cx, cy, s, [(vx - 0.5, by - 0.02), (vx + 0.5, by - 0.02), (vx + 0.1, by + 0.9), (vx - 0.1, by + 0.9)]))
            L.paint(vee, skin)
        else:
            L.paint(vee, c["shirt"])
            L.paint(vee * np.clip(0.5 + (-lx * (L.xx - cx) / s - 0.1) * 6, 0, 1), _shade(c["shirt"], 0.3), 0.8)
        if c.get("tie"):
            tie = poly(L, _pts(cx, cy, s, [(vx - 0.1, by + 0.05), (vx + 0.1, by + 0.05), (vx + 0.16, by + 1.5), (vx, by + 1.7), (vx - 0.16, by + 1.5)]))
            L.paint(tie, c["tie"])
            L.paint(rim(tie, lx, 0, 1), "ffffff", 0.5)
        # lapels / collar by jacket kind
        for side in (-1, 1):
            if kind in ("tux", "suit"):
                lap = poly(L, _pts(cx, cy, s, [(vx + side * 0.5, by - 0.02), (vx + side * 0.95, by + 0.15), (vx + side * 0.7, by + 0.6),
                                               (vx + side * 0.9, by + 0.75), (vx + side * 0.14, by + 1.75), (vx + side * 0.12, by + 1.6)]))
                L.paint(lap, mix(jk, "000000", 0.25) if kind == "tux" else mix(jk, "ffffff", 0.08))
                L.paint(rim(lap, lx, -1, 1), c["jacket_hi"], 0.7)
            elif kind in ("leather", "denim", "army", "uniform"):
                col_ = poly(L, _pts(cx, cy, s, [(vx + side * 0.45, by - 0.25), (vx + side * 1.1, by + 0.1), (vx + side * 0.85, by + 0.6), (vx + side * 0.2, by + 0.5)]))
                L.paint(col_, mix(jk, "ffffff", 0.1))
                L.paint(outline(col_, 0.8), INK, 0.6)
                L.paint(rim(col_, lx, -1, 1), c["jacket_hi"], 0.8)
            elif kind == "hawaiian":
                col_ = poly(L, _pts(cx, cy, s, [(vx + side * 0.45, by - 0.1), (vx + side * 1.0, by + 0.25), (vx + side * 0.3, by + 0.9), (vx + side * 0.1, by + 0.85)]))
                L.paint(col_, mix(jk, "ffffff", 0.2))
        if kind == "leather":
            # shine streaks across the shoulders, a zip
            for side in (-1, 1):
                L.paint(torso * blur(line(L, [U(vx + side * 1.1, by + 0.35), U(vx + side * 1.9, by + 0.5), U(vx + side * 2.1, by + 1.4)], s * 0.12), 1.5), c["jacket_hi"], 0.55)
            L.paint(line(L, [U(vx + 0.55, by + 1.2), U(vx + 0.62, 4.4)], 1.2), "c8c8d0", 0.7)
        elif kind == "denim":
            for side in (-1, 1):
                L.paint(line(L, [U(vx + side * 0.9, by + 1.1), U(vx + side * 1.7, by + 1.1)], 1), "e8c870", 0.8)       # stitching
                L.paint(rect(L, *U(vx + side * 1.3 - 0.3, by + 1.15), 0.6 * s, 0.4 * s), mix(jk, "000000", 0.15))  # pockets
        elif kind == "hawaiian":
            rng = np.random.default_rng(7)
            for i in range(18):
                px_, py_ = rng.uniform(-sw, sw), rng.uniform(by + 0.3, 3.5)
                fl = ellipse(L, *U(px_, py_), 0.18 * s, 0.14 * s) * torso
                L.paint(fl, rng.choice(["fff0a0", "35e0ff", "ffffff"]), 0.8)
        elif kind == "uniform":
            L.paint(poly(L, _pts(cx, cy, s, star_or_badge(vx - 1.0, by + 0.9))), GOLD)
        elif kind == "army":
            for side in (-1, 1):
                L.paint(rect(L, *U(vx + side * 1.2 - 0.35, by + 1.0), 0.7 * s, 0.5 * s), mix(jk, "000000", 0.2))
        if c.get("pin"):
            pp = U(vx - 1.05, by + 0.85)
            st = poly(L, star_points(pp[0], pp[1], 0.24 * s, 0.1 * s))
            L.paint(st, GOLD)
            L.paint(rim(st, lx, -1, 1), "ffffff", 0.9)
        if c.get("chain"):
            L.paint(line(L, smooth([U(vx - 0.42, by + 0.05), U(vx, by + 0.75), U(vx + 0.42, by + 0.05)], 6, False), 1.4), GOLD, 0.95)
        rims(L, torso, lx, 1, rim_a)
        sil += torso + neck

    # ---- head
    jw, ch_, ck = c.get("jaw", 1.0), c.get("chin", 1.0), c.get("cheek", 1.0)
    head_p = _turn_pts([(0, -1.05), (0.55, -0.95), (0.74 * ck, -0.45), (0.76 * ck, 0.05), (0.62 * jw, 0.52 * ch_), (0.3 * jw, 0.9 * ch_), (0.0, 1.0 * ch_),
                        (-0.3 * jw, 0.9 * ch_), (-0.62 * jw, 0.52 * ch_), (-0.76 * ck, 0.05), (-0.74 * ck, -0.45), (-0.55, -0.95)], d)
    head = spoly(L, _pts(cx, cy, s, head_p))
    # ear on the side away from the turn
    if abs(d) > 0.1:
        es = -1 if d > 0 else 1
        ear = ellipse(L, *U(es * 0.74 + d * 0.1, 0.08), 0.14 * s, 0.24 * s)
        cel(L, ear, skin, lx, cx, s, 0.0)
        head = np.clip(head + ear, 0, 1)
    cel(L, head, skin, lx, cx, s, -d * 0.35 + 0.18 * lx)
    # jaw shadow line & cheek blush
    if c.get("fem"):
        for side, k in ((-1, 1.0), (1, 1 - 0.5 * abs(d))):
            L.paint(head * blur(line(L, [U(fx + side * 0.32 * k, 0.28), U(fx + side * 0.58 * k, 0.12)], s * 0.1), s * 0.05), "ff6a8a", 0.35)
    if c.get("stubble"):
        jaw = head * np.clip((L.yy - (cy + 0.3 * s)) / (0.15 * s), 0, 1)
        L.paint(jaw * (value_noise(L.w, L.h, 1.5, 3, 1) > 0.55), _shade(skin, 0.55, "2a1a20"), 0.45)
    if c.get("beard"):
        br = spoly(L, _pts(cx, cy, s, _turn_pts([(-0.72, 0.1), (-0.5, 0.4), (0, 0.45), (0.5, 0.4), (0.72, 0.1), (0.6, 0.6), (0.2, 1.05), (-0.2, 1.05), (-0.6, 0.6)], d))) * head
        cel(L, br, hair, lx, cx, s, 0.1)
    if c.get("sweat"):
        for k in range(3):
            L.paint(ellipse(L, *U(fx + 0.4 - k * 0.35, -0.55 + k * 0.1), 0.05 * s, 0.08 * s), "e8f8ff", 0.9)
    if c.get("scar"):
        L.paint(line(L, [U(fx + 0.3, -0.35), U(fx + 0.5, 0.15)], max(1, s * 0.05)), _shade(skin, 0.3, "a02030"), 0.9)
    rims(L, head, lx, 1, rim_a)
    sil += head

    # ---- eyes
    ey = -0.02
    eyes_mask = np.zeros_like(sil)
    shades = c.get("shades") or aviators
    for side in (-1, 1):
        near = (side * d) <= 0
        k = 1.0 if near else 1 - 0.55 * abs(d)
        ex = fx + side * 0.34 * (1 - 0.25 * abs(d) * (0 if near else 1))
        w, h = 0.2 * k, 0.1
        if c.get("fem") and not shades:
            L.paint(head * blur(ellipse(L, *U(ex, ey - 0.12), w * 1.25 * s, 0.13 * s), s * 0.05), c.get("shadow_eye", "8a3a8a"), 0.6)
        if shades:
            continue
        if blink:
            L.paint(line(L, smooth([U(ex - w, ey), U(ex, ey + 0.05), U(ex + w, ey)], 4, False), max(1.2, s * 0.06)), INK)
        else:
            almond = poly(L, smooth(_pts(cx, cy, s, [(ex - w, ey), (ex - w * 0.3, ey - h), (ex + w * 0.5, ey - h * 0.9), (ex + w, ey - 0.01),
                                                     (ex + w * 0.3, ey + h * 0.7), (ex - w * 0.4, ey + h * 0.6)]), 5))
            L.paint(almond, "fbf4f0")
            look = 0.25 * d
            iris = ellipse(L, *U(ex + look * 0.25 + w * 0.05, ey), 0.075 * s * max(0.7, k), 0.085 * s) * almond
            L.paint(iris, c.get("eyes", "3a2a20"))
            L.paint(ellipse(L, *U(ex + look * 0.25 + w * 0.05, ey), 0.035 * s, 0.04 * s) * almond, INK)
            L.paint(ellipse(L, *U(ex + look * 0.25 + w * 0.05 + 0.03, ey - 0.03), 0.02 * s, 0.02 * s), "ffffff")
            # heavy upper lid (and lashes for her)
            L.paint(line(L, smooth([U(ex - w * 1.05, ey + 0.01), U(ex - w * 0.3, ey - h * 1.05), U(ex + w * 0.5, ey - h), U(ex + w * 1.15, ey - 0.02)], 4, False),
                         max(1.2, s * (0.07 if c.get("fem") else 0.05))), INK)
            if c.get("fem"):
                L.paint(line(L, [U(ex + w * 1.05 * side * (1 if side > 0 else -1), ey - 0.02), U(ex + side * w * 1.35, ey - 0.08)], max(1, s * 0.04)), INK)
            eyes_mask += almond
        # brows
        by_ = ey - 0.24 - (0.04 if c.get("fem") else 0.0)
        tilt = -0.06 if c.get("frown") else 0.03
        L.paint(line(L, smooth([U(ex - w * 1.1, by_ + 0.03), U(ex, by_ - 0.03 + (tilt if side < 0 else -tilt) * 0), U(ex + w * 1.15, by_ + 0.04 + (tilt * side))], 4, False),
                     max(1.2, s * (0.05 if c.get("fem") else 0.085))), mix(hair, INK, 0.5) if hs != "big80s" else "7a1a14")
    if shades:
        # aviators: teardrop lenses reflecting a synthwave sunset
        for side in (-1, 1):
            near = (side * d) <= 0
            k = 1.0 if near else 1 - 0.5 * abs(d)
            ex = fx + side * 0.34
            lens = spoly(L, _pts(cx, cy, s, [(ex - 0.24 * k, ey - 0.12), (ex + 0.24 * k, ey - 0.13), (ex + 0.22 * k, ey + 0.1),
                                             (ex + 0.02 * k, ey + 0.2), (ex - 0.2 * k, ey + 0.12)]))
            refl = Layer(L.w, L.h)
            refl.vgrad([(0, "2a0a4a"), (0.45, "ff3d7f"), (0.6, "ffb040"), (0.62, "1a0a2a"), (1, "3a1060")], cy + (ey - 0.13) * s, cy + (ey + 0.2) * s)
            L.paint(lens, refl.a)
            L.paint(lens * blur(line(L, [U(ex - 0.2 * k, ey + 0.1), U(ex + 0.1 * k, ey - 0.12)], s * 0.05), 0.6), "ffffff", 0.55)
            L.paint(outline(lens, 0.7), "d8b060", 0.95)
            eyes_mask += lens
        L.paint(line(L, [U(fx - 0.1, ey - 0.1), U(fx + 0.1, ey - 0.1)], max(1, s * 0.035)), "d8b060")
        for side in (-1, 1):
            if (side * d) <= 0 or abs(d) < 0.2:
                L.paint(line(L, [U(fx + side * 0.58, ey - 0.08), U(fx + side * 0.8, ey - 0.12)], max(1, s * 0.035)), "d8b060")
    if c.get("glasses"):
        for side in (-1, 1):
            ex = fx + side * 0.34
            fr = np.clip(ellipse(L, *U(ex, ey), 0.24 * s, 0.17 * s) - ellipse(L, *U(ex, ey), 0.2 * s, 0.13 * s), 0, 1)
            L.paint(fr, "d8b060")
        L.paint(line(L, [U(fx - 0.12, ey - 0.02), U(fx + 0.12, ey - 0.02)], max(1, s * 0.035)), "d8b060")

    # ---- nose: one shadow stroke and the tip
    nt = U(fx + d * 0.14, 0.36)
    L.paint(line(L, [U(fx + d * 0.06 - lx * 0.04, 0.02), U(fx + d * 0.12 - lx * 0.06, 0.3), nt], max(1, s * 0.04)), _shade(skin, 0.55), 0.75)
    L.paint(ellipse(L, nt[0] - lx * 0.06 * s, nt[1] + 0.02 * s, 0.05 * s, 0.03 * s), _shade(skin, 0.6), 0.7)

    # ---- mouth
    my = 0.6
    mw = 0.26 * (1 - 0.2 * abs(d))
    mx = fx + d * 0.08
    lips = c.get("lips", "b06050")
    if talk:
        om = spoly(L, _pts(cx, cy, s, [(mx - mw, my), (mx, my - 0.07), (mx + mw, my), (mx + mw * 0.5, my + 0.2), (mx - mw * 0.5, my + 0.2)]))
        L.paint(om, "3a0a14")
        L.paint(om * (L.yy < cy + (my + 0.04) * s), "f4f0e8", 0.9)          # teeth
        L.paint(outline(om, 0.9), lips, 0.95 if c.get("fem") else 0.6)
    elif c.get("grin"):
        g = spoly(L, _pts(cx, cy, s, [(mx - mw * 1.2, my - 0.04), (mx + mw * 1.2, my - 0.04), (mx + mw * 0.6, my + 0.14), (mx - mw * 0.6, my + 0.14)]))
        L.paint(g, "f8f4ec")
        L.paint(outline(g, 0.8), mix(lips, INK, 0.3), 0.9)
    else:
        if c.get("fem"):
            up = spoly(L, _pts(cx, cy, s, [(mx - mw, my), (mx - mw * 0.35, my - 0.08), (mx, my - 0.04), (mx + mw * 0.35, my - 0.08), (mx + mw, my), (mx, my + 0.02)]))
            lo = spoly(L, _pts(cx, cy, s, [(mx - mw * 0.9, my + 0.01), (mx + mw * 0.9, my + 0.01), (mx + mw * 0.4, my + 0.13), (mx - mw * 0.4, my + 0.13)]))
            L.paint(up + lo, lips)
            L.paint(ellipse(L, *U(mx + 0.05, my + 0.07), 0.07 * s, 0.025 * s), "ffb0c0", 0.8)
            L.paint(line(L, [U(mx - mw * 0.9, my + 0.01), U(mx + mw * 0.9, my + 0.01)], max(1, s * 0.03)), "5a0a18", 0.8)
        else:
            L.paint(line(L, smooth([U(mx - mw, my + (0.02 if c.get("frown") else 0)), U(mx, my + 0.02), U(mx + mw, my - (0.02 if not c.get("frown") else -0.02))], 4, False), max(1.2, s * 0.05)), mix(lips, INK, 0.35))
            L.paint(line(L, [U(mx - mw * 0.5, my + 0.12), U(mx + mw * 0.5, my + 0.12)], max(1, s * 0.04)), _shade(skin, 0.3), 0.5)
    if c.get("cig") and not talk:
        a, b = U(mx + mw * 0.6, my + 0.02), U(mx + mw * 0.6 + 0.5 * (1 if d >= 0 else -1), my + 0.1)
        L.paint(line(L, [a, b], max(1.5, s * 0.07)), "f4f0e8")
        L.add(ellipse(L, b[0], b[1], s * 0.05, s * 0.05, blur=0.5), col("ff6020"), 1.0)
        L.radial(b[0], b[1], s * 0.25, "ff6020", 1.6, 0.5)
    if star:
        sp = U(fx + (0.42 if d >= 0 else -0.42) * (1 if True else 1) * (1 if d >= 0 else 1) - 0.0, 0.22)
        sx = cx + (fx - 0.36) * s if d >= 0 else cx + (fx + 0.36) * s
        st = poly(L, star_points(sx, cy + 0.28 * s, 0.2 * s, 0.085 * s))
        L.paint(st, GOLD)
        L.paint(rim(st, lx, -1, 1), "ffffff", 0.9)
        L.add(blur(st, 2), col(GOLD), 0.4)

    # ---- hair in front
    front = None
    if hs == "big80s":
        # swept-over feathered bangs, volume on top
        front = spoly(L, _pts(cx, cy, s, _turn_pts([(-1.0, -0.25), (-1.15, -1.0), (-0.5, -1.55), (0.4, -1.6), (1.1, -1.15), (1.0, -0.4),
                                                     (0.82, -0.8), (0.45, -1.02), (0.2, -0.78), (-0.3, -0.5), (-0.75, -0.3)], d)))
        # side locks framing the face
        for side in (-1, 1):
            lock = spoly(L, _pts(cx, cy, s, _turn_pts([(side * 0.72, -0.5), (side * 0.95, -0.2), (side * 0.98, 0.5), (side * 0.85, 1.1), (side * 0.7, 0.4)], d)))
            front = np.clip(front + lock, 0, 1)
    elif hs == "ponytail":
        front = spoly(L, _pts(cx, cy, s, _turn_pts([(-0.8, -0.35), (-0.78, -0.95), (0, -1.18), (0.78, -0.95), (0.8, -0.35), (0.6, -0.72), (-0.6, -0.72)], d)))
    elif hs == "mullet":
        # pompadour: tall quiff rolling forward over the brow
        front = spoly(L, _pts(cx, cy, s, _turn_pts([(-0.8, -0.3), (-0.84, -0.95), (-0.5, -1.4), (0.1, -1.7), (0.75, -1.6), (1.0, -1.2),
                                                     (0.9, -0.85), (0.8, -0.35), (0.62, -0.72), (0.2, -0.82), (-0.5, -0.72)], d)))
    elif hs == "slick":
        front = spoly(L, _pts(cx, cy, s, _turn_pts([(-0.8, -0.2), (-0.82, -0.95), (-0.2, -1.35), (0.5, -1.35), (0.88, -0.95), (0.8, -0.2),
                                                     (0.66, -0.7), (0.0, -0.82), (-0.66, -0.7)], d)))
    elif hs == "helmet":
        front = spoly(L, _pts(cx, cy, s, _turn_pts([(-0.95, 0.3), (-1.0, -0.7), (-0.4, -1.25), (0.5, -1.25), (1.0, -0.7), (0.95, 0.3),
                                                     (0.8, -0.3), (0.4, -0.72), (-0.3, -0.62), (-0.8, -0.3)], d)))
    elif hs == "silver":
        front = spoly(L, _pts(cx, cy, s, _turn_pts([(-0.8, -0.3), (-0.8, -0.95), (-0.1, -1.25), (0.6, -1.2), (0.85, -0.85), (0.8, -0.3),
                                                     (0.6, -0.72), (-0.35, -0.8), (-0.65, -0.65)], d)))
    elif hs == "balding":
        front = np.zeros_like(sil)
        for side in (-1, 1):
            front += spoly(L, _pts(cx, cy, s, _turn_pts([(side * 0.72, -0.7), (side * 0.82, -0.2), (side * 0.78, 0.25), (side * 0.66, -0.1), (side * 0.6, -0.6)], d)))
        front = np.clip(front, 0, 1)
    elif hs == "buzz":
        front = spoly(L, _pts(cx, cy, s, _turn_pts([(-0.76, -0.4), (-0.7, -0.95), (0, -1.1), (0.7, -0.95), (0.76, -0.4), (0.6, -0.72), (-0.6, -0.72)], d)))
    elif hs == "cap":
        capm = spoly(L, _pts(cx, cy, s, _turn_pts([(-0.82, -0.45), (-0.78, -1.05), (0, -1.28), (0.78, -1.05), (0.82, -0.45)], d)))
        brim = spoly(L, _pts(cx, cy, s, [(fx - 0.95, -0.5), (fx + 0.95 + d * 0.4, -0.52), (fx + 0.7 + d * 0.5, -0.32), (fx - 0.75, -0.32)]))
        cel(L, np.clip(capm + brim, 0, 1), c["jacket"], lx, cx, s, 0.1)
        L.paint(brim, mix(c["jacket"], "000000", 0.35))
        L.paint(poly(L, star_points(cx + fx * s, cy - 0.8 * s, 0.16 * s, 0.07 * s)), GOLD)
        rims(L, np.clip(capm + brim, 0, 1), lx, 1, rim_a)
        sil += capm + brim
    if front is not None:
        cel(L, front, hair, lx, cx, s, -0.05)
        # feathered highlight strokes
        hi = c.get("hair_hi", hair)
        m = front if back is None else np.clip(front + back, 0, 1)
        n_ = 7 if hs in ("big80s", "helmet", "slick", "mullet", "silver") else 3
        part = 0.4 if hs in ("big80s", "silver") else 0.0
        for i in range(n_):
            t = (i + 0.5) / n_ * 2 - 1                 # -1..1 across the crown
            x0 = part + t * 0.25
            x1 = t * (1.25 if hs == "big80s" else 0.85)
            y1 = -0.9 + abs(t) * (0.55 if hs == "big80s" else 0.3)
            stroke = line(L, smooth([U(x0, -1.35), U((x0 + x1) * 0.55, -1.25 + abs(t) * 0.1), U(x1, y1)], 5, False), max(1, s * 0.045))
            L.paint(stroke * m, hi, 0.6 if i % 2 == 0 else 0.35)
        if hs == "slick":
            L.paint(front * blur(line(L, [U(-0.5, -1.05), U(0.5, -1.1)], s * 0.14), 2), hi, 0.8)
            if c.get("temples"):
                for side in (-1, 1):
                    L.paint(front * ellipse(L, *U(side * 0.72, -0.4), 0.15 * s, 0.3 * s), c["temples"], 0.9)
        rims(L, front, lx, 1, rim_a)
        sil += front
    if aviators_up:
        # aviators pushed up into the hair - her trademark
        for side in (-1, 1):
            ex = fx * 0.6 + side * 0.34
            lens = spoly(L, _pts(cx, cy, s, [(ex - 0.23, -0.98), (ex + 0.23, -0.99), (ex + 0.2, -0.8), (ex, -0.74), (ex - 0.2, -0.8)]))
            refl = Layer(L.w, L.h)
            refl.vgrad([(0, "2a0a4a"), (0.5, "ff3d7f"), (0.62, "ffb040"), (0.66, "1a0a2a"), (1, "3a1060")], cy - 1.0 * s, cy - 0.74 * s)
            L.paint(lens, refl.a)
            L.paint(outline(lens, 0.7), "d8b060", 0.95)
        L.paint(line(L, [U(fx * 0.6 - 0.1, -0.96), U(fx * 0.6 + 0.1, -0.96)], max(1, s * 0.035)), "d8b060")
    if c.get("earring") and abs(d) < 0.9:
        es = -1 if d >= 0 else 1
        ep = U(es * 0.72 + d * 0.1, 0.42)
        ring = np.clip(ellipse(L, ep[0], ep[1] + 0.12 * s, 0.12 * s, 0.14 * s) - ellipse(L, ep[0], ep[1] + 0.12 * s, 0.08 * s, 0.1 * s), 0, 1)
        L.paint(ring, GOLD)
        sil += ring
    # ---- ink outline round everything
    L.paint(outline(np.clip(sil, 0, 1), out_w), INK, 0.95)
    return np.clip(sil, 0, 1)

def star_points(cx, cy, r, ri, n=5, rot=-math.pi / 2):
    pts = []
    for i in range(n * 2):
        a = rot + i * math.pi / n
        rr = r if i % 2 == 0 else ri
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return pts

def star_or_badge(x, y):
    return [(x + math.cos(-math.pi / 2 + i * math.pi / 5) * (0.2 if i % 2 == 0 else 0.09),
             y + math.sin(-math.pi / 2 + i * math.pi / 5) * (0.2 if i % 2 == 0 else 0.09)) for i in range(10)]

# ------------------------------------------------------------ backdrops
def synth_sky(L, y0, y1, top="0a0420", mid="3a0a5a", low="ff3d7f", horizon="ffb040"):
    L.vgrad([(0, top), (0.55, mid), (0.85, low), (1, horizon)], y0, y1)

def synth_sun(L, cx, cy, r, bands=7, top="ffe060", bot="ff3d7f"):
    sun = ellipse(L, cx, cy, r, r)
    g = Layer(L.w, L.h)
    g.vgrad([(0, top), (1, bot)], cy - r, cy + r)
    cut = np.ones_like(sun)
    for i in range(bands):
        yy = cy + r * (0.1 + i * 0.13)
        cut -= rect(L, cx - r, yy, 2 * r, max(1.0, r * 0.025 * (i + 1)))
    L.add(blur(sun, r * 0.25), col(bot), 0.45)
    L.paint(sun * np.clip(cut, 0, 1), g.a)

def synth_grid(L, y0, vx, colr=PINK, rows=12, cols=26, a=0.8):
    H, W = L.h, L.w
    L.vgrad([(0, "1a0630"), (1, "05020c")], y0, H, mask=(L.yy >= y0).astype(np.float32))
    for i in range(rows):
        t = (i / rows) ** 2
        y = y0 + (H - y0) * t
        L.add(line(L, [(0, y), (W, y)], 1), col(colr), a * (0.3 + t))
    for j in range(-cols // 2, cols // 2 + 1):
        L.add(line(L, [(vx + j * 6, y0), (vx + j * W * 0.16, H)], 1), col(colr), a * 0.6)
    L.add(blur(line(L, [(0, y0), (W, y0)], 2), 3), col(colr), 1.0)

def halftone(L, mask, colr, cell=4, amount=0.5):
    """Comic/poster halftone dots inside mask, bigger where mask is stronger."""
    cx = (np.mod(L.xx, cell) - cell / 2)
    cy = (np.mod(L.yy, cell) - cell / 2)
    r = np.sqrt(cx ** 2 + cy ** 2) / (cell / 2)
    dots = (r < np.clip(mask, 0, 1) * 1.1).astype(np.float32)
    L.paint(dots, colr, amount)

def scanlines(L, amount=0.12):
    L.a[..., :3] *= (1 - amount * (np.mod(L.yy, 2) < 1))[..., None]
    return L

def grade80s(L, amount=0.35):
    """Push shadows to purple and highlights to warm pink: the VHS-poster look."""
    rgb = L.a[..., :3]
    lum = rgb.mean(axis=2, keepdims=True)
    sh = np.array([0.16, 0.05, 0.26]); hi = np.array([1.0, 0.8, 0.72])
    graded = rgb * (1 - amount) + amount * (sh * (1 - lum) + hi * lum) * (0.6 + rgb * 0.8)
    L.a[..., :3] = np.clip(graded, 0, 1)
    return L
