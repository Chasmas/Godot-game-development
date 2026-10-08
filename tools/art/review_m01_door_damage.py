"""Author a damaged intermediate state without replacing intact door geometry."""
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/art/prerendered/m01_sunset_palms/staging/guest_door_v1'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'guest_door.blend'))
scene=bpy.context.scene
scene.frame_set(1)
hinge=bpy.data.objects['Door hinge - independently animatable']
wood=bpy.data.materials['ImageGen walnut frame']
crack=bpy.data.materials.new('Exposed dark crack')
crack.diffuse_color=(.09,.065,.035,1)
paths=[[(.40,.92),(.37,1.10),(.40,1.24),(.36,1.39)],
       [(.36,1.39),(.30,1.46),(.32,1.65),(.28,1.82)],
       [(-.28,1.22),(-.20,1.13),(-.22,1.02),(-.12,.94)],
       [(-.12,.94),(.02,.88),(.09,.91)],
       [(.20,.71),(.15,.59),(.19,.48),(.13,.37)],
       [(-.27,.58),(-.20,.47),(-.22,.32)]]
for index,points in enumerate(paths):
    curve=bpy.data.curves.new('Impact paint fissure '+str(index),'CURVE')
    curve.dimensions='3D'
    curve.bevel_depth=.0009
    curve.bevel_resolution=2
    spline=curve.splines.new('POLY')
    spline.points.add(len(points)-1)
    for p,(x,z) in zip(spline.points,points):
        p.co=(x,-.046,z,1)
    obj=bpy.data.objects.new(curve.name,curve)
    bpy.context.collection.objects.link(obj)
    curve.materials.append(crack)
    matrix=obj.matrix_world.copy()
    obj.parent=hinge
    obj.matrix_world=matrix
# Exposed wood at the latch-side impact matches the approved damage source.
outline=[(.385,.99),(.405,1.07),(.392,1.14),(.425,1.25),(.416,1.10),(.43,.99)]
mesh=bpy.data.meshes.new('Latch-side chipped paint')
mesh.from_pydata([(x,-.0305,z) for x,z in outline],[],[tuple(range(len(outline)))])
mesh.update()
obj=bpy.data.objects.new('Latch impact exposed wood',mesh)
bpy.context.collection.objects.link(obj)
mesh.materials.append(wood)
matrix=obj.matrix_world.copy()
obj.parent=hinge
obj.matrix_world=matrix
scene['imagegen_damage_reference']='assets/art/materials/m01/batch_v1/damaged_door_reference_v2.png'
scene['damage_state']='chipped intermediate; not fully destroyed'
scene['runtime_approved']=False
scene.render.filepath=str(OUT/'guest_door_damaged_review.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'guest_door_damaged.blend'))
bpy.ops.render.render(write_still=True)
print('M01_DOOR_DAMAGE: intact identity retained; intermediate chipped state only')
