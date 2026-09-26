"""
Tiny painting toolkit for HOTSHOT CALIFORNIA's illustrated art (cutscene
shots, chapter covers, portraits). Everything is drawn from code: layered
RGBA float canvases, anti-aliased shapes, gradients, value noise, glows,
rim lights, grain and an ordered-dither finish so the art sits with the
game's pixel look.

Coordinates are in canvas pixels. Colours are hex strings or (r, g, b)
floats 0..1.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SS = 3  # supersampling for shape masks

def col(c, a=1.0):
    if isinstance(c, str):
        c = c.lstrip("#")
        return np.array([int(c[i:i + 2], 16) / 255.0 for i in (0, 2, 4)] + [a])
    c = list(c)
    return np.array(c[:3] + [c[3] if len(c) > 3 else a], dtype=float)

def mix(a, b, t):
    return col(a) * (1 - t) + col(b) * t


class Layer:
    """An RGBA float image (premultiplied-free, straight alpha)."""

    def __init__(self, w, h, fill=None):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), dtype=np.float32)
        if fill is not None:
            self.a[:] = col(fill)
        yy, xx = np.mgrid[0:h, 0:w]
        self.yy = yy.astype(np.float32)
        self.xx = xx.astype(np.float32)

    # ------------------------------------------------------------ compositing
    def paint(self, mask, color, alpha=1.0):
        """Alpha-composite `color` (vec4 or HxWx4 array) through mask 0..1."""
        c = color if isinstance(color, np.ndarray) and color.ndim == 3 else np.broadcast_to(col(color) if not isinstance(color, np.ndarray) else color, self.a.shape)
        m = np.clip(mask, 0, 1)[..., None] * alpha * c[..., 3:4]
        rgb = self.a[..., :3] * (1 - m) + c[..., :3] * m
        a = self.a[..., 3:4] + m * (1 - self.a[..., 3:4])
        self.a[..., :3] = rgb
        self.a[..., 3:4] = a
        return self

    def add(self, mask, color, amount=1.0):
        """Additive light (for glows); also raises alpha so it shows on empty layers."""
        c = col(color) if not isinstance(color, np.ndarray) else color
        m = np.clip(mask, 0, None)[..., None] * amount
        self.a[..., :3] = np.clip(self.a[..., :3] + c[:3] * m, 0, 1)
        self.a[..., 3:4] = np.clip(self.a[..., 3:4] + m * 0.9, 0, 1)
        return self

    def multiply(self, mask, color, amount=1.0):
        c = col(color)
        m = np.clip(mask, 0, 1)[..., None] * amount
        self.a[..., :3] = self.a[..., :3] * (1 - m) + self.a[..., :3] * c[:3] * m
        return self

    def over(self, other):
        """Composite another layer on top of this one."""
        m = other.a[..., 3:4]
        self.a[..., :3] = self.a[..., :3] * (1 - m) + other.a[..., :3] * m
        self.a[..., 3:4] = self.a[..., 3:4] + m * (1 - self.a[..., 3:4])
        return self

    def copy(self):
        l = Layer(self.w, self.h)
        l.a = self.a.copy()
        return l

    # ------------------------------------------------------------ gradients
    def vgrad(self, stops, y0=0, y1=None, mask=None):
        """Vertical gradient through [(t, colour), ...] between rows y0..y1."""
        y1 = self.h if y1 is None else y1
        t = np.clip((self.yy - y0) / max(1, (y1 - y0)), 0, 1)
        out = np.zeros_like(self.a)
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i + 1]
            k = np.clip((t - t0) / max(1e-6, t1 - t0), 0, 1)[..., None]
            seg = (t >= t0) & (t <= t1)
            out[seg] = (col(c0) * (1 - k) + col(c1) * k)[seg]
        out[t < stops[0][0]] = col(stops[0][1])
        out[t > stops[-1][0]] = col(stops[-1][1])
        self.paint(np.ones((self.h, self.w)) if mask is None else mask, out)
        return self

    def radial(self, cx, cy, r, color, power=2.0, amount=1.0, sy=1.0):
        d = np.sqrt((self.xx - cx) ** 2 + ((self.yy - cy) / sy) ** 2) / r
        m = np.clip(1 - d, 0, 1) ** power
        return self.add(m, color, amount)

    def to_image(self):
        return Image.fromarray((np.clip(self.a, 0, 1) * 255).astype(np.uint8), "RGBA")


# ------------------------------------------------------------------ masks
def _canvas(w, h):
    im = Image.new("L", (w * SS, h * SS), 0)
    return im, ImageDraw.Draw(im)

def _down(im, w, h, blur=0.0):
    im = im.resize((w, h), Image.LANCZOS)
    if blur > 0:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(im, dtype=np.float32) / 255.0

def poly(L, pts, blur=0.0):
    im, d = _canvas(L.w, L.h)
    d.polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    return _down(im, L.w, L.h, blur)

def smooth(pts, n=8, closed=True):
    """Catmull-Rom through control points: organic outlines from a few points."""
    P = list(pts)
    out = []
    cnt = len(P) if closed else len(P) - 1
    for i in range(cnt):
        p0 = P[(i - 1) % len(P)] if closed or i > 0 else P[0]
        p1 = P[i]
        p2 = P[(i + 1) % len(P)]
        p3 = P[(i + 2) % len(P)] if closed or i + 2 < len(P) else P[-1]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    if not closed:
        out.append(P[-1])
    return out

def spoly(L, pts, blur=0.0):
    return poly(L, smooth(pts), blur)

def ellipse(L, cx, cy, rx, ry, blur=0.0):
    im, d = _canvas(L.w, L.h)
    d.ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], fill=255)
    return _down(im, L.w, L.h, blur)

def rect(L, x, y, w, h, blur=0.0):
    return poly(L, [(x, y), (x + w, y), (x + w, y + h), (x, y + h)], blur)

def line(L, pts, width, blur=0.0):
    im, d = _canvas(L.w, L.h)
    d.line([(x * SS, y * SS) for x, y in pts], fill=255, width=max(1, int(width * SS)), joint="curve")
    return _down(im, L.w, L.h, blur)

def text_mask(L, x, y, s, size, font, anchor="la", rot=0.0):
    im, d = _canvas(L.w, L.h)
    f = ImageFont.truetype(font, int(size * SS))
    if rot == 0.0:
        d.text((x * SS, y * SS), s, font=f, fill=255, anchor=anchor)
    else:
        tmp = Image.new("L", im.size, 0)
        ImageDraw.Draw(tmp).text((x * SS, y * SS), s, font=f, fill=255, anchor=anchor)
        tmp = tmp.rotate(rot, center=(x * SS, y * SS), resample=Image.BICUBIC)
        im = tmp
    return _down(im, L.w, L.h)

def blur(mask, r):
    im = Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(r))
    return np.asarray(im, dtype=np.float32) / 255.0

def shift(mask, dx, dy):
    out = np.zeros_like(mask)
    h, w = mask.shape
    xs0, xs1 = max(0, dx), min(w, w + dx)
    ys0, ys1 = max(0, dy), min(h, h + dy)
    out[ys0:ys1, xs0:xs1] = mask[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return out

def rim(mask, dx, dy, width=1):
    """Edge of `mask` facing direction (dx, dy): where a light from there hits."""
    m = mask.copy()
    s = shift(mask, -int(np.sign(dx)) * width, -int(np.sign(dy)) * width)
    return np.clip(m - s, 0, 1)

# ------------------------------------------------------------------ noise
_rng = np.random.default_rng(1988)

def value_noise(w, h, scale, seed=0, octaves=4, persistence=0.5):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), dtype=np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        s = max(1, int(scale / (2 ** o)))
        gw, gh = w // s + 2, h // s + 2
        g = rng.random((gh, gw)).astype(np.float32)
        im = Image.fromarray((g * 255).astype(np.uint8), "L").resize((gw * s, gh * s), Image.BICUBIC)
        out += np.asarray(im, dtype=np.float32)[:h, :w] / 255.0 * amp
        tot += amp
        amp *= persistence
    return out / tot

def grain(L, amount=0.04, seed=3):
    rng = np.random.default_rng(seed)
    n = rng.normal(0, amount, (L.h, L.w, 1)).astype(np.float32)
    L.a[..., :3] = np.clip(L.a[..., :3] + n, 0, 1)
    return L

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0 - 0.5

def dither(L, levels=18):
    """Ordered dither to a limited number of levels per channel: retro finish
    that keeps gradients smooth-looking at pixel scale."""
    h, w = L.h, L.w
    th = np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w][..., None]
    L.a[..., :3] = np.clip(np.round(L.a[..., :3] * (levels - 1) + th) / (levels - 1), 0, 1)
    return L

def vignette(L, amount=0.5, power=2.2):
    cx, cy = L.w / 2, L.h / 2
    d = np.sqrt(((L.xx - cx) / cx) ** 2 + ((L.yy - cy) / cy) ** 2) / 1.414
    L.a[..., :3] *= (1 - amount * np.clip(d, 0, 1) ** power)[..., None]
    return L

def save(L, path, finish=True, levels=20):
    if finish:
        dither(L, levels)
    L.to_image().save(path)
