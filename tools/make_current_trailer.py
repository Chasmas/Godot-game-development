#!/usr/bin/env python3
"""Build the current-build English announcement trailer.

The edit deliberately reads only movie captures from the live Godot build plus
the game's approved pixel-art story plates.  It never reuses the old trailer.
"""
import os, subprocess, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
WORK = Path(sys.argv[1])
OUT = Path(sys.argv[2])
FF = r"C:\Program Files\Virtual Desktop Streamer\ffmpeg.exe"
W, H, FPS, LENGTH = 1920, 1080, 30, 66

FONT = ROOT / "assets/fonts/Poppins-BoldItalic.ttf"
MONO = ROOT / "assets/fonts/DejaVuSansMono-Bold.ttf"
PINK, CYAN, GOLD, PAPER = (255, 61, 127), (53, 224, 255), (255, 210, 63), (238, 232, 218)

def f(size, mono=False):
    return ImageFont.truetype(str(MONO if mono else FONT), size)

def card(lines, accent=PINK, kicker=""):
    im = Image.new("RGB", (W, H), (5, 7, 15)); d = ImageDraw.Draw(im)
    for y in range(0, H, 4): d.line((0, y, W, y), fill=(9, 12, 24))
    d.rectangle((W * .20, H * .28, W * .80, H * .285), fill=accent)
    if kicker:
        box = d.textbbox((0, 0), kicker, font=f(28, True)); x = (W - (box[2] - box[0])) // 2
        d.text((x, H * .36), kicker, font=f(28, True), fill=CYAN)
    y = H * (.45 if kicker else .42)
    for text, size in lines:
        box = d.textbbox((0, 0), text, font=f(size)); x = (W - (box[2] - box[0])) // 2
        d.text((x + 5, y + 5), text, font=f(size), fill=(0, 0, 0))
        d.text((x, y), text, font=f(size), fill=PAPER)
        y += size * 1.12
    return im

def studio_card():
    im = card([("INVERTED INDEX", 82), ("STUDIO", 42)], CYAN, "PRESENTS")
    d = ImageDraw.Draw(im); d.rectangle((W*.42, H*.66, W*.58, H*.665), fill=PINK)
    return im

def end_card():
    im = card([("HOTSHOT", 132), ("CALIFORNIA", 92)], PINK, "CREATED BY GILBERTO LOPES")
    d = ImageDraw.Draw(im)
    y = int(H * .73); labels = [("STEAM", PAPER), ("EPIC GAMES", PAPER), ("GOG.COM", PAPER)]
    total = 3 * 250 + 2 * 30; x = (W - total) // 2
    for label, col in labels:
        d.rounded_rectangle((x, y, x + 250, y + 72), radius=9, outline=col, width=3)
        box = d.textbbox((0, 0), label, font=f(25, True)); tx = x + (250 - box[2] + box[0]) // 2
        d.text((tx, y + 20), label, font=f(25, True), fill=col)
        x += 280
    d.text((W//2 - 178, y + 104), "COMING SOON", font=f(34, True), fill=GOLD)
    return im

def story(path):
    src = Image.open(path).convert("RGB")
    # slow crop preserves handcrafted pixels with a small cinematic push.
    sw, sh = src.size; target = W / H; ar = sw / sh
    if ar > target:
        cw, ch = int(sh * target), sh
    else:
        cw, ch = sw, int(sw / target)
    crop = src.crop(((sw-cw)//2, (sh-ch)//2, (sw+cw)//2, (sh+ch)//2)).resize((W, H), Image.Resampling.NEAREST)
    return crop

class Video:
    def __init__(self, path, start, duration):
        self.p = subprocess.Popen([FF, "-loglevel", "error", "-ss", str(start), "-i", str(path), "-t", str(duration), "-vf", f"scale={W}:{H}", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
        self.last = Image.new("RGB", (W, H), (0,0,0))
    def frame(self):
        raw = self.p.stdout.read(W*H*3)
        if len(raw) == W*H*3: self.last = Image.frombytes("RGB", (W,H), raw)
        return self.last.copy()
    def close(self): self.p.stdout.close(); self.p.wait()

def grade(im, t, heavy=False):
    im = ImageEnhance.Contrast(im).enhance(1.12)
    im = ImageEnhance.Color(im).enhance(1.12)
    ov = Image.new("RGBA", (W,H), (0,0,0,0)); d = ImageDraw.Draw(ov)
    for y in range(0, H, 4): d.line((0,y,W,y), fill=(0,0,0,34 if heavy else 20))
    d.rectangle((0,0,W,H), outline=(PINK[0],PINK[1],PINK[2],90), width=5)
    return Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB")

timeline = [
    (0, 3, "card", studio_card()),
    (3, 6, "card", card([("CREATED BY", 54), ("GILBERTO LOPES", 86)], GOLD)),
    (6, 11, "still", ROOT / "assets/art/painted/motel_night.webp"),
    (11, 17, "video", (WORK / "m01.avi", 5)),
    (17, 21, "card", card([("A TAPE WAS LEFT BEHIND.", 54)], CYAN)),
    (21, 26, "still", ROOT / "assets/art/painted/t_tape.webp"),
    (26, 33, "video", (WORK / "m03.avi", 4)),
    (33, 37, "still", ROOT / "assets/art/painted/live_monitors.webp"),
    (37, 44, "video", (WORK / "m01.avi", 16)),
    (44, 49, "card", card([("FAST.", 92), ("BRUTAL.", 92), ("UNFORGIVING.", 70)], PINK)),
    (49, 56, "video", (WORK / "m03.avi", 11)),
    (56, 60, "still", ROOT / "assets/art/painted/t_mansion.webp"),
    (60, 66, "card", end_card()),
]

def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    pipe = subprocess.Popen([FF, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-stream_loop", "-1", "-i", str(ROOT / "music/source/trailer_synthwave.mp3"), "-t", str(LENGTH), "-map", "0:v:0", "-map", "1:a:0", "-c:v", "libx264", "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", str(OUT)], stdin=subprocess.PIPE)
    for a,b,kind,src in timeline:
        frames = int((b-a)*FPS)
        content = story(src) if kind == "still" else src if kind == "card" else Video(src[0], src[1], b-a)
        for n in range(frames):
            k = n / max(1, frames-1)
            im = content.frame() if kind == "video" else content.copy()
            if kind == "still":
                # a restrained push, avoiding blur in pixel artwork
                scale = 1.0 + .035*k; crop = im.resize((int(W*scale), int(H*scale)), Image.Resampling.NEAREST)
                im = crop.crop(((crop.width-W)//2, (crop.height-H)//2, (crop.width+W)//2, (crop.height+H)//2))
            im = grade(im, a + n/FPS, kind != "card")
            # short fade around every edit
            fade = min(1.0, n / (FPS*.24), (frames-1-n)/(FPS*.24))
            if fade < 1: im = Image.blend(Image.new("RGB", (W,H)), im, max(0,fade))
            pipe.stdin.write(im.tobytes())
        if kind == "video": content.close()
    pipe.stdin.close(); code = pipe.wait()
    if code: raise SystemExit(code)
    print(OUT)

if __name__ == "__main__": main()
