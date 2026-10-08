"""Bounded static-table fit audit against actual moving heavy-knife poses."""
import json, math, numpy as np
from pathlib import Path
root=Path("build/melee_trail_review")
base=json.loads((root/"heavy_weapon_paths_16.json").read_text())
rows=base["samples"][16:]; results=[]
for filename in ["heavy_moving_paths_16.json","heavy_moving_midpoint_paths_16.json"]:
 data=json.loads((root/filename).read_text()); assert data["heavy"] and data["runtime_sha256"]==base["runtime_sha256"]
 for actual in data["samples"][16:]:
  facing=actual["angle"]%math.tau*16/math.tau; index=math.floor(facing)%16; f=facing-math.floor(facing)
  a=rows[index]["points"]; b=rows[(index+1)%16]["points"]; errors=[]; fallbacks=0
  for i,point in enumerate(actual["points"]):
   if not .30<=point["phase"]<=.78: continue
   pose=min(range(65),key=lambda k:abs(a[k]["phase"]-point["phase"]))
   head=np.array(a[pose]["tip"]); predicted=head*(1-f)+np.array(b[pose]["tip"])*f
   ids=range(max(0,pose-8),pose+1)
   X=np.array([np.array(a[k]["tip"])-head for k in ids]);Y=np.array([np.array(a[k]["tip"])*(1-f)+np.array(b[k]["tip"])*f-predicted for k in ids])
   matrix=np.linalg.lstsq(X,Y,rcond=None)[0]; scales=np.linalg.svd(matrix,compute_uv=False)
   gram=X.T@X
   if np.linalg.det(gram)<=max(1e-6,gram[0,0]*gram[1,1]*1e-6) or np.linalg.det(matrix)<=0 or min(scales)<.45 or max(scales)>1.8:
    matrix=np.eye(2);fallbacks+=1
   for old in actual["points"][max(0,i-8):i+1]:
    k=min(range(65),key=lambda k:abs(a[k]["phase"]-old["phase"]))
    estimate=(np.array(a[k]["tip"])-head)@matrix+point["tip"]
    errors.append(float(np.linalg.norm(estimate-old["tip"])))
  results.append({"source":filename,"angle":actual["angle"],"max_error_px":max(errors),"fallbacks":fallbacks})
report={"approved":False,"runtime_sha256":base["runtime_sha256"],"scope":"Lateral stride warmup, matching/midpoint headings, .30-.78, eight-pose curve; not arbitrary-action proof","results":results}
(root/"knife_heavy_fit_audit.json").write_text(json.dumps(report,indent=2))
print("Heavy fitted curve max px",max(r["max_error_px"] for r in results),"fallbacks",sum(r["fallbacks"] for r in results))
