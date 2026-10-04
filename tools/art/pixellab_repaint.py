#!/usr/bin/env python3
"""Repaint a character's existing top-down poses in PixelLab (bitforge),
keeping the silhouette: the pose is the init image, the text describes the
character, the camera stays straight overhead so it can rotate freely.

  python tools/art/pixellab_repaint.py <look> <sheet.png> <pose> [<pose> ...] [--strength 500]

<sheet.png> is tools/export_pose_sheet.gd's 4x2 grid (cells 384 px):
  unarmed aim_one aim_two aim_dual / melee punch_l legs0 legs1
Results: assets/art/Artwork/pixellab/<look>_<pose>.png (+ a comparison sheet).
"""
import base64, io, json, os, sys, urllib.request, urllib.error
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "art", "Artwork", "pixellab")
POSES = ["unarmed", "aim_one", "aim_two", "aim_dual", "melee", "punch_l", "legs0", "legs1"]
CELL = 384
SIZE = 128
LOOKS = {
    "cass": "Cass, a young woman in a crimson red leather jacket, a dark auburn braided ponytail down her back, a small gold star pin, blue jeans, black boots",
    "guard": "a motel security guard in a charcoal navy security shirt, short sleeves, shoulder radio, black trousers, black shoes and a small brass badge",
    "civilian": "a civilian witness in a muted 1980s casual jacket, faded jeans, simple shoes and no tactical equipment",
    "welder": "a salvage-yard welder in a soot-dark canvas work jacket, leather gloves, heavy brown work boots and a raised welding visor",
}

def key():
    k = os.environ.get("PIXELLAB_API_KEY", "")
    if not k:
        k = open(os.path.join(os.path.expanduser("~"), ".pixellab_key"), encoding="utf-8-sig").read().strip()
    return k

def b64(im):
    buf = io.BytesIO(); im.save(buf, "PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode(), "format": "png"}

def main():
    look, sheet = sys.argv[1], sys.argv[2]
    poses = [a for a in sys.argv[3:] if not a.startswith("--") and not a.isdigit()]
    strength = int(sys.argv[sys.argv.index("--strength") + 1]) if "--strength" in sys.argv else 500
    src = Image.open(sheet).convert("RGBA")
    os.makedirs(OUT, exist_ok=True)
    pairs = []
    for pose in poses:
        i = POSES.index(pose)
        cell = src.crop(((i % 4) * CELL, (i // 4) * CELL, (i % 4 + 1) * CELL, (i // 4 + 1) * CELL))
        init = cell.resize((SIZE, SIZE), Image.NEAREST)
        body = {
            "description": f"{LOOKS.get(look, look)}, seen from directly above, bird's-eye view straight down at 90 degrees, top of the head and shoulders, arms {'reaching forward holding a gun' if 'aim' in pose else 'at the sides'}, facing right, detailed pixel art game sprite, 1980s neon noir",
            "negative_description": "face visible, front view, side view, perspective, isometric, background, floor, shadow",
            "image_size": {"width": SIZE, "height": SIZE},
            "no_background": True,
            "init_image": b64(init),
            "init_image_strength": strength,
            "text_guidance_scale": 8.0,
        }
        req = urllib.request.Request("https://api.pixellab.ai/v2/create-image-bitforge", data=json.dumps(body).encode(),
                                     headers={"Authorization": "Bearer " + key(), "Content-Type": "application/json"})
        try:
            r = json.load(urllib.request.urlopen(req, timeout=300))
        except urllib.error.HTTPError as e:
            print(f"  ! {pose}: HTTP {e.code} {e.read()[:400]}")
            continue
        data = r["image"]["base64"].split(",")[-1]
        im = Image.open(io.BytesIO(base64.b64decode(data))).convert("RGBA")
        im.save(os.path.join(OUT, f"{look}_{pose}.png"))
        print(f"  {pose}: ok, usage {r.get('usage')}")
        pairs.append((init, im))
    if pairs:
        cmp = Image.new("RGBA", (SIZE * 2 * 3, SIZE * 3 * len(pairs)), (40, 36, 48, 255))
        for k, (a, b) in enumerate(pairs):
            cmp.alpha_composite(a.resize((SIZE * 3, SIZE * 3), Image.NEAREST), (0, k * SIZE * 3))
            cmp.alpha_composite(b.resize((SIZE * 3, SIZE * 3), Image.NEAREST), (SIZE * 3, k * SIZE * 3))
        cmp.save(os.path.join(OUT, f"{look}_compare.png"))

if __name__ == "__main__":
    main()
