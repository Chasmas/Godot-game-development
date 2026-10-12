#!/usr/bin/env python3
"""Extract transparent top-down guest-room prop sprites from the approved sheet.

The source sheet is retained beside the extracted staging sprites.  Hard-coded
bounds deliberately make the four intended objects reviewable rather than
silently accepting a later, differently arranged generation.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/art/prerendered/m01_sunset_palms/staging/guest_room_props_v1/source_sheet.png"
OUT = SOURCE.parent
EXPECTED_SIZE = (1254, 1254)
SPRITES = {
    "open_suitcase": ((50, 60, 700, 760), (44, 48)),
    "shoes": ((780, 220, 1190, 715), (28, 36)),
    "service_tray": ((110, 800, 660, 1145), (36, 24)),
    "bedside_lamp": ((770, 750, 1200, 1180), (32, 32)),
}


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"Missing generated guest-room source sheet: {SOURCE}")
    sheet = Image.open(SOURCE).convert("RGBA")
    if sheet.size != EXPECTED_SIZE:
        raise SystemExit(f"Unexpected source sheet dimensions {sheet.size}; expected {EXPECTED_SIZE}")
    OUT.mkdir(parents=True, exist_ok=True)
    report: list[str] = []
    for name, (bounds, game_size) in SPRITES.items():
        sprite = sheet.crop(bounds)
        alpha = sprite.getchannel("A")
        box = alpha.getbbox()
        if box is None:
            raise SystemExit(f"{name}.png has no visible pixels")
        # A crop must have useful transparent padding for clean nearest-neighbour
        # scaling and must not accidentally contain another generated prop.
        if box[0] == 0 and box[1] == 0 and box[2] == sprite.width and box[3] == sprite.height:
            raise SystemExit(f"{name}.png lacks transparent extraction padding")
        sprite.save(OUT / f"{name}.png")
        game = sprite.resize(game_size, Image.Resampling.LANCZOS)
        if game.getchannel("A").getbbox() is None:
            raise SystemExit(f"{name}_game.png lost all alpha during downsampling")
        game.save(OUT / f"{name}_game.png")
        report.append(f"{name}.png: {sprite.width}x{sprite.height}, alpha={box}; game={game.width}x{game.height}")
    (OUT / "extraction_report.txt").write_text("\n".join(report) + "\n", encoding="utf-8")
    print(f"M01 guest-room props extracted: {len(SPRITES)} transparent sprites")


if __name__ == "__main__":
    main()
