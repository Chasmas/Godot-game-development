"""Audit the review-only M01 pixel candidate before visual integration."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2] / "assets" / "art" / "prerendered" / "m01_sunset_palms"
SOURCE = ROOT / "courtyard_pixel_source.png"
CANDIDATE = ROOT / "courtyard_pixel_art_candidate.png"


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    candidate = Image.open(CANDIDATE).convert("RGBA")
    if source.size != (480, 270):
        raise SystemExit(f"FAIL: source size is {source.size}, expected (480, 270)")
    if candidate.size != (1920, 1080):
        raise SystemExit(f"FAIL: candidate size is {candidate.size}, expected (1920, 1080)")
    if candidate.getchannel("A").getextrema() == (0, 0):
        raise SystemExit("FAIL: candidate alpha is empty")
    colours = len(candidate.convert("RGB").getcolors(maxcolors=1_000_000) or [])
    if colours > 96:
        raise SystemExit(f"FAIL: candidate has {colours} colours, expected <= 96")
    print(f"M01 pixel candidate audit: PASS ({candidate.size}, {colours} RGB colours, non-empty alpha)")


if __name__ == "__main__":
    main()
