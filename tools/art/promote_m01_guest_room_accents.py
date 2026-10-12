#!/usr/bin/env python3
"""Promote the reviewed M01 guest-room accent sprites into a runtime family."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/art/prerendered/m01_sunset_palms/staging/guest_room_props_v1"
DEST = ROOT / "assets/art/prerendered/m01_sunset_palms/runtime/guest_room_props_v1"
REVIEW = ROOT / "build/m01_guest_room_accents_staging_review.json"
LEVEL = ROOT / "levels/m01_sunset_palms.json"


def main() -> None:
    contract = json.loads((SOURCE / "contract.json").read_text(encoding="utf-8"))
    review = json.loads(REVIEW.read_text(encoding="utf-8"))
    if contract.get("runtime_approved") or not review.get("passed") or review.get("runtime_approved"):
        raise SystemExit("Only a passing staging review may promote guest-room accents")
    accents = review.get("accents", [])
    if len(accents) < 1 or any(row.get("alpha_pixels_outside_room") != 0 for row in accents):
        raise SystemExit("Guest-room accent review lacks contained live placements")
    DEST.mkdir(parents=True, exist_ok=True)
    for descriptor in contract["items"].values():
        source = SOURCE / descriptor["file"]
        if not source.is_file():
            raise SystemExit(f"Missing reviewed sprite: {source}")
        shutil.copy2(source, DEST / source.name)
    runtime = {
        **contract,
        "runtime_approved": True,
        "pending": [],
        "expected_placements": len(accents),
        "source_level_sha256": hashlib.sha256(LEVEL.read_bytes()).hexdigest(),
        "approval_scope": "M01 guest-room suitcase, shoes and service-tray dressing only; visual replacements retain original authored cells and add no collision or navigation.",
    }
    (DEST / "contract.json").write_text(json.dumps(runtime, indent=2) + "\n", encoding="utf-8")
    print(f"M01 guest-room accents promoted: {len(accents)} reviewed placements")


if __name__ == "__main__":
    main()
