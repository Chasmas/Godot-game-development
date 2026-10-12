"""Verify the promoted M01 wall plate remains map-locked and runtime-isolated."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "assets/art/prerendered/m01_sunset_palms/runtime/walls_v1"
CONTRACT = RUNTIME / "runtime_contract.json"
LEVEL = ROOT / "levels/m01_sunset_palms.json"
SCRIPT = ROOT / "scripts/levels/m01_native_walls.gd"


def main() -> None:
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    image = RUNTIME / contract.get("image", "")
    if not contract.get("runtime_approved") or not image.is_file():
        raise SystemExit("M01 runtime wall contract or image is missing")
    if contract.get("source_level_sha256") != hashlib.sha256(LEVEL.read_bytes()).hexdigest():
        raise SystemExit("M01 runtime wall plate is not locked to the current level grid")
    if contract.get("image_sha256") != hashlib.sha256(image.read_bytes()).hexdigest():
        raise SystemExit("M01 runtime wall image hash mismatch")
    if tuple(contract.get("size_px", [])) != (2176, 1952):
        raise SystemExit("M01 runtime wall plate projection size changed")
    source = SCRIPT.read_text(encoding="utf-8")
    if "staging/" in source or "runtime/walls_v1" not in source:
        raise SystemExit("M01 native wall code must load only runtime artwork")
    print("M01 native wall audit: PASS (current-map plate, retained physics fallback)")


if __name__ == "__main__":
    main()
