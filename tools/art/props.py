"""Reusable painted pieces: skies, ridges, palms, cars, people, faces."""
import math
import numpy as np
from paint import *

FONT_DIR = __import__("os").path.join(__import__("os").path.dirname(__file__), "..", "..", "assets", "fonts")
F_DISPLAY = FONT_DIR + "/Poppins-BoldItalic.ttf"
F_BOLD = FONT_DIR + "/Poppins-Bold.ttf"
F_SCRIPT = FONT_DIR + "/Lora-Italic-Variable.ttf"
F_MONO = FONT_DIR + "/DejaVuSansMono-Bold.ttf"

INK = "0b0614"

def stars(L, n=120, y_max=0.5, seed=1, bright=1.0):
    rng = np.random.default_rng(seed)
    for _ in range(n):
        x, y = rng.random() * L.w, rng.random() * L.h * y_max
        b = rng.random() ** 3 * bright
        L.a[int(y), int(x), :3] = np.clip(L.a[int(y), int(x), :3] + b, 0, 1)
        if b > 0.6:
            L.radial(x, y, 3, "ffffff", 2, 0.25 * b)

def ridge(L, base_y, amp, seed, color, rough=60, top_light=None):
    """Mountain / mesa silhouette filling below a noise profile."""
    n = value_noise(L.w, 1, rough, seed, 4)[0]
    ys = base_y - amp * n
    pts = [(0, L.h)] + [(x, ys[x]) for x in range(L.w)] + [(L.w, L.h)]
    m = poly(L, pts)
    L.paint(m, color)
    if top_light:
        L.paint(rim(m, 0, -1, 1), top_light, 0.8)
    return m

def palm(L, x, y, h, color, lean=0.0, seed=0, rim_col=None, fronds=8):
    rng = np.random.default_rng(seed)
    top = (x + lean * h, y - h)
    pts = []
    for i in range(12):
        t = i / 11
        px = x + lean * h * t + math.sin(t * 2.5) * h * 0.03
        pts.append((px, y - h * t))
    trunk = line(L, pts, max(2, h * 0.035))
    L.paint(trunk, color)
    for k in range(fronds):
        ang = -math.pi / 2 + (k - (fronds - 1) / 2) * (math.pi * 1.5 / fronds) + rng.uniform(-0.12, 0.12)
        ln = h * rng.uniform(0.34, 0.46)
        spine = []
        for j in range(9):
            t = j / 8
            dx = math.cos(ang) * ln * t
            dy = math.sin(ang) * ln * t + (ln * 0.55) * t * t
            spine.append((top[0] + dx, top[1] + dy))
        # leaflets: a tapered ribbon along the spine
        left, right = [], []
        for j, (sx, sy) in enumerate(spine):
            t = j / 8
            wdt = h * 0.05 * math.sin(t * math.pi) + 0.6
            nx, ny = -math.sin(ang), math.cos(ang)
            left.append((sx + nx * wdt, sy + ny * wdt))
            right.append((sx - nx * wdt * 0.4, sy - ny * wdt * 0.4))
        m = poly(L, left + right[::-1])
        L.paint(m, color)
        if rim_col:
            L.paint(rim(m, 0, -1, 1), rim_col, 0.6)
    if rim_col:
        L.paint(rim(trunk, 1, 0, 1), rim_col, 0.5)

def glow_text(L, x, y, s, size, font, color, glow=1.0, anchor="la", rot=0.0):
    m = text_mask(L, x, y, s, size, font, anchor, rot)
    L.add(blur(m, size * 0.35), color, 0.9 * glow)
    L.add(blur(m, size * 0.1), color, 0.8 * glow)
    L.paint(m, mix(color, "ffffff", 0.55))
    return m

def light_cone(L, apex, left, right, color, amount=0.35, soft=6):
    m = blur(poly(L, [apex, left, right]), soft)
    # fade along the cone
    ax, ay = apex
    d = np.sqrt((L.xx - ax) ** 2 + (L.yy - ay) ** 2)
    fall = np.clip(1 - d / (max(abs(left[1] - ay), abs(left[0] - ax)) * 1.4 + 1), 0, 1)
    L.add(m * fall, color, amount)

# ------------------------------------------------------------------ people
def person(L, x, y, h, body, skin=None, hair=None, pose="stand", rimc=None, rim_dir=(1, 0), facing=1, coat=False):
    """A standing figure, feet at (x, y), height h. Mostly silhouette; a rim
    light picks out the edge facing the light."""
    s = h / 100.0
    f = facing
    parts = []
    head = ellipse(L, x + 2 * s * f, y - 91 * s, 6.5 * s, 8 * s)
    neck = rect(L, x - 2 * s + 1.5 * s * f, y - 85 * s, 4 * s, 6 * s)
    torso_pts = [(x - 11 * s, y - 80 * s), (x + 11 * s, y - 80 * s), (x + 9 * s, y - 46 * s), (x - 9 * s, y - 46 * s)]
    if coat:
        torso_pts = [(x - 12 * s, y - 80 * s), (x + 12 * s, y - 80 * s), (x + 13 * s, y - 28 * s), (x - 13 * s, y - 28 * s)]
    torso = poly(L, torso_pts)
    legs = poly(L, [(x - 9 * s, y - 48 * s), (x - 1 * s, y - 48 * s), (x - 2 * s, y), (x - 8 * s, y)]) + \
        poly(L, [(x + 1 * s, y - 48 * s), (x + 9 * s, y - 48 * s), (x + 8 * s, y), (x + 2 * s, y)])
    if pose == "stand":
        arms = line(L, [(x - 11 * s, y - 77 * s), (x - 14 * s, y - 60 * s), (x - 13 * s, y - 44 * s)], 5 * s) + \
            line(L, [(x + 11 * s, y - 77 * s), (x + 14 * s, y - 60 * s), (x + 13 * s, y - 44 * s)], 5 * s)
    elif pose == "gun":
        arms = line(L, [(x + 10 * s * f, y - 76 * s), (x + 24 * s * f, y - 70 * s), (x + 38 * s * f, y - 70 * s)], 5 * s) + \
            line(L, [(x - 10 * s * f, y - 76 * s), (x + 8 * s * f, y - 68 * s), (x + 36 * s * f, y - 69 * s)], 5 * s)
        arms += rect(L, min(x + 36 * s * f, x + 48 * s * f), y - 73 * s, 12 * s, 4 * s)
    elif pose == "hands_hips":
        arms = line(L, [(x - 11 * s, y - 77 * s), (x - 20 * s, y - 62 * s), (x - 10 * s, y - 50 * s)], 5 * s) + \
            line(L, [(x + 11 * s, y - 77 * s), (x + 20 * s, y - 62 * s), (x + 10 * s, y - 50 * s)], 5 * s)
    elif pose == "megaphone":
        arms = line(L, [(x + 10 * s * f, y - 76 * s), (x + 18 * s * f, y - 84 * s), (x + 12 * s * f, y - 90 * s)], 5 * s) + \
            line(L, [(x - 11 * s, y - 77 * s), (x - 14 * s, y - 60 * s), (x - 13 * s, y - 44 * s)], 5 * s)
        arms += poly(L, [(x + 9 * s * f, y - 92 * s), (x + 22 * s * f, y - 97 * s), (x + 22 * s * f, y - 83 * s), (x + 9 * s * f, y - 88 * s)])
    else:
        arms = np.zeros_like(head)
    body_m = np.clip(torso + legs + arms + neck, 0, 1)
    L.paint(body_m, body)
    L.paint(head, skin if skin else body)
    if hair:
        L.paint(ellipse(L, x + 1 * s * f, y - 95 * s, 7 * s, 5.5 * s), hair)
    full = np.clip(body_m + head, 0, 1)
    if rimc:
        L.paint(rim(full, rim_dir[0], rim_dir[1], max(1, int(s * 1.2))), rimc, 0.9)
    return full

def car_side(L, x, y, w, body, glass="1a2030", chrome="c8c8d0", rimc=None, lights_on=False, tail="ff2040"):
    """A long late-70s coupe in side view, wheels on y."""
    h = w * 0.26
    s = w / 200.0
    pts = [(x, y - 12 * s), (x + 8 * s, y - 30 * s), (x + 58 * s, y - 32 * s), (x + 80 * s, y - 52 * s),
           (x + 132 * s, y - 52 * s), (x + 152 * s, y - 33 * s), (x + 196 * s, y - 30 * s), (x + 200 * s, y - 14 * s),
           (x + 198 * s, y - 6 * s), (x + 2 * s, y - 6 * s)]
    m = poly(L, pts)
    L.vgrad([(0, mix(body, "ffffff", 0.25)), (0.35, body), (1, mix(body, INK, 0.6))], y - 52 * s, y, mask=m)
    win = poly(L, [(x + 84 * s, y - 49 * s), (x + 104 * s, y - 49 * s), (x + 104 * s, y - 34 * s), (x + 66 * s, y - 33 * s)]) + \
        poly(L, [(x + 108 * s, y - 49 * s), (x + 130 * s, y - 49 * s), (x + 146 * s, y - 34 * s), (x + 108 * s, y - 34 * s)])
    L.paint(win, glass)
    L.paint(line(L, [(x + 4 * s, y - 20 * s), (x + 196 * s, y - 20 * s)], 1.2 * s), chrome, 0.8)
    for wx in (38, 162):
        L.paint(ellipse(L, x + wx * s, y - 4 * s, 15 * s, 15 * s), "05040a")
        L.paint(ellipse(L, x + wx * s, y - 4 * s, 8 * s, 8 * s), mix(chrome, INK, 0.4))
        L.paint(ellipse(L, x + wx * s, y - 4 * s, 3 * s, 3 * s), chrome)
    if rimc:
        L.paint(rim(m, 0, -1, 1), rimc, 0.8)
    if lights_on:
        L.radial(x + 199 * s, y - 20 * s, 14 * s, "fff2c0", 1.5, 0.9)
        L.radial(x + 1 * s, y - 20 * s, 10 * s, tail, 1.5, 0.9)
    return m

# ------------------------------------------------------------------ faces
def star_pts(cx, cy, r_out, r_in, rot=0.0):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + rot + i * math.pi / 5
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts

def face(L, cx, cy, s, skin, hair, eyes="2a1810", jacket="c01830", lip="a03040", light=(1, -0.3),
         light_col="ff5a9a", fill_col="3040a0", hair_style="long", star=False, stubble=False,
         shirt=None, collar="popped", look=(0.0, 0.0), brows=0.0, mouth=0.0, glasses=False, scar=False,
         jaw=1.0, grime=0.0, cig=False, earring=False, tie=None):
    """A bust, three-quarter view, noir split lighting: warm key from the
    `light` side, cool fill from the other. s = half the head height."""
    lx = 1 if light[0] >= 0 else -1
    def P(x, y):
        return (cx + x * s, cy + y * s)
    # --- back hair (behind everything), shoulders, neck
    if hair_style == "long":
        bh = spoly(L, [P(-1.15, -1.0), P(0.0, -1.55), P(1.15, -1.0), P(1.35, 0.6), P(1.5, 2.1), P(0.9, 2.3), P(0.6, 1.2),
                       P(-0.6, 1.2), P(-0.95, 2.35), P(-1.55, 2.2), P(-1.35, 0.6)])
        L.vgrad([(0, mix(hair, "ffffff", 0.05)), (1, mix(hair, INK, 0.6))], cy - 1.5 * s, cy + 2.3 * s, mask=bh)
    sh = spoly(L, [P(-3.3, 4.8), P(-2.9, 2.3), P(-1.6, 1.55), P(-0.5, 1.3), P(0.5, 1.3), P(1.6, 1.55), P(2.9, 2.3), P(3.3, 4.8)])
    L.vgrad([(0, mix(jacket, "ffffff", 0.12)), (0.5, jacket), (1, mix(jacket, INK, 0.75))], cy + 1.2 * s, cy + 4.6 * s, mask=sh)
    # leather creases and wear
    rng = np.random.default_rng(int(s * 13 + cx))
    for i in range(7):
        x0 = rng.uniform(-2.6, 2.6)
        L.paint(line(L, [P(x0, 2.2 + rng.uniform(0, 0.6)), P(x0 + rng.uniform(-0.5, 0.5), 3.4 + rng.uniform(0, 1))], max(1, 0.04 * s)) * sh,
                mix(jacket, "ffffff", 0.35) if i % 2 else mix(jacket, INK, 0.5), 0.35)
    if grime > 0:
        L.multiply(sh * (value_noise(L.w, L.h, 3, 17, 3) > 0.6), "403040", grime * 0.5)
    if shirt:
        L.paint(spoly(L, [P(-0.62, 1.35), P(0.62, 1.35), P(0.2, 2.6), P(0, 3.3), P(-0.2, 2.6)]), shirt)
    if tie:
        L.paint(poly(L, [P(-0.12, 1.45), P(0.12, 1.45), P(0.2, 3.2), P(0, 3.5), P(-0.2, 3.2)]), tie)
    if collar == "popped":
        L.paint(poly(L, [P(-1.15, 0.95), P(-0.55, 1.35), P(-0.75, 2.6), P(-1.7, 1.9)]), mix(jacket, "ffffff", 0.14))
        L.paint(poly(L, [P(1.15, 0.95), P(0.55, 1.35), P(0.75, 2.6), P(1.7, 1.9)]), mix(jacket, INK, 0.3))
    elif collar == "lapel":
        L.paint(poly(L, [P(-0.62, 1.35), P(-1.55, 1.65), P(-0.25, 3.7)]), mix(jacket, "ffffff", 0.15))
        L.paint(poly(L, [P(0.62, 1.35), P(1.55, 1.65), P(0.25, 3.7)]), mix(jacket, INK, 0.3))
    L.paint(rim(sh, lx, -1, 1), light_col, 0.7)
    nk = spoly(L, [P(-0.48, 0.3), P(0.5, 0.3), P(0.58, 1.45), P(0, 1.6), P(-0.55, 1.45)])
    L.paint(nk, mix(skin, INK, 0.35))
    L.multiply(blur(rect(L, cx - 0.6 * s, cy + 0.3 * s, 1.2 * s, 0.45 * s), s * 0.12) * nk, "301828", 0.6)
    # --- face: smooth, jaw toward the light
    fm = spoly(L, [P(-0.95, -1.0), P(0.0, -1.22), P(0.95, -1.02), P(1.02, -0.2), P(0.88 * jaw, 0.45), P(0.42, 0.95),
                   P(0.0, 1.1), P(-0.4, 0.95), P(-0.82 * jaw, 0.45), P(-1.0, -0.2)])
    t = np.clip((L.xx - (cx - 1.0 * s)) / (2.0 * s), 0, 1)
    if lx < 0:
        t = 1 - t
    lit, mid_, dark = mix(skin, light_col, 0.22), col(skin), mix(skin, fill_col, 0.5) * np.array([0.5, 0.5, 0.6, 1])
    k = np.clip((t - 0.32) / 0.3, 0, 1)[..., None]
    sk = dark * (1 - k) + mid_ * k
    k2 = np.clip((t - 0.74) / 0.14, 0, 1)[..., None]
    sk = sk * (1 - k2) + lit * k2
    sk[..., 3] = 1
    L.paint(fm, sk)
    # cheek hollow, under-jaw shade, grime/bruise
    L.multiply(blur(spoly(L, [P(-0.8, 0.15), P(-0.35, 0.35), P(-0.35, 0.95), P(-0.8, 0.5)]), s * 0.15) * fm, "402838", 0.55)
    L.multiply(blur(spoly(L, [P(0.45, 0.2), P(0.85, 0.2), P(0.7, 0.6), P(0.4, 0.6)]), s * 0.12) * fm, "402838", 0.25)
    if grime > 0:
        n = value_noise(L.w, L.h, 2, 29, 2)
        L.multiply(fm * np.clip((n - 0.62) * 5, 0, 1), "6a4a50", grime * 0.3)
    if stubble:
        sm = blur(spoly(L, [P(-0.8, 0.35), P(0.85, 0.35), P(0.45, 1.0), P(0, 1.12), P(-0.45, 1.0)]), 1) * fm
        nz = (np.random.default_rng(5).random((L.h, L.w)) > 0.7).astype(np.float32)
        L.multiply(sm * nz, "3a2a38", 0.25)
        L.multiply(sm, "6a5a6a", 0.22)
    # --- eyes
    ex, ey = look
    for side, ox in ((-1, -0.4), (1, 0.4)):
        ecx, ecy = cx + ox * s, cy - 0.25 * s
        w_ = 0.25 * s
        L.multiply(blur(ellipse(L, ecx, ecy - 0.02 * s, w_ * 1.35, 0.2 * s), s * 0.07) * fm, "402a40", 0.5)
        eye = spoly(L, [(ecx - w_, ecy + 0.01 * s), (ecx - w_ * 0.1, ecy - 0.1 * s), (ecx + w_, ecy - 0.02 * s), (ecx + w_ * 0.1, ecy + 0.08 * s)])
        L.paint(eye, mix("e0d8d0", fill_col, 0.25 if side * lx < 0 else 0.0))
        L.paint(ellipse(L, ecx + ex * 0.09 * s, ecy + ey * 0.04 * s - 0.01 * s, 0.095 * s, 0.095 * s) * eye, eyes)
        L.paint(ellipse(L, ecx + ex * 0.09 * s, ecy + ey * 0.04 * s - 0.01 * s, 0.045 * s, 0.045 * s) * eye, "05030a")
        L.paint(ellipse(L, ecx + ex * 0.09 * s + 0.035 * s, ecy - 0.045 * s, 0.022 * s, 0.022 * s), "ffffff", 0.9)
        L.paint(line(L, smooth([(ecx - w_ * 1.05, ecy + 0.02 * s), (ecx - w_ * 0.15, ecy - 0.12 * s), (ecx + w_ * 1.08, ecy - 0.04 * s)], 6, False), max(1, 0.055 * s)), "120810")
        by = ecy - 0.27 * s - brows * 0.05 * s
        tilt = brows * 0.07 * s * side
        L.paint(line(L, smooth([(ecx - w_ * 1.15, by + 0.06 * s + tilt), (ecx - w_ * 0.2, by - 0.03 * s), (ecx + w_ * 1.1, by + 0.02 * s - tilt)], 6, False), max(1, 0.085 * s)), mix(hair, INK, 0.35))
    # --- nose: shadow side + highlight ridge
    nx = cx + 0.06 * s * lx
    L.multiply(blur(spoly(L, [(nx - 0.05 * s * lx, cy - 0.15 * s), (nx - 0.12 * s * lx, cy + 0.25 * s), (nx + 0.1 * s * lx, cy + 0.3 * s)]), s * 0.05), "402030", 0.6)
    L.paint(line(L, [(nx + 0.03 * s * lx, cy - 0.12 * s), (nx + 0.09 * s * lx, cy + 0.18 * s)], max(1, 0.045 * s)), mix(skin, "ffffff", 0.4), 0.5)
    L.paint(ellipse(L, nx - 0.02 * s * lx, cy + 0.3 * s, 0.1 * s, 0.035 * s), "40202a", 0.6)
    # --- mouth
    my = cy + 0.6 * s
    curve = mouth * 0.07 * s
    L.paint(spoly(L, [(cx - 0.3 * s, my - curve), (cx, my - 0.05 * s), (cx + 0.3 * s, my - curve), (cx, my + 0.11 * s)]), lip)
    L.paint(line(L, smooth([(cx - 0.3 * s, my - curve), (cx, my + 0.015 * s), (cx + 0.3 * s, my - curve)], 5, False), max(1, 0.04 * s)), "2a0612")
    L.paint(ellipse(L, cx + 0.05 * s * lx, my + 0.08 * s, 0.1 * s, 0.025 * s), mix(lip, "ffffff", 0.4), 0.4)
    if cig:
        L.paint(line(L, [(cx + 0.18 * s, my + 0.02 * s), (cx + 0.75 * s, my + 0.12 * s)], max(1, 0.07 * s)), "e8e0d0")
        L.radial(cx + 0.78 * s, my + 0.12 * s, 0.14 * s, "ff6020", 1.5, 1.0)
    # --- front hair
    if hair_style == "long":
        hp = [P(-1.25, 0.6), P(-1.18, -0.9), P(-0.6, -1.6), P(0.4, -1.72), P(1.1, -1.25), P(1.22, -0.2), P(1.1, 0.5),
              P(0.95, -0.55), P(0.55, -1.02), P(-0.15, -0.95), P(-0.7, -0.65), P(-0.9, 0.2)]
    elif hair_style == "ponytail":
        hp = [P(-1.08, -0.2), P(-1.1, -1.0), P(-0.5, -1.62), P(0.45, -1.65), P(1.1, -1.1), P(1.08, -0.35), P(0.9, -0.85),
              P(0.2, -1.1), P(-0.6, -0.95), P(-0.92, -0.55)]
    elif hair_style == "short":
        hp = [P(-1.02, -0.35), P(-1.1, -1.2), P(-0.4, -1.65), P(0.6, -1.6), P(1.1, -1.05), P(1.03, -0.5), P(0.78, -0.95),
              P(-0.2, -1.1), P(-0.82, -0.8)]
    elif hair_style == "slick":
        hp = [P(-1.02, -0.4), P(-1.08, -1.25), P(-0.2, -1.72), P(0.9, -1.5), P(1.08, -0.75), P(0.92, -1.05), P(-0.3, -1.12), P(-0.8, -0.95)]
    elif hair_style == "silver":
        hp = [P(-1.05, -0.3), P(-1.12, -1.2), P(-0.2, -1.75), P(0.95, -1.45), P(1.1, -0.5), P(0.95, -1.0), P(-0.2, -1.15), P(-0.85, -0.85)]
    elif hair_style == "helmet":
        hp = [P(-1.2, 0.0), P(-1.25, -1.1), P(-0.3, -1.85), P(0.8, -1.75), P(1.3, -1.0), P(1.25, 0.05), P(1.0, -0.8),
              P(0.1, -1.05), P(-0.9, -0.8)]
    elif hair_style == "balding":
        hp = [P(-1.02, -0.2), P(-1.05, -0.8), P(-0.8, -1.05), P(-0.75, -0.6), P(-0.95, 0.0)]
    else:
        hp = [P(-0.95, -0.9), P(0, -1.25), P(0.95, -0.95)]
    hm = spoly(L, hp)
    L.vgrad([(0, mix(hair, "ffffff", 0.14)), (0.5, hair), (1, mix(hair, INK, 0.5))], cy - 1.8 * s, cy + 0.8 * s, mask=hm)
    for i in range(16):
        x0 = cx + rng.uniform(-1.0, 1.0) * s
        L.paint(line(L, smooth([(x0, cy - 1.65 * s), (x0 + rng.uniform(-0.15, 0.15) * s, cy - 1.3 * s), (x0 + rng.uniform(-0.35, 0.35) * s, cy - 0.8 * s)], 4, False), max(1, 0.03 * s)) * hm,
                mix(hair, "ffffff", 0.3) if i % 3 else mix(hair, INK, 0.4), 0.35)
    if hair_style == "ponytail":
        pt = spoly(L, [P(-0.9, -1.2), P(-1.6, -0.9), P(-1.9, 0.3), P(-1.6, 1.6), P(-1.3, 0.4), P(-1.05, -0.5)])
        L.vgrad([(0, hair), (1, mix(hair, INK, 0.5))], cy - 1.2 * s, cy + 1.6 * s, mask=pt)
    head_all = np.clip(fm + hm, 0, 1)
    L.paint(rim(head_all, lx, 0, max(1, int(s * 0.05))), light_col, 0.85)
    L.paint(rim(head_all, 0, -1, 1), light_col, 0.35)
    L.paint(rim(head_all, -lx, 0, 1), fill_col, 0.5)
    if earring:
        L.radial(cx - 0.98 * s * lx, cy + 0.25 * s, 0.12 * s, "ffd040", 1.2, 1.0)
    if glasses:
        for ox in (-0.4, 0.4):
            L.paint(spoly(L, [(cx + ox * s - 0.33 * s, cy - 0.38 * s), (cx + ox * s + 0.33 * s, cy - 0.38 * s), (cx + ox * s + 0.28 * s, cy - 0.1 * s), (cx + ox * s - 0.28 * s, cy - 0.1 * s)]), "0c0a12", 0.92)
            L.paint(line(L, [(cx + ox * s - 0.15 * s, cy - 0.33 * s), (cx + ox * s + 0.2 * s, cy - 0.3 * s)], max(1, 0.04 * s)), light_col, 0.8)
        L.paint(line(L, [(cx - 0.08 * s, cy - 0.33 * s), (cx + 0.08 * s, cy - 0.33 * s)], max(1, 0.05 * s)), "0c0a12")
    if star:
        sx_, sy_ = cx - 0.4 * s, cy - 0.27 * s
        stm = poly(L, star_pts(sx_, sy_, 0.6 * s, 0.25 * s, 0.1))
        paint_n = value_noise(L.w, L.h, 2, 41, 2)
        L.paint(stm, "d8a428", 0.9)
        L.paint(stm * (paint_n > 0.55), "fff0a0", 0.5)   # streaky greasepaint
        L.paint(rim(stm, -1, -1, 1), "fff4b0", 0.8)
        L.add(blur(stm, 3), "ffb830", 0.22)
        eye = spoly(L, [(sx_ - 0.24 * s, sy_ + 0.03 * s), (sx_ - 0.03 * s, sy_ - 0.07 * s), (sx_ + 0.25 * s, sy_ + 0.0 * s), (sx_ + 0.02 * s, sy_ + 0.1 * s)])
        L.paint(eye, "d0c8c0")
        L.paint(ellipse(L, sx_ + look[0] * 0.09 * s, sy_ + 0.02 * s, 0.085 * s, 0.085 * s) * eye, "05030a")
        L.paint(ellipse(L, sx_ + 0.035 * s, sy_ - 0.015 * s, 0.022 * s, 0.022 * s), "ffffff")
    if scar:
        L.paint(line(L, [P(0.52, -0.7), P(0.72, 0.1)], max(1, 0.05 * s)), "c07070", 0.8)
    return np.clip(head_all + sh + nk, 0, 1)
