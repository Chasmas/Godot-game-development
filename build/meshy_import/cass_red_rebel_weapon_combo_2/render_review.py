import bpy, sys
from mathutils import Vector
out = sys.argv[sys.argv.index('--')+1]
sc=bpy.context.scene
sc.render.engine='BLENDER_EEVEE'
sc.render.resolution_x=512; sc.render.resolution_y=512; sc.render.resolution_percentage=100
sc.render.image_settings.file_format='PNG'
sc.render.film_transparent=False
world=bpy.data.worlds.new('ReviewWorld') if not bpy.data.worlds else bpy.data.worlds[0]; sc.world=world; world.color=(0.015,0.017,0.025)
# remove imported cameras/lights only
for ob in list(sc.objects):
 if ob.type in {'CAMERA','LIGHT'}: bpy.data.objects.remove(ob,do_unlink=True)
def track(ob, point): ob.rotation_euler=(Vector(point)-ob.location).to_track_quat('-Z','Y').to_euler()
camd=bpy.data.cameras.new('ReviewCamera'); camd.type='ORTHO'; camd.ortho_scale=3.8
cam=bpy.data.objects.new('ReviewCamera',camd); sc.collection.objects.link(cam); cam.location=(4.5,-7.5,3.3); track(cam,(0,0,0.2)); sc.camera=cam
for name,loc,energy,color in [('key',(4,-4,6),1100,(1,.78,.66)),('rim',(-4,2,5),700,(.25,.65,1)),('fill',(0,4,2),400,(1,.18,.4))]:
 data=bpy.data.lights.new(name,'AREA'); data.energy=energy; data.shape='DISK'; data.size=5
 ob=bpy.data.objects.new(name,data); sc.collection.objects.link(ob); ob.location=loc; ob.data.color=color; track(ob,(0,0,0))
for f in [1,70,136,205]:
 sc.frame_set(f); sc.render.filepath=out.replace('.png',f'_{f:03}.png'); bpy.ops.render.render(write_still=True)
print('MESHY_CASS_COMBO_RENDERED',out)
