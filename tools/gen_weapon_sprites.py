#!/usr/bin/env python3
"""World sprites for every weapon, from the painted HUD art.

The HUD pictures (assets/art/weapons, 256x128, side view, muzzle to the
right) are brought down to the size the weapon has in the world, at 4x
pixel density (the game draws them at 1/4 scale, so on the floor, in
Cass's hands and in a guard's they're the same size as before, with four
times the detail). The painted neon rim is cut away and replaced by the
game's dark outline; a touch of sharpening keeps the small shapes crisp.

  python tools/gen_weapon_sprites.py   ->  assets/art/weapons_world/<key>.png
"""
import os
from PIL import Image, ImageFilter, ImageChops, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "art", "weapons")
OUT = os.path.join(ROOT, "assets", "art", "weapons_world")
K = 4    # pixel density (must match SpriteLib.WEAPON_DENSITY)

# world length in pixels (as the old pixel-art sprites), a little longer for
# the long guns so their detail survives
LENGTH = {
    "pistol": 9, "whisper": 12, "revolver": 10, "hotshot": 10, "boomstick": 14,
    "flamethrower": 17, "smg": 11, "shotgun": 17, "rifle": 18, "knife": 9,
    "glass_shard": 9, "bat": 14, "pipe": 12, "machete": 13, "bottle": 9,
    "broken_bottle": 9, "brick": 7,
}
INK = (11, 7, 16, 255)

def build(key):
    im = Image.open(os.path.join(SRC, key + ".png")).convert("RGBA")
    r, g, b, a = im.split()
    # cut the neon rim: keep the solid body, shrink it past the glow
    thin = key in ("glass_shard", "knife", "machete", "pipe", "bat")
    solid = a.point(lambda v: 255 if v > 200 else 0).filter(ImageFilter.MinFilter(3 if thin else 7))
    # the rim is also tinted: drop strongly pink/cyan edge pixels that survive
    im.putalpha(solid)
    box = solid.getbbox()
    im = im.crop(box)
    tw = LENGTH[key] * K
    th = max(K * 2, round(im.height * tw / im.width))
    # two-step downscale keeps the painted texture from turning to mush
    mid = im.resize((tw * 2, th * 2), Image.LANCZOS)
    small = mid.resize((tw, th), Image.LANCZOS)
    # tone down the neon rim light painted into the edges (pink / cyan)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            r, g, b, al = px[x, y]
            neon = (r > 140 and b > 140 and g < 110) or (b > 170 and g > 140 and r < 110)
            if neon and al > 0:
                l = int(0.3 * r + 0.55 * g + 0.15 * b)
                px[x, y] = (int(r * 0.35 + l * 0.65), int(g * 0.35 + l * 0.65), int(b * 0.35 + l * 0.65), al)
    small = ImageEnhance.Contrast(small).enhance(1.12)
    small = small.filter(ImageFilter.UnsharpMask(radius=1.2, percent=90, threshold=2))
    r, g, b, a = small.split()
    a = a.point(lambda v: 255 if v > 110 else 0)
    small = Image.merge("RGBA", (r, g, b, a))
    # pad for the outline and draw it
    pad = Image.new("RGBA", (tw + 4, th + 4), (0, 0, 0, 0))
    pad.alpha_composite(small, (2, 2))
    a = pad.split()[3]
    grown = a.filter(ImageFilter.MaxFilter(3))
    ol = Image.new("RGBA", pad.size, INK)
    ol.putalpha(ImageChops.subtract(grown, a))
    out = Image.new("RGBA", pad.size, (0, 0, 0, 0))
    out.alpha_composite(ol)
    out.alpha_composite(pad)
    return out

os.makedirs(OUT, exist_ok=True)
for key in LENGTH:
    img = build(key)
    img.save(os.path.join(OUT, key + ".png"))
    print(key, img.size)
