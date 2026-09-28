#!/usr/bin/env python3
"""HOTSHOT CALIFORNIA - announcement trailer (about 1:20, 1080p30, English).

Inputs (see the session notes / tools/autoplay.gd AUTOPLAY_TRAILER):
  <work>/m01.avi m02w.avi m03w.avi m04.avi  - gameplay recorded with Godot's
                                              movie maker (--write-movie)
  <work>/score.wav                           - tools/gen_trailer_music.py
Paintings come from assets/art/painted, the key art from assets/art/title.

  python tools/make_trailer.py <work-dir> <out.mp4>

The cut follows the score's bar grid (BAR = 2 s at 120 bpm). No story
spoilers: the paintings are the trailer set from the game's own cold open.
"""
import os, sys, subprocess, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H, FPS = 1920, 1080, 30
BAR = 2.0
BEAT = 0.5
WORK = sys.argv[1]
OUT = sys.argv[2]
FFMPEG = "ffmpeg"

def font(name, size):
    return ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", name), size)
F_DISPLAY = lambda s: font("Poppins-BoldItalic.ttf", s)
F_MONO = lambda s: font("DejaVuSansMono-Bold.ttf", s)
GOLD = (255, 210, 63)
PINK = (255, 61, 127)
CYAN = (53, 224, 255)
PAPER = (244, 240, 232)

rng = np.random.default_rng(88)
NOISE = [Image.fromarray((rng.random((H // 2, W // 2)) * 255).astype(np.uint8), "L").resize((W, H)) for _ in range(6)]
SCAN = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(SCAN)
for y in range(0, H, 3):
    d.line([(0, y), (W, y)], fill=40)

# ------------------------------------------------------------------ sources
def painted(pid):
    p = os.path.join(ROOT, "assets", "art", "painted", pid + ".webp")
    return Image.open(p).convert("RGB")

_cache = {}
def still(pid):
    if pid not in _cache:
        _cache[pid] = painted(pid) if pid != "__title" else Image.open(os.path.join(ROOT, "assets", "art", "title", "hotshot_title.webp")).convert("RGB")
    return _cache[pid]

def kenburns(img, k, z0=1.04, z1=1.14, pan=(0.0, 0.0)):
    """a slow push-in, k 0..1"""
    z = z0 + (z1 - z0) * k
    iw, ih = img.size
    cw, ch = iw / z, ih / z
    cx = iw / 2 + pan[0] * iw * 0.03 * (k - 0.5)
    cy = ih / 2 + pan[1] * ih * 0.03 * (k - 0.5)
    box = (cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2)
    return img.resize((W, H), Image.BICUBIC, box=box)

class Clip:
    """frames from a recorded .avi, read through ffmpeg"""
    def __init__(self, src, start, dur):
        self.n = int(round(dur * FPS))
        self.p = subprocess.Popen([FFMPEG, "-loglevel", "error", "-ss", f"{start:.3f}", "-i", src, "-t", f"{dur:.3f}",
                                   "-vf", f"scale={W}:{H}", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
        self.last = None
    def frame(self):
        b = self.p.stdout.read(W * H * 3)
        if len(b) == W * H * 3:
            self.last = Image.frombuffer("RGB", (W, H), b)
        return self.last if self.last is not None else Image.new("RGB", (W, H))
    def close(self):
        self.p.stdout.close(); self.p.wait()

def action_moments(src, count, min_gap=4.0, skip=4.0):
    """seconds in the recording with the most going on: motion + muzzle
    flashes/explosions (bright bursts) + blood (red)."""
    p = subprocess.run([FFMPEG, "-loglevel", "error", "-i", src, "-vf", "fps=10,scale=160:90", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
    a = np.frombuffer(p.stdout, np.uint8).reshape(-1, 90, 160, 3).astype(np.float32)
    motion = np.abs(np.diff(a.mean(axis=3), axis=0)).mean(axis=(1, 2))
    bright = (a[1:].max(axis=3) > 235).mean(axis=(1, 2)) * 60
    red = ((a[1:, :, :, 0] > 150) & (a[1:, :, :, 1] < 60)).mean(axis=(1, 2)) * 80
    score = motion + bright + red
    sec = np.convolve(score, np.ones(15) / 15, mode="same")          # 1.5 s windows
    picks = []
    order = np.argsort(-sec)
    for i in order:
        t = i / 10.0
        if t < skip or t > len(sec) / 10.0 - 3.0:
            continue
        if all(abs(t - q) > min_gap for q in picks):
            picks.append(t)
        if len(picks) >= count:
            break
    return sorted(picks)

# ------------------------------------------------------------------ drawing
def vhs(img, glitch=0.0, t=0.0, grain=0.06):
    """grain, scanlines, a little colour split; more of everything when `glitch`"""
    img = img.copy()
    n = NOISE[int(t * 24) % len(NOISE)]
    img = Image.composite(Image.new("RGB", (W, H), (255, 255, 255)), img, n.point(lambda v: int(v * grain)))
    img = Image.composite(Image.new("RGB", (W, H), (0, 0, 0)), img, SCAN)
    if glitch > 0.01:
        r, g, b = img.split()
        off = int(6 + 18 * glitch)
        r = r.transform((W, H), Image.AFFINE, (1, 0, -off, 0, 1, 0))
        b = b.transform((W, H), Image.AFFINE, (1, 0, off, 0, 1, 0))
        img = Image.merge("RGB", (r, g, b))
        dr = ImageDraw.Draw(img)
        for i in range(int(8 * glitch)):
            y = int(rng.random() * H)
            dr.rectangle([0, y, W, y + int(rng.random() * 14) + 2], fill=(235, 235, 240))
    return img

def text_center(img, s, y, size, col=GOLD, alpha=1.0, fnt=None, shadow=True, spacing=0):
    if alpha <= 0.01:
        return img
    fnt = fnt or F_DISPLAY(size)
    over = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(over)
    w = dr.textlength(s, font=fnt) + spacing * max(0, len(s) - 1)
    x = (W - w) / 2
    def draw(xx, yy, c):
        if spacing:
            cx = xx
            for ch in s:
                dr.text((cx, yy), ch, font=fnt, fill=c)
                cx += dr.textlength(ch, font=fnt) + spacing
        else:
            dr.text((xx, yy), s, font=fnt, fill=c)
    a = int(255 * alpha)
    if shadow:
        draw(x + 5, y + 5, (0, 0, 0, int(a * 0.75)))
        draw(x - 3, y, (53, 224, 255, int(a * 0.35)))
    draw(x, y, col + (a,))
    return Image.alpha_composite(img.convert("RGBA"), over).convert("RGB")

def darken(img, k):
    return Image.blend(img, Image.new("RGB", (W, H)), k)

def env(t, a, b, fade=0.3):
    """0..1 visibility of something shown from a to b"""
    if t < a or t > b:
        return 0.0
    return min(1.0, (t - a) / fade, (b - t) / fade)

# ------------------------------------------------------------------ motion
_glows = {}
def glow_of(pid):
    """The painting's emissive mask (neon, lamps, screens, fire), full size."""
    if pid not in _glows:
        pth = os.path.join(ROOT, "assets", "art", "painted", pid + "_glow.png")
        g = None
        if os.path.exists(pth):
            src = still(pid)
            g = Image.open(pth).convert("L").resize(src.size, Image.BILINEAR).filter(ImageFilter.GaussianBlur(3))
        _glows[pid] = g
    return _glows[pid]

def kenburns_l(img, k, z0, z1, pan):
    z = z0 + (z1 - z0) * k
    iw, ih = img.size
    cw, ch = iw / z, ih / z
    cx = iw / 2 + pan[0] * iw * 0.03 * (k - 0.5)
    cy = ih / 2 + pan[1] * ih * 0.03 * (k - 0.5)
    return img.resize((W, H), Image.BILINEAR, box=(cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2))

PRNG = np.random.default_rng(7)
PARTS = [(PRNG.random(), PRNG.random(), PRNG.uniform(0.3, 1.0), PRNG.uniform(1.5, 4.0), PRNG.random()) for _ in range(90)]
def particles(img, t, warm=True, amount=1.0):
    """Embers / dust drifting up through the light, flickering."""
    over = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for (x0, y0, sp, r, ph) in PARTS[: int(len(PARTS) * amount)]:
        x = (x0 * W + np.sin(t * 0.7 + ph * 9) * 40) % W
        y = (y0 * H - t * sp * 90) % H
        a = int(160 * (0.5 + 0.5 * np.sin(t * 6 + ph * 20)))
        col = (255, 150 + int(80 * ph), 60, a) if warm else (200, 220, 255, a // 2)
        d.ellipse([x - r * 2.2, y - r * 2.2, x + r * 2.2, y + r * 2.2], fill=col[:3] + (a // 5,))
        d.ellipse([x - r * 0.7, y - r * 0.7, x + r * 0.7, y + r * 0.7], fill=col)
    return Image.alpha_composite(img.convert("RGBA"), over).convert("RGB")

LEAK = None
def light_leak(img, t, k):
    """A soft magenta / cyan film leak drifting across the frame."""
    global LEAK
    if LEAK is None:
        yy, xx = np.mgrid[0:H // 4, 0:W // 4]
        a = np.exp(-(((xx - W / 8) / (W / 9)) ** 2 + ((yy - H / 8) / (H / 6)) ** 2))
        LEAK = a
    shift = int((t * 90) % (W // 4)) - W // 8
    a = np.roll(LEAK, shift, axis=1)
    rgb = np.zeros((H // 4, W // 4, 3), np.float32)
    rgb[..., 0] = a * 255 * 0.9
    rgb[..., 1] = a * 60
    rgb[..., 2] = a * 180 * (0.6 + 0.4 * np.sin(t * 0.8))
    leak = Image.fromarray(np.clip(rgb * 0.35 * k, 0, 255).astype(np.uint8)).resize((W, H), Image.BILINEAR)
    return ImageChops.add(img, leak)

def typed(img, s, y, size, col, t0, t, cps=30.0):
    """A caption typing itself on, a little glitch on the newest letters."""
    n = int(max(0.0, t - t0) * cps)
    if n <= 0:
        return img
    shown = s[:n]
    img = text_center(img, shown + (" " * (len(s) - len(shown))), y, size, col, 1.0)
    if n < len(s):
        # the cursor block
        dr = ImageDraw.Draw(img)
        fnt = F_DISPLAY(size)
        w_full = dr.textlength(s, font=fnt)
        w_now = dr.textlength(shown, font=fnt)
        x = (W - w_full) / 2 + w_now + 6
        dr.rectangle([x, y + 8, x + size * 0.45, y + size * 1.05], fill=col)
    return img

def badge(kind, h=86):
    """A store badge in the store's own look (colours, type, shape)."""
    fb = font("Poppins-BoldItalic.ttf", int(h * 0.42))
    fm = font("DejaVuSansMono-Bold.ttf", int(h * 0.22))
    if kind == "STEAM":
        w = int(h * 3.1)
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        g = Image.new("RGBA", (w, h))
        for x in range(w):
            k = x / w
            ImageDraw.Draw(g).line([(x, 0), (x, h)], fill=(int(23 + 20 * k), int(26 + 40 * k), int(33 + 60 * k), 255))
        m = Image.new("L", (w, h), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius=h // 5, fill=255)
        im.paste(g, (0, 0), m)
        d = ImageDraw.Draw(im)
        d.rounded_rectangle([2, 2, w - 3, h - 3], radius=h // 5, outline=(102, 192, 244, 255), width=3)
        d.ellipse([h * 0.22, h * 0.22, h * 0.78, h * 0.78], outline=(199, 213, 224, 255), width=int(h * 0.07))
        d.ellipse([h * 0.40, h * 0.40, h * 0.60, h * 0.60], fill=(199, 213, 224, 255))
        d.text((h * 0.95, h * 0.18), "STEAM", font=fb, fill=(235, 240, 245, 255))
        d.text((h * 0.97, h * 0.66), "AVAILABLE ON", font=fm, fill=(102, 192, 244, 255))
    elif kind == "GOG":
        w = int(h * 2.5)
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.rounded_rectangle([0, 0, w - 1, h - 1], radius=h // 2, fill=(110, 37, 132, 255))
        d.rounded_rectangle([5, 5, w - 6, h - 6], radius=h // 2, outline=(206, 150, 222, 255), width=3)
        fb2 = font("Poppins-BoldItalic.ttf", int(h * 0.5))
        tw = d.textlength("GOG.COM", font=fb2)
        d.text(((w - tw) / 2, h * 0.14), "GOG.COM", font=fb2, fill=(255, 255, 255, 255))
    elif kind == "EPIC":
        w = int(h * 2.9)
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, w - 1, h - 1], fill=(18, 18, 18, 255))
        d.rectangle([4, 4, w - 5, h - 5], outline=(255, 255, 255, 255), width=4)
        f1 = font("Poppins-BoldItalic.ttf", int(h * 0.36))
        d.text((h * 0.25, h * 0.08), "EPIC GAMES", font=f1, fill=(255, 255, 255, 255))
        d.text((h * 0.27, h * 0.56), "STORE", font=fm, fill=(200, 200, 200, 255))
    else:  # PC
        w = int(h * 1.9)
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.rounded_rectangle([0, 0, w - 1, h - 1], radius=h // 6, fill=(20, 12, 34, 255))
        d.rounded_rectangle([3, 3, w - 4, h - 4], radius=h // 6, outline=(53, 224, 255, 255), width=3)
        tw = d.textlength("PC", font=fb)
        d.text(((w - tw) / 2, h * 0.2), "PC", font=fb, fill=(53, 224, 255, 255))
    return im

BADGES = [badge(k) for k in ("PC", "STEAM", "GOG", "EPIC")]

# ------------------------------------------------------------------ the cut
SRC = {k: os.path.join(WORK, k + ".avi") for k in ("m01", "m02w", "m03w", "m04")}
print("finding the action...")
moments = {k: action_moments(v, 8) for k, v in SRC.items() if os.path.exists(v)}
for k, v in moments.items():
    print(" ", k, [round(x, 1) for x in v])

# the timeline: [start, end, kind, payload]
TL = []
def story(a, b, pid, cap=None, pan=(0.0, 0.0)):
    TL.append([a, b, "still", {"id": pid, "cap": cap, "pan": pan}])
def play(a, b, src, cap=None, idx=0, off=0.0):
    TL.append([a, b, "clip", {"src": src, "cap": cap, "idx": idx, "off": off}])

# 0-9.5: studio, creator
TL.append([0.0, 9.5, "splash", {}])
# 9.5-32: the story, no spoilers
story(9.5, 12.8, "t_drive", "CALIFORNIA, 1988.", (1, 0))
story(12.8, 16.0, "t_tape", "SOMEBODY SENT HER A TAPE.", (-1, 0))
story(16.0, 20.0, "t_star", "SHE KNOWS WHAT IT MEANS.")
story(20.0, 22.0, "t_arsenal", "EVERY NAME ON THE CALL SHEET", (1, 0))
story(22.0, 24.0, "menu_revolver", "IS GOING TO ANSWER FOR IT.")
story(24.0, 26.0, "t_corridor")
story(26.0, 28.0, "t_dogs")
story(28.0, 30.0, "t_studio")
story(30.0, 31.5, "t_monitors", "AND SOMEBODY IS FILMING EVERYTHING.")
TL.append([31.5, 32.0, "black", {}])
# 32-64: the drop - gameplay cut to the bar, then the beat
order = [("m01", 0), ("m03w", 0), ("m02w", 0), ("m01", 1), ("m04", 0), ("m03w", 1), ("m02w", 1), ("m04", 1),
         ("m01", 2), ("m03w", 2), ("m02w", 2), ("m04", 2), ("m03w", 3), ("m01", 3), ("m02w", 3), ("m04", 3),
         ("m03w", 4), ("m01", 4), ("m02w", 4), ("m04", 4), ("m03w", 5), ("m01", 5), ("m02w", 5), ("m04", 5)]
caps = {32.0: "BRUTAL.", 36.0: "FAST.", 40.0: "UNFORGIVING.", 44.0: "PICK A FACE. PAY THE PRICE.",
        48.0: "BOSSES THAT FIGHT DIRTY.", 52.0: "A NIGHTMARE OR TWO.", 56.0: "ONE HIT. ONE LIFE. ONE MORE TRY."}
t = 32.0
oi = 0
while t < 64.0 - 1e-6:
    step = BAR if t < 56.0 else (BAR / 2 if t < 60.0 else BEAT)
    k, idx = order[oi % len(order)]
    oi += 1
    if k not in moments or not moments[k]:
        k = next(iter(moments))
    cap = None
    for ct, cs in caps.items():
        if abs(ct - t) < 1e-6:
            cap = cs
    if abs(t - 44.0) < 1e-6:
        TL.append([t, t + BAR, "masks", {"cap": cap}])
    elif abs(t - 48.0) < 1e-6:
        TL.append([t, t + BEAT * 2, "still", {"id": "k_buck", "cap": None, "pan": (0, 0), "flash": True}])
        play(t + BEAT * 2, t + BAR * 2, k, cap, idx)
        t += BAR * 2
        continue
    else:
        play(t, t + step, k, cap, idx)
    t += step
# 64-72: the title; 72-80: the release card
TL.append([64.0, 72.0, "title", {}])
TL.append([72.0, 80.0, "release", {}])

# ------------------------------------------------------------------ render
MASKS = [Image.open(os.path.join(ROOT, "assets", "art", "masks", m + ".png")).convert("RGBA") for m in
         ["star", "soldier", "dog", "cowboy", "angel", "saint", "ghost", "fool", "king", "devil"] if os.path.exists(os.path.join(ROOT, "assets", "art", "masks", m + ".png"))]

enc = subprocess.Popen([FFMPEG, "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                        "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", os.path.join(WORK, "video.mp4")], stdin=subprocess.PIPE)
game_audio = np.zeros((int(80 * 44100), 2), np.float32)
clips = {}
total = int(80 * FPS)
for fi in range(total):
    tt = fi / FPS
    seg = next((s for s in TL if s[0] <= tt < s[1]), TL[-1])
    a, b, kind, p = seg
    k = (tt - a) / max(b - a, 1e-3)
    since_cut = tt - a
    glitch = max(0.0, 1.0 - since_cut / 0.12) if a > 0 else 0.0
    if kind == "splash":
        # the game's own studio sting and credit, recorded from its splash
        img = Image.new("RGB", (W, H), (0, 0, 0))
        st = tt - 0.5
        if 0.0 <= st:
            key = "splash"
            if key not in clips:
                clips[key] = Clip(os.path.join(WORK, "splash.avi"), 0.0, 7.6)
            img = clips[key].frame().copy()
            # the credit gets a pulse of glitch on the beats and a light sweep
            if st > 3.6:
                beat = (tt % 0.5) / 0.5
                img = vhs(img, max(0.0, 0.6 - beat * 2.0) if st < 7.0 else 0.0, tt, 0.03)
                sweep = Image.new("L", (W, H), 0)
                x = int((st - 3.6) / 3.4 * (W + 600)) - 300
                ImageDraw.Draw(sweep).polygon([(x, 0), (x + 160, 0), (x - 140, H), (x - 300, H)], fill=70)
                img = Image.composite(Image.new("RGB", (W, H), (255, 220, 240)), img, sweep.filter(ImageFilter.GaussianBlur(30)))
                img = particles(img, tt, warm=True, amount=0.4)
            else:
                img = vhs(img, 0.0, tt, 0.03)
    elif kind == "card":
        img = Image.new("RGB", (W, H), (6, 2, 12))
        al = env(tt, a, b, 0.5)
        y0 = H / 2 - 20 * len(p["lines"]) - 30
        for s, size, col in p["lines"]:
            img = text_center(img, s, y0, size, col, al, spacing=6 if size < 40 else 0)
            y0 += size + 24
        img = vhs(img, 0.0, tt, 0.05)
    elif kind == "black":
        img = Image.new("RGB", (W, H), (0, 0, 0))
    elif kind == "still":
        pan = p.get("pan", (0, 0))
        # a faster, livelier push-in, and a jolt on the cut
        img = kenburns(still(p["id"]), k, 1.03, 1.16, pan=pan)
        if since_cut < 0.2:
            j = (1.0 - since_cut / 0.2) * 14
            img = img.transform((W, H), Image.AFFINE, (1, 0, np.sin(tt * 90) * j, 0, 1, np.cos(tt * 70) * j * 0.5))
        # the painting's own lights breathing: neon, lamps, screens, fire
        g = glow_of(p["id"])
        if g is not None:
            gm = kenburns_l(g, k, 1.03, 1.16, pan)
            pulse = 0.55 + 0.35 * np.sin(tt * 5.0) * np.sin(tt * 1.7 + 1.0)
            glow = Image.merge("RGB", [gm.point(lambda v: int(v * 0.9 * pulse)), gm.point(lambda v: int(v * 0.35 * pulse)), gm.point(lambda v: int(v * 0.7 * pulse))])
            img = ImageChops.add(img, glow.filter(ImageFilter.GaussianBlur(8)))
        img = darken(img, 0.1)
        img = light_leak(img, tt, 0.8)
        img = particles(img, tt, warm=p["id"] not in ("t_drive", "t_tape"), amount=0.7)
        # a white flash through the cut
        if since_cut < 0.09 and a > 9.6:
            img = Image.blend(img, Image.new("RGB", (W, H), (255, 245, 250)), 0.7 * (1.0 - since_cut / 0.09))
        if p.get("flash") and since_cut < 0.15:
            img = Image.blend(img, Image.new("RGB", (W, H), (255, 240, 220)), 1.0 - since_cut / 0.15)
        if p.get("cap"):
            img = typed(img, p["cap"], H - 190, 58, GOLD, a + 0.15, tt)
            if tt > b - 0.25:
                img = darken(img, (tt - (b - 0.25)) / 0.25 * 0.4)
        img = vhs(img, glitch, tt)
    elif kind == "clip":
        key = id(seg)
        if key not in clips:
            for c in list(clips.values()):
                c.close()
            clips.clear()
            src = SRC[p["src"]]
            ms = moments.get(p["src"], [10.0])
            start = ms[p["idx"] % len(ms)] - 0.7 + p.get("off", 0.0)
            clips[key] = Clip(src, max(0.0, start), b - a + 0.1)
            # the game's own sound for this cut, under the score
            ap = subprocess.run([FFMPEG, "-loglevel", "error", "-ss", f"{max(0.0, start):.3f}", "-i", src, "-t", f"{b - a:.3f}",
                                 "-f", "f32le", "-ac", "2", "-ar", "44100", "-"], stdout=subprocess.PIPE)
            aud = np.frombuffer(ap.stdout, np.float32).reshape(-1, 2).copy()
            # fade each cut's sound in and out (a hard cut is a click)
            fl = min(len(aud) // 2, 441)
            if fl > 1:
                r = np.linspace(0, 1, fl)[:, None]
                aud[:fl] *= r
                aud[-fl:] *= r[::-1]
            s0 = int(a * 44100)
            e0 = min(len(game_audio), s0 + len(aud))
            game_audio[s0:e0] += aud[: e0 - s0]
        img = clips[key].frame()
        # a punch-in on every cut
        z = 1.12 + 0.06 * max(0.0, 1.0 - since_cut / 0.25)   # a little closer than the game camera, and a punch on the cut
        if z > 1.001:
            cw, ch = W / z, H / z
            img = img.resize((W, H), Image.BICUBIC, box=((W - cw) / 2, (H - ch) / 2, (W + cw) / 2, (H + ch) / 2))
        if p.get("cap"):
            img = text_center(img, p["cap"], H - 170, 66, GOLD, env(tt, a + 0.1, a + BAR * 1.9, 0.2))
        img = vhs(img, glitch * 0.7, tt, 0.04)
    elif kind == "masks":
        img = Image.new("RGB", (W, H), (8, 3, 14))
        n = len(MASKS)
        size = 190
        x0 = (W - n * (size - 20)) / 2
        for i, m in enumerate(MASKS):
            show = min(1.0, max(0.0, (k * 2.2 - i * 0.08)))
            if show <= 0:
                continue
            mm = m.resize((size, size), Image.LANCZOS)
            yy = int(H / 2 - size / 2 - 40 + (1 - show) * 60)
            img.paste(mm, (int(x0 + i * (size - 20)), yy), mm)
        img = text_center(img, p["cap"], H - 250, 64, GOLD, env(tt, a + 0.2, b, 0.2))
        img = vhs(img, glitch, tt)
    elif kind == "title":
        base = still("__title")
        z = 1.12 - 0.08 * min(1.0, k * 3.0)
        img = kenburns(base, 0.0, z, z)
        if since_cut < 0.35:
            img = Image.blend(img, Image.new("RGB", (W, H), (255, 245, 230)), 1.0 - since_cut / 0.35)
        img = vhs(img, max(0.0, 0.8 - since_cut * 3), tt, 0.05)
    elif kind == "release":
        base = darken(kenburns(still("t_walk"), k, 1.02, 1.08), 0.55)
        al = env(tt, a + 0.2, b + 1.0, 0.6)
        base = light_leak(particles(base, tt, True, 0.6), tt, 0.6)
        img = text_center(base, "HOTSHOT CALIFORNIA", 250, 96, PINK, al)
        img = text_center(img, "RELEASE DATE TO BE ANNOUNCED", 400, 60, GOLD, env(tt, a + 0.2, b + 1.0, 0.3))
        # the stores pop in fast, one after another, each in its own style
        img = img.convert("RGBA")
        gap = 36
        tw = sum(bd.width for bd in BADGES) + gap * (len(BADGES) - 1)
        x = (W - tw) // 2
        for i2, bd in enumerate(BADGES):
            t0 = a + 0.45 + i2 * 0.12
            q = (tt - t0) / 0.22
            if q > 0:
                sc = 1.0 + 0.25 * np.sin(min(q, 1.0) * np.pi) if q < 1.0 else 1.0
                bw, bh = int(bd.width * sc), int(bd.height * sc)
                b2 = bd.resize((bw, bh), Image.LANCZOS)
                if q < 1.0:
                    b2.putalpha(b2.getchannel("A").point(lambda v, qq=q: int(v * min(1.0, qq * 1.6))))
                glow = Image.new("RGBA", (bw + 40, bh + 40), (0, 0, 0, 0))
                ImageDraw.Draw(glow).rounded_rectangle([10, 10, bw + 30, bh + 30], radius=20, fill=(255, 61, 127, 60 if q < 1.5 else 30))
                img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(10)), (x + bd.width // 2 - bw // 2 - 20, 560 - bh // 2 - 20))
                img.alpha_composite(b2, (x + bd.width // 2 - bw // 2, 560 - bh // 2))
            x += bd.width + gap
        img = img.convert("RGB")
        img = text_center(img, "INVERTED INDEX STUDIO   ·   A GAME BY GILBERTO LOPES", 800, 30, CYAN, env(tt, a + 2.0, b + 1.0, 0.6), fnt=F_MONO(30))
        if tt > b - 1.2:
            img = darken(img, (tt - (b - 1.2)) / 1.2)
        img = vhs(img, 0.0, tt, 0.05)
    # the tape counter, top-left (the splash has its own)
    if kind == "splash":
        enc.stdin.write(img.tobytes())
        continue
    dr = ImageDraw.Draw(img)
    dr.text((42, 34), "PLAY ▶   SP   0:%02d:%02d" % (int(tt) // 60, int(tt) % 60), font=F_MONO(30), fill=(235, 235, 240))
    enc.stdin.write(img.tobytes())
    if fi % 150 == 0:
        print(f"  {tt:5.1f}s  {kind}")
for c in clips.values():
    c.close()
enc.stdin.close(); enc.wait()

# ------------------------------------------------------------------ sound
with wave.open(os.path.join(WORK, "score.wav"), "rb") as w:
    sr = w.getframerate()
    score = np.frombuffer(w.readframes(w.getnframes()), np.int16).reshape(-1, 2).astype(np.float32) / 32767.0
n = min(len(score), len(game_audio))
ga = game_audio[:n]
peak = np.max(np.abs(ga)) + 1e-9
# a whoosh into every gameplay cut, so the edit has its own sound
rng2 = np.random.default_rng(3)
wh = np.zeros_like(game_audio)
for seg in TL:
    if seg[2] == "clip" or seg[2] == "masks":
        s0 = int(seg[0] * 44100)
        L = int(0.18 * 44100)
        nz = rng2.uniform(-1, 1, L)
        nz = np.convolve(nz, np.ones(12) / 12, "same")
        e = np.linspace(0, 1, L) ** 2
        e[-400:] *= np.linspace(1, 0, 400)
        s1 = max(0, s0 - L)
        wh[s1:s0, 0] += (nz * e)[: s0 - s1] * 0.35
        wh[s1:s0, 1] += (nz[::-1] * e)[: s0 - s1] * 0.35
n = min(len(score), len(game_audio))
ga = game_audio[:n]
peak = np.max(np.abs(ga)) + 1e-9
mix = score[:n] * 0.85 + ga / peak * 0.42 + wh[:n]   # gunfire, glass, bodies under the score
mix = mix / (np.max(np.abs(mix)) + 1e-9) * 0.89
with wave.open(os.path.join(WORK, "mix.wav"), "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr)
    w.writeframes((mix * 32767).astype(np.int16).tobytes())
subprocess.run([FFMPEG, "-loglevel", "error", "-y", "-i", os.path.join(WORK, "video.mp4"), "-i", os.path.join(WORK, "mix.wav"),
                "-c:v", "copy", "-c:a", "aac", "-b:a", "256k", "-shortest", "-movflags", "+faststart", OUT], check=True)
print("trailer", OUT)
