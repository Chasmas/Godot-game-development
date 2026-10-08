"""Create the review-only higher-resolution pixel candidate for M01.

The source is rendered at 960x540 in Blender with ``--pixel_hq`` so the
palette reduction does not throw away facade and foliage edges before the
nearest-neighbour upscale.  This file is deliberately not a runtime import.
"""

from pathlib import Path

from PIL import Image, ImageEnhance


ROOT = Path(__file__).resolve().parents[2] / "assets" / "art" / "prerendered" / "m01_sunset_palms"
SOURCE = ROOT / "courtyard_pixel_source_hq.png"
OUTPUT = ROOT / "courtyard_pixel_art_candidate_hq.png"


def main() -> None:
    source = Image.open(SOURCE).convert("RGB")
    # Keep a little more headroom in bright emissive windows/neon.  The old
    # 0.45 compression made the highlights merge into the same pale bucket as
    # the motel plaster; 0.70 still prevents clipped whites while preserving
    # a readable warm highlight after the 192-colour reduction.
    source = source.point(lambda value: 224 + int((value - 224) * 0.70) if value > 224 else value)
    reduced = source.quantize(colors=192, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    reduced = ImageEnhance.Contrast(reduced.convert("RGB")).enhance(1.05)
    reduced = ImageEnhance.Color(reduced).enhance(1.05)
    output = reduced.resize((1920, 1080), Image.Resampling.NEAREST).convert("RGBA")
    output.save(OUTPUT)
    print(f"created {OUTPUT} {output.size} {output.mode}")


if __name__ == "__main__":
    main()
