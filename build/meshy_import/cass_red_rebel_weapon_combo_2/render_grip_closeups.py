import bpy
from pathlib import Path
from mathutils import Vector
ROOT=Path.cwd(); OUT=ROOT/'build/meshy_import/cass_red_rebel_weapon_combo_2'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'cass_pistol_attachment_probe.blend'))
s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.render.resolution_x=640;s.render.resolution_y=640;s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG';s.world=bpy.data.worlds.new('Review');s.world.color=(.12,.12,.12)
a=next(o for o in s.objects if o.type=='ARMATURE')
c=bpy.data.objects.new('GripReviewCamera',bpy.data.cameras.new('GripReviewCamera'));s.collection.objects.link(c);c.data.type='ORTHO';c.data.ortho_scale=.42;s.camera=c
for n,loc in [('Key',(2,-2,3)),('Fill',(-2,0,2))]:
 l=bpy.data.objects.new(n,bpy.data.lights.new(n,'AREA'));s.collection.objects.link(l);l.data.energy=250;l.data.size=2;l.location=loc
for f in (1,70,136,205):
 s.frame_set(f);bpy.context.view_layer.update()
 p=(a.matrix_world @ a.pose.bones['mixamorig:RightHand'].matrix).translation
 c.location=p+Vector((.5,-.7,.4));c.rotation_euler=(p-c.location).to_track_quat('-Z','Y').to_euler()
 for l in [o for o in s.objects if o.type=='LIGHT']:l.rotation_euler=(p-l.location).to_track_quat('-Z','Y').to_euler()
 s.render.filepath=str(OUT/f'grip_closeup_{f:03}.png');bpy.ops.render.render(write_still=True)

