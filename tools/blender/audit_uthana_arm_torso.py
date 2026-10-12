"""Exact posed triangle crossing evidence; no claim of full anatomical clearance."""
import bpy,json,os
import math
from mathutils import Quaternion
from pathlib import Path
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_ray_tri
ROOT=Path(__file__).resolve().parents[2]
out=ROOT/'build/uthana/cast_roster/motions/guard/arm_pose_inspection'
bpy.ops.wm.open_mainfile(filepath=str(out/'posed_guard.blend'))
rest_review=os.environ.get('UTHANA_ARM_REST_REVIEW')=='1'
if rest_review:
    for arm in [o for o in bpy.context.scene.objects if o.type=='ARMATURE']:
        for bone in arm.pose.bones:bone.matrix_basis.identity()
    bpy.context.view_layer.update()
angle_text=os.environ.get('UTHANA_ELBOW_ORBIT_DEGREES','')
if angle_text:
    arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    def world(bone):return arm.matrix_world@bone.matrix
    def turn(bone,rotation):
        before=world(bone);after=rotation.to_matrix().to_4x4()@before;after.translation=before.translation
        bone.matrix=arm.matrix_world.inverted()@after;bpy.context.view_layer.update()
    for side in ['Right','Left']:
        upper=arm.pose.bones[side+'Arm'];lower=arm.pose.bones[side+'ForeArm'];hand=arm.pose.bones[side+'Hand']
        shoulder=world(upper).translation;elbow=world(lower).translation;wrist=world(hand)
        axis=(wrist.translation-shoulder).normalized()
        orbit=Quaternion(axis,math.radians(float(angle_text))*(1 if side=='Right' else -1))
        desired=shoulder+orbit@(elbow-shoulder)
        turn(upper,(elbow-shoulder).normalized().rotation_difference((desired-shoulder).normalized()))
        moved_elbow=world(lower).translation;moved_hand=world(hand).translation
        turn(lower,(moved_hand-moved_elbow).normalized().rotation_difference((wrist.translation-moved_elbow).normalized()))
        assert (world(hand).translation-wrist.translation).length<.00001
        current=world(hand);current.col[0]=wrist.col[0];current.col[1]=wrist.col[1];current.col[2]=wrist.col[2]
        hand.matrix=arm.matrix_world.inverted()@current;bpy.context.view_layer.update()
twist_text=os.environ.get('UTHANA_UPPER_ARM_TWIST_DEGREES','')
if twist_text:
    arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    for side in ['Right','Left']:
        upper=arm.pose.bones[side+'Arm'];lower=arm.pose.bones[side+'ForeArm'];hand=arm.pose.bones[side+'Hand']
        upper_world=arm.matrix_world@upper.matrix;lower_world=arm.matrix_world@lower.matrix;hand_world=arm.matrix_world@hand.matrix
        axis=(lower_world.translation-upper_world.translation).normalized()
        twist=Quaternion(axis,math.radians(float(twist_text))*(1 if side=='Right' else -1))
        turned=twist.to_matrix().to_4x4()@upper_world;turned.translation=upper_world.translation
        upper.matrix=arm.matrix_world.inverted()@turned;bpy.context.view_layer.update()
        lower.matrix=arm.matrix_world.inverted()@lower_world;bpy.context.view_layer.update()
        hand.matrix=arm.matrix_world.inverted()@hand_world;bpy.context.view_layer.update()
        assert ((arm.matrix_world@lower.matrix).translation-lower_world.translation).length<.00001
        assert ((arm.matrix_world@hand.matrix).translation-hand_world.translation).length<.00001
def crosses(a,b):
    for edges,face in [(a,b),(b,a)]:
        for i in range(3):
            start,end=edges[i],edges[(i+1)%3];delta=end-start;length=delta.length
            if length<1e-8:continue
            hit=intersect_ray_tri(*face,delta/length,start,True)
            if hit is not None and 1e-5<(hit-start).dot(delta/length)<length-1e-5:return True
    return False
def tree(triangles):
    points=[v for t in triangles for v in t]
    return BVHTree.FromPolygons(points,[(i*3,i*3+1,i*3+2) for i in range(len(triangles))],all_triangles=True)
records=[]
for body in [o for o in bpy.context.scene.objects if o.type=='MESH' and 'Spine02' in o.vertex_groups]:
    groups={g.index:g.name for g in body.vertex_groups}
    def weight(vertex,names):return sum(g.weight for g in vertex.groups if groups[g.group] in names)
    torso_names={'Hips','Spine','Spine01','Spine02','LeftShoulder','RightShoulder','neck'}
    counts={}
    for v in body.data.vertices:
        if v.groups:
            dominant=groups[max(v.groups,key=lambda g:g.weight).group]
            counts[dominant]=counts.get(dominant,0)+1
    coverage={str(t):sum(all(weight(body.data.vertices[i],torso_names)>t for i in p.vertices) for p in body.data.polygons) for t in [.2,.4,.6,.8]}
    (out/'torso_weight_coverage.json').write_text(json.dumps({'dominant_bone_vertex_counts':counts,'torso_face_coverage_by_weight_threshold':coverage,'runtime_approved':False},indent=2))
    print('TORSO COVERAGE',coverage,'DOMINANT BONES',counts)
    arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    rest=lambda name:(arm.matrix_world@arm.data.bones[name].matrix_local).translation
    hips=rest('Hips');neck=rest('neck')
    left_shoulder=rest('LeftArm');right_shoulder=rest('RightArm')
    half_width=abs(left_shoulder.x-right_shoulder.x)*.40
    lower=hips.z+.04;upper=neck.z-.03
    def central_torso(v):
        point=body.matrix_world@v.co
        return abs(point.x-hips.x)<half_width and lower<point.z<upper
    torso_vertices={v.index for v in body.data.vertices if central_torso(v)}
    evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
    assert len(mesh.vertices)==len(body.data.vertices),'Modifier changed vertex correspondence'
    torso=[tuple(evaluated.matrix_world@mesh.vertices[i].co for i in t.vertices) for t in mesh.loop_triangles if all(i in torso_vertices for i in t.vertices)]
    assert len(torso)>500,'Insufficient torso coverage: '+str(len(torso))
    torso_tree=tree(torso)
    for side in ['Right','Left']:
        arm_names={side+s for s in ['Arm','ForeArm','Hand']}
        eligible={v.index for v in body.data.vertices if weight(v,arm_names)>.8}
        central_overlap=len(eligible&torso_vertices)
        eligible-=torso_vertices
        arm_faces=[t for t in mesh.loop_triangles if all(i in eligible for i in t.vertices)]
        arms=[tuple(evaluated.matrix_world@mesh.vertices[i].co for i in t.vertices) for t in arm_faces]
        pairs=tree(arms).overlap(torso_tree)
        pierced=[(a,b) for a,b in pairs if crosses(arms[a],torso[b])]
        pierced_faces={a for a,b in pierced}
        categories={}
        for a in pierced_faces:
            strongest=max(arm_names,key=lambda name:sum(weight(body.data.vertices[i],{name}) for i in arm_faces[a].vertices))
            categories[strongest]=categories.get(strongest,0)+1
        records.append({'side':side,'arm_weight_vertices_in_rest_torso_region':central_overlap,'arm_triangles':len(arms),'torso_triangles':len(torso),'triangle_crossings':len(pierced),'distinct_pierced_arm_faces':len(pierced_faces),'pierced_faces_by_dominant_bone':categories})
    evaluated.to_mesh_clear()
report={'runtime_approved':False,'pose':'rest with grip morph' if rest_review else 'rifle run frame12','rows':records,'scope':'Triangle crossings of central torso selected in rest world space (80% shoulder span, hips+4cm to neck-3cm) against >80% arm-weight faces. Excludes lateral torso, blended arm boundaries, coplanar contact and fully contained surfaces. Not full clearance proof.'}
filename='arm_torso_elbow_'+angle_text+'.json' if angle_text else ('arm_torso_rest_crossings.json' if rest_review else 'arm_torso_crossings.json')
if twist_text:filename='arm_torso_twist_'+twist_text+'.json'
(out/filename).write_text(json.dumps(report,indent=2))
print('ARM TORSO CROSSINGS',json.dumps(records))
