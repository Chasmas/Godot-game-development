"""Stage an anatomical fist volume from the ImageGen hand reference; never ship."""
import bpy
import json
import sys
import bmesh
import math
from pathlib import Path
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
parts = []
refine = '--refine' in sys.argv
anatomy = '--anatomy' in sys.argv
thumb_contact = '--thumb-contact' in sys.argv
closed_palm = '--closed-palm' in sys.argv
thumb_contact = thumb_contact or closed_palm
anatomy = anatomy or thumb_contact
refine = refine or anatomy
def volume(name, at, scale):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    if refine and name.startswith('Finger_'):
        obj.scale.x *= 0.86
        obj.scale.y *= 0.94
        if '_joint_' in name:
            obj.scale.z *= 0.82
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    parts.append(obj)
    return obj

def segment(name, start, end, radius):
    midpoint = (Vector(start) + Vector(end)) * 0.5
    obj = volume(name, midpoint, (radius, radius, (Vector(end) - Vector(start)).length * 0.5 + radius))
    obj.rotation_euler = (Vector(end) - Vector(start)).to_track_quat('Z', 'Y').to_euler()

if anatomy:
    rings = [(-0.015, 0.022, 0.012), (0.0, 0.023, 0.013),
             (0.02, 0.027, 0.016), (0.045, 0.033, 0.018),
             (0.065, 0.033, 0.017), (0.08, 0.027, 0.013),
             (0.088, 0.014, 0.008)]
    vertices = []
    for y, width, depth in rings:
        for i in range(48):
            angle = i * math.tau / 48
            # Broad dorsal/palmar planes with rounded sides, rather than a ball.
            x = math.copysign(abs(math.cos(angle)) ** 0.72, math.cos(angle)) * width
            z = math.copysign(abs(math.sin(angle)) ** 0.72, math.sin(angle)) * depth
            vertices.append((x, y, z))
    faces = []
    for row in range(len(rings) - 1):
        for i in range(48):
            j = (i + 1) % 48
            faces.append((row * 48 + i, row * 48 + j, (row + 1) * 48 + j, (row + 1) * 48 + i))
    faces.extend([tuple(reversed(range(48))), tuple(range((len(rings) - 1) * 48, len(rings) * 48))])
    mesh = bpy.data.meshes.new('Palm_loft')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    palm = bpy.data.objects.new('Palm_loft', mesh)
    bpy.context.collection.objects.link(palm)
    parts.append(palm)
    volume('Thumb_base_pad', (-0.025, 0.035, -0.012), (0.015, 0.025, 0.010))
else:
    volume('Palm', (0, 0.045, 0), (0.034, 0.046, 0.018))
    volume('Wrist', (0, 0.005, 0), (0.025, 0.027, 0.016))
for i, (x, y, radius) in enumerate([(-0.026, 0.078, 0.010), (-0.009, 0.083, 0.011), (0.009, 0.080, 0.010), (0.025, 0.072, 0.0085)]):
    points = [(x, y, 0), (x, y + 0.023, -0.018), (x, y + 0.009, -0.035), (x, y - 0.013, -0.030)]
    if closed_palm:
        points = [(x, y, 0), (x, y + 0.020, -0.017),
                  (x, y + 0.005, -0.028), (x, y - 0.016, -0.019)]
    for joint, point in enumerate(points):
        volume('Finger_%d_joint_%d' % (i, joint), point, (radius, radius, radius))
    for joint in range(3):
        segment('Finger_%d_phalanx_%d' % (i, joint), points[joint], points[joint + 1], radius * 0.93)
thumb = [(-0.033, 0.032, -0.003), (-0.039, 0.053, -0.018), (-0.017, 0.063, -0.038), (0.001, 0.063, -0.037)]
if refine:
    thumb = [(-0.030, 0.029, -0.004), (-0.033, 0.051, -0.020), (-0.014, 0.060, -0.039), (-0.002, 0.063, -0.039)]
if thumb_contact:
    # Oppose the thumb across the exterior index/middle finger pads. The
    # previous abducted proximal segment left a conspicuous side-view gap.
    thumb = [(-0.029, 0.039, -0.006), (-0.031, 0.060, -0.022),
             (-0.015, 0.070, -0.043), (0.003, 0.070, -0.044)]
if closed_palm:
    thumb = [(-0.029, 0.039, -0.006), (-0.031, 0.062, -0.020),
             (-0.015, 0.074, -0.038), (0.003, 0.074, -0.039)]
for i, point in enumerate(thumb):
    volume('Thumb_joint_%d' % i, point, (0.009, 0.010, 0.008) if refine else (0.011, 0.011, 0.011))
for i in range(3):
    segment('Thumb_phalanx_%d' % i, thumb[i], thumb[i + 1], 0.0085 if refine else 0.010)
bpy.ops.object.select_all(action='DESELECT')
for part in parts:
    part.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
fist = bpy.context.object
fist.name = 'Cass_Fist_Volume_Study'
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
remesh = fist.modifiers.new('Connected_sculpt_volume', 'REMESH')
remesh.mode = 'VOXEL'
remesh.voxel_size = 0.0012
bpy.ops.object.modifier_apply(modifier=remesh.name)
smooth = fist.modifiers.new('Surface_relax', 'SMOOTH')
smooth.factor = 0.35
smooth.iterations = 2
bpy.ops.object.modifier_apply(modifier=smooth.name)
for polygon in fist.data.polygons:
    polygon.use_smooth = True
material = bpy.data.materials.new('Neutral_skin_study')
material.diffuse_color = (0.52, 0.30, 0.21, 1)
material.use_nodes = True
bsdf = material.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Base Color'].default_value = (0.52, 0.30, 0.21, 1)
bsdf.inputs['Roughness'].default_value = 0.62
fist.data.materials.append(material)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.render.resolution_x = 900
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.world = bpy.data.worlds.new('StudyWorld')
scene.world.color = (0.1, 0.1, 0.1)
bpy.ops.object.camera_add(location=(0.19, 0.20, -0.22))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0.05, -0.01)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 0.17
scene.camera = camera
bpy.ops.object.light_add(type='AREA', location=(0.1, 0.15, -0.3))
light = bpy.context.object
light.data.energy = 3
light.data.size = 0.3
light.rotation_euler = (Vector((0, 0.05, 0)) - light.location).to_track_quat('-Z', 'Y').to_euler()
out = Path('build/cass_fist_review/' + ('volume_candidate_v5' if closed_palm else 'volume_candidate_v4' if thumb_contact else 'volume_candidate_v3' if anatomy else 'volume_candidate_v2' if refine else 'volume_candidate_v1')).resolve()
out.mkdir(parents=True, exist_ok=True)
scene.render.filepath = str(out / 'fist.png')
bpy.ops.render.render(write_still=True)
if anatomy:
    for name, position in [('dorsal', (0.16, 0.16, 0.25)), ('profile', (-0.26, 0.09, -0.10))]:
        camera.location = position
        camera.rotation_euler = (Vector((0, 0.05, -0.01)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
        light.location = Vector(position) * 1.3
        light.rotation_euler = (Vector((0, 0.05, 0)) - light.location).to_track_quat('-Z', 'Y').to_euler()
        scene.render.filepath = str(out / (name + '.png'))
        bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out / 'fist.blend'))
bm = bmesh.new()
bm.from_mesh(fist.data)
unvisited = set(bm.verts)
components = []
while unvisited:
    stack = [unvisited.pop()]
    count = 0
    while stack:
        vertex = stack.pop()
        count += 1
        for edge in vertex.link_edges:
            neighbor = edge.other_vert(vertex)
            if neighbor in unvisited:
                unvisited.remove(neighbor)
                stack.append(neighbor)
    components.append(count)
topology = {'connected_components': sorted(components, reverse=True),
            'nonmanifold_edges': sum(not e.is_manifold for e in bm.edges)}
bm.free()
(out / 'status.json').write_text(json.dumps({'reference': 'assets/art/reference/cass_fist/hands_anatomy_v1.png', 'runtime_promoted': False, 'visual_approved': False, 'scope': 'Fist volume study; thumb placement, knuckle planes, finger curvature, skin texture, wrist seam and rigging still need review', 'vertices': len(fist.data.vertices), 'topology': topology}, indent=2))
