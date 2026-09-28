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
from PIL import Image, ImageDraw, ImageFont, ImageFilter

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
TL.append([0.0, 5.5, "card", {"lines": [("INVERTED INDEX STUDIO", 64, GOLD), ("PRESENTS", 30, CYAN)]}])
TL.append([5.5, 9.5, "card", {"lines": [("A GAME BY", 30, CYAN), ("GILBERTO LOPES", 78, PINK)]}])
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
    if kind == "card":
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
        img = kenburns(still(p["id"]), k, pan=p.get("pan", (0, 0)))
        if p.get("flash") and since_cut < 0.15:
            img = Image.blend(img, Image.new("RGB", (W, H), (255, 240, 220)), 1.0 - since_cut / 0.15)
        img = darken(img, 0.12)
        if p.get("cap"):
            img = text_center(img, p["cap"], H - 190, 58, GOLD, env(tt, a + 0.15, b, 0.25))
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
            aud = np.frombuffer(ap.stdout, np.float32).reshape(-1, 2)
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
        img = text_center(base, "HOTSHOT CALIFORNIA", 250, 96, PINK, al)
        img = text_center(img, "RELEASE DATE TO BE ANNOUNCED", 430, 60, GOLD, env(tt, a + 0.8, b + 1.0, 0.6))
        img = text_center(img, "PC  ·  STEAM  ·  GOG  ·  EPIC GAMES STORE", 540, 40, PAPER, env(tt, a + 1.4, b + 1.0, 0.6), fnt=F_MONO(40))
        img = text_center(img, "INVERTED INDEX STUDIO   ·   A GAME BY GILBERTO LOPES", 800, 30, CYAN, env(tt, a + 2.0, b + 1.0, 0.6), fnt=F_MONO(30))
        if tt > b - 1.2:
            img = darken(img, (tt - (b - 1.2)) / 1.2)
        img = vhs(img, 0.0, tt, 0.05)
    # the tape counter, top-left, all the way through
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
mix = score[:n] + ga / peak * 0.28           # the gunfire sits under the music
mix = np.tanh(mix * 1.1) / np.tanh(1.1)
mix = mix / (np.max(np.abs(mix)) + 1e-9) * 0.95
with wave.open(os.path.join(WORK, "mix.wav"), "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr)
    w.writeframes((mix * 32767).astype(np.int16).tobytes())
subprocess.run([FFMPEG, "-loglevel", "error", "-y", "-i", os.path.join(WORK, "video.mp4"), "-i", os.path.join(WORK, "mix.wav"),
                "-c:v", "copy", "-c:a", "aac", "-b:a", "256k", "-shortest", "-movflags", "+faststart", OUT], check=True)
print("trailer", OUT)
