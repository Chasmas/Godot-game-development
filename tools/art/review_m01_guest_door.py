"""Reconstruct the ImageGen guest door as separate, animatable Blender parts."""
from pathlib import Path
import json
import math
import sys
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from m01_imagegen_materials import apply_reviewed_source
OUT = ROOT / 'assets/art/prerendered/m01_sunset_palms/staging/guest_door_v1'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name, color, metallic=0, source=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = .48
    if source:
        apply_reviewed_source(m, source)
    return m

wood = mat('ImageGen walnut frame', (.24,.12,.05), source='walnut')
paint = mat('ImageGen painted metal finish', (.7,.65,.5), source='painted_metal')
brass = mat('Reference brass hardware', (.55,.34,.1), .78)
dark = mat('Peephole glass', (.015,.02,.022), .2)
bpy.ops.object.empty_add(location=(-.43,0,0))
hinge = bpy.context.object
hinge.name = 'Door hinge - independently animatable'

def cube(name, pos, size, material, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    o = bpy.context.object
    o.name = name
    o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    b = o.modifiers.new('Manufactured edge', 'BEVEL')
    b.width = .005
    b.segments = 3
    if parent:
        matrix = o.matrix_world.copy()
        o.parent = parent
        o.matrix_world = matrix
    return o

for x in (-.48,.48):
    cube('Stationary walnut jamb', (x,0,1.0275), (.09,.14,2.055), wood)
cube('Stationary walnut lintel', (0,0,2.1), (1.05,.14,.09), wood)
cube('Movable door slab', (0,0,1.02), (.86,.055,2.04), paint, hinge)
for lo,hi in ((.24,.73),(.85,1.85)):
    cube('Recessed panel', (0,-.031,(lo+hi)/2), (.65,.012,hi-lo), paint, hinge)
    for x in (-.34,.34):
        cube('Panel vertical moulding', (x,-.045,(lo+hi)/2), (.022,.018,hi-lo+.04), paint, hinge)
    for z in (lo-.02,hi+.02):
        cube('Panel horizontal moulding', (0,-.045,z), (.70,.018,.022), paint, hinge)
cube('Brass kickplate', (0,-.044,.14), (.79,.018,.24), brass, hinge)
cube('Handle escutcheon', (.34,-.054,.91), (.085,.022,.28), brass, hinge)
def cylinder(name, pos, radius, depth, material, parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=radius, depth=depth,
        location=pos, rotation=(math.pi/2,0,0))
    obj=bpy.context.object
    obj.name=name
    obj.data.materials.append(material)
    bevel=obj.modifiers.new('Hardware rounded rim','BEVEL')
    bevel.width=.0015
    bevel.segments=3
    if parent:
        matrix=obj.matrix_world.copy()
        obj.parent=parent
        obj.matrix_world=matrix
    return obj

cylinder('Key cylinder', (.34,-.075,.98), .023,.022,brass,hinge)
cube('Key slot', (.34,-.088,.98), (.004,.002,.016), dark,hinge)
cylinder('Lever rose', (.34,-.083,.85), .025,.03,brass,hinge)
cube('Lever handle', (.285,-.104,.85), (.16,.037,.027), brass, hinge)
cube('Room plaque', (0,-.061,1.57), (.24,.016,.09), brass, hinge)
for name,z,r,material in (('Peephole rim',1.40,.019,brass),('Peephole glass',1.40,.012,dark)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=r, location=(0,-.059,z))
    o=bpy.context.object
    o.name=name
    o.scale.y=.3
    o.data.materials.append(material)
    matrix=o.matrix_world.copy()
    o.parent=hinge
    o.matrix_world=matrix
bpy.ops.object.text_add(location=(-.09,-.072,1.546), rotation=(1.570796,0,0))
o=bpy.context.object
o.data.body='204'
o.data.size=.066
o.data.extrude=.0004
o.data.materials.append(dark)
matrix=o.matrix_world.copy()
o.parent=hinge
o.matrix_world=matrix
scene=bpy.context.scene
scene['imagegen_reference']='assets/art/materials/m01/batch_v1/guest_door_reference.png'
scene['runtime_approved']=False
scene['review_note']='Full-height model; gameplay cutaway projection and collision still require review.'
bpy.ops.object.camera_add(location=(3,-5,2.8))
camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,1.05))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'
camera.data.ortho_scale=2.65
scene.camera=camera
scene.world=bpy.data.worlds.new('Door review world')
scene.world.color=(.12,.12,.12)
bpy.ops.object.light_add(type='AREA', location=(0,-3,4))
bpy.context.object.data.energy=400
bpy.context.object.data.size=3
scene.render.engine='CYCLES'
scene.cycles.samples=16
scene.render.resolution_x=720
scene.render.resolution_y=900
scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.filepath=str(OUT/'guest_door_review.png')
hinge.rotation_euler.z=0
hinge.keyframe_insert(data_path='rotation_euler',frame=1)
hinge.rotation_euler.z=math.radians(85)
hinge.keyframe_insert(data_path='rotation_euler',frame=40)
scene.frame_start=1
scene.frame_end=40
scene.frame_set(1)
bpy.context.view_layer.update()
frame_objects=[obj for obj in scene.objects if obj.name.startswith('Stationary')]
frame_closed={obj.name:list(obj.matrix_world.translation) for obj in frame_objects}
slab=bpy.data.objects['Movable door slab']
closed=list(slab.matrix_world.translation)
scene.frame_set(40)
bpy.context.view_layer.update()
opened=list(slab.matrix_world.translation)
assert all((obj.matrix_world.translation-Vector(frame_closed[obj.name])).length < 1e-6 for obj in frame_objects)
assert (Vector(opened)-Vector(closed)).length > .4
(OUT/'hinge_review.json').write_text(json.dumps({
    'closed_slab_center':closed,'open_slab_center':opened,
    'stationary_frame_verified':True,'opening_degrees':85,
    'runtime_approved':False,'collision_validated':False},indent=2),encoding='utf-8')
scene.frame_set(1)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'guest_door.blend'))
bpy.ops.render.render(write_still=True)
scene.frame_set(40)
scene.render.filepath=str(OUT/'guest_door_open_review.png')
bpy.ops.render.render(write_still=True)
scene.frame_set(1)
for obj in frame_objects:
    obj.hide_render=True
camera.location=(0,0,10)
camera.rotation_euler=(0,0,0)
camera.data.ortho_scale=1.2
scene.render.resolution_x=384
scene.render.resolution_y=192
scene.render.filepath=str(OUT/'guest_door_leaf_topdown.png')
bpy.ops.render.render(write_still=True)
(OUT/'leaf_projection_contract.json').write_text(json.dumps({
    'image':'guest_door_leaf_topdown.png','image_size':[384,192],
    'projection':'orthographic top-down; image +x is leaf direction',
    'hinge_pixel':[54.4,96],'leaf_tip_pixel':[329.6,96],
    'leaf_width_m':.86,'texture_scale_for_32px_leaf':32/(.86*320),
    'frame_included':False,'runtime_approved':False,
    'remaining':['Check actual gameplay illumination and readable thickness.',
        'Provide damaged leaf render before replacing destructible runtime art.']},indent=2),encoding='utf-8')
print('M01_GUEST_DOOR: separate hinged slab and stationary frame saved; preview only')
