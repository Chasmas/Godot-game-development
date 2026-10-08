"""Compare Blender's reconstructed bone frames with source glTF joint frames."""
import bpy,json,struct
from pathlib import Path
from mathutils import Matrix,Quaternion,Vector
path=Path('build/guard_receiver_index_current_v3/guard.glb')
raw=path.read_bytes();size=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+size]);nodes=doc['nodes']
parents={child:i for i,n in enumerate(nodes) for child in n.get('children',[])}
def world(i):
 n=nodes[i]
 local=(Matrix([n['matrix'][a:a+4] for a in range(0,16,4)]).transposed() if 'matrix' in n else
        Matrix.LocRotScale(Vector(n.get('translation',[0,0,0])),Quaternion((n.get('rotation',[0,0,0,1])[3],*n.get('rotation',[0,0,0,1])[:3])),Vector(n.get('scale',[1,1,1]))))
 return world(parents[i])@local if i in parents else local
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(path.resolve()))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
conversion=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)))
rows=[]
for side in ('Right','Left'):
 name=side+'Hand';index=next(i for i,n in enumerate(nodes) if n.get('name')==name)
 reconstructed=conversion@arm.matrix_world@arm.data.bones[name].matrix_local
 # Offset maps the imported glTF joint frame into Blender's authored frame.
 offset=world(index).inverted()@reconstructed
 rows.append({'bone':name,'author_frame_in_gltf_joint':[list(row) for row in offset]})
out=path.parent/'socket_frames.json';out.write_text(json.dumps({'approved':False,'rows':rows},indent=2))
print(json.dumps(rows))
