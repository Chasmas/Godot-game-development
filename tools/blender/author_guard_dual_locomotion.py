"""Stage restrained dual-pistol arm sway; preserve locomotion below shoulders."""
import json,struct,copy,math,hashlib,os
from pathlib import Path
from mathutils import Quaternion,Vector,Matrix
source=Path('assets/art/cast3d_rt/guard/guard.glb')
raw=source.read_bytes();length=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+length]);at=20+length
blob=bytearray(raw[at+8:at+8+struct.unpack_from('<I',raw,at)[0]])
result=copy.deepcopy(doc)
aim=next(a for a in doc['animations'] if a['name']=='aim_dual')
parents={child:i for i,n in enumerate(doc['nodes']) for child in n.get('children',[])}
def values(index):
 a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
 count=4 if a['type']=='VEC4' else 1
 offset=v.get('byteOffset',0)+a.get('byteOffset',0)
 return [struct.unpack_from('<'+'f'*count,blob,offset+i*v.get('byteStride',count*4)) for i in range(a['count'])]
def rotation(anim,node,t):
 for c in anim['channels']:
  if c['target']=={'node':node,'path':'rotation'}:
   sampler=anim['samplers'][c['sampler']];ts=[v[0] for v in values(sampler['input'])];vs=values(sampler['output'])
   i=max(0,min(sum(s<=t for s in ts)-1,len(ts)-1));j=min(i+1,len(ts)-1)
   def q(row):return Quaternion((row[3],*row[:3]))
   alpha=0 if i==j or sampler.get('interpolation')=='STEP' else (t-ts[i])/(ts[j]-ts[i])
   return q(vs[i]).slerp(q(vs[j]),max(0,min(1,alpha)))
 n=doc['nodes'][node]
 if 'matrix' in n:return Matrix([n['matrix'][a:a+4] for a in range(0,16,4)]).transposed().to_quaternion()
 x,y,z,w=n.get('rotation',[0,0,0,1]);return Quaternion((w,x,y,z))
def global_rotation(anim,node,t):
 local=rotation(anim,node,t)
 return global_rotation(anim,parents[node],t)@local if node in parents else local
def append(data,kind):
 while len(blob)%4:blob.append(0)
 start=len(blob)
 for row in data:blob.extend(struct.pack('<'+'f'*len(row),*row))
 view=len(result['bufferViews']);result['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(blob)-start})
 index=len(result['accessors']);result['accessors'].append({'bufferView':view,'componentType':5126,'count':len(data),'type':kind})
 return index
rows=[]
selected=os.environ.get('GUARD_DUAL_AUTHOR_CLIPS','aim_dual,armed_dual_walk,armed_dual_run').split(',')
for anim in result['animations']:
 if anim['name'] not in selected:continue
 reload_only=anim['name']=='reload_dual'
 duration=max(values(s['input'])[-1][0] for s in anim['samplers'])
 original=next(a for a in doc['animations'] if a['name']==anim['name'])
 times=[(duration*i/64,) for i in range(65)]
 changed=[]
 for channel in anim['channels']:
  node=channel['target']['node'];name=doc['nodes'][node]['name']
  if channel['target']['path']!='rotation' or name not in ('LeftArm','RightArm','LeftForeArm','RightForeArm','LeftHand','RightHand'):continue
  if reload_only and not name.endswith('Hand'):continue
  reference=next(c for c in aim['channels'] if c['target']==channel['target'])
  x,y,z,w=values(aim['samplers'][reference['sampler']]['output'])[0]
  rest=Quaternion((w,x,y,z));side=1 if name.startswith('Left') else -1
  amplitude=math.radians(2.5 if name.endswith('Arm') else 1.0)
  poses=[]
  for (t,) in times:
   sway=Quaternion(Vector((0,0,1)),amplitude*math.sin(2*math.pi*t/duration)*side)
   if reload_only:
    q=rotation(original,node,t)
   elif name in ('LeftArm','RightArm'):
    # Cancel the moving shoulder parent's rotation before applying the
    # reference world-space arm direction. Keep hips/spine tracks intact.
    parent=global_rotation(original,parents[node],t)
    q=parent.inverted()@global_rotation(aim,node,0)@sway
   else:q=rest@sway
   if name.endswith('Hand'):
    x0,y0,z0,w0=doc['nodes'][node].get('rotation',[0,0,0,1])
    bind=Quaternion((w0,x0,y0,z0))
    delta=bind.inverted()@q
    axis=Vector((0,1,0))
    q=bind@axis.rotation_difference(delta@axis)
   q.normalize();poses.append((q.x,q.y,q.z,q.w))
  sampler=copy.deepcopy(anim['samplers'][channel['sampler']])
  sampler.update(input=append(times,'SCALAR'),output=append(poses,'VEC4'),interpolation='LINEAR')
  channel['sampler']=len(anim['samplers']);anim['samplers'].append(sampler);changed.append(name)
 assert len(changed)==(2 if reload_only else 6),changed
 rows.append({'clip':anim['name'],'changed_bones':changed,'samples':65,'duration':duration})
result['buffers'][0]['byteLength']=len(blob)
encoded=json.dumps(result,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);blob+=b'\0'*((-len(blob))%4)
output=struct.pack('<III',0x46546c67,2,28+len(encoded)+len(blob))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(blob),0x004e4942)+blob
out=Path(os.environ.get('GUARD_DUAL_AUTHOR_OUTPUT','build/guard_dual_locomotion_v3'));out.mkdir(exist_ok=True)
(out/'guard.glb').write_bytes(output)
(out/'report.json').write_text(json.dumps({'approved':False,'base_sha256':hashlib.sha256(raw).hexdigest(),'rows':rows,'scope':'Only six arm rotation channels changed; hips, legs, spine and other clips retained. Whole-body clearance and visual motion unverified.'},indent=2))
print(json.dumps(rows))
