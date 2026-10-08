"""Review-only guard grip deformation. Preserve skin UVs and wrist topology."""
import bpy, bmesh, math, json
from pathlib import Path
from mathutils import Vector

out = Path('build/consumable_grip_sculpt_v3').resolve()
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path('build/consumable_contact_v3_isolated/guard.glb').resolve()))
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
arm.animation_data_clear()
for bone in arm.pose.bones: bone.matrix_basis.identity()
bone_frame = arm.matrix_world @ arm.data.bones['RightHand'].matrix_local
changed = 0
for body in list(bpy.context.scene.objects):
    if body.type != 'MESH' or 'RightHand' not in body.vertex_groups: continue
    group = body.vertex_groups['RightHand'].index
    inverse = bone_frame.inverted() @ body.matrix_world
    forward = inverse.inverted()
    # Extra segments only on the hand allow the bend to follow an arc rather
    # than folding long, low-poly finger faces into angular corners. BMesh
    # interpolates skin weights and UV coordinates on the split edges.
    bm = bmesh.new()
    bm.from_mesh(body.data)
    weights = bm.verts.layers.deform.active
    edges = [edge for edge in bm.edges if all(
        vertex[weights].get(group,0) > .5 and (inverse @ vertex.co).y > 7
        for vertex in edge.verts)]
    bmesh.ops.subdivide_edges(bm, edges=edges, cuts=3, use_grid_fill=True)
    bm.to_mesh(body.data)
    bm.free()
    original_uvs = [tuple(loop.uv) for loop in body.data.uv_layers.active.data]
    for vertex in body.data.vertices:
        weight = next((g.weight for g in vertex.groups if g.group == group), 0)
        point = inverse @ vertex.co
        # Keep palm and wrist fixed; curl distal fingers continuously from
        # their knuckles, retaining the original skin texture and topology.
        if weight < .5 or point.y <= 7: continue
        length = max(0,point.y - 9)
        radius = 4.1
        angle = min(length / radius, 2.75)
        curled = Vector((point.x, 9 + radius*math.sin(angle) + point.z*math.sin(angle),
                         -radius*(1-math.cos(angle)) + point.z*math.cos(angle))) if length > 0 else point.copy()
        # Fit the actual transverse 32mm can surface. Finger thickness in the
        # source is asymmetric, so bending its centreline alone buries skin.
        radial = Vector((0,curled.y-9,curled.z+4.1))
        if -5.75 < curled.x < 5.75 and radial.length < 3.3:
            radial = radial.normalized() * 3.3
            curled.y = 9 + radial.y
            curled.z = -4.1 + radial.z
        vertex.co = forward @ curled
        changed += 1
    assert original_uvs == [tuple(loop.uv) for loop in body.data.uv_layers.active.data]
    body.data.update()
assert changed > 0
bpy.ops.wm.save_as_mainfile(filepath=str(out/'guard_grip.blend'))
bpy.ops.export_scene.gltf(filepath=str(out/'guard_grip.glb'), export_format='GLB', export_animations=False)
(out/'report.json').write_text(json.dumps({'approved':False,'modified_vertices':changed,
    'uvs_preserved_after_subdivision':True,'scope':'Static review candidate; hand-only subdivision interpolates source UVs and weights. Finger/prop fit and action-specific playback remain unvalidated.'},indent=2))
