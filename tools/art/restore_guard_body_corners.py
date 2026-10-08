"""Build-only restore original untouched GLB triangle corners and winding."""
import json,struct,copy,hashlib,os
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree
def read(path):
 raw=Path(path).read_bytes();n=struct.unpack_from('<I',raw,12)[0];at=20+n
 return json.loads(raw[20:at]),raw[at+8:at+8+struct.unpack_from('<I',raw,at)[0]]
def values(doc,blob,index):
 a=doc['accessors'][index];width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
 types={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'};dtype=types[a['componentType']];size=np.dtype(dtype).itemsize
 result=np.zeros((a['count'],width),dtype=dtype)
 if 'bufferView' in a:
  v=doc['bufferViews'][a['bufferView']];start=v.get('byteOffset',0)+a.get('byteOffset',0)
  result=np.array([np.frombuffer(blob,dtype=dtype,count=width,offset=start+i*v.get('byteStride',width*size)) for i in range(a['count'])])
 if 'sparse' in a:
  sparse=a['sparse'];indices=sparse['indices'];sv=doc['bufferViews'][indices['bufferView']]
  ids=np.frombuffer(blob,dtype=types[indices['componentType']],count=sparse['count'],offset=sv.get('byteOffset',0)+indices.get('byteOffset',0))
  vals=sparse['values'];sv=doc['bufferViews'][vals['bufferView']]
  result[ids]=np.frombuffer(blob,dtype=dtype,count=sparse['count']*width,offset=sv.get('byteOffset',0)+vals.get('byteOffset',0)).reshape(-1,width)
 return result
base,bb=read('assets/art/cast3d_rt/guard/guard.glb')
doc,original=read(os.environ.get('GUARD_CORNER_SOURCE','build/guard_runtime_locomotion_v17/guard.glb'));blob=bytearray(original)
bp=base['meshes'][0]['primitives'][0];cp=doc['meshes'][0]['primitives'][0]
ba={k:values(base,bb,v) for k,v in bp['attributes'].items()};ca={k:values(doc,original,v) for k,v in cp['attributes'].items()}
bi=values(base,bb,bp['indices']).ravel().reshape(-1,3);ci=values(doc,original,cp['indices']).ravel().reshape(-1,3)
points=np.column_stack((ba['POSITION'],ba['TEXCOORD_0']));tree=cKDTree(points)
canonical={};groups={}
for i,p in enumerate(points):
 key=tuple(p);groups.setdefault(key,i);canonical[i]=groups[key]
faces={}
for tri in bi:
 ids=tuple(canonical[int(i)] for i in tri)
 faces[tuple(sorted(ids))]=tuple(int(i) for i in tri)
review_points=np.column_stack((ca['POSITION'],ca['TEXCOORD_0']));dist,nearest=tree.query(review_points)
mapped=[canonical[int(i)] for i in nearest]
arm_joints={i for i,j in enumerate(doc['skins'][0]['joints']) if doc['nodes'][j]['name'] in ('LeftHand','RightHand','LeftForeArm','RightForeArm')}
untouched=[sum(float(w) for j,w in zip(js,ws) if int(j) in arm_joints)<=.001 for js,ws in zip(ca['JOINTS_0'],ca['WEIGHTS_0'])]
arrays={k:list(v) for k,v in ca.items()};target_arrays=[{k:list(values(doc,original,a)) for k,a in target.items()} for target in cp.get('targets',[])]
cache={};restored=0;unmatched=0;result_indices=[]
def restore_corner(candidate_index,source_index):
 key=(candidate_index,source_index)
 if key not in cache:
  cache[key]=len(arrays['POSITION'])
  for name in arrays:arrays[name].append(ba[name][source_index] if name in ba else ca[name][candidate_index])
  for target in target_arrays:
   for name in target:target[name].append(target[name][candidate_index].copy())
 return cache[key]
for tri in ci:
 if not all(untouched[int(i)] for i in tri):
  for i in tri:
   i=int(i)
   if not untouched[i]:result_indices.append(i);continue
   matches=tree.query_ball_point(review_points[i],2.3e-5)
   matches=[j for j in matches if np.max(np.abs(points[j]-review_points[i]))<=1e-5]
   assert matches,'Untouched boundary vertex missing from original'
   closest=min(matches,key=lambda j:np.linalg.norm(ba['NORMAL'][j]-ca['NORMAL'][i]))
   result_indices.append(restore_corner(i,closest))
  continue
 reference=faces.get(tuple(sorted(mapped[int(i)] for i in tri)))
 if reference is None or any(dist[int(i)]>1e-5 for i in tri):
  unmatched+=1;result_indices.extend(int(i) for i in tri);continue
 by_id={mapped[int(i)]:int(i) for i in tri}
 # Restore original triangle winding as well as each corner's attributes.
 for source_index in reference:
  candidate_index=by_id[canonical[source_index]]
  result_indices.append(restore_corner(candidate_index,source_index))
 restored+=1
assert unmatched==0,unmatched
used=sorted(set(result_indices));remap={old:new for new,old in enumerate(used)}
def append(array,template):
 while len(blob)%4:blob.append(0)
 payload=array.tobytes();offset=len(blob);blob.extend(payload)
 view=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(payload)})
 a=copy.deepcopy(template);a.update(bufferView=view,byteOffset=0,count=len(array));a.pop('min',None);a.pop('max',None);a.pop('sparse',None)
 index=len(doc['accessors']);doc['accessors'].append(a);return index
for name,index in list(cp['attributes'].items()):cp['attributes'][name]=append(np.array(arrays[name],dtype=ca[name].dtype)[used],doc['accessors'][index])
for target,arrays_target in zip(cp.get('targets',[]),target_arrays):
 for name,index in list(target.items()):target[name]=append(np.array(arrays_target[name],dtype='<f4')[used],doc['accessors'][index])
index_array=np.array([[remap[i]] for i in result_indices],dtype='<u4')
template=copy.deepcopy(doc['accessors'][cp['indices']]);template['componentType']=5125
cp['indices']=append(index_array,template)
doc['buffers'][0]['byteLength']=len(blob)
js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4);blob+=b'\0'*((-len(blob))%4)
raw=struct.pack('<III',0x46546c67,2,28+len(js)+len(blob))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(blob),0x004e4942)+blob
out=Path(os.environ.get('GUARD_CORNER_OUTPUT','build/guard_restored_locomotion_v18'));out.mkdir(parents=True,exist_ok=True);(out/'guard.glb').write_bytes(raw)
(out/'corner_restore_report.json').write_text(json.dumps({'approved':False,'restored_triangles':restored,'unmatched_triangles':unmatched,'old_vertex_count':len(ca['POSITION']),'new_vertex_count':len(used),'sha256':hashlib.sha256(raw).hexdigest(),'scope':'Restore body outside hands/forearms only; candidate hand geometry untouched. GPU visual and preservation audit pending.'},indent=2))
print('Restored',restored,'triangles; vertices',len(ca['POSITION']),'->',len(used))
