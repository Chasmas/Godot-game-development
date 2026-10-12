#!/usr/bin/env python3
"""Extract a compact transparent M01 curtain panel from its generated source."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/art/prerendered/m01_sunset_palms/staging/guest_curtain_v1/source.png"
OUT = SOURCE.parent / "curtain_panel_game.png"
# The generator placed the panel on an opaque black field.  The source's
# non-black content has a stable bounded extent; preserve it as alpha rather
# than letting a black rectangle leak into live room floors.
CROP = (430, 95, 855, 1180)
GAME_SIZE = (18, 44)


def main() -> None:
    image = Image.open(SOURCE).convert("RGBA")
    if image.size != (1244, 1264):
        raise SystemExit(f"Unexpected curtain source dimensions: {image.size}")
    rgba = np.array(image.crop(CROP)).astype(np.float32)
    alpha = (rgba[:, :, :3].max(axis=2) > 10).astype(np.float32)
    rgba[:, :, 3] = alpha * 255.0
    if not alpha.any():
        raise SystemExit("Curtain extraction produced no visible pixels")
    # Resize premultiplied RGB and alpha independently.  This prevents the
    # opaque black generator canvas from bleeding into translucent curtain
    # edges when the large source is reduced to gameplay scale.
    premultiplied = np.clip(rgba[:, :, :3] * alpha[:, :, None], 0, 255).astype(np.uint8)
    rgb_small = np.array(Image.fromarray(premultiplied, "RGB").resize(GAME_SIZE, Image.Resampling.LANCZOS), dtype=np.float32)
    alpha_small = np.array(Image.fromarray((alpha * 255).astype(np.uint8), "L").resize(GAME_SIZE, Image.Resampling.LANCZOS), dtype=np.float32)
    visible = alpha_small > 0.5
    rgb_small[visible] = np.clip(rgb_small[visible] * 255.0 / alpha_small[visible, None], 0, 255)
    out = np.dstack((rgb_small.astype(np.uint8), alpha_small.astype(np.uint8)))
    Image.fromarray(out, "RGBA").save(OUT)
    print(f"M01 curtain panel extracted: {GAME_SIZE[0]}x{GAME_SIZE[1]} transparent sprite")


if __name__ == "__main__":
    main()
