#!/usr/bin/env python3
"""
Turn the source paintings in assets/art/Artwork/ into the files the game
loads (see scripts/ui/cinematic_art.gd and scripts/narrative/portrait.gd):

  title key art           -> assets/art/title/hotshot_title.webp
  apartment / news frames -> assets/art/cutscenes/<id>.webp
  3x3 portrait sheet      -> assets/characters/portraits/<speaker>.png

The Artwork folder itself is excluded from the export.
  python3 tools/art/import_artwork.py
"""
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
A = os.path.join(ROOT, "assets", "art", "Artwork")
FRAMES = {
    "image-1790495576303.webp": "assets/art/title/hotshot_title.webp",
    "image-1790495600990.webp": "assets/art/cutscenes/apartment_1988.webp",
    "image-1790495608708.webp": "assets/art/cutscenes/news_1988.webp",
}
SHEET = "image-1790495612810.webp"
GRID = [["cass_star", "harcourt", "earl"], ["tommy", "anchor", "guard"], ["marv", "voice", "machine"]]

def main():
    for src, dst in FRAMES.items():
        im = Image.open(os.path.join(A, src)).convert("RGB")
        if im.width > 1600:
            im = im.resize((1600, int(im.height * 1600 / im.width)), Image.LANCZOS)
        os.makedirs(os.path.dirname(os.path.join(ROOT, dst)), exist_ok=True)
        im.save(os.path.join(ROOT, dst), "WEBP", quality=88)
    sheet = Image.open(os.path.join(A, SHEET)).convert("RGB")
    cw, ch = sheet.width / 3, sheet.height / 3
    out = os.path.join(ROOT, "assets", "characters", "portraits")
    for r in range(3):
        for c in range(3):
            box = (round(c * cw) + 4, round(r * ch) + 4, round((c + 1) * cw) - 4, round((r + 1) * ch) - 4)
            cell = sheet.crop(box).resize((192, 192), Image.LANCZOS)
            cell.save(os.path.join(out, GRID[r][c] + ".png"))
            if GRID[r][c] == "cass_star":
                cell.save(os.path.join(out, "cass.png"))
    print("artwork imported")

if __name__ == "__main__":
    main()
