"""Bake a span-aware, camera-matched M01 window family for staging review.

The live M01 windows are thin breakable strips.  This builds their visual
counterpart from geometry rather than scaling the full-height window preview.
It intentionally does not create runtime files or alter GlassWindow drawing.
"""
from pathlib import Path
import json, math, sys
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from m01_imagegen_materials import apply_reviewed_source
OUT=ROOT/'assets/art/prerendered/m01_sunset_palms/staging/window_strip_family_v1'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name,color,source=None,metal=0.0):
    value=bpy.data.materials.new(name);value.use_nodes=True
    shader=value.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Roughness'].default_value=.58
    shader.inputs['Metallic'].default_value=metal
    if source:apply_reviewed_source(value,source)
    return value
frame=mat('Window painted motel frame',(.52,.56,.48),'painted_metal',.12)
cloth=mat('Teal motel curtain fabric',(.035,.16,.18),'towel')
glass=mat('Window night glass',(.06,.16,.20))
brass=mat('Curtain rod brass',(.44,.28,.10),metal=.72)

def box(root,name,pos,size,material,bevel=.01):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
    obj=bpy.context.object;obj.name=name;obj.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(material);obj.parent=root
    mod=obj.modifiers.new('Rounded edge','BEVEL');mod.width=bevel;mod.segments=3
    return obj

def build(width,name):
    root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
    z=.72;h=1.12;half=width*.5
    # Frame and sill sit at a common floor anchor; only pane spans vary.
    for x in (-half,half): box(root,'Frame upright',(x,0,z),(0.07,.10,h),frame)
    for zz in (z-h*.5,z+h*.5): box(root,'Frame rail',(0,0,zz),(width+.10,.10,.07),frame)
    box(root,'Projecting sill',(0,-.06,z-h*.5-.045),(width+.18,.20,.08),frame)
    box(root,'Night glass',(0,.012,z),(width-.10,.008,h-.10),glass,.002)
    # Repeated slats retain scale across wide spans instead of stretching art.
    for x in [(-half+.18)+step*.30 for step in range(max(1,round((width-.36)/.30)+1))]:
        for step in range(9):
            slat=box(root,'Blind slat',(x,-.053,z+h*.36-step*.09),(.27,.070,.012),frame,.002)
            slat.rotation_euler.x=math.radians(-62)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.018,depth=width+.34,location=(0,-.12,z+h*.5+.06),rotation=(0,math.pi*.5,0))
    rod=bpy.context.object;rod.name='Curtain rod';rod.data.materials.append(brass);rod.parent=root
    # Fixed-width gathered curtains at both ends; the centre is left legible.
    for side in (-1,1):
        for index in range(8):
            x=side*(half-.08-index*.035)
            panel=box(root,'Gathered curtain fold',(x,-.11,z),(.042,.052,h+.10),cloth,.006)
            panel.rotation_euler.y=side*.13
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=.042,location=(side*(half+.17),-.12,z+h*.5+.06))
        finial=bpy.context.object;finial.name='Curtain rod finial';finial.data.materials.append(brass);finial.parent=root
    return root

def dispose(root):
    for child in list(root.children):
        bpy.data.objects.remove(child,do_unlink=True)
    bpy.data.objects.remove(root,do_unlink=True)

scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard';scene.world=bpy.data.worlds.new('Window family neutral world')
look=Vector((0,0,.45));bpy.ops.object.camera_add(location=look+Vector((0,-4.0,4.75)))
camera=bpy.context.object;camera.rotation_euler=(look-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=3.2;scene.camera=camera
for pos,energy in [((-2,-3,4),150),((2,2,3),80)]:
    bpy.ops.object.light_add(type='AREA',location=pos)
    light=bpy.context.object;light.data.energy=energy;light.data.size=3;light.rotation_euler=(look-light.location).to_track_quat('-Z','Y').to_euler()
frames=[]
for span in (32,48,64,128):
    width=span/16.0
    camera.data.ortho_scale=max(3.2,width+1.2)
    anchor=world_to_camera_view(scene,camera,Vector((0,0,0)))
    root=build(width,'M01 horizontal %dpx window'%span)
    path=OUT/('window_h_%03d.png'%span);scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    frames.append({'file':path.name,'orientation':'horizontal','span_px':span,'pixels_per_metre':512/camera.data.ortho_scale,'floor_anchor_px':[anchor.x*512,(1-anchor.y)*512]})
    dispose(root)
camera.data.ortho_scale=3.2
anchor=world_to_camera_view(scene,camera,Vector((0,0,0)))
root=build(2.0,'M01 vertical 32px window');root.rotation_euler.z=math.pi*.5
path=OUT/'window_v_032.png';scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
frames.append({'file':path.name,'orientation':'vertical','span_px':32,'pixels_per_metre':512/camera.data.ortho_scale,'floor_anchor_px':[anchor.x*512,(1-anchor.y)*512]})
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'window_strip_family.blend'))
(OUT/'contract.json').write_text(json.dumps({'runtime_approved':False,'camera_elevation_degrees':49.72,'frames':frames,'source':'Authored Blender geometry with reviewed M01 ImageGen material sources','pending':['Actual Camera2D projection review','Twenty-window placement, light-mask and actor-occlusion review','Break-state handoff to legacy GlassWindow art','Runtime integration approval']},indent=2)+'\n',encoding='utf-8')
print('M01_WINDOW_STRIP_FAMILY: four horizontal spans plus vertical staging frame')
