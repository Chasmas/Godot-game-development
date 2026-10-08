"""Render original hand geometry in rest space before authoring fist shapes."""
import bpy
import json
from pathlib import Path
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path('assets/art/cast3d_rt/cass/cass.glb').resolve()))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
rig.animation_data_clear()
for bone in rig.pose.bones:
    bone.matrix_basis.identity()
source_meshes = [o for o in bpy.data.objects if o.type == 'MESH']
studies = []
for side, offset in [('LeftHand', -0.13), ('RightHand', 0.13)]:
    body = next(o for o in source_meshes if side in o.vertex_groups)
    group = body.vertex_groups[side].index
    indices = {v.index for v in body.data.vertices if any(g.group == group and g.weight > 0.5 for g in v.groups)}
    weighted_count = len(indices)
    # Include adjoining polygons at blended wrist/hand weights instead of
    # discarding triangles merely because one corner falls below 0.5.
    for ring in range(2):
        adjoining = [p for p in body.data.polygons if any(i in indices for i in p.vertices)]
        indices.update(i for p in adjoining for i in p.vertices)
    faces = [tuple(p.vertices) for p in body.data.polygons if all(i in indices for i in p.vertices)]
    used = sorted({i for face in faces for i in face})
    mapping = {old: new for new, old in enumerate(used)}
    local = (rig.matrix_world @ rig.data.bones[side].matrix_local).inverted() @ body.matrix_world
    points = [local @ body.data.vertices[i].co for i in used]
    # Native source uses centimetres; make the study camera operate in metres.
    vertices = [(p.x * 0.01 + offset, p.y * 0.01, p.z * 0.01) for p in points]
    mesh = bpy.data.meshes.new(side + '_study')
    mesh.from_pydata(vertices, [], [tuple(mapping[i] for i in face) for face in faces])
    mesh.update()
    obj = bpy.data.objects.new(side + '_study', mesh)
    bpy.context.collection.objects.link(obj)
    studies.append({'hand': side, 'weighted_vertices': weighted_count,
                    'vertices_with_two_adjoining_rings': len(used), 'faces': len(faces),
                    'boundary_cut_is_diagnostic_only': True})
for obj in [rig] + source_meshes:
    obj.hide_render = True
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.render.resolution_x = 1200
scene.render.resolution_y = 700
scene.render.resolution_percentage = 100
scene.world = bpy.data.worlds.new('StudyWorld')
scene.world.color = (0.08, 0.08, 0.08)
camera_data = bpy.data.cameras.new('StudyCamera')
camera = bpy.data.objects.new('StudyCamera', camera_data)
bpy.context.collection.objects.link(camera)
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 0.50
scene.camera = camera
for position, power in [((0, -0.3, 0.5), 30), ((0.3, 0.3, 0.3), 15)]:
    light_data = bpy.data.lights.new('StudyLight', 'AREA')
    light_data.energy = power
    light_data.shape = 'DISK'
    light_data.size = 0.4
    light = bpy.data.objects.new('StudyLight', light_data)
    bpy.context.collection.objects.link(light)
    light.location = position
    light.rotation_euler = (Vector((0, 0.1, 0)) - light.location).to_track_quat('-Z', 'Y').to_euler()
out = Path('build/cass_fist_review').resolve()
out.mkdir(exist_ok=True)
for name, location in [('palm', (0, 0.10, 0.6)), ('profile', (0, -0.5, 0.25))]:
    camera.location = location
    camera.rotation_euler = (Vector((0, 0.1, 0)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(out / (name + '.png'))
    bpy.ops.render.render(write_still=True)
(out / 'hand_study.json').write_text(json.dumps({'hands': studies, 'scope': 'Original hand surface inventory, not a fist candidate', 'runtime_promoted': False}, indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(out / 'hand_study.blend'))
