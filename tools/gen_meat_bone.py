#!/usr/bin/env python3
"""The meat bone for the dogs: painted big and brought down to a crisp
sprite. Two states: the full bone (seared meat, grill marks, marbling, a
glossy highlight, a bitten face showing the pink inside) and the bone
picked clean with a few ragged strips left. Outlined like the game's props.

  python tools/gen_meat_bone.py   ->  assets/art/props/meat_bone.png, meat_bone_eaten.png
"""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "art", "props")
W, H, SS = 58, 44, 6          # final size, supersampling
w, h = W * SS, H * SS

def S(v):
    return v * SS

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))

def radial(size, c0, c1, center, radius):
    im = Image.new("RGBA", size)
    px = im.load()
    for y in range(size[1]):
        for x in range(size[0]):
            d = math.hypot(x - center[0], (y - center[1]) * 1.25) / radius
            px[x, y] = lerp(c0, c1, min(1.0, d)) + (255,)
    return im

def bone_layer():
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cream, shade, hi = (238, 229, 206), (196, 182, 152), (255, 250, 236)
    cy = h / 2
    # the shaft, slightly waisted
    d.rounded_rectangle([S(8), cy - S(3.4), w - S(8), cy + S(3.4)], radius=S(3), fill=cream)
    d.rectangle([S(10), cy + S(1.2), w - S(10), cy + S(3.2)], fill=shade)
    d.rectangle([S(12), cy - S(2.6), w - S(12), cy - S(1.6)], fill=hi)
    # knuckles at both ends
    for ex in (S(7), w - S(7)):
        for dy in (-S(4.6), S(4.6)):
            r = S(5.0)
            d.ellipse([ex - r, cy + dy - r, ex + r, cy + dy + r], fill=cream)
            d.ellipse([ex - r * 0.8, cy + dy - r * 0.2, ex + r * 0.9, cy + dy + r * 0.95], fill=shade)
            d.ellipse([ex - r * 0.9, cy + dy - r * 0.95, ex + r * 0.4, cy + dy - r * 0.1], fill=cream)
            d.ellipse([ex - r * 0.55, cy + dy - r * 0.75, ex - r * 0.05, cy + dy - r * 0.35], fill=hi)
    return im

def meat_mask(rng, scale=1.0, ragged=0.0):
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    cx, cy = w / 2, h / 2
    # a lumpy haunch: overlapping blobs
    blobs = [(0, 0, 13.5, 11.5), (-6, -2, 9, 8.5), (6, 1, 9.5, 9), (-2, 4, 9, 7), (3, -4, 8, 7)]
    for bx, by, rx, ry in blobs:
        rx, ry = rx * scale, ry * scale
        d.ellipse([cx + S(bx) - S(rx), cy + S(by) - S(ry), cx + S(bx) + S(rx), cy + S(by) + S(ry)], fill=255)
    if ragged > 0:
        # tear it up: bites taken out all round
        for i in range(int(40 * ragged)):
            a = rng.uniform(0, math.tau)
            rr = S(rng.uniform(6, 13)) * scale
            r2 = S(rng.uniform(2.5, 5.5))
            x, y = cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.8
            d.ellipse([x - r2, y - r2, x + r2, y + r2], fill=0)
    return m.filter(ImageFilter.GaussianBlur(S(0.35))).point(lambda v: 255 if v > 120 else 0)

def meat_layer(rng, mask):
    cx, cy = w / 2, h / 2
    base = radial((w, h), (196, 86, 52), (104, 38, 22), (cx - S(4), cy - S(5)), S(17))
    d = ImageDraw.Draw(base)
    # the bitten face: a pink-red cross-section on the right with a fat rim
    bx, by = cx + S(8), cy + S(1)
    d.ellipse([bx - S(5.5), by - S(6.5), bx + S(5.5), by + S(6.5)], fill=(236, 214, 190))
    d.ellipse([bx - S(4.6), by - S(5.6), bx + S(4.6), by + S(5.6)], fill=(202, 64, 70))
    d.ellipse([bx - S(3.2), by - S(4.0), bx + S(2.4), by + S(3.6)], fill=(226, 96, 96))
    for i in range(7):
        a = rng.uniform(0, math.tau)
        d.line([bx, by, bx + math.cos(a) * S(4.2), by + math.sin(a) * S(5.0)], fill=(176, 48, 56), width=int(S(0.5)))
    # grill marks across the sear
    for k in range(4):
        x0 = cx - S(15) + k * S(5.2)
        d.line([x0, cy - S(10), x0 + S(7), cy + S(9)], fill=(58, 22, 14), width=int(S(1.3)))
        d.line([x0 + S(0.9), cy - S(10), x0 + S(7.9), cy + S(9)], fill=(84, 34, 20), width=int(S(0.6)))
    # marbling: thin fat streaks
    for k in range(6):
        x = cx + S(rng.uniform(-11, 3))
        y = cy + S(rng.uniform(-7, 7))
        pts = [(x + S(i * 1.4), y + math.sin(i * 0.9 + k) * S(0.8)) for i in range(5)]
        d.line(pts, fill=(238, 196, 170), width=int(S(0.45)))
    # glossy fat highlight on the top
    gl = Image.new("L", (w, h), 0)
    ImageDraw.Draw(gl).ellipse([cx - S(11), cy - S(10.5), cx - S(1), cy - S(6.5)], fill=150)
    ImageDraw.Draw(gl).ellipse([cx - S(8), cy - S(9.8), cx - S(4), cy - S(8.2)], fill=255)
    gl = gl.filter(ImageFilter.GaussianBlur(S(0.8)))
    base = Image.composite(Image.new("RGBA", (w, h), (255, 226, 190, 255)), base, gl.point(lambda v: int(v * 0.55)))
    # a darker underside for weight
    sh = Image.new("L", (w, h), 0)
    ImageDraw.Draw(sh).ellipse([cx - S(14), cy + S(3), cx + S(10), cy + S(14)], fill=120)
    sh = sh.filter(ImageFilter.GaussianBlur(S(1.5)))
    base = Image.composite(Image.new("RGBA", (w, h), (52, 16, 10, 255)), base, sh)
    base.putalpha(mask)
    return base

def outline(im, col=(28, 10, 10, 255)):
    a = im.split()[3]
    grown = a.filter(ImageFilter.MaxFilter(3))
    ol = Image.new("RGBA", im.size, col)
    ol.putalpha(ImageChops.subtract(grown, a))
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.alpha_composite(ol)
    out.alpha_composite(im)
    return out

def build(eaten):
    rng = random.Random(7 if not eaten else 11)
    im = bone_layer()
    if not eaten:
        m = meat_mask(rng)
        im.alpha_composite(meat_layer(rng, m))
    else:
        # a few ragged strips still on the bone
        m = meat_mask(rng, 0.8, ragged=0.35)
        im.alpha_composite(meat_layer(rng, m))
    small = im.resize((W, H), Image.LANCZOS)
    # crisp alpha edge, then the outline at final size
    r, g, b, a = small.split()
    a = a.point(lambda v: 255 if v > 110 else 0)
    small = Image.merge("RGBA", (r, g, b, a))
    return outline(small)

os.makedirs(OUT, exist_ok=True)
build(False).save(os.path.join(OUT, "meat_bone.png"))
build(True).save(os.path.join(OUT, "meat_bone_eaten.png"))
print("meat bone sprites written")
