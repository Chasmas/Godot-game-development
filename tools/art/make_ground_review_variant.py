"""Create a review-only ground layer with baked light pools softened.

The Blender ground export contains useful pool/pavement geometry but also
bright baked light pools that compete with Godot's live lighting.  This tool
keeps the layer aligned and RGBA-compatible while compressing only the upper
end of RGB values.  It is deliberately a staging asset and is never imported
by normal gameplay.
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2] / "assets" / "art" / "prerendered" / "m01_sunset_palms"
SOURCE = ROOT / "layers" / "ground.png"
OUTPUT = ROOT / "layers" / "ground_no_emissive_review.png"


def soften(value: int) -> int:
    if value <= 150:
        return value
    return 150 + round((value - 150) * 0.55)


def main() -> None:
    image = Image.open(SOURCE).convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            pixels[x, y] = (soften(r), soften(g), soften(b), a)
    image.save(OUTPUT)
    print(f"created {OUTPUT} {image.size} {image.mode}")


if __name__ == "__main__":
    main()
