import bpy,os,json
from mathutils import Vector
out=os.path.abspath('build/consumable_head_landmarks');os.makedirs(out,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath('build/consumable_contact_isolated/guard.glb'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');head=arm.pose.bones.get('Head');p=arm.matrix_world@head.head
print('HEAD_METRES',tuple(p))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Studio');scene.world.color=(.4,.4,.4)
for xyz,power in [((2,-2,3),60),((-2,1,2),25)]:
 bpy.ops.object.light_add(type='AREA',location=p+Vector(xyz));o=bpy.context.object;o.data.energy=power;o.data.size=2;o.rotation_euler=(p-o.location).to_track_quat('-Z','Y').to_euler()
for view,offset in [('front',Vector((.55,0,.08))),('side',Vector((0,-.55,.08)))]:
 bpy.ops.object.camera_add(location=p+offset);cam=bpy.context.object;cam.rotation_euler=(p+Vector((0,0,.035))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=.32;scene.camera=cam;scene.render.filepath=os.path.join(out,view+'.png');bpy.ops.render.render(write_still=True)
json.dump({'head_world_blender':list(p),'approved':False},open(os.path.join(out,'head.json'),'w'),indent=2)

# Side render mouth centre selected on the visible lower-lip seam.
cam=scene.camera;x,y=149,505;w,h=640,640
origin=cam.matrix_world @ Vector(((x/w-.5)*cam.data.ortho_scale,(.5-y/h)*cam.data.ortho_scale,0))
direction=cam.matrix_world.to_3x3() @ Vector((0,0,-1))
hit,location,normal,index,obj,matrix=scene.ray_cast(bpy.context.evaluated_depsgraph_get(),origin,direction)
assert hit
local=(arm.matrix_world@head.matrix).inverted()@location
json.dump({'pixel':[x,y],'mesh':obj.name,'face':index,'world_blender':list(location),'head_local_blender':list(local),'scope':'Raycast on visible lip seam in authored side-view render; review candidate'},open(os.path.join(out,'lip_surface.json'),'w'),indent=2)
print('LIP_SURFACE',tuple(location),'HEAD_LOCAL',tuple(local))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out,'landmark_review.blend'))
