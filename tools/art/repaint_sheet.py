#!/usr/bin/env python3
"""The painter goes over the game's own characters instead of inventing them.

  python tools/art/repaint_sheet.py <look> <sheet_in.png>

<sheet_in.png> is tools/export_pose_sheet.gd's 4x2 grid of one look's poses
(seen from above, exact silhouettes). It goes to the image edits endpoint
with the instruction to repaint every figure in place - same outline, pose
and hand positions - in the game's painted style. The result is cut back
into cells; each cell is kept only if its silhouette still matches the
original (IoU), and saved as assets/art/cast/pose_<look>_<pose>.png at the
pose's texture size. Cells that drift are dropped (the game keeps the
drawn pose). One image per look, quality medium.
"""
import io, os, sys, json, base64, urllib.request
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_ai_art as G

ROOT = G.ROOT
POSES = ["unarmed", "aim_one", "aim_two", "aim_dual", "melee", "punch_l", "legs0", "legs1"]
CELL = 384
TEX = 64     # a pose texture (32 canvas px x RES 2)

PROMPT = ("Repaint this sprite sheet in place. It is a grid of 8 top-down video game sprites of the SAME character seen "
          "from directly above (bird's-eye view): 6 upper-body poses and 2 pairs of walking legs. Keep EVERY figure exactly "
          "where it is, with exactly the same outline, size, pose, arm angles and hand positions - only repaint the surface: "
          "detailed hand-painted style, real fabric folds and seams on the sleeves and trousers, proper hands with fingers "
          "clenched into fists, shaded hair, leather sheen, strong dark outline, limited palette, readable at small size. "
          "Do not add or remove anything, do not move anything, no background, transparent background. ")

def call(sheet_png, look_desc):
    key = os.environ["OPENAI_API_KEY"]
    fields = {"model": G.MODEL, "prompt": PROMPT + look_desc, "size": "1536x1024", "quality": "medium", "n": "1", "background": "transparent"}
    body, ctype = G._multipart(fields, [("image[]", ("sheet.png", sheet_png))])
    req = urllib.request.Request("https://api.openai.com/v1/images/edits", data=body, headers={"Authorization": "Bearer " + key, "Content-Type": ctype})
    r = json.load(urllib.request.urlopen(req, timeout=900))
    return Image.open(io.BytesIO(base64.b64decode(r["data"][0]["b64_json"]))).convert("RGBA")

def iou(a, b):
    a = np.asarray(a.getchannel("A")) > 100
    b = np.asarray(b.getchannel("A")) > 100
    inter = (a & b).sum()
    union = (a | b).sum()
    return inter / union if union else 0.0

def main():
    look = sys.argv[1]
    src = Image.open(sys.argv[2]).convert("RGBA")
    raw = os.path.join(ROOT, "assets", "art", "Artwork", "ai", "poses", look + ".png")
    if os.path.exists(raw) and "--again" not in sys.argv:
        out = Image.open(raw).convert("RGBA")
    else:
        buf = io.BytesIO()
        src.save(buf, "PNG")
        desc = {"cass": "The character: Cass, a woman in a crimson red leather jacket, dark auburn braided ponytail, a small gold star on her head, blue jeans, black boots."}.get(look, "")
        out = call(buf.getvalue(), desc)
        os.makedirs(os.path.dirname(raw), exist_ok=True)
        out.save(raw)
    out = out.resize(src.size, Image.LANCZOS)
    kept = []
    for i, pose in enumerate(POSES):
        box = ((i % 4) * CELL, (i // 4) * CELL, (i % 4 + 1) * CELL, (i // 4 + 1) * CELL)
        a = src.crop(box)
        b = out.crop(box)
        score = iou(a, b)
        print(f"  {pose:9s} silhouette match {score:.2f}")
        if score < 0.72:
            continue
        # back to the pose texture: the figure occupied 90% of the cell
        inner = int(CELL * 0.9)
        off = (CELL - inner) // 2
        cell = b.crop((off, off, off + inner, off + inner)).resize((TEX, TEX), Image.LANCZOS)
        al = cell.getchannel("A").point(lambda v: 255 if v > 110 else 0)
        cell.putalpha(al)
        cell.save(os.path.join(ROOT, "assets", "art", "cast", f"pose_{look}_{pose}.png"))
        kept.append(pose)
    print("kept", kept)

if __name__ == "__main__":
    main()
