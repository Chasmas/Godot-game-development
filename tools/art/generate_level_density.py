#!/usr/bin/env python3
"""Generate the review-only level-density queue through PixelLab.

Usage: python tools/art/generate_level_density.py [asset id ...] [--manifest path] [--force]
Outputs go to assets/art/pixellab_level_density_review/ first.  They are never
loaded by ArtLib until a reviewed asset is copied into pixellab_world/sprites.
"""
import base64, io, json, os, sys, urllib.error, urllib.request
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "tools/art/pixellab_level_density_manifest.json"
OUT = ROOT / "assets/art/pixellab_level_density_review"

def api_key():
    value = os.environ.get("PIXELLAB_API_KEY", "")
    if not value:
        value = (Path.home() / ".pixellab_key").read_text(encoding="utf-8-sig").strip()
    return value

def size(value):
    width, height = value.lower().split("x")
    return {"width": int(width), "height": int(height)}

def image_payload(path, target_size):
    image = Image.open(ROOT / path).convert("RGBA")
    image = image.resize((target_size["width"], target_size["height"]), Image.Resampling.NEAREST)
    buffer = io.BytesIO()
    image.save(buffer, "PNG")
    return {"type": "base64", "base64": base64.b64encode(buffer.getvalue()).decode(), "format": "png"}

def generate(entry):
    structural = entry["category"].startswith("A_")
    canvas = size(entry["canvas"])
    body = {
        "description": entry["prompt"],
        "negative_description": "person, character, text, logo, watermark, border, perspective, isometric view, photorealism, blurry details, mushy pixels",
        "image_size": canvas,
        "no_background": not structural,
        "text_guidance_scale": 8.0,
    }
    if entry.get("reference"):
        body["init_image"] = image_payload(entry["reference"], canvas)
        body["init_image_strength"] = int(entry.get("reference_strength", 450))
    request = urllib.request.Request(
        "https://api.pixellab.ai/v2/create-image-bitforge",
        data=json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + api_key(), "Content-Type": "application/json"},
    )
    response = json.load(urllib.request.urlopen(request, timeout=300))
    raw = response["image"]["base64"].split(",")[-1]
    image = Image.open(io.BytesIO(base64.b64decode(raw))).convert("RGBA")
    OUT.mkdir(parents=True, exist_ok=True)
    image.save(OUT / (entry["id"] + ".png"))
    print(entry["id"], image.size, "usage", response.get("usage", "unknown"))

def main():
    args = sys.argv[1:]
    force = "--force" in args
    manifest = MANIFEST
    if "--manifest" in args:
        index = args.index("--manifest")
        manifest = ROOT / args[index + 1]
        del args[index:index + 2]
    wanted = {arg for arg in args if not arg.startswith("--")}
    queue = json.loads(manifest.read_text(encoding="utf-8"))["queue"]
    entries = [item for item in queue if not wanted or item["id"] in wanted]
    missing = wanted - {item["id"] for item in entries}
    if missing:
        raise SystemExit("Unknown asset ids: " + ", ".join(sorted(missing)))
    for entry in entries:
        target = OUT / (entry["id"] + ".png")
        if target.exists() and not force:
            print(entry["id"], "already generated")
            continue
        try:
            generate(entry)
        except urllib.error.HTTPError as exc:
            print(entry["id"], "HTTP", exc.code, exc.read()[:400])
        except Exception as exc:
            print(entry["id"], "ERROR", exc)

if __name__ == "__main__":
    main()
