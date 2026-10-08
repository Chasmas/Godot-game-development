"""Audit texture deformation at headings between the 16 Blender renders.
Offline evidence only: not a runtime approval or an arbitrary-action proof.
"""
import json, math, numpy as np
from pathlib import Path
root=Path(__file__).resolve().parents[2]/"build/melee_trail_review"
base=json.loads((root/"actual_weapon_paths_16.json").read_text())
moving=json.loads((root/"moving_weapon_paths_32_midpoints.json").read_text())
results=[]
for sample in moving["samples"]:
 rows=[r for r in base["samples"] if r["weapon"]==sample["weapon"]]
 baked=min(rows,key=lambda r:abs(math.atan2(math.sin(r["angle"]-sample["angle"]),math.cos(r["angle"]-sample["angle"]))))
 errors=[];fit_errors=[];scales=[];poses=[]
 for i,point in enumerate(sample["points"]):
  if not .3<=point["phase"]<=.78:continue
  head=min(baked["points"],key=lambda p:abs(p["phase"]-point["phase"]))
  offset=np.array(point["tip"])-head["tip"];X=[];Y=[]
  for history in sample["points"][max(0,i-8):i+1]:
   past=min(baked["points"],key=lambda p:abs(p["phase"]-history["phase"]))
   X.append(np.array(past["tip"])-head["tip"])
   Y.append(np.array(history["tip"])-point["tip"])
   errors.append(math.dist(history["tip"],np.array(past["tip"])+offset))
  X=np.array(X);Y=np.array(Y)
  matrix=np.linalg.lstsq(X,Y,rcond=None)[0]
  fit_errors.extend(np.linalg.norm(X@matrix-Y,axis=1).tolist())
  scale=np.linalg.svd(matrix,compute_uv=False);scales.extend(scale.tolist())
  poses.append({"phase":point["phase"],"row_vector_matrix":matrix.tolist(),"singular_values":scale.tolist()})
 results.append({"weapon":sample["weapon"],"heading_deg":math.degrees(sample["angle"]),"translation_error_px":max(errors),"affine_error_px":max(fit_errors),"scale_min":min(scales),"scale_max":max(scales),"poses":poses})
report={"approved":False,"source":"actual_weapon_paths_16.json","moving_source":"moving_weapon_paths_32_midpoints.json","scope":"lateral stride warmup; phases .30-.78; eight recent samples; excludes anticipation and final recovery", "decision":"Prototype bounded affine fit for bat; reject affine for knife due to ill-conditioned path. Keep translation-only knife.","results":results}
(root/"midpoint_affine_audit.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
for weapon in ["bat","knife"]:
 rows=[r for r in results if r["weapon"]==weapon]
 print(weapon,"translation",round(max(r["translation_error_px"] for r in rows),3),"affine",round(max(r["affine_error_px"] for r in rows),3),"scale",round(min(r["scale_min"] for r in rows),3),round(max(r["scale_max"] for r in rows),3))
