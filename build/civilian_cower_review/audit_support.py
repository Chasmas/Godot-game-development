import math,json
from pathlib import Path
rows={s:[] for s in ['LeftFoot','RightFoot']}
for line in Path('build/civilian_cower_candidate.log').read_text().splitlines():
 p=line.split()
 if len(p)==6 and p[0]=='COWER_SUPPORT' and p[2] in rows: rows[p[2]].append(tuple(map(float,p[3:])))
report={}
for name,points in rows.items():
 report[name]={'samples':len(points),'max_horizontal_drift_m':max(math.hypot(p[0]-points[0][0],p[1]-points[0][1]) for p in points),'ankle_height_range_m':[min(p[2] for p in points),max(p[2] for p in points)]}
Path('build/civilian_cower_review/foot_support_audit.json').write_text(json.dumps(report,indent=2))
print(report)