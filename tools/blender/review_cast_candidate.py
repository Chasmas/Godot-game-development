"""Import the persisted Cass pilot and render independent Blender anatomy views."""
import bpy
import json
import sys
import re
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
CHARACTER = sys.argv[sys.argv.index('--character') + 1] if '--character' in sys.argv else 'cass'
if not re.fullmatch(r'[a-z][a-z0-9_]*', CHARACTER):
    raise RuntimeError('Invalid character identifier')
CONFIG = json.loads((ROOT / 'tools/art/cast_reference_crops.json').read_text(encoding='utf-8'))[CHARACTER]
HEIGHT_M = CONFIG['height_m']
HIGH = '--pre-remeshed' in sys.argv
REPAIRED = '--repaired' in sys.argv
SOURCE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/cass/raw' / ('pre_remeshed.glb' if HIGH else 'model.glb')
OUT = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/cass' / ('blender_review_high' if HIGH else 'blender_review')
if CHARACTER != 'cass':
    if '--face-polish' in sys.argv:
        raise RuntimeError('Cass repair selectors cannot be applied to another asset')
    SOURCE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1' / CHARACTER / 'raw' / ('pre_remeshed.glb' if HIGH else 'model.glb')
    OUT = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1' / CHARACTER / ('blender_review_high' if HIGH else 'blender_review')
if REPAIRED:
    SOURCE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1' / CHARACTER / 'repaired_v1' / (CHARACTER + '_surface_candidate.glb')
    OUT = SOURCE.parent / 'review'
if '--face-polish' in sys.argv:
    SOURCE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/cass/face_polish_v1/cass_face_candidate.glb'
    OUT = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/cass/face_polish_v1/review'
if '--head-geometry' in sys.argv:
    if CHARACTER != 'cass_head_detail':
        raise RuntimeError('Head geometry selector requires cass_head_detail')
    SOURCE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/cass_head_detail/geometry_lod_v2/cass_head_geometry_candidate.glb'
    OUT = SOURCE.parent / 'review'
if '--head-cleanup' in sys.argv:
    if CHARACTER != 'cass_head_detail':
        raise RuntimeError('Head cleanup selector requires cass_head_detail')
    SOURCE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/cass_head_detail/geometry_cleanup_v4/cass_head_cleanup_candidate.glb'
    OUT = SOURCE.parent / 'review'
if '--dog-surface-cleanup' in sys.argv:
    if CHARACTER != 'dog_doberman':
        raise RuntimeError('Dog cleanup selector requires dog_doberman')
    SOURCE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/surface_cleanup_v2/dog_doberman_surface_candidate.glb'
    OUT = SOURCE.parent / 'review'
if '--clay' in sys.argv:
    OUT = OUT / 'clay_review'

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    if not meshes:
        raise RuntimeError('Candidate contains no character mesh')
    original = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    lower = Vector(tuple(min(point[axis] for point in original) for axis in range(3)))
    upper = Vector(tuple(max(point[axis] for point in original) for axis in range(3)))
    source_height = upper.z-lower.z
    if source_height <= 0.01:
        raise RuntimeError('Candidate has invalid height')
    root = bpy.data.objects.new(CHARACTER.upper() + '_REVIEW_ROOT', None)
    bpy.context.scene.collection.objects.link(root)
    top_objects = [obj for obj in list(bpy.context.scene.objects) if obj != root and obj.parent is None]
    for obj in top_objects:
        world = obj.matrix_world.copy()
        obj.parent = root
        obj.matrix_world = world
    scale = HEIGHT_M/source_height
    root.scale = (scale,)*3
    root.location = Vector((-(lower.x+upper.x)/2, -(lower.y+upper.y)/2, -lower.z))*scale
    bpy.context.view_layer.update()
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    try:
        preferences = bpy.context.preferences.addons['cycles'].preferences
        preferences.compute_device_type = 'CUDA'
        preferences.get_devices()
        gpu = False
        for device in preferences.devices:
            device.use = device.type != 'CPU'
            gpu |= device.use
        if gpu:
            scene.cycles.device = 'GPU'
    except Exception:
        scene.cycles.device = 'CPU'
    scene.render.resolution_x = 768
    scene.render.resolution_y = 1024
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.film_transparent = False
    scene.view_settings.view_transform = 'Standard'
    scene.world = bpy.data.worlds.new('Neutral review studio')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.16,0.18,0.21,1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.35
    target = Vector((0,0,HEIGHT_M * 0.5232558))
    for location, energy, size in [((2,-3,3),250,3),((-3,-1,2),100,3),((0,3,3),180,2)]:
        bpy.ops.object.light_add(type='AREA', location=location)
        lamp = bpy.context.object
        lamp.data.energy = energy
        lamp.data.shape = 'DISK'
        lamp.data.size = size
        lamp.rotation_euler = (target-lamp.location).to_track_quat('-Z','Y').to_euler()
    materials = []
    for material in bpy.data.materials:
        textures = []
        if material.use_nodes:
            textures = [{'name': node.image.name, 'size': list(node.image.size),
                         'color_space': node.image.colorspace_settings.name}
                        for node in material.node_tree.nodes if node.type == 'TEX_IMAGE' and node.image]
        materials.append({'name': material.name, 'textures': textures})
    report = {'source': str(SOURCE.relative_to(ROOT)), 'runtime_approved': False,
              'normalized_height_m': HEIGHT_M, 'source_bounds': {'lower': list(lower), 'upper': list(upper)},
              'mesh_objects': len(meshes), 'vertices': sum(len(obj.data.vertices) for obj in meshes),
              'polygons': sum(len(obj.data.polygons) for obj in meshes),
              'smooth_polygons': sum(sum(poly.use_smooth for poly in obj.data.polygons) for obj in meshes),
              'armature_objects': sum(obj.type == 'ARMATURE' for obj in bpy.context.scene.objects),
              'materials': materials,
              'scope': 'Static imported model and reference renders; no rig, facial animation, weapon contacts or Godot gameplay validation.',
              'renders': []}
    views = [('front',(0,-4,0.96),target,2.05),('side',(4,0,0.96),target,2.05),
             ('back',(0,4,0.96),target,2.05),('face_front',(0,-3,1.56),Vector((0,0,1.56)),0.5)]
    if CHARACTER == 'cass_head_detail':
        views = [('front',(0,-3,0.25),Vector((0,0,0.25)),0.58),
                 ('side',(3,0,0.25),Vector((0,0,0.25)),0.58),
                 ('back',(0,3,0.25),Vector((0,0,0.25)),0.58),
                 ('face_front',(0,-3,0.3),Vector((0,0,0.3)),0.32)]
    if CONFIG.get('anatomy_type') == 'quadruped':
        # Fit the full muzzle, paws and tail in landscape views. Human framing
        # and the fixed human face height can hide quadruped anatomy defects.
        scene.render.resolution_x = 1024
        scene.render.resolution_y = 768
        extent = (upper - lower) * scale
        focus = Vector((0, 0, HEIGHT_M / 2))
        # Blender's orthographic scale spans the larger image dimension.
        ortho = max(HEIGHT_M * (1024 / 768), max(extent.x, extent.y)) * 1.25
        diagonal_ortho = max(HEIGHT_M * (1024 / 768),
                             (extent.x ** 2 + extent.y ** 2) ** .5) * 1.25
        views = [('front', (0, -4, focus.z), focus, ortho),
                 ('side', (4, 0, focus.z), focus, ortho),
                 ('back', (0, 4, focus.z), focus, ortho),
                 ('three_quarter', (3, -3, focus.z), focus, diagonal_ortho)]
        report['anatomy_type'] = 'quadruped'
        report['framing'] = 'Full normalized bounds; no fixed humanoid face crop'
    if '--clay' in sys.argv:
        OUT.mkdir(parents=True, exist_ok=True)
        diagnostic = bpy.data.materials.new('Neutral geometry review clay')
        diagnostic.use_nodes = True
        shader = diagnostic.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = (0.3, 0.3, 0.3, 1)
        shader.inputs['Roughness'].default_value = 0.8
        scene.view_layers[0].material_override = diagnostic
        views = [(name + '_clay', position, focus, ortho) for name, position, focus, ortho in views]
        report['material_override'] = 'Neutral clay; geometry diagnostic only'
    for name, location, focus, ortho in views:
        bpy.ops.object.camera_add(location=location)
        camera = bpy.context.object
        camera.data.type = 'ORTHO'
        camera.data.ortho_scale = ortho
        camera.rotation_euler = (focus-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.camera = camera
        scene.render.filepath = str(OUT / (name+'.png'))
        bpy.ops.render.render(write_still=True)
        report['renders'].append(name+'.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / (CHARACTER + '_candidate_review.blend')))
    (OUT / 'model_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({'review_folder': str(OUT), 'vertices': report['vertices'], 'polygons': report['polygons'], 'runtime_approved': False}))

if __name__ == '__main__':
    main()
