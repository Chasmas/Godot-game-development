"""Crop the empty world margin from the M01 entrance staging review.

This is presentation-only. It never changes the Godot entrance layout or any
runtime texture; it simply makes the opt-in 4K Blender review match the other
M01 detail panels after a fresh render.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
IMAGE = ROOT / "assets/art/prerendered/m01_sunset_palms/entrance_approach_detail_staging_4k.png"

def main() -> None:
    image = Image.open(IMAGE).convert("RGBA")
    width, height = image.size
    crop = image.crop((420, 610, width - 420, height - 20))
    crop.resize((width, height), Image.Resampling.LANCZOS).save(IMAGE)
    print(f"entrance review cropped: {width}x{height} from {crop.size}")

if __name__ == "__main__":
    main()
