"""Promote the reviewed M01 CRT-dresser family to isolated runtime assets."""
from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/art/prerendered/m01_sunset_palms/staging/tv_dresser_family_v1"
DESTINATION = ROOT / "assets/art/prerendered/m01_sunset_palms/runtime/tv_dresser_v1"
REVIEW = ROOT / "build/m01_dresser_integrated_review.json"


def main() -> None:
    review = json.loads(REVIEW.read_text(encoding="utf-8"))
    bodies = review.get("integrated_bodies", [])
    if len(bodies) != 7 or not all(body.get("overlap_free") and body.get("actor_overlap_free") and body.get("actual_player_contact_directions", 0) > 0 for body in bodies):
        raise SystemExit("Each M01 dresser needs a reviewed actor-clear, player-contacting body")
    if not review.get("assembled_navigation", {}).get("passed"):
        raise SystemExit("M01 dresser navigation review must pass before promotion")

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
        expected_placements=7,
        approval_scope=(
            "M01 CRT-dresser family only: seven reviewed replacement positions, collision volumes, actor clearance, "
            "navigation connectivity and CRT screen overlay."
        ),
        pending=["Full guest-room visual assembly and lighting refinement remain separate work."],
    )
    (DESTINATION / "runtime_contract.json").write_text(json.dumps(contract, indent=2) + "\n", encoding="utf-8")
    print("M01 CRT dressers promoted: four reviewed frames and seven validated placements.")


if __name__ == "__main__":
    main()
