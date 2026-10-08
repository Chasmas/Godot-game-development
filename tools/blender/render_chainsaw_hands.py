import bpy,os
from pathlib import Path
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path(os.environ.get('HAND_SOURCE','build/chainsaw_pose_candidate/cass_grip_mesh.glb')).resolve()))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('HandReviewWorld');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.1,.1,.1,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.8
for side in ['Left','Right']:
 bone=arm.data.bones[side+'Hand'];frame=arm.matrix_world@bone.matrix_local
 target=frame@Vector((0,8,0));at=frame@Vector((0,8,-40))
 bpy.ops.object.camera_add(location=at);camera=bpy.context.object;camera.rotation_euler=(target-at).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=24*arm.scale.x;camera.data.clip_start=.001;camera.data.clip_end=1000;scene.camera=camera
 bpy.ops.object.light_add(type='AREA',location=frame@Vector((0,8,-20)));lamp=bpy.context.object;lamp.rotation_euler=camera.rotation_euler;lamp.data.energy=.6;lamp.data.shape='DISK';lamp.data.size=.2
 scene.render.filepath=str(Path('build/chainsaw_pose_candidate/'+side.lower()+os.environ.get('HAND_SUFFIX','')+'_hand_closeup.png').resolve());bpy.ops.render.render(write_still=True)
 bpy.data.objects.remove(camera,do_unlink=True);bpy.data.objects.remove(lamp,do_unlink=True)
