"""Build labelled contact sheets for every PixelLab painting used at runtime."""

from __future__ import annotations

import json
import re
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
PAINTED = ROOT / "assets/art/pixellab_ui_v3_approved/painted"
OUT = Path("C:/tmp_shots/cutscene_audit")
THUMB = (256, 144)
CELL = (272, 178)
COLS = 4
ROWS = 4


def used_shots() -> list[str]:
    dialogue = "\n".join(
        p.read_text(encoding="utf-8", errors="ignore")
        for p in (ROOT / "data/dialogue").glob("*.json")
    )
    shots = set(re.findall(r'"shot"\s*:\s*"([^"]+)"', dialogue))
    intro = (ROOT / "scripts/ui/intro.gd").read_text(
        encoding="utf-8", errors="ignore"
    )
    shots.update(re.findall(r'\["(t_[^"]+)"\s*,', intro))
    shots.discard("static")
    return sorted(shots)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    shots = used_shots()
    missing = [shot_id for shot_id in shots if not (PAINTED / f"{shot_id}.png").exists()]
    if missing:
        raise FileNotFoundError("Missing runtime cutscene shots: " + ", ".join(missing))
    per_page = COLS * ROWS
    for page_index in range((len(shots) + per_page - 1) // per_page):
        page = Image.new(
            "RGB",
            (COLS * CELL[0], ROWS * CELL[1]),
            (20, 17, 25),
        )
        draw = ImageDraw.Draw(page)
        for slot, shot_id in enumerate(
            shots[page_index * per_page : (page_index + 1) * per_page]
        ):
            x = (slot % COLS) * CELL[0] + 8
            y = (slot // COLS) * CELL[1] + 8
            path = PAINTED / f"{shot_id}.png"
            image = Image.open(path).convert("RGB")
            image.thumbnail(THUMB, Image.Resampling.LANCZOS)
            thumb = Image.new("RGB", THUMB, (4, 3, 6))
            thumb.paste(
                image,
                ((THUMB[0] - image.width) // 2, (THUMB[1] - image.height) // 2),
            )
            page.paste(thumb, (x, y))
            draw.text((x, y + THUMB[1] + 5), shot_id, fill=(245, 235, 225))
        destination = OUT / f"used_shots_{page_index + 1:02d}.jpg"
        page.save(destination, quality=92)
        print(destination)


if __name__ == "__main__":
    main()
