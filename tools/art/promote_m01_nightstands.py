"""Promote the reviewed M01 bedside-cabinet render family to runtime assets."""
from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/art/prerendered/m01_sunset_palms/staging/nightstand_family_v1"
DESTINATION = ROOT / "assets/art/prerendered/m01_sunset_palms/runtime/nightstand_v1"
REVIEW = ROOT / "build/m01_native_bed_review.json"


def main() -> None:
    review = json.loads(REVIEW.read_text(encoding="utf-8"))
    if review.get("nightstand_count") != 21:
        raise SystemExit("M01 bedside review must prove the original 13 cabinets plus eight legacy lamp positions")
    if not review.get("nightstand_navigation", {}).get("passed"):
        raise SystemExit("M01 bedside navigation review must pass before promotion")
    if review.get("legacy_nightstands_pending"):
        raise SystemExit("M01 bedside review left unresolved legacy placements")
    physics = review.get("nightstand_physics", [])
    if len(physics) != 21 or not all(item.get("registered_solid") and item.get("actor_overlap_free") for item in physics):
        raise SystemExit("Every M01 bedside cabinet needs a reviewed solid, actor-clear placement")

    contract = json.loads((SOURCE / "contract.json").read_text(encoding="utf-8"))
    DESTINATION.mkdir(parents=True, exist_ok=True)
    hashes: dict[str, str] = {}
    for frame in contract["frames"]:
        name = frame["file"]
        if Path(name).name != name:
            raise SystemExit(f"Unsafe frame name: {name}")
        shutil.copy2(SOURCE / name, DESTINATION / name)
        hashes[name] = hashlib.sha256((DESTINATION / name).read_bytes()).hexdigest()
    contract.update(
        runtime_approved=True,
        source_sha256=hashes,
        expected_placements=13,
        approval_scope=(
            "M01 bedside cabinet family only: thirteen original nightstand positions, reviewed Blender frames, "
            "solid collision volumes and preserved navigation connectivity. Legacy decorative lamps remain visual-only."
        ),
        pending=["Full guest-room visual assembly and lighting refinement remain separate work."],
    )
    (DESTINATION / "runtime_contract.json").write_text(json.dumps(contract, indent=2) + "\n", encoding="utf-8")
    print("M01 nightstands promoted: four reviewed frames and 13 gameplay-safe cabinet placements.")


if __name__ == "__main__":
    main()
