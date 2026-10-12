"""Generate staged lower-body locomotion studies for uploaded humanoid casts.

This script deliberately never writes runtime GLBs or animation libraries. Each
study must pass visual, contact and weapon-overlay review before promotion.
"""
import argparse
import dataclasses
import json
from pathlib import Path

from uthana_client import client

parser = argparse.ArgumentParser()
parser.add_argument("ids", nargs="+", help="Cast IDs with confirmed upload manifests")
args = parser.parse_args()
root = Path("build/uthana/cast_roster")
def locomotion_studies(cast_id: str):
    """Keep generated motion appropriate to the existing cast's presentation.

    This stays staging-only: it is deliberately not a runtime promotion path.
    Uthana's gendered neutral walk changes the shoulder/hip read substantially,
    so the male cast must not receive Cass's female study by accident.
    """
    walk_style = "neutral_female_a" if cast_id == "cass" else "neutral_male_a"
    return {
        "walk": (walk_style, 1.8),
        "run": ("rushed", 3.4),
        "stealth": ("crouching", 0.75),
    }
api = client()
for cast_id in args.ids:
    upload = json.loads((root / (cast_id + ".json")).read_text(encoding="utf-8"))
    character_id = upload.get("result", {}).get("character_id")
    if not character_id:
        print(cast_id + ": no confirmed Uthana character; skipped", flush=True)
        continue
    target_dir = root / "motions" / cast_id
    target_dir.mkdir(parents=True, exist_ok=True)
    for name, (style, speed) in locomotion_studies(cast_id).items():
        manifest = target_dir / (name + ".json")
        if manifest.exists():
            record = json.loads(manifest.read_text(encoding="utf-8"))
            if not record.get("motion_id"):
                print(cast_id + " " + name + ": unresolved submission; skipped", flush=True)
                continue
        else:
            record = {"state": "submitted", "character_id": character_id, "style_id": style, "speed_m_s": speed, "strides": 2}
            manifest.write_text(json.dumps(record, indent=2), encoding="utf-8")
            try:
                result = api.motions.create_locomotion_sync(character_id, strides=2, move_speed=speed, style_id=style, travel_angle=0)
                record.update(dataclasses.asdict(result) if dataclasses.is_dataclass(result) else vars(result))
                record["state"] = "generated"
            except Exception as error:
                record.update(state="request_error", error_type=type(error).__name__)
            manifest.write_text(json.dumps(record, indent=2, default=str), encoding="utf-8")
        if not record.get("motion_id"):
            print(cast_id + " " + name + ": request failed", flush=True)
            continue
        glb = target_dir / (name + ".glb")
        if not glb.exists():
            glb.write_bytes(api.motions.download_sync(character_id, record["motion_id"], output_format="glb", fps=30, in_place=True))
        print(cast_id + " " + name + ": downloaded for review", flush=True)
