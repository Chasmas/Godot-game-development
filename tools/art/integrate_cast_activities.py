"""Integrate manually reviewed Blender candidates, retaining hashed originals."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from stage_cast_activities import animation_names

ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "build/cast_activity_candidates"

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("looks", nargs="+")
    parser.add_argument("--reviewed", action="store_true", help="Confirm actual inspection of the phase, direction and paired hold renders")
    args = parser.parse_args()
    if not args.reviewed:
        parser.error("Inspect the rendered artifacts before integration")
    audit = STAGE / "audit.json"
    rows = json.loads(audit.read_text(encoding="utf-8"))
    entries = {row["look"]: row for row in rows}
    # Validate the entire selection before changing any runtime file.
    for look in args.looks:
        row = entries[look]
        source = STAGE / (look + ".glb")
        assert row["valid"] and digest(source) == row["candidate_sha256"], look + ": stale or invalid candidate"
        runtime = ROOT / "assets/art/cast3d_rt" / look / (look + ".glb")
        assert animation_names(runtime) <= animation_names(source), look + ": candidate would remove current runtime clips"
        for suffix in ["_idle_review.png", "_idle_review_directions.png", "_execution_pose_review.png"]:
            assert (ROOT / "build" / (look + suffix)).is_file(), look + ": missing review artifact"
        result = (STAGE / (look + "_activity.log")).read_text(encoding="utf-8-sig")
        assert "IDLE ACTIVITY REGRESSION: 0 failures" in result and "SCRIPT ERROR" not in result, look + ": activity regression did not pass"
    for look in args.looks:
        runtime = ROOT / "assets/art/cast3d_rt" / look / (look + ".glb")
        backup = STAGE / (look + "_before_" + digest(runtime)[:12] + ".glb")
        if not backup.exists():
            shutil.copy2(runtime, backup)
        pending = runtime.with_suffix(".glb.tmp")
        shutil.copy2(STAGE / (look + ".glb"), pending)
        pending.replace(runtime)
        entries[look].update(reviewed=True, integrated=True, runtime_sha256=digest(runtime), backup=str(backup),
                             review_artifacts=["build/" + look + suffix for suffix in ["_idle_review.png", "_idle_review_directions.png", "_execution_pose_review.png"]])
        print(look, "integrated", flush=True)
    temporary = audit.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(rows, indent=2), encoding="utf-8")
    temporary.replace(audit)

if __name__ == "__main__":
    main()
