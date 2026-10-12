"""Promote the map-validated M01 v6 wall plate to a runtime-only location."""
from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/art/prerendered/m01_sunset_palms/staging/layout_reconstruction_v1"
DESTINATION = ROOT / "assets/art/prerendered/m01_sunset_palms/runtime/walls_v1"
LEVEL = ROOT / "levels/m01_sunset_palms.json"


def main() -> None:
    contract = json.loads((SOURCE / "wall_layer_contract_v6.json").read_text(encoding="utf-8"))
    audit = json.loads((SOURCE / "wall_projection_audit_v6_current.json").read_text(encoding="utf-8"))
    level_hash = hashlib.sha256(LEVEL.read_bytes()).hexdigest()
    if not audit.get("passed") or audit.get("source_sha256") != level_hash or contract.get("source_level_sha256") != level_hash:
        raise SystemExit("M01 wall plate must pass the current-map projection audit")
    source_image = SOURCE / contract["image"]
    if not source_image.is_file() or tuple(contract.get("size_px", [])) != (2176, 1952):
        raise SystemExit("M01 wall plate image is missing or has an unexpected projection size")
    DESTINATION.mkdir(parents=True, exist_ok=True)
    destination_image = DESTINATION / "m01_walls_v6.png"
    shutil.copy2(source_image, destination_image)
    contract.update(
        image=destination_image.name,
        runtime_approved=True,
        image_sha256=hashlib.sha256(destination_image.read_bytes()).hexdigest(),
        approval_scope="M01 v6 wall plate visual layer only; original wall physics and door interaction remain authoritative.",
        pending=["Full environment composition and lighting refinement remain separate work."],
        runtime_light_mask=2,
    )
    (DESTINATION / "runtime_contract.json").write_text(json.dumps(contract, indent=2) + "\n", encoding="utf-8")
    print("M01 walls promoted: current-map v6 plate with original wall physics retained.")


if __name__ == "__main__":
    main()
