"""Build-only pistol finger curl; source rig and texture UVs retained."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector

out = Path('build/guard_pistol_grasp').resolve()
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path('build/guard_dual_wrist_isolated/guard.glb').resolve()))
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
arm.animation_data_clear()
for bone in arm.pose.bones:
    bone.matrix_basis.identity()
counts = {}
for body in list(bpy.context.scene.objects):
    if body.type != 'MESH':
        continue
    # Keep the existing drink shape and the rest hand intact. The weapon
    # grasp must be opt-in so smoking, drinking and open-hand actions survive.
    if not body.data.shape_keys:
        body.shape_key_add(name='Basis')
    grasp = body.shape_key_add(name='WeaponGrip')
    grasp.value = 0.0
    uv_before = [tuple(loop.uv) for loop in body.data.uv_layers.active.data]
    for name in ('RightHand', 'LeftHand'):
        group = body.vertex_groups.get(name)
        if group is None:
            continue
        frame = arm.matrix_world @ arm.data.bones[name].matrix_local
        inverse = frame.inverted() @ body.matrix_world
        forward = inverse.inverted()
        changed = 0
        for vertex in body.data.vertices:
            weight = next((g.weight for g in vertex.groups if g.group == group.index), 0)
            point = inverse @ vertex.co
            if weight < .5 or point.y <= 9:
                continue
            radius = 3.4
            # A hard angle cap collapses long fingers onto one cross-section.
            # Smooth saturation keeps the distal surface ordered and avoids
            # folding fingertips all the way back into the wrist.
            angle = 2.2 * math.tanh((point.y - 9) / (radius * 2.2))
            curled = Vector((point.x, 9 + radius * math.sin(angle) - point.z * math.sin(angle),
                             radius * (1 - math.cos(angle)) + point.z * math.cos(angle)))
            # The raised thumb in this source sits above the finger plane.
            # Preserve it with a smooth transition rather than folding it
            # through the same cylinder as the four gripping fingers.
            thumb_blend = min(1.0, max(0.0, (point.z - 2.4) / 1.6))
            thumb_blend = thumb_blend * thumb_blend * (3 - 2 * thumb_blend)
            curled = curled.lerp(point, thumb_blend)
            grasp.data[vertex.index].co = forward @ curled
            changed += 1
        counts[name] = changed
    assert uv_before == [tuple(loop.uv) for loop in body.data.uv_layers.active.data]
    body.data.update()
assert all(counts.get(side, 0) > 0 for side in ('RightHand', 'LeftHand'))
bpy.ops.wm.save_as_mainfile(filepath=str(out / 'guard_grasp.blend'))
bpy.ops.export_scene.gltf(filepath=str(out / 'guard_grasp.glb'), export_format='GLB', export_animations=False)
(out / 'report.json').write_text(json.dumps({'approved': False, 'changed_vertices': counts,
    'uvs_preserved': True, 'default_weight': 0, 'scope': 'Opt-in WeaponGrip morph; original rest and CanGrip retained. Finger self-intersection and pistol contact not approved.'}, indent=2))
