#!/usr/bin/env python3
"""Re-render existing prop sprites in PixelLab quality mode at 2x resolution.
The current sprite (upscaled x2) is the init image so the silhouette and on-screen
size stay; the result goes to assets/art/pixellab_world/sprites_hq/<id>.png
(ArtLib shows it at the same size as before, with twice the pixels).
  python tools/art/pixellab_upgrade_sprites.py <id> [<id> ...]   |  --all
"""
import base64, io, json, os, sys, time, urllib.request, urllib.error
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "art", "pixellab_world", "sprites")
OUT = os.path.join(ROOT, "assets", "art", "pixellab_world", "sprites_hq")
STYLE = ("highly detailed pixel art game prop, seen from above at a three-quarter angle, 1980s California neon noir, "
         "rich material texture, dense small details, warm and cool rim lighting, ambient occlusion, crisp pixels, clean silhouette")

def key():
    k = os.environ.get("PIXELLAB_API_KEY", "")
    return k or open(os.path.join(os.path.expanduser("~"), ".pixellab_key"), encoding="utf-8-sig").read().strip()

def b64(im):
    buf = io.BytesIO(); im.save(buf, "PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode(), "format": "png"}

def clear_backdrop(im):
    """The API sometimes returns an opaque flat backdrop: flood it to transparent from the borders."""
    px = im.load(); w, h = im.size
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    if all(c[3] < 10 for c in corners): return im
    bg = corners[0]
    if any(abs(c[i] - bg[i]) > 10 for c in corners for i in range(3)): return im
    near = lambda c: c[3] > 0 and all(abs(c[i] - bg[i]) <= 14 for i in range(3))
    stack = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    seen = set()
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h) or not near(px[x, y]): continue
        seen.add((x, y)); px[x, y] = (0, 0, 0, 0)
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return im

def upgrade(pid, strength=380):
    im = Image.open(os.path.join(SRC, pid + ".png")).convert("RGBA")
    w, h = im.size
    if max(w, h) * 2 > 400: return "skip (too large)"
    init = im.resize((w * 2, h * 2), Image.NEAREST)
    desc = pid.replace("_", " ")
    body = {"description": f"{desc}, {STYLE}", "negative_description": "blurry, flat, noisy, text, watermark, low detail, front view, characters",
            "image_size": {"width": w * 2, "height": h * 2}, "no_background": True,
            "init_image": b64(init), "init_image_strength": strength,
            "detail": "highly detailed", "shading": "highly detailed shading", "outline": "single color black outline",
            "text_guidance_scale": 7.0}
    for attempt in range(6):
        req = urllib.request.Request("https://api.pixellab.ai/v2/create-image-pixflux", data=json.dumps(body).encode(),
                                     headers={"Authorization": "Bearer " + key(), "Content-Type": "application/json"})
        try:
            r = json.load(urllib.request.urlopen(req, timeout=300)); break
        except urllib.error.HTTPError as e:
            if e.code == 429: time.sleep(20 * (attempt + 1)); continue
            return f"HTTP {e.code} {e.read()[:160]}"
    else:
        return "rate limited"
    out = Image.open(io.BytesIO(base64.b64decode(r["image"]["base64"].split(",")[-1]))).convert("RGBA")
    out = clear_backdrop(out)
    os.makedirs(OUT, exist_ok=True)
    out.save(os.path.join(OUT, pid + ".png"))
    return "ok"

if __name__ == "__main__":
    a = sys.argv[1:]
    ids = sorted(f[:-4] for f in os.listdir(SRC) if f.endswith(".png")) if "--all" in a else [x for x in a if not x.startswith("--")]
    for pid in ids:
        if "--all" in a and os.path.exists(os.path.join(OUT, pid + ".png")): continue
        print(pid, upgrade(pid), flush=True)
