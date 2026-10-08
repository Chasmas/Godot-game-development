"""Blender IK proof: off hand reaches right pistol magazine, not runtime-ready."""
import bpy,json,math,os
from pathlib import Path
from mathutils import Vector,Matrix
root=Path(os.environ.get('GUARD_CONTACT_OUTPUT','build/guard_reload_hand_contact_v2'));root.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path('build/guard_hand_blend_restored_v33/guard.glb').resolve()))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
source_clip=os.environ.get('GUARD_CONTACT_BASE_CLIP','reload_dual')
action=next(a for a in bpy.data.actions if a.name.split('.')[0]==source_clip)
action=action.copy();action.name='reload_contact_proof'
arm.animation_data_clear();arm.animation_data_create().action=action
frame=action.frame_range[0]+.25*(action.frame_range[1]-action.frame_range[0])
bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update()
right=arm.matrix_world@arm.pose.bones['RightHand'].matrix
axes=right.to_3x3().normalized()
magazine=right.translation+axes.col[1]*.06+axes.col[2]*.039-axes.col[0]*.051
target=bpy.data.objects.new('LeftHandMagazineContact',None);bpy.context.collection.objects.link(target)
target.empty_display_type='SPHERE';target.empty_display_size=.012
def world(name):return arm.matrix_world@arm.pose.bones[name].matrix
shoulder=world('LeftArm').translation.copy()
elbow=world('LeftForeArm').translation.copy()
wrist=world('LeftHand').translation.copy()
approach=(magazine-shoulder).normalized()
target.location=magazine-approach*.09
length1=(elbow-shoulder).length;length2=(wrist-elbow).length
distance=(target.location-shoulder).length
assert abs(length1-length2)<distance<length1+length2,(distance,length1,length2)
direction=(target.location-shoulder).normalized()
along=(length1*length1-length2*length2+distance*distance)/(2*distance)
height=math.sqrt(max(0,length1*length1-along*along))
bend=(elbow-shoulder)-direction*(elbow-shoulder).dot(direction)
assert bend.length>.001
desired_elbow=shoulder+direction*along+bend.normalized()*height
def rotate_segment(name,old_direction,new_direction):
 current=world(name)
 rotation=old_direction.normalized().rotation_difference(new_direction.normalized())
 matrix=rotation.to_matrix().to_4x4()@current;matrix.translation=current.translation
 arm.pose.bones[name].matrix=arm.matrix_world.inverted()@matrix
 bpy.context.view_layer.update()
rotate_segment('LeftArm',elbow-shoulder,desired_elbow-shoulder)
current_elbow=world('LeftForeArm').translation.copy()
current_wrist=world('LeftHand').translation.copy()
rotate_segment('LeftForeArm',current_wrist-current_elbow,target.location-current_elbow)
hand=arm.pose.bones['LeftHand']
rotate_segment('LeftHand',world('LeftHand').to_3x3().normalized().col[1],approach)
for body in [o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.shape_keys]:
 body.data.shape_keys.key_blocks['WeaponGrip'].value=1
bpy.context.view_layer.update()
posed=arm.matrix_world@hand.matrix
palm=posed.translation+posed.to_3x3().normalized().col[1]*.09
error=(palm-magazine).length
print('FK_DIAGNOSTIC',distance,length1,length2,error)
assert error<.015,error
for name in ('LeftArm','LeftForeArm','LeftHand'):
 bone=arm.pose.bones[name]
 bone.keyframe_insert(data_path='rotation_quaternion',frame=frame)
 bone.keyframe_insert(data_path='location',frame=frame)
 bone.keyframe_insert(data_path='scale',frame=frame)
# Native right pistol only: the other gun must be holstered for this gesture.
before=set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=str(Path('build/held_pistol_magazine_v2/pistol.glb').resolve()))
gunframe=Matrix((axes.col[1],axes.col[2],axes.col[0])).transposed().to_4x4()
gunframe.translation=right.translation+axes.col[1]*.06+axes.col[2]*.039
for obj in [o for o in bpy.context.scene.objects if o not in before and o.type=='MESH']:
 obj.matrix_world=gunframe@obj.matrix_world
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
scene.render.resolution_x=960;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Contact review world');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.14,.18,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
look=(shoulder+magazine)/2
bpy.ops.object.camera_add(location=look+Vector((.8,-1.5,.9)))
camera=bpy.context.object;camera.rotation_euler=(look-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=.95;scene.camera=camera
for offset in [Vector((.5,-1,1)),Vector((-.6,.4,.6))]:
 bpy.ops.object.light_add(type='AREA',location=look+offset)
 light=bpy.context.object;light.data.energy=55;light.data.size=1
 light.rotation_euler=(look-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.wm.save_as_mainfile(filepath=str((root/'guard_reload_contact_proof.blend').resolve()))
scene.render.filepath=str((root/'contact_review.png').resolve());bpy.ops.render.render(write_still=True)
bpy.context.view_layer.update()
rendered=world('LeftHand');rendered_palm=rendered.translation+rendered.to_3x3().normalized().col[1]*.09
assert (rendered_palm-magazine).length<.015, 'Render reset authored contact pose'
(root/'report.json').write_text(json.dumps({'approved':False,'contact_passed':error<.015,'phase':.25,'left_palm_to_right_magazine_m':error,'magazine_world':list(magazine),'left_palm_world':list(palm),'ik_chain':{name:{'length_native':arm.data.bones[name].length,'head':list(arm.data.bones[name].head_local),'tail':list(arm.data.bones[name].tail_local)} for name in ('LeftArm','LeftForeArm','LeftHand')},'scope':'Single Blender IK diagnostic only; contact must pass before animation authoring. Requires elbow/palm collision review, holstered off-hand gun, individual hand grasp morphs, full keyframe animation and Godot validation.'},indent=2))
print('RELOAD_CONTACT_ERROR_M',error)
