"""Destroyed door continuation from the same ImageGen-backed native model."""
from pathlib import Path
import json
import math
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/art/prerendered/m01_sunset_palms/staging/guest_door_v1'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'guest_door.blend'))
scene=bpy.context.scene
scene.frame_set(1)
hinge=bpy.data.objects['Door hinge - independently animatable']
for obj in hinge.children_recursive:
    obj.hide_render=True
wood=bpy.data.materials['ImageGen walnut frame']
paint=bpy.data.materials['ImageGen painted metal finish']
pieces=[]
for index,(x,y,width,length,angle) in enumerate((
    (-.25,-.36,.12,.62,-.35),(.08,-.48,.18,.50,.3),
    (.34,-.30,.10,.47,-.55),(-.05,-.80,.14,.35,.7),
    (.27,-.72,.09,.31,-.2))):
    # Irregular polygon edges retain visible timber under the paint face.
    outline=[(-width/2,-length/2),(width*.1,-length/2+.025),
        (width/2,-length/2-.014),(width/2,length/2-.024),
        (0,length/2+.015),(-width/2,length/2-.035)]
    verts=[(px,py,z) for z in (0,.032) for px,py in outline]
    n=len(outline)
    faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    mesh=bpy.data.meshes.new('Jagged painted door board')
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    mesh.materials.append(wood)
    mesh.materials.append(paint)
    mesh.polygons[1].material_index=1
    obj=bpy.data.objects.new('Detached door fragment '+str(index),mesh)
    bpy.context.collection.objects.link(obj)
    obj.location=(x,y,.012+index*.008)
    obj.rotation_euler.z=angle
    pieces.append(obj)
scene['damage_state']='destroyed; standing leaf hidden; fragments nonblocking in runtime'
scene['runtime_approved']=False
scene['imagegen_reference']='assets/art/materials/m01/batch_v1/guest_door_reference.png'
camera=scene.camera
camera.location=(2.3,-4,2.3)
camera.rotation_euler=(Vector((0,-.15,.9))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=2.8
scene.render.filepath=str(OUT/'guest_door_destroyed_review.png')
assert all(obj.hide_render for obj in hinge.children_recursive)
assert len(pieces)==5
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'guest_door_destroyed.blend'))
bpy.ops.render.render(write_still=True)
for obj in scene.objects:
    if obj.name.startswith('Stationary'):
        obj.hide_render=True
camera.location=(0,-.5,10)
camera.rotation_euler=(0,0,0)
camera.data.ortho_scale=1.2
scene.render.resolution_x=384
scene.render.resolution_y=384
scene.render.filepath=str(OUT/'guest_door_debris_topdown.png')
bpy.ops.render.render(write_still=True)
(OUT/'destroyed_state_contract.json').write_text(json.dumps({
    'standing_leaf_visible':False,'stationary_frame_visible':True,
    'fragment_count':len(pieces),'fragment_colliders_required':False,
    'debris_image':'guest_door_debris_topdown.png','hinge_pixel':[54.4,32],
    'image_size':[384,384],'scale_for_32px_leaf':32/275.2,
    'runtime_approved':False,'layout_changed':False,
    'remaining':['Godot projection and actual map review','Hardware debris and finer splinter detail']
},indent=2),encoding='utf-8')
print('M01_DOOR_DESTROYED: leaf hidden; stationary frame and five detached boards rendered')
