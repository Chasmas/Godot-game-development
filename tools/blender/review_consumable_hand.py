"""Inspect source guard fingers in their native bone frame before sculpting grips."""
import bpy, json, os
from pathlib import Path
from mathutils import Vector, Matrix

output = Path(os.environ.get('GUARD_HAND_REVIEW_OUTPUT','build/consumable_hand_anatomy')).resolve()
output.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path(os.environ.get('GUARD_HAND_REVIEW_SOURCE','build/consumable_contact_v3_isolated/guard.glb')).resolve()))
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
arm.animation_data_clear()
for bone in arm.pose.bones:
    bone.matrix_basis.identity()
requested_shape = os.environ.get('GUARD_HAND_REVIEW_SHAPE', '')
if requested_shape:
    activated = 0
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH' and obj.data.shape_keys:
            shape = obj.data.shape_keys.key_blocks.get(requested_shape)
            if shape:
                shape.value = 1.0
                activated += 1
    assert activated > 0, requested_shape
hand_name = os.environ.get('GUARD_HAND_REVIEW_BONE', 'RightHand')
hand = arm.data.bones[hand_name]
frame = arm.matrix_world @ hand.matrix_local
samples = []
for obj in bpy.context.scene.objects:
    if obj.type != 'MESH' or hand_name not in obj.vertex_groups:
        continue
    group = obj.vertex_groups[hand_name].index
    inverse = frame.inverted() @ obj.matrix_world
    for vertex in obj.data.vertices:
        weight = next((g.weight for g in vertex.groups if g.group == group), 0)
        if weight > .8:
            samples.append(list(inverse @ vertex.co))
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.render.resolution_x = 640
scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
scene.world = bpy.data.worlds.new('HandStudio')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.15,.15,.15,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .8
target = frame @ Vector((0,5,0))
if os.environ.get('GUARD_HAND_REVIEW_CAN') == '1':
    with bpy.data.libraries.load(str(Path('build/idle_consumables_candidate/can.blend').resolve()), link=False) as (source, destination):
        destination.objects = source.objects
    axes = frame.to_3x3().normalized()
    prop_frame = Matrix((axes.col[0], -axes.col[2], axes.col[1])).transposed().to_4x4()
    socket = (0,5,-4.1) if os.environ.get('GUARD_HAND_REVIEW_FITTED') == '1' else (0,-2.75,-5.5)
    prop_frame.translation = frame @ Vector(socket)
    if os.environ.get('GUARD_HAND_REVIEW_FITTED') == '2':
        # Fingers curl in the bone Y/Z plane: the cylinder must run across
        # the palm along X rather than parallel to the extended fingers.
        prop_frame = Matrix((axes.col[1], axes.col[2], axes.col[0])).transposed().to_4x4()
        prop_frame.translation = frame @ Vector((-5.75,9,-4.1))
    for obj in destination.objects:
        if obj is None or obj.type not in {'MESH','CURVE','FONT'}: continue
        scene.collection.objects.link(obj)
        obj.matrix_world = prop_frame @ obj.matrix_world
for name, offset in [('palm',(0,5,-40)), ('edge',(40,5,0))]:
    bpy.ops.object.camera_add(location=frame @ Vector(offset))
    camera = bpy.context.object
    camera.rotation_euler = (target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = .22
    camera.data.clip_start = .001
    scene.camera = camera
    bpy.ops.object.light_add(type='AREA', location=frame @ Vector((0,5,-25)))
    lamp = bpy.context.object
    lamp.rotation_euler = (target-lamp.location).to_track_quat('-Z','Y').to_euler()
    lamp.data.energy = 1.2
    lamp.data.size = .2
    scene.render.filepath = str(output / (name+'.png'))
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)
    bpy.data.objects.remove(lamp, do_unlink=True)
(output/'hand_vertices.json').write_text(json.dumps({'bones':list(arm.data.bones.keys()),'reviewed_bone':hand_name,'right_hand_local_vertices':samples,'approved':False},indent=2))
