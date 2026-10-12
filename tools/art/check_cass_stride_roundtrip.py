"""Isolate glTF export/import drift from Godot playback."""
from pathlib import Path
import bpy, math
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'build/locomotion_candidates/cass/walk_contact_candidate.glb'))
scene = bpy.context.scene
arm = next(o for o in scene.objects if o.type=='ARMATURE')
start = None
worst = 0
for sample in range(35):
    time = sample/60
    frame = time*scene.render.fps
    scene.frame_set(math.floor(frame), subframe=frame-math.floor(frame))
    bpy.context.view_layer.update()
    evaluated = arm.evaluated_get(bpy.context.evaluated_depsgraph_get())
    point = evaluated.matrix_world @ evaluated.pose.bones['LeftFoot'].head
    point += Vector((0,-(.55/.6)*time,0))
    if start is None: start = point.copy()
    worst = max(worst,(point-start).length)
print('BLENDER GLTF ROUNDTRIP STANCE DRIFT:',worst)
