"""Summarize measured Godot joint trajectories without implying visual approval."""
import argparse,json,math
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument("source",type=Path)
parser.add_argument("output",type=Path)
args=parser.parse_args()
data=json.loads(args.source.read_text())
rows=data["rows"]
assert len(rows)>=65, "Dense samples required"
bones=rows[0]["bones"]
assert all(set(r["bones"])==set(bones) for r in rows)
contact=[r for r in rows if .25<=r["phase"]<=.45]
report={"approved":False,"source":data["source"],"clip":data["clip"],"samples":len(rows),"scope":"Joint trajectories only; actual rendered review required","max_step_m":{bone:max(math.dist(a["bones"][bone],b["bones"][bone]) for a,b in zip(rows,rows[1:])) for bone in bones},"loop_gap_m":{bone:math.dist(rows[0]["bones"][bone],rows[-1]["bones"][bone]) for bone in bones},"foot_drift_m":{bone:max(math.dist(rows[0]["bones"][bone],r["bones"][bone]) for r in rows) for bone in ["LeftFoot","RightFoot"]}}
if data["clip"]=="smoke":
 report["contact_elbow_minus_shoulder_m"]=max(r["bones"]["RightForeArm"][1]-r["bones"]["RightArm"][1] for r in contact)
 report["contact_hand_minus_head_m"]=[min(r["bones"]["RightHand"][1]-r["bones"]["Head"][1] for r in contact),max(r["bones"]["RightHand"][1]-r["bones"]["Head"][1] for r in contact)]
args.output.write_text(json.dumps(report,indent=2)+"\n")
print(json.dumps({k:report[k] for k in ["source","samples","foot_drift_m"]}))
