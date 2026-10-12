"""Render staged contact poses; does not modify runtime assets."""
from pathlib import Path
import bpy, argparse, sys
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--cast', choices=['cass','guard','civilian','boss'], default='cass')
parser.add_argument('--gait', choices=['walk','run','sneak'], default='walk')
parser.add_argument('--profile', choices=['study','grounded','preserved'], default='study')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT = ROOT / 'build/locomotion_candidates' / args.cast
if args.profile != 'study': OUT = OUT / args.profile
if args.gait != 'walk': OUT = OUT / args.gait
bpy.ops.wm.open_mainfile(filepath=str(OUT / (args.gait+'_contact_candidate.blend')))
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 16
scene.render.resolution_x = 360
scene.render.resolution_y = 480
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.world = bpy.data.worlds.new('review world')
scene.world.color = (.22, .22, .22)
scene.render.film_transparent = False
camera_data = bpy.data.cameras.new('review camera')
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 2.5
camera = bpy.data.objects.new('review camera', camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
for name, position, power in [('key', (2,-3,4), 450), ('fill', (-3,1,3), 300)]:
    data = bpy.data.lights.new(name, 'AREA')
    data.energy = power
    data.shape = 'DISK'
    data.size = 3
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (Vector((0,0,.9)) - obj.location).to_track_quat('-Z','Y').to_euler()
for view, location in [('front', (0,-5,2.0)), ('side', (5,0,2.0))]:
    camera.location = location
    camera.rotation_euler = (Vector((0,0,.9)) - camera.location).to_track_quat('-Z','Y').to_euler()
    for frame in [0,scene.frame_end//4,scene.frame_end//2,scene.frame_end*3//4]:
        scene.frame_set(frame)
        scene.render.filepath = str(OUT / f'{view}_{frame:02d}.png')
        bpy.ops.render.render(write_still=True)
print('CASS STRIDE POSE REVIEW RENDERED')
