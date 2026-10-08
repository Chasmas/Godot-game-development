"""Create a small, production-safe Blender animation rig for a cutscene.

Run inside Blender with an authored still/scene already open. The preset adds
subtle film movement without changing the game's camera perspective: a 16:9
camera push, breathing keyframes, hair/cloth sway and looping rain/fire
drivers. Artists can replace the placeholder collections with real meshes.
"""
import bpy, math
from mathutils import Vector

FPS = 12
SECONDS = 4

def key(obj, path, frame, value):
    setattr(obj, path, value)
    obj.keyframe_insert(data_path=path, frame=frame)

def add_camera():
    # Keep the reviewed shot's lens, perspective and initial framing.
    if bpy.context.scene.camera:
        cam = bpy.context.scene.camera
        start = cam.location.copy()
        key(cam, "location", 1, start)
        key(cam, "location", FPS * SECONDS, start + cam.rotation_euler.to_matrix() @ Vector((0,0,-.12)))
        return cam
    cam_data = bpy.data.cameras.get("CinematicCamera") or bpy.data.cameras.new("CinematicCamera")
    cam = bpy.data.objects.get("CinematicCamera") or bpy.data.objects.new("CinematicCamera", cam_data)
    if not cam.users_collection:
        bpy.context.scene.collection.objects.link(cam)
    cam.data.lens = 50
    cam.data.sensor_width = 36
    bpy.context.scene.camera = cam
    cam.location = (0, -10, 4)
    cam.rotation_euler = (math.radians(76), 0, 0)
    key(cam, "location", 1, (0, -10, 4))
    key(cam, "location", FPS * SECONDS, (0.18, -9.55, 4.04))
    key(cam, "rotation_euler", 1, cam.rotation_euler)
    key(cam, "rotation_euler", FPS * SECONDS, (math.radians(75.4), math.radians(-0.3), math.radians(0.8)))
    return cam

def animate_named(name, amplitude=(0.0, 0.0, 0.0), rotation=0.0):
    obj = bpy.data.objects.get(name)
    if not obj:
        return False
    start = obj.location.copy()
    end = start + Vector(amplitude)
    key(obj, "location", 1, start)
    key(obj, "location", FPS * SECONDS // 2, end)
    key(obj, "location", FPS * SECONDS, start)
    if rotation:
        r = obj.rotation_euler.copy()
        key(obj, "rotation_euler", 1, r)
        key(obj, "rotation_euler", FPS * SECONDS // 2, (r.x, r.y, r.z + rotation))
        key(obj, "rotation_euler", FPS * SECONDS, r)
    return True

def main():
    scene = bpy.context.scene
    engines = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items}
    scene.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in engines else 'BLENDER_EEVEE_NEXT'
    scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
    scene.render.resolution_percentage = 100
    scene.render.fps = FPS
    scene.frame_start, scene.frame_end = 1, FPS * SECONDS
    scene.render.image_settings.file_format = 'PNG'
    add_camera()
    # Convention-based hooks: authored scenes can name these objects when
    # available; absent hooks are intentionally harmless.
    animate_named("Character", (0.0, 0.0, 0.035))
    animate_named("Hair", (0.025, 0.0, 0.0), 0.025)
    animate_named("Hands", (0.012, 0.0, 0.018), -0.02)
    animate_named("Fire", (0.0, 0.0, 0.05), 0.08)
    animate_named("Rain", (0.0, 0.08, -0.12))
    # Bezier interpolation gives film-like ease instead of robotic linear cuts.
    for action in bpy.data.actions:
        curves = []
        if hasattr(action, 'fcurves'):
            curves.extend(action.fcurves)
        else:
            for layer in action.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        curves.extend(bag.fcurves)
        for fc in curves:
            for kp in fc.keyframe_points:
                kp.interpolation = 'BEZIER'
    print("Cutscene preset ready: 1920x1080, 12 fps, 4 seconds")

if __name__ == '__main__':
    main()
