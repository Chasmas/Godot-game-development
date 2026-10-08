"""Prepare independent paw IK and measure a small body-shift contact probe."""
import bpy
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman'
OUT = BASE / 'contact_candidate_v3'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE / 'skin_candidate_v6/dog_doberman_skin_candidate.blend'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH')

# Sole vertices follow the paw rigidly; blend at the ankle instead of allowing
# lower-leg weights to shear the planted sole through the ground.
sole_indices = []
for vertex in obj.data.vertices:
    p = vertex.co
    if p.z >= .12 or abs(p.x) <= .025 or abs(p.y) <= .13:
        continue
    key = ('front' if p.y < 0 else 'rear') + ('_negative_x' if p.x < 0 else '_positive_x')
    paw_group = obj.vertex_groups[key + '_paw']
    amount = max(0., min(1., (.12 - p.z) / .06))
    amount = amount * amount * (3. - 2. * amount)
    existing = [(g.group, g.weight) for g in vertex.groups]
    for index, weight in existing:
        obj.vertex_groups[index].add([vertex.index], weight * (1. - amount), 'REPLACE')
    previous = sum(weight for index, weight in existing if index == paw_group.index)
    paw_group.add([vertex.index], previous * (1. - amount) + amount, 'REPLACE')
    if p.z < .06:
        sole_indices.append(vertex.index)

def sole_positions():
    evaluated_obj = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated_obj.to_mesh()
    points = [mesh.vertices[index].co.copy() for index in sole_indices]
    minimum = min(v.co.z for v in mesh.vertices)
    evaluated_obj.to_mesh_clear()
    return points, minimum

bpy.context.view_layer.update()
source_soles, _ = sole_positions()
targets = {}
for pair in ['front', 'rear']:
    for side in ['negative_x', 'positive_x']:
        key = pair + '_' + side
        paw = rig.pose.bones[key + '_paw']
        control = rig.pose.bones[key + '_contact']
        targets[key] = paw.tail.copy()
        # Solve the two leg segments to the ankle, preserving paw orientation
        # separately. Three-segment IK rotates the sole through the floor.
        matrix = paw.matrix.copy()
        matrix.translation = paw.head.copy()
        control.matrix = matrix
        constraint = rig.pose.bones[key + '_lower'].constraints.new('IK')
        constraint.name = 'Measured paw endpoint contact'
        constraint.target = rig
        constraint.subtarget = control.name
        constraint.chain_count = 2
        constraint.use_stretch = False
        constraint.iterations = 128
        orientation = paw.constraints.new('COPY_ROTATION')
        orientation.name = 'Grounded paw orientation'
        orientation.target = rig
        orientation.subtarget = control.name
        orientation.owner_space = 'POSE'
        orientation.target_space = 'POSE'
        for suffix in ['upper', 'lower', 'paw']:
            rig.pose.bones[key + '_' + suffix].ik_stretch = 0.0
bpy.context.view_layer.update()
pelvis = rig.pose.bones['pelvis']
samples = []
for offset in [(0,0,0), (.005,0,.005), (-.005,0,.005), (0,0,.01), (0,0,0)]:
    # A 10mm lower neutral stance provides bend reserve without lengthening bones.
    actual_offset = Vector(offset) + Vector((0,0,-.01))
    pelvis.location = pelvis.bone.matrix_local.to_3x3().inverted() @ actual_offset
    bpy.context.view_layer.update()
    evaluated_rig = rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
    errors = {key: (evaluated_rig.pose.bones[key + '_paw'].tail - target).length for key, target in targets.items()}
    points, minimum_z = sole_positions()
    sole_displacement = max((a-b).length for a,b in zip(points, source_soles))
    samples.append({'body_offset_m': offset, 'paw_endpoint_errors_m': errors,
        'actual_body_offset_m': list(actual_offset),
        'maximum_sole_displacement_m': sole_displacement,
        'minimum_mesh_height_m': minimum_z})
pelvis.location = pelvis.bone.matrix_local.to_3x3().inverted() @ Vector((0,0,-.01))
bpy.context.view_layer.update()
maximum = max(error for sample in samples for error in sample['paw_endpoint_errors_m'].values())
report = {'runtime_approved': False, 'contact_solver_approved': False,
    'scope': 'Four ankle IK contacts with grounded paw orientation and rigid soles, five body-shift probes around a 10mm lower neutral stance; visual review and locomotion pending',
    'sole_sample_vertices': len(sole_indices),
    'maximum_paw_endpoint_error_m': maximum, 'samples': samples}
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'dog_doberman_contact_candidate.blend'))
(OUT / 'contact_audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'maximum_paw_endpoint_error_m': maximum, 'runtime_approved':False}), flush=True)
