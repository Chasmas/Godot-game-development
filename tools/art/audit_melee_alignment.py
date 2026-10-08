"""Compare fixed-pose Blender paths against runtime motion, with and without tip anchoring."""
import json, math, argparse
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument("--source",default="actual_weapon_paths_16.json")
args=parser.parse_args()
root=Path(__file__).resolve().parents[2]/"build/melee_trail_review"
base=json.loads((root/args.source).read_text())
moving=json.loads((root/"moving_weapon_paths.json").read_text())
results=[]
for sample in moving["samples"]:
 candidates=[r for r in base["samples"] if r["weapon"]==sample["weapon"]]
 baked=min(candidates,key=lambda r:abs(math.atan2(math.sin(r["angle"]-sample["angle"]),math.cos(r["angle"]-sample["angle"]))))
 def tip(phase):
  return min(baked["points"],key=lambda p:abs(p["phase"]-phase))["tip"]
 fixed_error=shape_error=0.0
 for i,point in enumerate(sample["points"]):
  if not .22<=point["phase"]<=.78:continue
  expected=tip(point["phase"])
  fixed_error=max(fixed_error,math.dist(point["tip"],expected))
  offset=[point["tip"][axis]-expected[axis] for axis in range(2)]
  for history in sample["points"][max(0,i-8):i+1]:
   past=tip(history["phase"])
   shape_error=max(shape_error,math.dist(history["tip"],[past[axis]+offset[axis] for axis in range(2)]))
 results.append({"weapon":sample["weapon"],"heading_deg":round(math.degrees(sample["angle"]),1),"fixed_origin_error_px":fixed_error,"tip_anchored_shape_error_px":shape_error})
report={"base_source":args.source,"moving_source":"moving_weapon_paths.json","scope":"lateral stride warmup, attack preparation/contact/recovery window .22-.78; eight-point recent trail history; does not prove level lighting or all actions", "results":results}
(root/"alignment_16_audit.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
for weapon in ["bat","knife"]:
 rows=[r for r in results if r["weapon"]==weapon]
 print(weapon,"fixed",round(max(r["fixed_origin_error_px"] for r in rows),3),"tip anchored",round(max(r["tip_anchored_shape_error_px"] for r in rows),3),"px")
