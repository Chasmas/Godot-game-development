"""Upload each existing rig once for per-character Uthana motion studies.

The source models remain untouched. Each response is persisted immediately so an
interrupted run cannot silently make a duplicate character on a later run.
"""
import argparse
import dataclasses
import json
from pathlib import Path

from uthana_client import client

ROOT = Path("build/uthana/cast_roster")
RUNTIME = Path("assets/art/cast3d_rt")
DOBERMAN = Path("assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/native_clips_candidate_v8/dog_doberman_native_clips.glb")

parser = argparse.ArgumentParser()
parser.add_argument("--priority", action="store_true", help="M01 humans plus Doberman")
parser.add_argument("--all", action="store_true", help="Every rigged runtime human plus Doberman")
args = parser.parse_args()
if not args.priority and not args.all:
    parser.error("Choose --priority or --all explicitly")

priority = ["boss", "guard", "gunner", "security", "sniper", "civilian", "cass", "dog_doberman"]
roster = priority if args.priority else [path.name for path in sorted(RUNTIME.iterdir()) if path.is_dir()] + ["dog_doberman"]
ROOT.mkdir(parents=True, exist_ok=True)
api = client()

for cast_id in roster:
    if cast_id == "cass":
        print("cass: existing upload is authoritative; skipped", flush=True)
        continue
    source = DOBERMAN if cast_id == "dog_doberman" else RUNTIME / cast_id / (cast_id + ".glb")
    manifest = ROOT / (cast_id + ".json")
    if not source.is_file():
        manifest.write_text(json.dumps({"state": "blocked_missing_rig", "source": str(source)}, indent=2), encoding="utf-8")
        print(cast_id + ": missing rig", flush=True)
        continue
    if manifest.exists():
        previous = json.loads(manifest.read_text(encoding="utf-8"))
        if previous.get("result", {}).get("character_id"):
            print(cast_id + ": existing upload preserved", flush=True)
            continue
        print(cast_id + ": unresolved prior submission; skipped", flush=True)
        continue
    manifest.write_text(json.dumps({"state": "submitted", "source": str(source), "auto_rig": False}, indent=2), encoding="utf-8")
    try:
        result = api.characters.create_from_file_sync(str(source), auto_rig=False, name="Hotshot " + cast_id + " original rig")
        data = dataclasses.asdict(result) if dataclasses.is_dataclass(result) else vars(result)
        manifest.write_text(json.dumps({"state": "response_received", "source": str(source), "result": data}, indent=2, default=str), encoding="utf-8")
        print(cast_id + ": uploaded", flush=True)
    except Exception as error:
        manifest.write_text(json.dumps({"state": "request_error", "source": str(source), "error_type": type(error).__name__}, indent=2), encoding="utf-8")
        print(cast_id + ": " + type(error).__name__, flush=True)
