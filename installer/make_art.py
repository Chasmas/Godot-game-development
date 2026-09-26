#!/usr/bin/env python3
"""Builds the installer artwork from the game's title backdrop renders.

  python3 installer/make_art.py <splash_src.png 1600x900> <side_src.png tall>

Sources come from tools/screenshot.tscn (SHOT_MODE=backdrop). Outputs 24-bit
BMPs NSIS can use, into installer/art/:
  splash.bmp  640x360   AdvSplash, shown while the installer starts
  sidebar.bmp 164x314   welcome / finish page (Modern UI)
  header.bmp  150x57    page header (Modern UI)
"""
import os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "installer", "art")
FONTS = os.path.join(ROOT, "assets", "fonts")
INK = (11, 6, 20)
PINK = (255, 61, 127)
CYAN = (53, 224, 255)
GOLD = (255, 210, 63)
PAPER = (244, 240, 232)

def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)

def gradient_text(text, fnt, stops, stripes=True, glint=True):
    """Text filled with a vertical gradient, retro stripe cuts in the lower
    half and a chrome glint, like the in-game logo shader."""
    l, t, r, b = fnt.getbbox(text)
    w, h = r - l + 8, b - t + 8
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text((4 - l, 4 - t), text, font=fnt, fill=255)
    fill = Image.new("RGB", (w, h))
    px = fill.load()
    for y in range(h):
        k = y / max(1, h - 1)
        for i in range(len(stops) - 1):
            a, bb = stops[i], stops[i + 1]
            if a[0] <= k <= bb[0]:
                f = (k - a[0]) / max(1e-6, bb[0] - a[0])
                c = tuple(int(a[1][j] + (bb[1][j] - a[1][j]) * f) for j in range(3))
                break
        for x in range(w):
            px[x, y] = c
    if stripes:
        d = ImageDraw.Draw(mask)
        n = 0
        y = int(h * 0.55)
        while y < h:
            gap = max(1, int(h * 0.035) + n // 2)
            d.rectangle([0, y, w, y + gap - 1], fill=0)
            y += int(h * 0.1)
            n += 1
    out = Image.new("RGBA", (w, h))
    out.paste(fill, (0, 0), mask)
    if glint:
        g = Image.new("L", (w, h), 0)
        gd = ImageDraw.Draw(g)
        x0 = int(w * 0.42)
        gd.polygon([(x0, 0), (x0 + h * 0.35, 0), (x0 - h * 0.25, h), (x0 - h * 0.6, h)], fill=170)
        g = Image.composite(g, Image.new("L", (w, h), 0), mask)
        out = Image.alpha_composite(out, Image.merge("RGBA", (g.point(lambda v: 255), g.point(lambda v: 255), g.point(lambda v: 255), g)))
    return out

def shadowed(img, off, color=(40, 8, 60, 230)):
    w, h = img.size
    base = Image.new("RGBA", (w + off, h + off), (0, 0, 0, 0))
    sh = Image.new("RGBA", img.size, color)
    base.paste(sh, (off, off), img.split()[3])
    base.alpha_composite(img)
    return base

def neon_script(text, fnt, color):
    l, t, r, b = fnt.getbbox(text)
    w, h = r - l + 24, b - t + 24
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).text((12 - l, 12 - t), text, font=fnt, fill=color + (255,))
    halo = glow.filter(ImageFilter.GaussianBlur(5))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for _ in range(2):
        out.alpha_composite(halo)
    out.alpha_composite(glow)
    return out

LOGO_STOPS = [(0.0, (255, 140, 60)), (0.45, PINK), (1.0, (122, 44, 255))]

def scanlines(img, alpha=40, step=3):
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for y in range(0, img.size[1], step):
        d.line([(0, y), (img.size[0], y)], fill=(0, 0, 0, alpha))
    return Image.alpha_composite(img.convert("RGBA"), ov)

def save_bmp(img, name):
    img.convert("RGB").save(os.path.join(OUT, name), "BMP")

def splash(src):
    im = Image.open(src).convert("RGB").resize((640, 360), Image.LANCZOS)
    save_bmp(im, "splash.bmp")

def draw_palm(img, base, height, lean, color=(6, 3, 12, 255)):
    """Palm silhouette like the title backdrop's: a curved, tapering trunk
    and drooping fronds."""
    d = ImageDraw.Draw(img)
    bx, by = base
    pts = []
    for i in range(21):
        t = i / 20
        pts.append((bx + lean * t * t * height, by - t * height))
    for i in range(20):
        w = int(9 - 6 * i / 20) + 2
        d.line([pts[i], pts[i + 1]], fill=color, width=w)
    tx, ty = pts[-1]
    import math
    for k in range(8):
        ang = -math.pi / 2 + (k - 3.5) * 0.42 + lean * 0.3
        length = min(95, height * (0.36 + 0.06 * ((k * 3) % 4) / 3))
        prev = (tx, ty)
        for j in range(1, 13):
            u = j / 12
            droop = u * u * length * 0.55
            x = tx + math.cos(ang) * length * u
            y = ty + math.sin(ang) * length * u + droop
            d.line([prev, (x, y)], fill=color, width=max(2, int(7 * (1 - u)) + 2))
            prev = (x, y)
    d.ellipse([tx - 6, ty - 5, tx + 6, ty + 7], fill=color)

def sidebar(src, splash_src=None):
    S = 3
    W, H = 164 * S, 314 * S
    im = Image.open(src).convert("RGBA")
    # crop the sun + horizon out of the tall render, keep the sky for the logo
    sw, sh = im.size
    cw = int(sh * W / H)
    x0 = max(0, min(sw - cw, int(sw * 0.5 - cw * 0.5) - int(sw * 0.07)))   # sun centred, sign out of frame
    bg = im.crop((x0, 0, x0 + cw, sh)).resize((W, H), Image.LANCZOS)
    # fade the top into ink so the logo sits on a clean field
    fade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fade)
    for y in range(int(H * 0.42)):
        a = int(210 * (1 - y / (H * 0.42)) ** 1.4)
        fd.line([(0, y), (W, y)], fill=INK + (a,))
    bg.alpha_composite(fade)
    horizon = int(H * 0.62)
    draw_palm(bg, (40, horizon + 2), 250, 0.35)
    draw_palm(bg, (120, horizon + 2), 150, -0.25)
    draw_palm(bg, (W - 40, horizon + 2), 290, -0.3)
    logo = gradient_text("HOTSHOT", font("Poppins-BoldItalic.ttf", 84), LOGO_STOPS)
    logo = shadowed(logo, 6)
    lw = W - 24
    logo = logo.resize((lw, int(logo.size[1] * lw / logo.size[0])), Image.LANCZOS)
    bg.alpha_composite(logo, (10, 150))
    cal = neon_script("California", font("Lora-Italic-Variable.ttf", 66), PINK)
    bg.alpha_composite(cal.rotate(4, resample=Image.BICUBIC, expand=True), (W - cal.size[0] - 4, 150 + logo.size[1] - 18))
    d = ImageDraw.Draw(bg)
    osd = font("DejaVuSansMono-Bold.ttf", 30)
    d.text((24, 36), "PLAY ▶", font=osd, fill=PAPER + (235,))
    d.text((24, H - 120), "1988", font=font("DejaVuSansMono-Bold.ttf", 40), fill=GOLD + (255,))
    d.text((24, H - 72), "SUNSET PALMS", font=font("DejaVuSansMono.ttf", 26), fill=CYAN + (220,))
    bg = scanlines(bg, 38, 3)
    save_bmp(bg.resize((164, 314), Image.LANCZOS), "sidebar.bmp")

def header():
    S = 3
    W, H = 150 * S, 57 * S
    im = Image.new("RGBA", (W, H), INK + (255,))
    d = ImageDraw.Draw(im)
    # a retro striped sun setting in the bottom-left corner
    sun = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cx, cy, r = 52, H - 6, 92
    sd = ImageDraw.Draw(sun)
    for y in range(cy - r, cy):
        k = (y - (cy - r)) / r
        c = (255, int(150 - 100 * k), int(70 + 60 * k), 170)
        half = int((r * r - (cy - y) ** 2) ** 0.5)
        sd.line([(cx - half, y), (cx + half, y)], fill=c)
    for i in range(7):   # gaps widen toward the horizon
        y = cy - r + 40 + i * 12
        sd.rectangle([0, y, W, y + 1 + i // 2], fill=(0, 0, 0, 0))
    im.alpha_composite(sun)
    logo = shadowed(gradient_text("HOTSHOT", font("Poppins-BoldItalic.ttf", 64), LOGO_STOPS), 4)
    lw = int(W * 0.66)
    logo = logo.resize((lw, int(logo.size[1] * lw / logo.size[0])), Image.LANCZOS)
    im.alpha_composite(logo, (W - lw - 10, 16))
    cal = neon_script("California", font("Lora-Italic-Variable.ttf", 44), PINK)
    im.alpha_composite(cal, (W - cal.size[0] - 8, 16 + logo.size[1] - 26))
    d.line([(0, H - 3), (W, H - 3)], fill=PINK + (255,), width=3)
    im = scanlines(im, 30, 3)
    save_bmp(im.resize((150, 57), Image.LANCZOS), "header.bmp")

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    splash(sys.argv[1])
    sidebar(sys.argv[2], sys.argv[1])
    header()
    print("art written to", OUT)
