"""Render skin deformation probes; no gait or runtime approval."""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/skin_candidate_v6'
OUT = BASE / 'pose_review'
IDLE = '--idle' in sys.argv
WALK = '--walk' in sys.argv
walk_version = 'walk_candidate_v3' if '--shoulder-polish' in sys.argv else 'walk_candidate_v2'
if '--balanced' in sys.argv:
    walk_version = 'walk_candidate_v4'
if '--native-skin' in sys.argv:
    walk_version = 'walk_candidate_v4/native_skin_candidate_v4'
if '--chest-refine' in sys.argv:
    walk_version = 'walk_candidate_v4/native_skin_candidate_v5'
CONTACTS = '--contacts' in sys.argv
if IDLE:
    OUT = BASE.parent / 'idle_candidate_v1/preview_frames'
if '--expanded' in sys.argv:
    OUT = BASE / 'expanded_pose_review'
if CONTACTS:
    OUT = BASE.parent / 'contact_candidate_v3/pose_review'
if WALK:
    OUT = BASE.parent / walk_version / ('opposite_preview_frames' if '--opposite' in sys.argv else 'preview_frames')
OUT.mkdir(parents=True, exist_ok=True)
source = (BASE.parent / 'idle_candidate_v1/dog_doberman_idle_candidate.blend'
    if IDLE else BASE / 'dog_doberman_skin_candidate.blend')
if CONTACTS:
    source = BASE.parent / 'contact_candidate_v3/dog_doberman_contact_candidate.blend'
if WALK:
    source = BASE.parent / walk_version / 'dog_doberman_walk_candidate.blend'
    if '--native-skin' in sys.argv:
        source = BASE.parent / walk_version / 'dog_doberman_native_skin.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 12
scene.cycles.use_denoising = True
try:
    preferences = bpy.context.preferences.addons['cycles'].preferences
    preferences.compute_device_type = 'CUDA'
    preferences.get_devices()
    for device in preferences.devices:
        device.use = device.type != 'CPU'
    scene.cycles.device = 'GPU'
except Exception:
    scene.cycles.device = 'CPU'
scene.render.resolution_x = 1024
scene.render.resolution_y = 768
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'Standard'
scene.world = bpy.data.worlds.new('Deformation review world')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.16,.18,.21,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .35
focus = Vector((0,0,.44))
for loc,energy,size in [((2,-3,3),250,3),((-3,-1,2),100,3),((0,3,3),180,2)]:
    bpy.ops.object.light_add(type='AREA',location=loc)
    light=bpy.context.object
    light.data.energy=energy
    light.data.size=size
    light.rotation_euler=(focus-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(3,-3,.60))
camera=bpy.context.object
camera.data.type='ORTHO'
camera.data.ortho_scale=1.65
camera.rotation_euler=(focus-camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera=camera
if IDLE or WALK:
    scene.render.resolution_x=640
    scene.render.resolution_y=480
    scene.cycles.samples=8
    camera.location=(-4 if '--opposite' in sys.argv else 4,0,.44)
    camera.rotation_euler=(focus-camera.location).to_track_quat('-Z','Y').to_euler()
probes=[('rest',None,0,0),
        ('front_paw_bend','front_positive_x_lower',0,25),
        ('rear_hip_bend','rear_positive_x_upper',0,20),
        ('head_turn','head',2,20),
        ('tail_bend','tail_1',0,25)]
if '--expanded' in sys.argv:
    camera.location = (-3,-3,.60)
    camera.rotation_euler=(focus-camera.location).to_track_quat('-Z','Y').to_euler()
    probes=[('opposite_front_paw','front_negative_x_lower',0,25),
            ('opposite_rear_hip','rear_negative_x_upper',0,20),
            ('opposite_head_turn','head',2,-20),
            ('tail_moderate_positive','tail_1',0,12),
            ('tail_moderate_negative','tail_1',0,-12)]
contact_offsets = {'neutral_stance': (0,0,-.01), 'side_shift': (.005,0,-.005), 'upper_stance': (0,0,0)}
if CONTACTS:
    probes = [(name,None,0,0) for name in contact_offsets]
for name,bone_name,axis,degrees in probes:
    if IDLE or WALK:
        break
    if CONTACTS:
        pelvis = rig.pose.bones['pelvis']
        pelvis.location = pelvis.bone.matrix_local.to_3x3().inverted() @ Vector(contact_offsets[name])
    else:
        for bone in rig.pose.bones:
            bone.rotation_mode='XYZ'
            bone.rotation_euler=(0,0,0)
    if bone_name:
        rig.pose.bones[bone_name].rotation_euler[axis]=math.radians(degrees)
    bpy.context.view_layer.update()
    scene.render.filepath=str(OUT/(name+'.png'))
    bpy.ops.render.render(write_still=True)
if IDLE or WALK:
    animation_frames = range(1,31,2) if WALK else range(1,73,3)
    if WALK and '--probe-frames' in sys.argv:
        animation_frames = [1,9,21]
    for frame in animation_frames:
        scene.frame_set(frame)
        scene.render.filepath=str(OUT/(('walk_' if WALK else 'idle_')+'%03d.png'%frame))
        bpy.ops.render.render(write_still=True)
report={'runtime_approved':False,'rig_approved':False,
        'scope':'Idle sequence preview at 10fps; no gameplay approval' if IDLE else 'Static skin deformation probes; no walk/run cycle or gameplay validation',
        'probes':([{'render':'idle_%03d.png'%frame,'frame':frame} for frame in range(1,73,3)] if IDLE else [{'render':n+'.png','bone':b,'axis':a,'degrees':d} for n,b,a,d in probes])}
if CONTACTS:
    report['scope'] = 'Three grounded contact stance renders; no locomotion or gameplay approval'
    report['body_offsets_m'] = contact_offsets
if WALK:
    report['scope'] = 'Walk sequence preview at 15fps; no gait or gameplay approval'
    if '--probe-frames' in sys.argv:
        report['scope'] = 'Three sampled walk poses; no continuous playback or gait approval'
    report['probes'] = [{'render':'walk_%03d.png'%frame,'frame':frame} for frame in animation_frames]
(OUT/'pose_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('%d animation frames rendered' % len(animation_frames) if IDLE or WALK else '%d pose probes rendered' % len(probes),flush=True)
