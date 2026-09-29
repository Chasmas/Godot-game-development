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
    cx = min(max(cx, cw / 2), iw - cw / 2)
    cy = min(max(cy, ch / 2), ih - ch / 2)
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

# ------------------------------------------------------------------ language
# TRAILER_LANG=pt makes the Portuguese cut (captions, the release card, the
# game's own splash and menus recorded in Portuguese)
LANG = os.environ.get("TRAILER_LANG", "en")
PT = {"SPOTLIGHT.": "SPOTLIGHT.",
 "CALIFORNIA, 1988.": "CALIFÓRNIA, 1988.",
 "SOMEBODY SENT HER A TAPE.": "ALGUÉM LHE ENVIOU UMA CASSETE.",
 "SHE KNOWS WHAT IT MEANS.": "ELA SABE O QUE SIGNIFICA.",
 "EVERY NAME ON THE CALL SHEET": "CADA NOME DA FOLHA DE SERVIÇO",
 "IS GOING TO ANSWER FOR IT.": "VAI PAGAR POR ISSO.",
 "AND SOMEBODY IS FILMING EVERYTHING.": "E ALGUÉM ESTÁ A FILMAR TUDO.",
 "BRUTAL.": "BRUTAL.",
 "FAST.": "RÁPIDO.",
 "UNFORGIVING.": "IMPLACÁVEL.",
 "PICK A FACE. PAY THE PRICE.": "ESCOLHE UMA CARA. PAGA O PREÇO.",
 "EVERY TAPE TELLS ON SOMEBODY.": "CADA CASSETE DENUNCIA ALGUÉM.",
 "BOSSES THAT FIGHT DIRTY.": "CHEFES QUE LUTAM SUJO.",
 "ARCADE. SEVEN WAYS TO PLAY.": "ARCADA. SETE MANEIRAS DE JOGAR.",
 "A NIGHTMARE OR TWO.": "UM PESADELO OU DOIS.",
 "ONE HIT. ONE LIFE. ONE MORE TRY.": "UM GOLPE. UMA VIDA. MAIS UMA TENTATIVA.",
 "RELEASE DATE TO BE ANNOUNCED": "DATA DE LANÇAMENTO A ANUNCIAR",
 "INVERTED INDEX STUDIO   ·   A GAME BY GILBERTO LOPES": "INVERTED INDEX STUDIO   ·   UM JOGO DE GILBERTO LOPES",
 "AVAILABLE ON": "DISPONÍVEL NA"
}
def L(s):
    return PT.get(s, s) if LANG == "pt" and s else s
GAME_LANG = "pt_PT" if LANG == "pt" else "en"

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
    cx = min(max(cx, cw / 2), iw - cw / 2)
    cy = min(max(cy, ch / 2), ih - ch / 2)
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

def caption(img, s, since, dur):
    """a clean lower-third line: fades up with a small rise, holds, fades"""
    al = min(1.0, max(0.0, (since - 0.12) / 0.25), max(0.0, (dur - since) / 0.25))
    if al <= 0.01:
        return img
    rise = int((1.0 - min(1.0, max(0.0, (since - 0.12) / 0.35))) * 14)
    # a soft dark band behind it, so it reads over anything
    band = Image.new("L", (W, H), 0)
    ImageDraw.Draw(band).rectangle([0, H - 250, W, H - 90], fill=int(120 * al))
    img = Image.composite(Image.new("RGB", (W, H), (4, 2, 8)), img, band.filter(ImageFilter.GaussianBlur(40)))
    return text_center(img, s, H - 200 + rise, 60, GOLD, al)

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
        d.text((h * 0.97, h * 0.66), L("AVAILABLE ON"), font=fm, fill=(102, 192, 244, 255))
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

BADGES = [badge(k) for k in ("STEAM", "GOG", "EPIC")]

# ------------------------------------------------------------------ the cut
SRC = {k: os.path.join(WORK, k + ".avi") for k in ("m01", "m02w", "m03w", "m04")}
print("finding the action...")
moments = {k: action_moments(v, 8) for k, v in SRC.items() if os.path.exists(v)}
for k, v in moments.items():
    print(" ", k, [round(x, 1) for x in v])

# the timeline: [start, end, kind, payload]
TL = []
def story(a, b, pid, cap=None, pan=(0.0, 0.0)):
    TL.append([a, b, "still", {"id": pid, "cap": L(cap), "pan": pan}])
def play(a, b, src, cap=None, idx=0, off=0.0):
    TL.append([a, b, "clip", {"src": src, "cap": L(cap), "idx": idx, "off": off}])
def play_file(a, b, name, at, cap=None, zoom=1.0):
    """A fixed stretch of one recording (menus, the boss)."""
    TL.append([a, b, "clip", {"file": os.path.join(WORK, name + ".avi"), "at": at, "cap": L(cap), "zoom": zoom}])

# The shape (bars of 2 s, tools/gen_trailer_music.py):
#   0-9.5   the studio and the creator (the game's own splash)
#   9.5-22  the story on the paintings, slow, one line each
#   22-31   the build: paintings and the first glimpses of play, faster
#   31-32   silence
#   32-56   the drop: play, one cut a bar, a line every few bars
#   56-64   frenzy: a cut a beat, then two
#   64-68   the title
#   68-72   the Fireman walks on: the stinger
#   72-82   release card
TL.append([0.0, 9.5, "splash", {}])
story(9.5, 12.5, "t_drive", "CALIFORNIA, 1988.", (1, 0))
story(12.5, 15.5, "t_tape", "SOMEBODY SENT HER A TAPE.", (-1, 0))
story(15.5, 18.5, "t_star", "SHE KNOWS WHAT IT MEANS.")
story(18.5, 20.5, "t_arsenal", "EVERY NAME ON THE CALL SHEET", (1, 0))
story(20.5, 22.0, "menu_revolver", "IS GOING TO ANSWER FOR IT.")
story(22.0, 24.0, "t_corridor")
play(24.0, 26.0, "m01", None, 0)
story(26.0, 28.0, "t_dogs")
play(28.0, 30.0, "m02w", None, 0)
story(30.0, 31.0, "t_monitors", "AND SOMEBODY IS FILMING EVERYTHING.")
TL.append([31.0, 32.0, "black", {}])
play(32.0, 34.0, "m01", "BRUTAL.", 1)
play(34.0, 36.0, "m03w", None, 0)
play(36.0, 38.0, "m02w", None, 1)
play(38.0, 40.0, "m02w", "FAST.", 5)
play_file(40.0, 42.0, "breach", 3.2, None, 1.08)
play_file(42.0, 44.0, "breach", 4.9, "UNFORGIVING.", 1.08)
play_file(44.0, 46.0, "menu_masks_" + GAME_LANG, 3.4, "PICK A FACE. PAY THE PRICE.", 1.0)
play_file(46.0, 48.0, "menu_vcr_" + GAME_LANG, 7.0, "EVERY TAPE TELLS ON SOMEBODY.", 1.0)
play(48.0, 50.0, "m04", "A NIGHTMARE OR TWO.", 0)
play_file(50.0, 52.0, "spot", 26.9, "SPOTLIGHT.", 1.15)
play_file(52.0, 54.0, "menu_arcade_" + GAME_LANG, 3.6, "ARCADE. SEVEN WAYS TO PLAY.", 1.0)
play(54.0, 56.0, "m03w", None, 1)
order = [("m01", 2), ("m02w", 2), ("m03w", 2), ("m04", 1), ("m01", 3), ("m02w", 3), ("m03w", 3), ("m04", 2),
         ("m01", 4), ("m02w", 4), ("m03w", 4), ("m04", 3)]
t = 56.0
oi = 0
while t < 64.0 - 1e-6:
    step = 1.0 if t < 60.0 else 0.5
    k, idx = order[oi % len(order)]
    oi += 1
    if k not in moments or not moments[k]:
        k = next(iter(moments))
    play(t, t + step, k, "ONE HIT. ONE LIFE. ONE MORE TRY." if abs(t - 56.0) < 1e-6 else None, idx)
    t += step
TL.append([64.0, 68.0, "title", {}])
play_file(68.0, 70.0, "boss", 2.3, None, 1.0)
play_file(70.0, 72.0, "boss", 12.4, "BOSSES THAT FIGHT DIRTY.", 1.0)
TL.append([72.0, 82.0, "release", {}])

# ------------------------------------------------------------------ render
MASKS = [Image.open(os.path.join(ROOT, "assets", "art", "masks", m + ".png")).convert("RGBA") for m in
         ["star", "soldier", "dog", "cowboy", "angel", "saint", "ghost", "fool", "king", "devil"] if os.path.exists(os.path.join(ROOT, "assets", "art", "masks", m + ".png"))]

enc = subprocess.Popen([FFMPEG, "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                        "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", os.path.join(WORK, "video.mp4")], stdin=subprocess.PIPE)
game_audio = np.zeros((int(82 * 44100), 2), np.float32)
clips = {}
total = int(82 * FPS)
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
                clips[key] = Clip(os.path.join(WORK, "splash_%s.avi" % GAME_LANG), 0.0, 7.6)
            img = clips[key].frame().copy()
            img = vhs(img, 0.0, tt, 0.025)
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
        img = kenburns(still(p["id"]), k, 1.02, 1.1, pan=pan)
        g = glow_of(p["id"])
        if g is not None:
            gm = kenburns_l(g, k, 1.02, 1.1, pan)
            pulse = 0.45 + 0.2 * np.sin(tt * 2.2)
            glow = Image.merge("RGB", [gm.point(lambda v: int(v * 0.8 * pulse)), gm.point(lambda v: int(v * 0.3 * pulse)), gm.point(lambda v: int(v * 0.6 * pulse))])
            img = ImageChops.add(img, glow.filter(ImageFilter.GaussianBlur(10)))
        img = darken(img, 0.08)
        # dip to black through each cut between paintings
        dip = max(0.0, 1.0 - since_cut / 0.25) if a > 9.6 else 0.0
        if tt > b - 0.2:
            dip = max(dip, (tt - (b - 0.2)) / 0.2)
        if p.get("cap"):
            img = caption(img, p["cap"], since_cut, b - a)
        img = darken(img, dip * 0.9)
        img = vhs(img, 0.0, tt, 0.035)
    elif kind == "clip":
        key = id(seg)
        if key not in clips:
            for c in list(clips.values()):
                c.close()
            clips.clear()
            if "file" in p:
                src = p["file"]
                start = float(p["at"])
            else:
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
        z = float(p.get("zoom", 1.1)) + 0.025 * max(0.0, 1.0 - since_cut / 0.3)   # a little closer than the game camera, and a punch on the cut
        if z > 1.001:
            cw, ch = W / z, H / z
            img = img.resize((W, H), Image.BICUBIC, box=((W - cw) / 2, (H - ch) / 2, (W + cw) / 2, (H + ch) / 2))
        cap_seg = next((q for q in TL if q[2] == "clip" and q[3].get("cap") and q[0] <= tt < q[0] + 2.0), None)
        if cap_seg is not None:
            img = caption(img, cap_seg[3]["cap"], tt - cap_seg[0], 2.0)
        img = vhs(img, 0.0, tt, 0.03)
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
        img = text_center(img, L("RELEASE DATE TO BE ANNOUNCED"), 400, 60, GOLD, env(tt, a + 0.2, b + 1.0, 0.3))
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
        img = text_center(img, L("INVERTED INDEX STUDIO   ·   A GAME BY GILBERTO LOPES"), 800, 30, CYAN, env(tt, a + 2.0, b + 1.0, 0.6), fnt=F_MONO(30))
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
