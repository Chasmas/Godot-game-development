"""Pack Blender RGBA frames without resampling or altering artwork."""
from pathlib import Path
import json
import argparse
from PIL import Image
parser = argparse.ArgumentParser()
parser.add_argument("--weapon", default="bat", choices=["bat", "knife"])
parser.add_argument("--source-root", default="build/melee_trail_review/measured_dense")
options = parser.parse_args()
weapon = options.weapon
root = Path(options.source_root)
items = []
for folder in (root / weapon).iterdir():
    if not folder.is_dir():
        continue
    for path in folder.glob("*.png"):
        with Image.open(path) as image:
            image = image.convert("RGBA")
            bounds = image.getchannel("A").getbbox()
            assert bounds is None or (bounds[0] > 1 and bounds[1] > 1 and bounds[2] < 255 and bounds[3] < 255), f"Clipped source frame: {path}"
            box = bounds or (0, 0, 1, 1)
            crop = image.crop(box)
        items.append((folder.name, path.stem, box, crop))
expected_headings = {str(round(index * 22.5, 1)).removesuffix(".0") for index in range(16)}
assert {item[0] for item in items} == expected_headings
for heading in expected_headings:
    assert {item[1] for item in items if item[0] == heading} == {f"{pose:03d}" for pose in range(65)}
items.sort(key=lambda item: item[3].height, reverse=True)
width, padding = 1024, 2
x = y = row_height = 0
placements = []
for heading, frame, box, crop in items:
    if x + crop.width + padding * 2 > width:
        x = 0
        y += row_height
        row_height = 0
    placements.append((heading, frame, box, crop, x + padding, y + padding))
    x += crop.width + padding * 2
    row_height = max(row_height, crop.height + padding * 2)
height = 1
while height < y + row_height:
    height *= 2
atlas = Image.new("RGBA", (width, height))
metadata = {"approved": False, "source": "Blender measured dense " + weapon + " renders", "frames": {}, "size": [width, height]}
for heading, frame, box, crop, px, py in placements:
    atlas.paste(crop, (px, py))
    metadata["frames"].setdefault(heading, {})[frame] = {
        "region": [px, py, crop.width, crop.height],
        "offset": [(box[0] + box[2]) / 2 - 128, (box[1] + box[3]) / 2 - 128],
    }
for _, _, _, crop, px, py in placements:
    assert atlas.crop((px, py, px + crop.width, py + crop.height)).tobytes() == crop.tobytes()
assert len(items) == 1040
out = root / "packed"
out.mkdir(exist_ok=True)
atlas.save(out / (weapon + ".png"))
(out / (weapon + ".json")).write_text(json.dumps(metadata), encoding="utf-8")
print(f"Verified {len(items)} exact RGBA crops, atlas {width}x{height}, raw bytes {width*height*4}")
