"""Audit central torso/arm triangle crossings for every captured Godot frame."""
import bpy,json,os
import math
from pathlib import Path
from mathutils import Matrix,Quaternion
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_ray_tri
ROOT=Path(__file__).resolve().parents[2]
source=Path(os.environ['UTHANA_ARM_POSE_SOURCE'])
frames=json.loads((source/'poses.json').read_text())
assert len(frames)==48
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'build/uthana/cast_roster/motions/guard/hand_foreend_preserved/guard.glb'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and 'Spine02' in o.vertex_groups)
for mesh in [o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.shape_keys and 'WeaponGrip' in o.data.shape_keys.key_blocks]:
    mesh.data.shape_keys.key_blocks['WeaponGrip'].value=1
groups={g.index:g.name for g in body.vertex_groups}
def weight(vertex,names):return sum(g.weight for g in vertex.groups if groups[g.group] in names)
def crosses(a,b):
    for edges,face in ((a,b),(b,a)):
        for i in range(3):
            start,end=edges[i],edges[(i+1)%3];delta=end-start;length=delta.length
            if length<1e-8:continue
            hit=intersect_ray_tri(*face,delta/length,start,True)
            if hit is not None and 1e-5<(hit-start).dot(delta/length)<length-1e-5:return True
    return False
def tree(triangles):
    vertices=[p for tri in triangles for p in tri]
    return BVHTree.FromPolygons(vertices,[(i*3,i*3+1,i*3+2) for i in range(len(triangles))],all_triangles=True)
# The region is selected in rest world space before any frame is posed.
rest=lambda name:(arm.matrix_world@arm.data.bones[name].matrix_local).translation
hips,neck=rest('Hips'),rest('neck')
width=abs(rest('LeftArm').x-rest('RightArm').x)*.40
torso_vertices={v.index for v in body.data.vertices if abs((body.matrix_world@v.co).x-hips.x)<width and hips.z+.04<(body.matrix_world@v.co).z<neck.z-.03}
assert len(torso_vertices)>1000
arm_vertex_sets={side:{v.index for v in body.data.vertices if weight(v,{side+s for s in ['Arm','ForeArm','Hand']})>.8}-torso_vertices for side in ['Right','Left']}
conversion=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
inverse=conversion.inverted()
def depth(bone):return 0 if bone.parent is None else 1+depth(bone.parent)
bones=sorted(arm.pose.bones,key=depth)
rows=[]
for frame_index,pose in enumerate(frames):
    for bone in bones:
        values=pose[bone.name]
        assert isinstance(values,list) and len(values)==4 and all(isinstance(row,list) and len(row)==4 for row in values),(frame_index,bone.name,values)
        desired=conversion@Matrix(values)@inverse
        bone.matrix=arm.matrix_world.inverted()@desired
    bpy.context.view_layer.update()
    # Review an equal extra axial twist after the exact captured pose.
    extra_twist=float(os.environ.get('UTHANA_BATCH_EXTRA_TWIST','0'))
    if extra_twist:
        for side in ['Right','Left']:
            upper=arm.pose.bones[side+'Arm'];lower=arm.pose.bones[side+'ForeArm'];hand=arm.pose.bones[side+'Hand']
            upper_world=arm.matrix_world@upper.matrix;lower_world=arm.matrix_world@lower.matrix;hand_world=arm.matrix_world@hand.matrix
            axis=(lower_world.translation-upper_world.translation).normalized()
            twist=Quaternion(axis,math.radians(extra_twist)*(1 if side=='Right' else -1))
            turned=twist.to_matrix().to_4x4()@upper_world;turned.translation=upper_world.translation
            upper.matrix=arm.matrix_world.inverted()@turned;bpy.context.view_layer.update()
            lower.matrix=arm.matrix_world.inverted()@lower_world;hand.matrix=arm.matrix_world.inverted()@hand_world;bpy.context.view_layer.update()
    evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
    assert len(mesh.vertices)==len(body.data.vertices)
    torso=[tuple(evaluated.matrix_world@mesh.vertices[i].co for i in tri.vertices) for tri in mesh.loop_triangles if all(i in torso_vertices for i in tri.vertices)]
    torso_tree=tree(torso)
    counts={}
    for side,eligible in arm_vertex_sets.items():
        arms=[tuple(evaluated.matrix_world@mesh.vertices[i].co for i in tri.vertices) for tri in mesh.loop_triangles if all(i in eligible for i in tri.vertices)]
        arm_tree=tree(arms)
        counts[side]=sum(crosses(arms[a],torso[b]) for a,b in arm_tree.overlap(torso_tree))
    evaluated.to_mesh_clear()
    rows.append({'frame':frame_index,'triangle_crossings':counts})
result={'runtime_approved':False,'frames':len(rows),'source':str(source),'additional_axial_twist_degrees':extra_twist,'max_right_crossings':max(row['triangle_crossings']['Right'] for row in rows),'max_left_crossings':max(row['triangle_crossings']['Left'] for row in rows),'frames_with_crossings':[row for row in rows if any(row['triangle_crossings'].values())],'scope':'Exact 48 captured poses; central torso versus >80% arm-weight faces. Excludes blended boundaries/lateral torso/coplanar/containment.'}
(source/('arm_clearance_batch'+('_twist_'+str(extra_twist) if extra_twist else '')+'.json')).write_text(json.dumps(result,indent=2))
print('ARM CLEARANCE BATCH',json.dumps({k:v for k,v in result.items() if k not in ['frames_with_crossings','source']}))
