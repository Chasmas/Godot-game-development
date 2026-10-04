#!/usr/bin/env python3
"""Pixel-art versions of assets/art/painted/<id>.webp through PixelLab pixflux
(the painting is the init image, 384x216), then a x10 nearest upscale to a
crisp 3840x2160.  Output: assets/art/pixellab_paint_4k/<id>.png

  python tools/art/pixellab_paint4k.py <id> [<id> ...] [--strength 500] [--out dir]
  python tools/art/pixellab_paint4k.py --all
"""
import base64, io, json, os, sys, time, urllib.request, urllib.error
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "art", "painted")
W, H, UP = 384, 216, 10
GAME = os.path.join(ROOT, "assets", "art", "pixellab_ui_v3_approved", "painted")   # 1920x1080 for the game (the 4K masters stay out of the export)

def key():
    k = os.environ.get("PIXELLAB_API_KEY", "")
    return k or open(os.path.join(os.path.expanduser("~"), ".pixellab_key"), encoding="utf-8-sig").read().strip()

def b64(im):
    buf = io.BytesIO(); im.save(buf, "PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode(), "format": "png"}

def paint(pid, strength, out):
    init = Image.open(os.path.join(SRC, pid + ".webp")).convert("RGB").resize((W, H), Image.LANCZOS)
    body = {
        "description": "highly detailed cinematic pixel art illustration, faithful redraw of the reference, "
                       "1980s neon noir California, rich saturated colour, dramatic warm and cool lighting, "
                       "clean readable shapes, smooth colour ramps, crisp pixels",
        "negative_description": "blurry, noisy, dithering noise, jpeg artifacts, text, watermark, abstract blobs, low detail",
        "image_size": {"width": W, "height": H},
        "init_image": b64(init), "init_image_strength": strength,
        "detail": "highly detailed", "shading": "highly detailed shading", "outline": "lineless",
        "text_guidance_scale": 6.0, "no_background": False,
    }
    for attempt in range(6):
        req = urllib.request.Request("https://api.pixellab.ai/v2/create-image-pixflux", data=json.dumps(body).encode(),
                                     headers={"Authorization": "Bearer " + key(), "Content-Type": "application/json"})
        try:
            r = json.load(urllib.request.urlopen(req, timeout=300)); break
        except urllib.error.HTTPError as e:
            if e.code == 429: time.sleep(20 * (attempt + 1)); continue
            print("  !", pid, e.code, e.read()[:300]); return False
    else:
        return False
    im = Image.open(io.BytesIO(base64.b64decode(r["image"]["base64"].split(",")[-1]))).convert("RGB")
    os.makedirs(out, exist_ok=True)
    im.resize((W * UP, H * UP), Image.NEAREST).save(os.path.join(out, pid + ".png"), optimize=True)
    if GAME:
        os.makedirs(GAME, exist_ok=True)
        im.resize((W * 5, H * 5), Image.NEAREST).save(os.path.join(GAME, pid + ".png"), optimize=True)
    return True

if __name__ == "__main__":
    a = sys.argv[1:]
    strength = int(a[a.index("--strength") + 1]) if "--strength" in a else 500
    out = a[a.index("--out") + 1] if "--out" in a else os.path.join(ROOT, "assets", "art", "Artwork", "paint_4k")
    ids = [x for x in a if not x.startswith("--") and not x.isdigit() and x != out]
    if "--all" in a:
        ids = sorted(f[:-5] for f in os.listdir(SRC) if f.endswith(".webp"))
    for pid in ids:
        print(pid, "ok" if paint(pid, strength, out) else "FAILED", flush=True)
