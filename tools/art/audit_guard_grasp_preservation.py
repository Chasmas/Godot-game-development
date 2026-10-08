"""Read-only rig/clip and untouched body attribute comparison against runtime."""
import json,struct,hashlib,os
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree
def read(path):
 raw=Path(path).read_bytes();n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);at=20+n
 return doc,raw[at+8:at+8+struct.unpack_from('<I',raw,at)[0]],hashlib.sha256(raw).hexdigest()
def accessor(doc,blob,index):
 a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
 dtype={5126:'<f4',5123:'<u2',5121:'u1',5125:'<u4'}[a['componentType']];size=np.dtype(dtype).itemsize
 start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',count*size)
 return np.array([np.frombuffer(blob,dtype=dtype,count=count,offset=start+i*stride) for i in range(a['count'])])
base,bb,bhash=read('assets/art/cast3d_rt/guard/guard.glb')
candidate_path=Path(os.environ.get('GUARD_PRESERVATION_CANDIDATE','build/guard_receiver_locomotion_v15/guard.glb'))
candidate,cb,chash=read(candidate_path)
changed=[];unchanged=[]
for animation in base['animations']:
 other=next(a for a in candidate['animations'] if a['name']==animation['name'])
 (unchanged if other==animation else changed).append(animation['name'])
expected=set(os.environ.get('GUARD_PRESERVATION_CLIPS','aim_dual,armed_dual_walk,armed_dual_run').split(','))
assert set(changed)==expected,(changed,expected)
assert base['skins']==candidate['skins']
extra_materials=candidate['materials'][len(base['materials']):]
assert candidate['materials'][:len(base['materials'])]==base['materials']
if extra_materials:
 assert os.environ.get('GUARD_PRESERVATION_ALLOW_HAND_MATERIAL')=='1'
 assert [m.get('name') for m in extra_materials]==['GuardHandSkin_ImageGen_v1']
 for collection in ('images','textures','samplers'):
  original_records=base.get(collection,[])
  assert candidate.get(collection,[])[:len(original_records)]==original_records
assert cb[:len(bb)]==bb, 'Original binary payload changed'
assert all({k:v for k,v in a.items() if k not in ('weights','mesh')}=={k:v for k,v in b.items() if k not in ('weights','mesh')} for a,b in zip(base['nodes'],candidate['nodes']))
def untouched(doc,blob,kind='all'):
 skin=doc['skins'][0];joints=skin['joints']
 arms={i for i,j in enumerate(joints) if doc['nodes'][j]['name'] in ('RightHand','LeftHand','RightForeArm','LeftForeArm')}
 rows=[]
 for p in doc['meshes'][0]['primitives']:
  attrs={k:accessor(doc,blob,v) for k,v in p['attributes'].items()}
  for i,position in enumerate(attrs['POSITION']):
   weights=attrs['WEIGHTS_0'][i];indices=attrs['JOINTS_0'][i]
   if sum(float(w) for j,w in zip(indices,weights) if int(j) in arms)>.001:continue
   components=[*position,*attrs['TEXCOORD_0'][i]]
   if kind in ('all','normal'):components.extend(attrs['NORMAL'][i])
   if kind in ('all','skin'):
    # Slot order is not skin semantics; compare joint/weight pairs by joint.
    for joint,weight in sorted((int(j),float(w)) for j,w in zip(indices,weights) if w>1e-6):
     components.extend((joint,weight))
   rows.append(tuple(np.round(components,5)))
 return set(rows)
original=untouched(base,bb);review=untouched(candidate,cb)
missing=original-review;added=review-original
attribute_comparisons={}
for kind in ('position_uv','normal','skin'):
 a=untouched(base,bb,kind);b=untouched(candidate,cb,kind)
 attribute_comparisons[kind]={'missing':len(a-b),'added':len(b-a)}
def body_arrays(doc,blob):
 p=doc['meshes'][0]['primitives'][0];attrs={k:accessor(doc,blob,v) for k,v in p['attributes'].items()}
 joints=doc['skins'][0]['joints'];arms={i for i,j in enumerate(joints) if doc['nodes'][j]['name'] in ('RightHand','LeftHand','RightForeArm','LeftForeArm')}
 mask=np.array([sum(float(w) for j,w in zip(js,ws) if int(j) in arms)<=.001 for js,ws in zip(attrs['JOINTS_0'],attrs['WEIGHTS_0'])])
 return {k:v[mask] for k,v in attrs.items()}
ba=body_arrays(base,bb);ca=body_arrays(candidate,cb)
points=np.column_stack((ba['POSITION'],ba['TEXCOORD_0']));review_points=np.column_stack((ca['POSITION'],ca['TEXCOORD_0']))
tree=cKDTree(points);unmatched=0;normal_mismatches=0;max_normal_error=0
for i,point in enumerate(review_points):
 indices=tree.query_ball_point(point,2.3e-5)
 indices=[j for j in indices if np.max(np.abs(points[j]-point))<=1e-5]
 if not indices:unmatched+=1;continue
 error=min(float(np.linalg.norm(ba['NORMAL'][j]-ca['NORMAL'][i])) for j in indices)
 max_normal_error=max(max_normal_error,error)
 if error>1e-4:normal_mismatches+=1
tolerant={'position_uv_unmatched_candidate_vertices':unmatched,'normal_mismatches_above_1e_4':normal_mismatches,'max_nearest_normal_vector_error':max_normal_error,'position_uv_tolerance':1e-5,'scope':'Forward matching only, normal nearest among colocated source corners; does not establish reverse coverage or topology.'}
report={'approved':False,'base_sha256':bhash,'candidate_sha256':chash,'changed_clips':changed,'unchanged_clips':unchanged,'rig_and_material_records_preserved':True,'original_binary_prefix_preserved':True,'untouched_body_attributes':['POSITION','TEXCOORD_0','NORMAL','JOINTS_0','WEIGHTS_0'],'comparison_precision':1e-5,'original_unique_vertices':len(original),'candidate_unique_vertices':len(review),'missing_untouched_vertices':len(missing),'added_untouched_vertices':len(added),'scope':'Attributes outside hands and forearms; excludes tangents, topology and silhouette approval. Original clip records and binary payload preserved for 24 unchanged clips.'}
report['attribute_comparisons']=attribute_comparisons
report['appended_hand_materials']=[m.get('name') for m in extra_materials]
report['scope']=f'Attributes outside hands and forearms; excludes tangents, topology and silhouette approval. {len(unchanged)} unchanged animation records and original binary payload preserved.'
report['tolerant_comparison']=tolerant
(candidate_path.parent/'preservation_report.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
assert not missing and not added, 'Untouched body attributes differ'
assert unmatched==0 and normal_mismatches==0, 'Untouched body matching failed'
