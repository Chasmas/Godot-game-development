"""Create a review-only pixel-art candidate from the M01 low-resolution render."""

from pathlib import Path

from PIL import Image, ImageEnhance


ROOT = Path(__file__).resolve().parents[2] / "assets" / "art" / "prerendered" / "m01_sunset_palms"
SOURCE = ROOT / "courtyard_pixel_source.png"
OUTPUT = ROOT / "courtyard_pixel_art_candidate.png"


def main() -> None:
    source = Image.open(SOURCE).convert("RGB")
    # Compress only the top end so neon remains luminous without erasing nearby
    # trim and foliage detail during palette reduction.
    source = source.point(lambda value: 220 + int((value - 220) * 0.35) if value > 220 else value)
    reduced = source.quantize(colors=96, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    reduced = ImageEnhance.Contrast(reduced.convert("RGB")).enhance(1.06)
    reduced = ImageEnhance.Color(reduced).enhance(1.08)
    output = reduced.resize((1920, 1080), Image.Resampling.NEAREST).convert("RGBA")
    output.save(OUTPUT)
    print(f"created {OUTPUT} {output.size} {output.mode}")


if __name__ == "__main__":
    main()
