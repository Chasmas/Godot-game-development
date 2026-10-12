"""One persisted guard re-rig pilot; outputs never replace production sources."""
import base64, json, sys
from pathlib import Path
import meshy3d
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/meshy_guard_rerig_pilot'
OUT.mkdir(parents=True,exist_ok=True)
STATE=OUT/'state.json'
s=json.loads(STATE.read_text()) if STATE.exists() else {}
def save(): STATE.write_text(json.dumps(s,indent=2))
if sys.argv[1]=='create':
 if not s.get('task_id'):
  if s.get('submission_started'): raise RuntimeError('Unknown submission outcome: reconcile before retry')
  old=json.loads((ROOT/'assets/art/Artwork/3d/guard/tasks.json').read_text())
  s.update(submission_started=True,source_task=old['refine'],runtime_approved=False)
  save()
  source=ROOT/'assets/art/Artwork/3d/guard/model.glb'
  s['source_file']=str(source.relative_to(ROOT)); save()
  uri='data:model/gltf-binary;base64,'+base64.b64encode(source.read_bytes()).decode('ascii')
  r=meshy3d.call('POST','/v1/rigging',{'model_url':uri,'height_meters':1.8})
  s['task_id']=r['result']; save()
 print(json.dumps({'task_id':s['task_id'],'runtime_approved':False}))
else:
 t=meshy3d.call('GET','/v1/rigging/'+s['task_id'])
 s['last_response']=t; save()
 print(json.dumps({k:t.get(k) for k in ('id','status','progress','task_error','consumed_credits')}))
 if sys.argv[1]=='download' and t['status']=='SUCCEEDED':
  for k,v in t.get('result',{}).items():
   if isinstance(v,str) and k.endswith('_url'):
    ext='.fbx' if 'fbx' in k else '.glb'
    meshy3d.fetch(v,str(OUT/(k+ext)))
