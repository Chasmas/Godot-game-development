import re,json,math
from pathlib import Path
rows={s:[] for s in ['Right','Left']}
for line in Path('build/civilian_cower_candidate.log').read_text().splitlines():
 m=re.search(r'ELBOW cower (Right|Left) ([-.0-9]+)',line)
 if m: rows[m[1]].append(float(m[2]))
report={s:{'samples':len(v),'maximum_pole_step_degrees':max([abs((b-a+math.pi)%(2*math.pi)-math.pi)*180/math.pi for a,b in zip(v,v[1:])] or [0])} for s,v in rows.items()}
Path('build/civilian_cower_review/elbow_continuity.json').write_text(json.dumps(report,indent=2))
print(report)