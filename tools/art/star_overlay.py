"""Paints Cass's gold greasepaint star crisply over the painted portrait so it
reads at thumbnail size (the model paints it too faint)."""
from PIL import Image, ImageDraw, ImageFilter
import math, numpy as np, sys
P = 'assets/characters/portraits/cass_star.png'
im = Image.open(P).convert('RGB')
W = im.width
cx, cy, R = 0.598 * W, 0.405 * W, 0.105 * W
S = 4
m = Image.new('L', (W * S, W * S), 0)
pts = [(cx + (R if i % 2 == 0 else R * 0.44) * math.cos(-math.pi / 2 + i * math.pi / 5),
        cy + (R if i % 2 == 0 else R * 0.44) * math.sin(-math.pi / 2 + i * math.pi / 5)) for i in range(10)]
ImageDraw.Draw(m).polygon([(x * S, y * S) for x, y in pts], fill=255)
m = m.resize((W, W), Image.LANCZOS)
base = np.asarray(im).astype(float) / 255
lum = base.mean(axis=2, keepdims=True)
yy, xx = np.mgrid[0:W, 0:W]
sheen = np.clip(1.0 - np.abs(((xx - cx) + (yy - cy)) / (R * 1.2)), 0, 1)[..., None]
# greasepaint over skin: gold that keeps the face's shading, so the eye,
# lashes and brow still show through the paint
gold = np.clip(np.array([1.0, 0.76, 0.2]) * (0.25 + 1.1 * lum) + sheen * 0.3, 0, 1)
a = (np.asarray(m).astype(float) / 255 * 0.82)[..., None]
out = base * (1 - a) + gold * a
edge = np.asarray(m.filter(ImageFilter.FIND_EDGES)).astype(float)[..., None] / 255 * 0.3
out = out * (1 - edge) + np.array([0.3, 0.17, 0.04]) * edge
Image.fromarray((out * 255).astype(np.uint8)).save(P)
