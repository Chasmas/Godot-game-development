"""Validate the opt-in M01 4K Blender layer export without touching runtime art."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/prerendered/m01_sunset_palms/layers/4k"
EXPECTED = (3840, 2160)
NAMES = ("ground", "architecture", "props_vegetation", "foreground_occlusion",
         "ground_no_pool_review", "ground_no_pool_neutral_review")

missing = [name for name in NAMES if not (OUT / f"{name}.png").exists()]
if missing:
    raise SystemExit(f"FAIL: missing 4K layers: {', '.join(missing)}")
for name in NAMES:
    path = OUT / f"{name}.png"
    with Image.open(path) as image:
        if image.size != EXPECTED or image.mode != "RGBA":
            raise SystemExit(f"FAIL: {path.name} is {image.size} {image.mode}, expected {EXPECTED} RGBA")
print(f"M01 4K layer audit: PASS ({len(NAMES)} RGBA layers at {EXPECTED[0]}x{EXPECTED[1]})")
