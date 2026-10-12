import bpy
bpy.ops.wm.open_mainfile(filepath=r'C:\Users\Gil\Documents\GitHub\Hotshot-California\assets\art\Artwork\3d\cast_redesign_v1\cass\repaired_v1\cass_surface_work.blend')
print([(a.name, round(a.frame_range[0]), round(a.frame_range[1])) for a in bpy.data.actions])
