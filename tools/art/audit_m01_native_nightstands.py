"""Static integrity checks for the promoted M01 bedside-cabinet family."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "assets/art/prerendered/m01_sunset_palms/runtime/nightstand_v1"
CONTRACT_PATH = RUNTIME / "runtime_contract.json"
SCRIPT = ROOT / "scripts/levels/m01_native_nightstands.gd"
DRESSING = ROOT / "scripts/levels/dressing.gd"


def main() -> None:
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    if not contract.get("runtime_approved"):
        raise SystemExit("M01 runtime nightstand contract is not approved")
    if contract.get("expected_placements") != 13:
        raise SystemExit("M01 runtime nightstand contract must preserve exactly 13 gameplay-safe cabinets")
    frames = contract.get("frames", [])
    if [frame.get("rotation_degrees") for frame in frames] != [0, 90, 180, 270]:
        raise SystemExit("M01 runtime nightstands need all four authored views")
    hashes = contract.get("source_sha256", {})
    for frame in frames:
        name = frame.get("file", "")
        path = RUNTIME / name
        if Path(name).name != name or not path.is_file():
            raise SystemExit(f"Missing or unsafe runtime nightstand frame: {name}")
        if hashes.get(name) != hashlib.sha256(path.read_bytes()).hexdigest():
            raise SystemExit(f"Runtime nightstand hash mismatch: {name}")
    source = SCRIPT.read_text(encoding="utf-8")
    if "staging/" in source or "runtime/nightstand_v1" not in source:
        raise SystemExit("Runtime nightstand code must load only the promoted runtime family")
    dressing = DRESSING.read_text(encoding="utf-8")
    if "M01NativeNightstands.build(level,floor_layer)" not in dressing:
        raise SystemExit("M01 dressing does not invoke the native nightstand family")
    print("M01 native nightstand audit: PASS (13 gameplay-safe cabinets, four verified runtime frames)")


if __name__ == "__main__":
    main()
