"""Static integrity checks for the promoted M01 CRT-dresser family."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "assets/art/prerendered/m01_sunset_palms/runtime/tv_dresser_v1"
CONTRACT = RUNTIME / "runtime_contract.json"
SCRIPT = ROOT / "scripts/levels/m01_native_dressers.gd"
DRESSING = ROOT / "scripts/levels/dressing.gd"


def main() -> None:
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    if not contract.get("runtime_approved") or contract.get("expected_placements") != 7:
        raise SystemExit("M01 CRT dresser contract must approve exactly seven reviewed placements")
    frames = contract.get("frames", [])
    if [frame.get("rotation_degrees") for frame in frames] != [0, 90, 180, 270]:
        raise SystemExit("M01 CRT dressers require all four authored views")
    hashes = contract.get("source_sha256", {})
    for frame in frames:
        name = frame.get("file", "")
        asset = RUNTIME / name
        if Path(name).name != name or not asset.is_file():
            raise SystemExit(f"Missing or unsafe runtime dresser frame: {name}")
        if hashes.get(name) != hashlib.sha256(asset.read_bytes()).hexdigest():
            raise SystemExit(f"Runtime dresser hash mismatch: {name}")
    source = SCRIPT.read_text(encoding="utf-8")
    if "staging/" in source or "runtime/tv_dresser_v1" not in source:
        raise SystemExit("Runtime dresser code must not load staging artwork")
    if "M01NativeDressers.build(level,floor_layer)" not in DRESSING.read_text(encoding="utf-8"):
        raise SystemExit("M01 dressing does not invoke native CRT dressers")
    print("M01 native dresser audit: PASS (seven gameplay-safe CRT dressers, four verified runtime frames)")


if __name__ == "__main__":
    main()
