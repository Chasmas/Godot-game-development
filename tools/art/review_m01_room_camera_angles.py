"""Compare authored room angles; never rotate gameplay visuals independently of physics."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'assets/art/prerendered/m01_sunset_palms/staging'
OUT=BASE/'guest_room_camera_review_v1';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE/'guest_room_composition_v3/guest_room_composition.blend'))
scene=bpy.context.scene;camera=scene.camera
scene.render.resolution_x=960;scene.render.resolution_y=720;scene.cycles.samples=24
reviews=[]
for yaw in (0,30):
    elevation=math.radians(50);angle=math.radians(yaw)
    target=Vector((0,.15,.15))
    camera.location=target+Vector((math.sin(angle)*math.cos(elevation),-math.cos(angle)*math.cos(elevation),math.sin(elevation)))*15
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    bpy.context.view_layer.update()
    points={}
    for label,point in [('origin',(0,0,0)),('one_metre_x',(1,0,0)),('one_metre_y',(0,1,0))]:
        projected=world_to_camera_view(scene,camera,Vector(point))
        points[label]=[projected.x*960,(1-projected.y)*720]
    scene.render.filepath=str(OUT/f'room_elevation50_yaw{yaw:02}.png')
    bpy.ops.render.render(write_still=True)
    reviews.append({'yaw_degrees':yaw,'elevation_degrees':50,'ground_projection_probes_px':points})
(OUT/'projection_review.json').write_text(json.dumps({'runtime_approved':False,'views':reviews,'requirements':['Chosen yaw requires consistent world-to-screen mapping for floors, objects, characters, aim and collisions','Do not rotate or squash background alone','Check actor occlusion and clear door approaches in an actual gameplay prototype'],'scope':'Blender composition comparison only; does not demonstrate runtime camera compatibility'},indent=2)+'\n',encoding='utf-8')
print('ROOM CAMERA REVIEW: two rendered angles with measured ground projection probes')
