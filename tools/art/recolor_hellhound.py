"""Hellhound paintings: the doberman ones recolored (charred coat, molten markings, ember cracks).
  python tools/art/recolor_hellhound.py  (run from the repo root)"""
from PIL import Image
import colorsys, random
for src, dst in [("dog_doberman", "dog_hellhound"), ("dog_doberman_down", "dog_hellhound_down")]:
    im = Image.open(f"assets/art/cast/{src}.png").convert("RGBA"); px = im.load(); w, h = im.size
    random.seed(7)
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 10: continue
            hh, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            if s > 0.35 and 0.02 < hh < 0.14 and l > 0.18:      # tan markings -> molten
                l2 = min(1.0, l * 1.25 + 0.08)
                nr, ng, nb = colorsys.hls_to_rgb(0.045 + (l2 - 0.4) * 0.08, l2, 1.0)
            elif l < 0.3:                                         # black coat -> charred, red undertone
                nr, ng, nb = colorsys.hls_to_rgb(0.0, l * 0.7, 0.45)
            else:
                nr, ng, nb = r / 255, g / 255, b / 255
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    # ember cracks: short jagged glowing lines across the coat
    for _ in range(9):
        x, y = random.randrange(w // 6, w * 5 // 6), random.randrange(h // 4, h * 3 // 4)
        for step in range(random.randrange(4, 9)):
            if 0 <= x < w and 0 <= y < h and px[x, y][3] > 200:
                c = px[x, y]
                if sum(c[:3]) < 260:
                    px[x, y] = (255, 120 + step * 10, 30, 255)
            x += random.choice((1, 1, 2)); y += random.choice((-1, 0, 1))
    im.save(f"assets/art/cast/{dst}.png")
