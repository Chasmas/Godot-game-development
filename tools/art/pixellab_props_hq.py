#!/usr/bin/env python3
"""High-quality dense prop sprites (3/4 view, highly detailed) via PixelLab pixflux.
  python tools/art/pixellab_props_hq.py <name> [<name> ...] [--out dir]
Edit PROPS below; output defaults to assets/art/Artwork/pixellab/hq/<name>.png (review first, then promote).
"""
import base64, io, json, os, sys, time, urllib.request, urllib.error
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
STYLE = ("highly detailed isometric-style pixel art game asset, three-quarter view from above, 1980s California neon noir, "
         "rich material texture, dense small details, strong warm and cool rim lighting, ambient occlusion, "
         "clean silhouette, limited but rich colour ramps, crisp pixels, no background")
PROPS = {
  "hq_persian_rug": (192, 128, "ornate persian rug seen from above, deep red and gold geometric border, intricate medallion pattern, worn fringe tassels"),
  "hq_bookshelf_full": (128, 160, "tall wooden bookshelf crammed with colourful books, vinyl records, trophies, a small lamp and potted plant on top"),
  "hq_motel_bed": (160, 128, "1980s motel double bed with rumpled orange floral bedspread, two pillows, a worn blanket, bedside shadow"),
  "hq_bar_counter": (192, 96, "retro bar counter with rows of liquor bottles behind, glowing neon pink and blue light strip, bar stools, glasses on the surface"),
  "hq_sofa_velvet": (160, 96, "plush teal velvet sofa with throw cushions and a magazine, polished wood legs"),
  "hq_crt_wall": (192, 128, "wall of stacked CRT televisions all playing different colourful static and test patterns, cables hanging"),
}

def key():
    k = os.environ.get("PIXELLAB_API_KEY", "")
    return k or open(os.path.join(os.path.expanduser("~"), ".pixellab_key"), encoding="utf-8-sig").read().strip()

def gen(name, out):
    w, h, desc = PROPS[name]
    body = {"description": desc + ", " + STYLE, "negative_description": "blurry, flat, noisy, text, watermark, low detail, front view, side view",
            "image_size": {"width": w, "height": h}, "no_background": True,
            "detail": "highly detailed", "shading": "highly detailed shading", "outline": "single color black outline",
            "text_guidance_scale": 8.0}
    for attempt in range(6):
        req = urllib.request.Request("https://api.pixellab.ai/v2/create-image-pixflux", data=json.dumps(body).encode(),
                                     headers={"Authorization": "Bearer " + key(), "Content-Type": "application/json"})
        try:
            r = json.load(urllib.request.urlopen(req, timeout=300)); break
        except urllib.error.HTTPError as e:
            if e.code == 429: time.sleep(20 * (attempt + 1)); continue
            print("  !", name, e.code, e.read()[:200]); return False
    else:
        return False
    im = Image.open(io.BytesIO(base64.b64decode(r["image"]["base64"].split(",")[-1]))).convert("RGBA")
    os.makedirs(out, exist_ok=True)
    im.save(os.path.join(out, name + ".png"))
    return True

if __name__ == "__main__":
    a = sys.argv[1:]
    out = a[a.index("--out") + 1] if "--out" in a else os.path.join(ROOT, "assets", "art", "Artwork", "pixellab", "hq")
    for n in [x for x in a if x in PROPS]:
        print(n, "ok" if gen(n, out) else "FAILED", flush=True)
