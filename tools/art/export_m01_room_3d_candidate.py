"""Export existing room geometry for shared 3D visual review; no physics migration."""
from pathlib import Path
import bpy, math, json, sys, argparse
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/prerendered/m01_sunset_palms/staging'
parser=argparse.ArgumentParser()
parser.add_argument('--room101',action='store_true')
parser.add_argument('--room-version',choices=['19','20','21'],default='19')
parser.add_argument('--yaw',type=float,default=0,help='Staging camera orbit in degrees')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
source=('room_101_v'+args.room_version+'/room_101.blend') if args.room101 else 'guest_room_composition_v10/guest_room_composition.blend'
OUT = BASE / (('room_101_shared_3d_v1' if args.room_version=='19' else 'room_101_shared_3d_v'+args.room_version) if args.room101 else 'guest_room_shared_3d_v1')
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE / source))
missing = [im.filepath for im in bpy.data.images if im.filepath and not im.packed_file and not Path(bpy.path.abspath(im.filepath)).is_file()]
assert not missing, missing
scene = bpy.context.scene
target = Vector((4,-2,.15)) if args.room101 else Vector((0,.15,.15))
angle = math.radians(50)
yaw=math.radians(args.yaw)
scene.camera.location = target + Vector((math.sin(yaw)*math.cos(angle),-math.cos(yaw)*math.cos(angle),math.sin(angle))) * 15
scene.camera.rotation_euler = (target-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera.data.type = 'ORTHO'
scene.camera.data.ortho_scale = 11 if args.room101 else 9.1
# glTF carries UVs, but cannot carry Blender's object-space BOX shader network.
# Project the reviewed physical repeat into explicit UVs on each face.
uv_objects = []
reviewed_materials = set()
for obj in scene.objects:
    if obj.type != 'MESH': continue
    reviewed_slots = {i: m for i,m in enumerate(obj.data.materials) if m and m.get('imagegen_source') and m.get('repeat_metres')}
    if not reviewed_slots: continue
    obj.data = obj.data.copy()
    uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name='Physical texture repeat')
    for face in obj.data.polygons:
        material = reviewed_slots.get(face.material_index)
        if material is None: continue
        repeat = float(material['repeat_metres'])
        axis = max(range(3), key=lambda i: abs(face.normal[i]))
        axes = [(1,2), (0,2), (0,1)][axis]
        for loop in face.loop_indices:
            point = obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (point[axes[0]]/repeat, point[axes[1]]/repeat)
        reviewed_materials.add(material)
    uv_objects.append(obj.name)
for material in reviewed_materials:
    nodes, links = material.node_tree.nodes, material.node_tree.links
    image = next(n for n in nodes if n.type == 'TEX_IMAGE' and n.get('m01_reviewed_source'))
    image.projection = 'FLAT'
    for link in list(image.inputs['Vector'].links): links.remove(link)
    coords = nodes.new('ShaderNodeTexCoord')
    links.new(coords.outputs['UV'], image.inputs['Vector'])
bpy.ops.export_scene.gltf(filepath=str(OUT / 'room.glb'), export_format='GLB',
                          export_cameras=True, export_lights=True, export_animations=False,export_apply=True)
(OUT / 'review.json').write_text(json.dumps({'runtime_approved':False,
    'source':source, 'physics_change':False,'camera_yaw_degrees':args.yaw,
    'scope':'Shared 3D environment/actor visual stage only',
    'physical_uv_objects':uv_objects,
    'uv_conversion':'Dominant local face projection at authored metres per repeat; BOX seam blend is not reproduced',
    'pending':['Compare Godot materials and lighting to approved reference',
               'Verify actual depth occlusion with actors',
               'Map existing floor physics and aim through the shared camera']}, indent=2))
print('M01 SHARED 3D ROOM EXPORTED')
