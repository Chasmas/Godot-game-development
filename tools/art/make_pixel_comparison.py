"""Build a side-by-side review sheet for the M01 render candidates."""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2] / "assets" / "art" / "prerendered" / "m01_sunset_palms"
OUT = ROOT / "courtyard_pixel_comparison.png"


def main() -> None:
    master = Image.open(ROOT / "courtyard_master.png").convert("RGB").resize((960, 540), Image.Resampling.LANCZOS)
    candidate = Image.open(ROOT / "courtyard_pixel_art_candidate.png").convert("RGB").resize((960, 540), Image.Resampling.NEAREST)
    sheet = Image.new("RGB", (1920, 590), (12, 12, 18))
    sheet.paste(master, (0, 50))
    sheet.paste(candidate, (960, 50))
    draw = ImageDraw.Draw(sheet)
    draw.text((18, 18), "MASTER", fill=(255, 255, 255))
    draw.text((978, 18), "PIXEL CANDIDATE", fill=(255, 255, 255))
    sheet.save(OUT)
    print(f"created {OUT} {sheet.size}")


if __name__ == "__main__":
    main()
