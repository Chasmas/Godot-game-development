"""Bake a reviewed 16:9 still into a subtle cinematic camera-move sequence.

This is a staging bridge until a full Blender scene is authored: the artwork
is never resampled into a different aspect ratio, and the gentle push/drift is
exported as real PNG frames consumed by FrameSequence.
"""
import bpy, os, sys, math
from mathutils import Vector

def cli():
    raw = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    vals = {'src': '', 'out': '', 'frames': 24}
    i = 0
    while i < len(raw):
        if raw[i].startswith('--') and i + 1 < len(raw):
            vals[raw[i][2:]] = raw[i + 1]; i += 2
        else: i += 1
    return vals

def main():
    a = cli(); src, out = a['src'], a['out']; count = int(a.get('frames', 24))
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE_NEXT'
    scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.film_transparent = False
    scene.render.fps = 12
    img = bpy.data.images.load(src, check_existing=True)
    aspect = img.size[0] / max(1, img.size[1])
    plane = bpy.data.meshes.new('reviewed_art_mesh')
    plane.from_pydata([(-aspect, -1, 0), (aspect, -1, 0), (aspect, 1, 0), (-aspect, 1, 0)], [], [(0,1,2,3)])
    plane.update()
    uv = plane.uv_layers.new(name='UVMap')
    for loop in plane.loops:
        uv.data[loop.index].uv = [(0, 0), (1, 0), (1, 1), (0, 1)][loop.vertex_index]
    obj = bpy.data.objects.new('reviewed_art', plane); scene.collection.objects.link(obj)
    mat = bpy.data.materials.new('reviewed_art_material'); mat.use_nodes = True
    nodes = mat.node_tree.nodes; links = mat.node_tree.links
    tex = nodes.new('ShaderNodeTexImage'); tex.image = img
    tex.interpolation = 'Closest'
    # Emission keeps the approved artwork unchanged in a headless render
    # (there is deliberately no lighting rig in this bridge scene).
    out_node = nodes.get('Material Output')
    emission = nodes.new('ShaderNodeEmission')
    links.new(tex.outputs['Color'], emission.inputs['Color'])
    links.new(emission.outputs['Emission'], out_node.inputs['Surface'])
    obj.data.materials.append(mat)
    cam_data = bpy.data.cameras.new('CinematicCamera'); cam = bpy.data.objects.new('CinematicCamera', cam_data)
    scene.collection.objects.link(cam); scene.camera = cam; cam_data.type = 'ORTHO'; cam_data.ortho_scale = 2.0
    # Blender camera looks down its local -Z axis; the art plane is XY at Z=0.
    cam.location = (0, 0, 8); cam.rotation_euler = (0, 0, 0)
    for n in range(count):
        t = n / max(1, count - 1)
        cam.data.ortho_scale = 2.0 - 0.045 * math.sin(t * math.pi)
        cam.location.x = math.sin(t * math.pi * 2.0) * 0.018
        cam.location.y = math.cos(t * math.pi * 2.0) * 0.012
        scene.render.filepath = os.path.join(out, f'frame_{n+1:04d}.png')
        scene.frame_set(n + 1); bpy.ops.render.render(write_still=True)
    print(f'Wrote {count} frames to {out}')

if __name__ == '__main__': main()
