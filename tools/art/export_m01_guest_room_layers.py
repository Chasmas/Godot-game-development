"""Export measured oblique room layers for gameplay projection review only."""
from pathlib import Path
import bpy, json, math, hashlib, re
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/prerendered/m01_sunset_palms/staging'
OUT = BASE / 'guest_room_gameplay_layers_v2'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE / 'guest_room_composition_v10/guest_room_composition.blend'))
missing = [im.filepath for im in bpy.data.images if im.filepath and not im.packed_file and not Path(bpy.path.abspath(im.filepath)).is_file()]
assert not missing, f'Unresolved image sources: {missing}'
scene = bpy.context.scene
scene.render.film_transparent = True
scene.render.resolution_x = 960
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.cycles.samples = 24
camera = scene.camera
target = Vector((0, .15, .15))
elevation = math.radians(50)
camera.location = target + Vector((0, -math.cos(elevation), math.sin(elevation))) * 15
camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
bpy.context.view_layer.update()
probes = {}
for key, point in [('origin', (0, 0, 0)), ('x', (1, 0, 0)), ('y', (0, 1, 0)), ('height', (0, 0, 1))]:
    p = world_to_camera_view(scene, camera, Vector(point))
    probes[key] = [p.x * 960, (1 - p.y) * 720]
meshes = [o for o in scene.objects if o.type in {'MESH', 'CURVE', 'FONT'}]
initial = {o.name: o.hide_render for o in meshes}
floors = {'Room floor', 'Bathroom tile floor', 'Entry threshold tile floor'}
def category(obj):
    if obj.name in floors: return 'floor'
    if obj.name.startswith(('Headboard wall', 'West wall', 'Bathroom inner wall', 'Bathroom rear tile wall', 'Bathroom east tile wall', 'North skirting', 'West skirting')): return 'walls'
    return 'furniture'
inventory = {kind: [o.name for o in meshes if category(o) == kind and not initial[o.name]] for kind in ['floor', 'walls', 'furniture']}
for kind in ['floor', 'walls', 'furniture', 'complete']:
    for obj in meshes:
        obj.hide_render = initial[obj.name] or (kind != 'complete' and category(obj) != kind)
    scene.render.filepath = str(OUT / f'{kind}.png')
    bpy.ops.render.render(write_still=True)
for obj in meshes: obj.hide_render = initial[obj.name]
pieces = []
for root in sorted(scene.objects, key=lambda o: o.name):
    if root.type != 'EMPTY' or not re.search(r' placement(?:\.\d+)?$', root.name): continue
    members = [o for o in root.children_recursive if o in meshes and not initial[o.name]]
    if not members: continue
    corners = [o.matrix_world @ Vector(c) for o in members if o.type == 'MESH' for c in o.bound_box]
    if not corners: continue
    low = [min(p[i] for p in corners) for i in range(3)]
    high = [max(p[i] for p in corners) for i in range(3)]
    anchor = Vector(((low[0]+high[0])/2, (low[1]+high[1])/2, low[2]))
    projected = world_to_camera_view(scene, camera, anchor)
    filename = f'piece_{len(pieces):02d}.png'
    for obj in meshes: obj.hide_render = obj not in members
    scene.render.filepath = str(OUT / filename)
    bpy.ops.render.render(write_still=True)
    pieces.append({'name': root.name, 'file': filename, 'objects': [o.name for o in members],
                   'anchor_metres': list(anchor), 'anchor_pixels': [projected.x*960, (1-projected.y)*720],
                   'visual_bounds_metres': [low, high],
                   'collision_approved': False})
for obj in meshes: obj.hide_render = initial[obj.name]
source = BASE / 'guest_room_composition_v10/guest_room_composition.blend'
(OUT / 'projection.json').write_text(json.dumps({'runtime_approved': False, 'source': 'guest_room_composition_v10', 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'elevation_degrees': 50, 'yaw_degrees': 0, 'floor_probes_px': probes, 'layers': inventory, 'pieces': pieces, 'bounds_scope': 'Visual bounding boxes only; not approved collision footprints. Isolated renders omit cross-object shadows.', 'pending': ['Align actors and input through the measured floor transform', 'Validate individual furniture occlusion and collision footprints', 'Validate traversal and aim in gameplay', 'Preserve complete-room lighting when composing isolated pieces']}, indent=2) + '\n')
print('M01 ROOM LAYER EXPORT DONE')
