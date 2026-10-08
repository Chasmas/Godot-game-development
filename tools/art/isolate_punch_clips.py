"""Preserve the runtime rig and copy Blender punch clips only after pose-space verification."""
import copy,json,struct,hashlib,argparse
from pathlib import Path
import numpy as np
parser=argparse.ArgumentParser()
parser.add_argument("--base",default="assets/art/cast3d_rt/cass/cass.glb")
parser.add_argument("--source",default="build/cass_punch_dense/cass.glb")
parser.add_argument("--output",default="build/cass_punch_isolated")
parser.add_argument("--clips",default="punch,punch_left")
parser.add_argument("--allow-add",action="store_true",help="Allow explicitly requested new clips while preserving every existing clip")
parser.add_argument("--filename",default="cass.glb")
parser.add_argument("--preserve-lower-body",action="store_true",help="Keep base hips and leg channels in each replaced clip")
parser.add_argument("--breathing-from-idle",action="store_true",help="Use native idle spine rotations while retaining candidate arms")
options=parser.parse_args()
BASE=Path(options.base);SOURCE=Path(options.source);OUT=Path(options.output);OUT.mkdir(exist_ok=True)
CLIPS=options.clips.split(",");assert CLIPS and len(set(CLIPS))==len(CLIPS)
assert Path(options.filename).name==options.filename and options.filename.endswith(".glb")
assert (OUT/options.filename).resolve()!=BASE.resolve()
added=[];replaced=[]

def read(path):
 raw=path.read_bytes();n=struct.unpack_from("<I",raw,12)[0];doc=json.loads(raw[20:20+n]);off=20+n;size=struct.unpack_from("<I",raw,off)[0];return doc,raw[off+8:off+8+size]
def accessor(doc,blob,index):
 a=doc["accessors"][index];assert a["componentType"]==5126 and "sparse" not in a
 v=doc["bufferViews"][a["bufferView"]];count={"SCALAR":1,"VEC3":3,"VEC4":4,"MAT4":16}[a["type"]];start=v.get("byteOffset",0)+a.get("byteOffset",0);stride=v.get("byteStride",count*4)
 return np.array([np.frombuffer(blob,dtype="<f4",count=count,offset=start+i*stride) for i in range(a["count"])],dtype=float)
def matrix(node):
 if "matrix" in node:return np.array(node["matrix"]).reshape(4,4).T
 x,y,z,w=node.get("rotation",[0,0,0,1]);m=np.eye(4);m[:3,:3]=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]];m[:3,:3]=m[:3,:3]@np.diag(node.get("scale",[1,1,1]));m[:3,3]=node.get("translation",[0,0,0]);return m
def world(doc,overrides):
 nodes=[dict(n,**overrides.get(i,{})) for i,n in enumerate(doc["nodes"])];parents={child:i for i,n in enumerate(nodes) for child in n.get("children",[])};cache={}
 def get(i):
  if i not in cache:cache[i]=(get(parents[i]) if i in parents else np.eye(4))@matrix(nodes[i])
  return cache[i]
 return [get(i) for i in range(len(nodes))]
def pose(doc,blob,anim,t,node_map=None):
 result={}
 for c in anim["channels"]:
  sampler=anim["samplers"][c["sampler"]];assert sampler.get("interpolation","LINEAR") in ["LINEAR","STEP"]
  times=accessor(doc,blob,sampler["input"]).ravel();values=accessor(doc,blob,sampler["output"]);i=max(0,min(int(np.searchsorted(times,t,side="right"))-1,len(times)-1));j=min(i+1,len(times)-1);k=0 if i==j else np.clip((t-times[i])/(times[j]-times[i]),0,1);a=values[i];b=values[j];kind=c["target"]["path"]
  if sampler.get("interpolation")=="STEP":k=0
  if kind=="rotation":
   dot=np.dot(a,b)
   if dot<0:b=-b;dot=-dot
   if dot<.9995:
    theta=np.arccos(np.clip(dot,-1,1));value=(np.sin((1-k)*theta)*a+np.sin(k*theta)*b)/np.sin(theta)
   else:value=a*(1-k)+b*k
   value=value/np.linalg.norm(value)
  else:value=a*(1-k)+b*k
  node=c["target"]["node"];node=node_map[node] if node_map else node;result.setdefault(node,{})[kind]=value.tolist()
 return result
base,base_blob=read(BASE);source,source_blob=read(SOURCE)
base_names={n["name"]:i for i,n in enumerate(base["nodes"])};source_names={n["name"]:i for i,n in enumerate(source["nodes"])};assert len(base_names)==len(base["nodes"]) and set(base_names)==set(source_names)
mapping={i:base_names[n["name"]] for i,n in enumerate(source["nodes"])}
for i,n in enumerate(source["nodes"]):assert sorted(mapping[j] for j in n.get("children",[]))==sorted(base["nodes"][mapping[i]].get("children",[]))
bs=base["skins"][0];ss=source["skins"][0];assert [mapping[i] for i in ss["joints"]]==bs["joints"]
bi=accessor(base,base_blob,bs["inverseBindMatrices"]).reshape(-1,4,4).transpose(0,2,1);si=accessor(source,source_blob,ss["inverseBindMatrices"]).reshape(-1,4,4).transpose(0,2,1)
errors=[]
for clip in CLIPS:
 anim=next(a for a in source["animations"] if a["name"]==clip);length=max(accessor(source,source_blob,s["input"])[-1,0] for s in anim["samplers"])
 world_error=skin_error=0
 for t in np.linspace(0,length,65):
  intended=world(source,pose(source,source_blob,anim,t));mapped=world(base,pose(source,source_blob,anim,t,mapping))
  for k,joint in enumerate(ss["joints"]):
   world_error=max(world_error,float(np.linalg.norm(intended[joint][:3,3]-mapped[mapping[joint]][:3,3])))
   skin_error=max(skin_error,float(np.max(np.abs(intended[joint]@si[k]-mapped[mapping[joint]]@bi[k]))))
 assert world_error<.001 and skin_error<.002,(clip,world_error,skin_error)
 errors.append({"clip":clip,"posed_joint_world_error":world_error,"skin_matrix_error":skin_error})
result=copy.deepcopy(base);blob=bytearray(base_blob);accessors={};views={}
def copy_accessor(index):
 if index in accessors:return accessors[index]
 ac=copy.deepcopy(source["accessors"][index]);view_index=ac["bufferView"]
 if view_index not in views:
  view=copy.deepcopy(source["bufferViews"][view_index]);assert view.get("buffer",0)==0
  while len(blob)%4:blob.append(0)
  start=view.get("byteOffset",0);data=source_blob[start:start+view["byteLength"]];view["byteOffset"]=len(blob);view["buffer"]=0;blob.extend(data);views[view_index]=len(result["bufferViews"]);result["bufferViews"].append(view)
 ac["bufferView"]=views[view_index];accessors[index]=len(result["accessors"]);result["accessors"].append(ac);return accessors[index]
for clip in CLIPS:
 anim=copy.deepcopy(next(a for a in source["animations"] if a["name"]==clip))
 for s in anim["samplers"]:
  for field in ["input","output"]:s[field]=copy_accessor(s[field])
 for c in anim["channels"]:c["target"]["node"]=mapping[c["target"]["node"]]
 if options.preserve_lower_body:
  lower={i for i,n in enumerate(base['nodes']) if n.get('name')=='Hips' or n.get('name','').startswith(('LeftUpLeg','RightUpLeg','LeftLeg','RightLeg','LeftFoot','RightFoot','LeftToe','RightToe'))}
  original_anim=next(a for a in base['animations'] if a['name']==clip)
  anim['channels']=[c for c in anim['channels'] if c['target']['node'] not in lower]
  for channel in original_anim['channels']:
   if channel['target']['node'] not in lower:continue
   retained=copy.deepcopy(channel)
   retained['sampler']=len(anim['samplers'])
   anim['samplers'].append(copy.deepcopy(original_anim['samplers'][channel['sampler']]))
   anim['channels'].append(retained)
  for channel in original_anim['channels']:
   if channel['target']['node'] not in lower:continue
   retained=next(c for c in anim['channels'] if c['target']==channel['target'])
   assert anim['samplers'][retained['sampler']]==original_anim['samplers'][channel['sampler']]
 if options.breathing_from_idle:
  idle=next(a for a in base['animations'] if a['name']=='idle')
  breath=[c for c in idle['channels'] if base['nodes'][c['target']['node']].get('name','').lower().startswith('spine') and c['target']['path']=='rotation']
  assert breath
  for channel in breath:
   anim['channels']=[c for c in anim['channels'] if c['target']!=channel['target']]
   retained=copy.deepcopy(channel)
   retained['sampler']=len(anim['samplers'])
   anim['samplers'].append(copy.deepcopy(idle['samplers'][channel['sampler']]))
   anim['channels'].append(retained)
 idx=next((i for i,a in enumerate(result["animations"]) if a["name"]==clip),None)
 if idx is None:
  assert options.allow_add,("Missing base clip; explicit --allow-add required",clip)
  result["animations"].append(anim);added.append(clip)
 else:
  result["animations"][idx]=anim;replaced.append(clip)
for field in ["nodes","skins","meshes","materials","images","textures"]:assert result.get(field)==base.get(field)
assert bytes(blob[:len(base_blob)])==base_blob
unchanged=[a["name"] for a,b in zip(base["animations"],result["animations"]) if a==b];assert len(unchanged)==len(base["animations"])-len(replaced)
result["buffers"][0]["byteLength"]=len(blob);j=json.dumps(result,separators=(",",":")).encode();j+=b" "*((-len(j))%4);blob+=b"\0"*((-len(blob))%4);raw=struct.pack("<III",0x46546c67,2,28+len(j)+len(blob))+struct.pack("<II",len(j),0x4e4f534a)+j+struct.pack("<II",len(blob),0x004e4942)+blob
(OUT/options.filename).write_bytes(raw)
(OUT/"audit.json").write_text(json.dumps({"approved":False,"base_sha256":hashlib.sha256(BASE.read_bytes()).hexdigest(),"candidate_sha256":hashlib.sha256(raw).hexdigest(),"unchanged_clips":unchanged,"changed_clips":replaced,"added_clips":added,"rig_geometry_bind_preserved":True,"pose_space_checks":errors},indent=2))
print("Isolated selected clips; unchanged clips",len(unchanged),"lower body retained",options.preserve_lower_body,"pose checks",errors)
