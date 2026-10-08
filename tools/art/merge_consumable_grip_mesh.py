"""Preserve candidate rig/animation bytes, replace only its skinned hand-morph mesh."""
import copy,json,struct,hashlib,os
from pathlib import Path
import numpy as np
def read(path):
 raw=Path(path).read_bytes();size=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+size]);offset=20+size;length=struct.unpack_from('<I',raw,offset)[0]
 return doc,raw[offset+8:offset+8+length]
base,bb=read(os.environ.get('CONSUMABLE_MESH_BASE','build/consumable_clearance_isolated/guard.glb'))
source,sb=read(os.environ.get('CONSUMABLE_MESH_SOURCE','build/consumable_grip_morph/guard_grip.glb'))
result=copy.deepcopy(base);blob=bytearray(bb);cache={};views={}
def copy_view(index):
 if index in views:return views[index]
 view=source['bufferViews'][index];start=view.get('byteOffset',0)
 while len(blob)%4:blob.append(0)
 offset=len(blob);blob.extend(sb[start:start+view['byteLength']])
 new_view=copy.deepcopy(view);new_view['buffer']=0;new_view['byteOffset']=offset
 views[index]=len(result['bufferViews']);result['bufferViews'].append(new_view)
 return views[index]
def accessor(index):
 if index in cache:return cache[index]
 value=copy.deepcopy(source['accessors'][index])
 if 'bufferView' in value:value['bufferView']=copy_view(value['bufferView'])
 if 'sparse' in value:
  for key in ['indices','values']:
   value['sparse'][key]['bufferView']=copy_view(value['sparse'][key]['bufferView'])
 cache[index]=len(result['accessors']);result['accessors'].append(value);return cache[index]
sn=next(n for n in source['nodes'] if 'skin' in n and 'mesh' in n)
bn=next(n for n in result['nodes'] if 'skin' in n and 'mesh' in n)
sj=source['skins'][sn['skin']]['joints'];bj=base['skins'][bn['skin']]['joints']
names=[base['nodes'][i]['name'] for i in bj]
mapping=[names.index(source['nodes'][i]['name']) for i in sj]
# The morph export keeps this skeleton's joint order; reject a changed order
# rather than silently apply skin weights to the wrong bones.
assert mapping==list(range(len(mapping))),mapping
mesh=copy.deepcopy(source['meshes'][sn['mesh']])
new_materials=[]
def material_index(index):
 name=source['materials'][index]['name']
 existing=next((i for i,m in enumerate(result['materials']) if m.get('name')==name),None)
 if existing is not None:return existing
 assert os.environ.get('CONSUMABLE_ALLOW_NEW_MATERIAL')=='1',name
 value=copy.deepcopy(source['materials'][index])
 # Dedicated hand material has one albedo image. Reject extra maps until
 # their dependency remapping is explicitly supported.
 pbr=value.get('pbrMetallicRoughness',{})
 assert not any(k in value for k in ('normalTexture','occlusionTexture','emissiveTexture','extensions'))
 assert 'metallicRoughnessTexture' not in pbr
 if 'baseColorTexture' in pbr:
  texture=copy.deepcopy(source['textures'][pbr['baseColorTexture']['index']])
  assert not texture.get('extensions')
  picture=copy.deepcopy(source['images'][texture['source']])
  assert 'bufferView' in picture and 'uri' not in picture
  picture['bufferView']=copy_view(picture['bufferView'])
  images=result.setdefault('images',[]);texture['source']=len(images);images.append(picture)
  if 'sampler' in texture:
   samplers=result.setdefault('samplers',[])
   sample=copy.deepcopy(source['samplers'][texture['sampler']])
   texture['sampler']=len(samplers);samplers.append(sample)
  textures=result.setdefault('textures',[])
  pbr['baseColorTexture']['index']=len(textures);textures.append(texture)
 new_materials.append(name)
 result['materials'].append(value)
 return len(result['materials'])-1
for primitive in mesh['primitives']:
 primitive['attributes']={key:accessor(value) for key,value in primitive['attributes'].items()}
 if 'indices' in primitive:primitive['indices']=accessor(primitive['indices'])
 for target in primitive.get('targets',[]):
  for key,value in list(target.items()):target[key]=accessor(value)
 if 'material' in primitive:
  primitive['material']=material_index(primitive['material'])
old_mesh=bn['mesh'];result['meshes'][old_mesh]=mesh
bn['weights']=mesh.get('weights',[0]*len(mesh['primitives'][0].get('targets',[])))
result['buffers'][0]['byteLength']=len(blob)
js=json.dumps(result,separators=(',',':')).encode();js+=b' '*((-len(js))%4);blob+=b'\0'*((-len(blob))%4)
raw=struct.pack('<III',0x46546c67,2,12+8+len(js)+8+len(blob))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(blob),0x004e4942)+blob
out=Path(os.environ.get('CONSUMABLE_MESH_OUTPUT','build/consumable_combined'));out.mkdir(exist_ok=True);(out/'guard.glb').write_bytes(raw)
assert result['animations']==base['animations'] and result['skins']==base['skins']
assert result['materials'][:len(base['materials'])]==base['materials']
assert bytes(blob[:len(bb)])==bb
(out/'report.json').write_text(json.dumps({'approved':False,'preserved_animations':[a['name'] for a in base['animations']],
 'original_binary_prefix_preserved':True,'skin_joint_order_preserved':True,'original_materials_preserved':True,'appended_materials':new_materials,
 'mesh_morph_names':mesh.get('extras',{}),'sha256':hashlib.sha256(raw).hexdigest()},indent=2))
print('Combined mesh, preserved',len(base['animations']),'animations and original skin/materials')
