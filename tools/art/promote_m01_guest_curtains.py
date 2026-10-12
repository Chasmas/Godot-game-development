#!/usr/bin/env python3
"""Promote a passing M01 guest-window curtain review to runtime."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/art/prerendered/m01_sunset_palms/staging/guest_curtain_v1"
DEST = ROOT / "assets/art/prerendered/m01_sunset_palms/runtime/guest_curtain_v1"
REVIEW = ROOT / "build/m01_guest_curtains_staging_review.json"
LEVEL = ROOT / "levels/m01_sunset_palms.json"


def main() -> None:
    contract = json.loads((SOURCE / "contract.json").read_text(encoding="utf-8"))
    review = json.loads(REVIEW.read_text(encoding="utf-8"))
    rows = review.get("curtained_windows", [])
    if contract.get("runtime_approved") or not review.get("passed") or review.get("runtime_approved"):
        raise SystemExit("Curtain promotion requires a passing staging-only review")
    if not review.get("shatter_hides_dressing") or not rows or any(row.get("alpha_pixels_outside_room") != 0 for row in rows):
        raise SystemExit("Curtain review lacks required containment or shatter proof")
    source = SOURCE / contract["file"]
    if not source.is_file():
        raise SystemExit(f"Missing reviewed curtain sprite: {source}")
    DEST.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, DEST / source.name)
    runtime = {
        **contract,
        "runtime_approved": True,
        "pending": [],
        "expected_windows": len(rows),
        "source_level_sha256": hashlib.sha256(LEVEL.read_bytes()).hexdigest(),
        "approval_scope": "M01 horizontal GlassWindow bodies adjoining guest rooms only; curtains are visual-only and hide with a shattered pane.",
    }
    (DEST / "contract.json").write_text(json.dumps(runtime, indent=2) + "\n", encoding="utf-8")
    print(f"M01 guest curtains promoted: {len(rows)} reviewed windows")


if __name__ == "__main__":
    main()
