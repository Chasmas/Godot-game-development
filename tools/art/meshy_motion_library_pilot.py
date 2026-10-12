"""Persisted Meshy library motion pilot for shared retarget studies."""
import json,sys
from pathlib import Path
import meshy3d
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'build/meshy_guard_rerig_pilot'; P=OUT/'motion_batch.json'
s=json.loads(P.read_text()) if P.exists() else {}
def save(): P.write_text(json.dumps(s,indent=2))
if sys.argv[1]=='create':
 if not s.get('task_id'):
  if s.get('submission_started'): raise RuntimeError('Reconcile unknown submission before retry')
  rig=json.loads((OUT/'state.json').read_text())['task_id']
  body={'rig_task_id':rig,'action_ids':[30,14,524,234,233],'post_process':{'operation_type':'change_fps','fps':60}}
  s.update(submission_started=True,parameters=body,runtime_approved=False);save()
  s['task_id']=meshy3d.call('POST','/v1/animations',body)['result'];save()
 print(json.dumps({'task_id':s['task_id']}))
else:
 t=meshy3d.call('GET','/v1/animations/'+s['task_id']);s['last_response']=t;save()
 print(json.dumps({k:t.get(k) for k in ('id','status','progress','consumed_credits','task_error')}))
 if sys.argv[1]=='download' and t['status']=='SUCCEEDED':
  for k in ('animation_glb_url','animation_fbx_url'):
   if t.get('result',{}).get(k):meshy3d.fetch(t['result'][k],str(OUT/('motion_batch.'+('fbx' if 'fbx' in k else 'glb'))))
