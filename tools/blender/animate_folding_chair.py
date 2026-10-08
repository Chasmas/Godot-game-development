"""Author a grounded, bouncing chair tip from the existing Blender chair."""
import bpy, math, os, sys, json
from mathutils import Vector, Matrix

out = os.path.abspath(sys.argv[sys.argv.index('--') + 1])
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
bpy.ops.wm.open_mainfile(filepath=os.path.join(root, 'assets/art/Artwork/3d/folding_chair/scene.blend'))
scene = bpy.context.scene
scene.render.fps = 240
scene.frame_start, scene.frame_end = 1, 145
meshes = [obj for obj in scene.objects if obj.type == 'MESH']
# Apply each object's authored bevel before joining, preserving all materials.
for obj in meshes:
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target='MESH')
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.join()
chair = bpy.context.object
chair.name = 'GroundedChair'
scene.cursor.location = (0, -0.27, 0)
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
points = [v.co.copy() for v in chair.data.vertices]
landmarks = [(1, 0), (21, -3), (89, 98), (113, 86), (129, 92), (145, 90)]

def angle_at(frame):
    for (a, va), (b, vb) in zip(landmarks, landmarks[1:]):
        if frame <= b:
            k = (frame-a)/(b-a)
            k = k*k*(3-2*k)
            return math.radians(va+(vb-va)*k)
    return math.pi/2

contacts = []
for frame in range(1, 146):
    angle = angle_at(frame)
    rotation = Matrix.Rotation(angle, 4, 'X')
    lowest = min((rotation @ p).z for p in points)
    chair.rotation_euler = (angle, 0, 0)
    chair.location = (0, -0.27, -lowest)
    chair.keyframe_insert('rotation_euler', frame=frame)
    chair.keyframe_insert('location', frame=frame)
    contacts.append({'frame': frame, 'minimum_z': lowest + chair.location.z})
chair.animation_data.action.name = 'tip'
scene.frame_set(1)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(os.path.dirname(out), 'folding_chair_tip.blend'))
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True, export_animation_mode='ACTIONS')
with open(os.path.join(os.path.dirname(out), 'chair_contact_audit.json'), 'w') as f:
    json.dump({'duration_seconds': 0.6, 'vertices': len(points), 'contacts': contacts, 'runtime_approved': False}, f, indent=2)
print('Authored grounded chair tip:', out)
