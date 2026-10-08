#!/usr/bin/env python3
"""Top-down renders (tools/art/render_cast3d.py) -> the game's pixel-art strips.

  python tools/art/pack_cast3d.py <char_id> [--px 80] [--colors 48] [--src <render dir>]

assets/art/Artwork/3d/<id>/render/<anim>/fNN.png  ->  assets/art/cast3d/<id>/<anim>.png
(one row of frames, each `px` square) + assets/art/cast3d/<id>/meta.json with
the frame counts, fps and the hands' positions in texels from the frame
centre. One palette for every frame of the character (no flicker between
animations), a dark one-texel outline round the silhouette.

Oblique renders (render_cast3d.py --elev/--dirs, files dDD_fNN.png) pack each
facing as its own block of rows: frame i of facing d sits at column i % columns,
row d * rows_per_dir + i // columns. Their hands are screen texels from the
ground point ("origin"), per facing.
"""
import json, os, sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def main():
    cid = sys.argv[1]
    px = int(sys.argv[sys.argv.index("--px") + 1]) if "--px" in sys.argv else 80
    ncol = int(sys.argv[sys.argv.index("--colors") + 1]) if "--colors" in sys.argv else 48
    src = sys.argv[sys.argv.index("--src") + 1] if "--src" in sys.argv else os.path.join(ROOT, "assets", "art", "Artwork", "3d", cid, "render")
    dst = os.path.join(ROOT, "assets", "art", "cast3d", cid)
    os.makedirs(dst, exist_ok=True)
    meta = json.load(open(os.path.join(src, "meta.json")))
    dirs = int(meta.get("directions", 1))
    oblique = "elevation" in meta
    k = px / meta["size"]
    frames = {}
    for anim, info in meta["anims"].items():
        names = ["d%02d_f%02d.png" % (d, i) for d in range(dirs) for i in range(info["frames"])] if oblique else ["f%02d.png" % i for i in range(info["frames"])]
        frames[anim] = [Image.open(os.path.join(src, anim, n)).convert("RGBA").resize((px, px), Image.LANCZOS) for n in names]
    # one palette from every opaque pixel of every frame
    allpx = np.concatenate([np.array(f)[..., :3][np.array(f)[..., 3] > 110] for fs in frames.values() for f in fs])
    sample = Image.fromarray(allpx[np.random.default_rng(1).choice(len(allpx), min(len(allpx), 200000), replace=False)][None, :, :])
    pal = sample.quantize(ncol, method=Image.Quantize.MEDIANCUT)
    out_meta = {"px": px, "fps": meta["fps"], "meters": meta["meters"], "anims": {}}
    if oblique:
        out_meta.update({"directions": dirs, "elevation": meta["elevation"],
                         "origin": [round(meta["origin"][0] * k, 1), round(meta["origin"][1] * k, 1)]})
    for anim, fs in frames.items():
        per_dir = len(fs) // dirs
        cols = min(32, per_dir)
        rows_per_dir = (per_dir + cols - 1) // cols
        strip = Image.new("RGBA", (px * cols, px * rows_per_dir * dirs), (0, 0, 0, 0))
        for j, f in enumerate(fs):
            d, i = divmod(j, per_dir)
            a = np.array(f)
            alpha = a[..., 3] > 110
            q = Image.fromarray(a[..., :3]).quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
            o = np.dstack([np.array(q), np.where(alpha, 255, 0)]).astype(np.uint8)
            dil = np.zeros_like(alpha)
            for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                dil |= np.roll(np.roll(alpha, dy, 0), dx, 1)
            o[dil & ~alpha] = (14, 8, 20, 255)
            strip.alpha_composite(Image.fromarray(o, "RGBA"), ((i % cols) * px, (d * rows_per_dir + i // cols) * px))
        strip.save(os.path.join(dst, anim + ".png"))
        info = meta["anims"][anim]
        scale = lambda pair: [[round(h[0] * k, 1), round(h[1] * k, 1)] for h in pair]
        hands = [[scale(p) for p in row] for row in info["hands"]] if oblique else [scale(p) for p in info["hands"]]
        out_meta["anims"][anim] = {
            "frames": per_dir,
            "columns": cols,
            "rows_per_dir": rows_per_dir,
            "angles": info.get("angles", [0.0] * per_dir),
            "duration": info.get("duration", per_dir / meta["fps"]),
            "fps": info.get("fps", meta["fps"]),
            "hands": hands,
            "hips": [[round(p[0] * k, 1), round(p[1] * k, 1)] for p in info["hips"]],
        }
        print(f"  {anim}: {per_dir} frames x {dirs} facings")
    json.dump(out_meta, open(os.path.join(dst, "meta.json"), "w"), indent=1)

if __name__ == "__main__":
    main()
