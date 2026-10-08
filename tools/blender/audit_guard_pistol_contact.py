"""Read-only posed hand/gun triangle crossings; excludes coplanar contact."""
import bpy, json, os
from pathlib import Path
from mathutils import Matrix
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_ray_tri

source = os.environ.get('GUARD_CONTACT_SOURCE', 'build/guard_pistol_anatomy_review/guard.glb')
output = Path(os.environ.get('GUARD_CONTACT_REPORT', 'build/guard_pistol_anatomy_review/contact_report.json'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path(source).resolve()))
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
clip = os.environ.get('GUARD_CONTACT_CLIP', 'aim_dual')
phase = float(os.environ.get('GUARD_CONTACT_PHASE', '0'))
assert 0 <= phase <= 1
action = next(a for a in bpy.data.actions if a.name.split('.')[0] == clip)
arm.animation_data_clear()
arm.animation_data_create().action = action
frame = action.frame_range[0] + phase * (action.frame_range[1]-action.frame_range[0])
bpy.context.scene.frame_set(int(frame), subframe=frame-int(frame))
bpy.context.view_layer.update()
bodies = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.data.shape_keys
          and 'WeaponGrip' in o.data.shape_keys.key_blocks]
assert bodies
for body in bodies:
    body.data.shape_keys.key_blocks['WeaponGrip'].value = 1
bpy.context.view_layer.update()
# Evaluate the full deforming mesh, excluding only fully hand-weighted
# faces. Torso/forearm surfaces remain eligible for weapon clearance.
body_triangles = []
for body in bodies:
    hands = {body.vertex_groups[s+'Hand'].index for s in ('Right', 'Left')}
    hand_vertices = {v.index for v in body.data.vertices
                     if sum(g.weight for g in v.groups if g.group in hands) >= .99}
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    body_triangles.extend(tuple(evaluated.matrix_world @ mesh.vertices[i].co for i in tri.vertices)
                          for tri in mesh.loop_triangles
                          if not all(i in hand_vertices for i in tri.vertices))
    evaluated.to_mesh_clear()
body_vertices = [p for tri in body_triangles for p in tri]
body_bvh = BVHTree.FromPolygons(body_vertices, [(i*3,i*3+1,i*3+2)
                               for i in range(len(body_triangles))], all_triangles=True)
before = set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=str(Path('build/held_pistol_candidate/pistol.glb').resolve()))
guns = [o for o in bpy.context.scene.objects if o not in before and o.type == 'MESH']

def crosses(first, second):
    # Both edge directions are necessary: a narrow gun triangle may pierce
    # the interior of a larger hand face without touching its three edges.
    for edges, face in ((first, second), (second, first)):
        for i in range(3):
            start, end = edges[i], edges[(i+1) % 3]
            delta = end-start
            length = delta.length
            if length < 1e-8:
                continue
            hit = intersect_ray_tri(*face, delta/length, start, True)
            if hit is not None and 1e-6 < (hit-start).dot(delta/length) < length-1e-6:
                return True
    return False

# A pierced face with its edges outside the other face exercises the reverse
# edge test; separated triangles must not be counted by BVH overlap alone.
from mathutils import Vector
wide = tuple(Vector(p) for p in ((-2,-2,0),(2,-2,0),(0,2,0)))
needle = tuple(Vector(p) for p in ((0,0,-1),(.1,0,1),(0,.1,1)))
far = tuple(p+Vector((0,0,3)) for p in wide)
assert crosses(wide, needle) and not crosses(wide, far)

rows = []
for side in ('Right', 'Left'):
    pb = arm.pose.bones[side+'Hand']
    hand = arm.matrix_world @ pb.matrix
    x, y, z = hand.to_3x3().normalized().col
    attachment = (Matrix((y,z,x)).transposed() if side == 'Right'
                  else Matrix((y,-z,-x)).transposed()).to_4x4()
    if os.environ.get('GUARD_PISTOL_UPRIGHT') == '1':
        attachment = (Matrix((y,-z,-x)).transposed() if side == 'Right'
                      else Matrix((y,z,x)).transposed()).to_4x4()
    depth = -.039 if os.environ.get('GUARD_DUAL_ROTATED_GRASP') == '1' else .039
    attachment.translation = hand.translation+y*.06+z*depth
    triangles = []
    for body in bodies:
        group = body.vertex_groups[side+'Hand'].index
        native = pb.bone.matrix_local.inverted() @ arm.matrix_world.inverted() @ body.matrix_world
        skin = hand @ (arm.matrix_world @ pb.bone.matrix_local).inverted() @ body.matrix_world
        key = body.data.shape_keys.key_blocks['WeaponGrip']
        eligible = {v.index for v in body.data.vertices
                    if next((g.weight for g in v.groups if g.group == group), 0) >= .99
                    and (native @ v.co).y >= 5}
        body.data.calc_loop_triangles()
        triangles.extend([tuple(skin @ key.data[i].co for i in t.vertices)
                          for t in body.data.loop_triangles if all(i in eligible for i in t.vertices)])
    assert len(triangles) > 100
    vertices = [v for t in triangles for v in t]
    faces = [(i*3,i*3+1,i*3+2) for i in range(len(triangles))]
    hand_bvh = BVHTree.FromPolygons(vertices, faces, all_triangles=True)
    hits = {}
    body_hits = {}
    pierced = set()
    for gun in guns:
        matrix = attachment @ gun.matrix_world
        gun.data.calc_loop_triangles()
        gun_triangles = [tuple(matrix @ gun.data.vertices[i].co for i in t.vertices)
                         for t in gun.data.loop_triangles]
        gun_vertices = [v for t in gun_triangles for v in t]
        gun_bvh = BVHTree.FromPolygons(gun_vertices, [(i*3,i*3+1,i*3+2)
                                      for i in range(len(gun_triangles))], all_triangles=True)
        count = 0
        for a,b in hand_bvh.overlap(gun_bvh):
            if crosses(triangles[a], gun_triangles[b]):
                count += 1
                pierced.add(a)
        if count:
            hits[gun.name] = count
        body_count = sum(crosses(body_triangles[a], gun_triangles[b])
                         for a,b in body_bvh.overlap(gun_bvh))
        if body_count:
            body_hits[gun.name] = body_count
    # The imported hand matrix contains the centimetre-to-metre rig scale.
    # Use unit axes for this metric diagnostic, rather than its inverse scale.
    metric_inverse = hand.to_3x3().normalized().transposed()
    centres = [metric_inverse @ (sum(triangles[i], Vector())/3-hand.translation) for i in pierced]
    bounds = {'min': [min(p[a] for p in centres) for a in range(3)],
              'max': [max(p[a] for p in centres) for a in range(3)]} if centres else None
    rows.append({'side': side, 'hand_triangles': len(triangles),
                 'pierced_hand_triangles': len(pierced), 'crossing_pairs_by_part': hits,
                 'body_crossing_pairs_by_part': body_hits,
                 'pierced_face_centres_hand_local_m': bounds})
report = {'approved': False, 'source': source, 'clip': clip, 'phase': phase, 'rows': rows,
          'scope': 'Sampled phase, fully hand-weighted faces distal to 5 cm and evaluated non-hand body; '
                   'segment-triangle crossings in both directions. Does not prove '
                   'absence of containment, coplanar overlap or contact in other poses.'}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(report, indent=2))
print(json.dumps(report))
