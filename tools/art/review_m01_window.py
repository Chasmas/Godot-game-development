"""Native window reconstruction from the reviewed ImageGen reference."""
from pathlib import Path
import math
import sys
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from m01_imagegen_materials import apply_reviewed_source
OUT=ROOT/'assets/art/prerendered/m01_sunset_palms/staging/window_v1'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def material(name,color,source=None):
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    shader=mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Roughness'].default_value=.5
    if source:
        apply_reviewed_source(mat,source)
    return mat
frame=material('ImageGen aged painted frame',(.65,.62,.5),'painted_metal')
cloth=material('Teal fabric based on ImageGen window reference',(.05,.22,.23))
brass=material('Aged brass curtain rod',(.4,.28,.12))
brass.node_tree.nodes.get('Principled BSDF').inputs['Metallic'].default_value=.7
glass=material('Separate glass - environment reflection only',(.18,.26,.3))
shader=glass.node_tree.nodes.get('Principled BSDF')
shader.inputs['Transmission Weight'].default_value=.9
shader.inputs['Roughness'].default_value=.1
def box(name,pos,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
    obj=bpy.context.object
    obj.name=name
    obj.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(mat)
    mod=obj.modifiers.new('Soft frame edges','BEVEL')
    mod.width=.004
    mod.segments=3
    return obj
for x in (-.9,0,.9):
    box('Window frame upright',(x,0,1.1),(.055,.09,1.145),frame)
for z in (.5,1.7):
    box('Window frame rail',(0,0,z),(1.85,.09,.055),frame)
box('Projecting sill',(0,-.045,.46),(2,.19,.07),frame)
for side in (-1,1):
    box('Independent glass pane',(.45*side,.018,1.1),(.84,.006,1.14),glass)
    for step in range(10):
        slat=box('Independent blind slat',(.45*side,-.057,1.65-step*.047),(.82,.078,.009),frame)
        slat.rotation_euler.x=math.radians(-65)
    # Authored folds are geometry, not shadows sampled from the source bitmap.
    verts=[]
    faces=[]
    columns=64
    for row in range(13):
        z=.5+row*.1
        for column in range(columns+1):
            u=column/columns
            x=side*(.72+u*.31)
            y=-.12-.028*math.cos(u*math.pi*10)
            verts.append((x,y,z+.005*math.sin(u*math.pi*10)))
    for row in range(12):
        for column in range(columns):
            a=row*(columns+1)+column
            faces.append((a,a+1,a+columns+2,a+columns+1))
    mesh=bpy.data.meshes.new('Pleated curtain geometry')
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new('Independent teal curtain '+str(side),mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(cloth)
    for poly in mesh.polygons:
        poly.use_smooth=True
    obj.shape_key_add(name='Basis')
    breeze=obj.shape_key_add(name='Gentle draft - anchored top')
    for index,point in enumerate(breeze.data):
        strength=0 if index>=12*(columns+1) else max(0,min(1,(1.7-point.co.z)/1.2))
        point.co.y-=.022*strength*strength
        point.co.x+=side*.009*strength
    breeze.value=0
    breeze.keyframe_insert(data_path='value',frame=1)
    breeze.value=1
    breeze.keyframe_insert(data_path='value',frame=25)
    breeze.value=0
    breeze.keyframe_insert(data_path='value',frame=49)
    basis=obj.data.shape_keys.key_blocks['Basis']
    top_indices=list(range(12*(columns+1),13*(columns+1)))
    assert top_indices
    assert all((breeze.data[i].co-basis.data[i].co).length<.00001 for i in top_indices)
    assert max((a.co-b.co).length for a,b in zip(breeze.data,basis.data))>.02
    solid=obj.modifiers.new('Fabric thickness','SOLIDIFY')
    solid.thickness=.001
    for ring in range(6):
        bpy.ops.mesh.primitive_torus_add(major_radius=.02,minor_radius=.003,
            location=(side*(.73+ring*.055),-.12,1.73),rotation=(0,math.pi/2,0))
        bpy.context.object.data.materials.append(brass)
bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.015,depth=2.22,
    location=(0,-.12,1.76),rotation=(0,math.pi/2,0))
bpy.context.object.name='Independent brass curtain rod'
bpy.context.object.data.materials.append(brass)
def cord(name, points, radius, mat):
    curve=bpy.data.curves.new(name,'CURVE')
    curve.dimensions='3D'
    curve.bevel_depth=radius
    curve.bevel_resolution=3
    spline=curve.splines.new('POLY')
    spline.points.add(len(points)-1)
    for p,co in zip(spline.points,points):
        p.co=(*co,1)
    obj=bpy.data.objects.new(name,curve)
    bpy.context.collection.objects.link(obj)
    curve.materials.append(mat)
    return obj
for side in (-1,1):
    box('Rod wall bracket',(side*.99,-.045,1.76),(.065,.025,.10),brass)
    cord('Rod support',[(side*.99,-.045,1.76),(side*.99,-.12,1.76)],.008,brass)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=.031,
        location=(side*1.13,-.12,1.76))
    bpy.context.object.name='Brass rod finial'
    bpy.context.object.data.materials.append(brass)
    for x in (side*.18,side*.68):
        cord('Blind ladder cord',[(x,-.099,1.67),(x,-.099,1.20)],.0015,frame)
    cord('Blind pull cord',[(side*.68,-.099,1.67),(side*.68,-.105,1.10)],.0015,frame)
    box('Blind cord pull',(side*.68,-.105,1.08),(.012,.012,.035),frame)
scene=bpy.context.scene
scene.frame_start=1
scene.frame_end=49
scene.render.fps=24
scene.frame_set(1)
scene['imagegen_reference']='assets/art/materials/m01/batch_v1/window_reference.png'
scene['runtime_approved']=False
scene['reflection_note']='No sunset image baked into glass; live environment required.'
bpy.ops.object.camera_add(location=(3,-5,2.6))
camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,1.1))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'
camera.data.ortho_scale=2.65
scene.camera=camera
scene.world=bpy.data.worlds.new('Window review world')
scene.world.color=(.2,.2,.2)
bpy.ops.object.light_add(type='AREA',location=(0,-3,4))
bpy.context.object.data.energy=400
bpy.context.object.data.size=3
scene.render.engine='CYCLES'
scene.cycles.samples=16
scene.render.resolution_x=960
scene.render.resolution_y=720
scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.filepath=str(OUT/'window_review.png')
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'window.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'window_review.glb'),
    export_format='GLB',export_cameras=False,export_lights=False,
    export_animations=True,export_morph=True)
bpy.ops.render.render(write_still=True)
print('M01_WINDOW: frame, panes, blinds, curtains and rod separate; preview only')
