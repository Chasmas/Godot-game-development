"""Render bone-placement overlays in Blender using the reviewed model cameras."""
import bpy
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman'
OUT = BASE / 'rig_candidate_v2/review'
OUT.mkdir(parents=True, exist_ok=True)
audit = json.loads((BASE / 'surface_cleanup_v2/review/model_audit.json').read_text())
rig_audit = json.loads((BASE / 'rig_candidate_v2/rig_audit.json').read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 4
scene.render.resolution_x = 1024
scene.render.resolution_y = 768
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.view_settings.view_transform = 'Standard'
def material(name, color):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    n = m.node_tree.nodes
    n.clear()
    e = n.new('ShaderNodeEmission')
    e.inputs['Color'].default_value = (*color, 1)
    e.inputs['Strength'].default_value = 1
    o = n.new('ShaderNodeOutputMaterial')
    m.node_tree.links.new(e.outputs[0], o.inputs[0])
    return m
deform_mat = material('Deform bones cyan', (.02, .8, 1))
target_mat = material('Contact controls orange', (1, .25, .02))
for b in rig_audit['bones']:
    start, end = Vector(b['head_m']), Vector(b['tail_m'])
    delta = end - start
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=.003,
        depth=delta.length, location=(start+end)/2)
    o = bpy.context.object
    o.name = b['name']
    o.rotation_euler = delta.to_track_quat('Z', 'Y').to_euler()
    o.data.materials.append(deform_mat if b['deform'] else target_mat)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=4, radius=.006, location=start)
    bpy.context.object.data.materials.append(deform_mat if b['deform'] else target_mat)
height = audit['normalized_height_m']
lo, hi = Vector(audit['source_bounds']['lower']), Vector(audit['source_bounds']['upper'])
extent = (hi-lo) * (height/(hi.z-lo.z))
ortho = max(height * 1024/768, max(extent.x, extent.y)) * 1.25
focus = Vector((0, 0, height/2))
for name, loc in [('front', (0, -4, focus.z)), ('side', (4, 0, focus.z))]:
    bpy.ops.object.camera_add(location=loc)
    camera = bpy.context.object
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = ortho
    camera.rotation_euler = (focus-camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = camera
    scene.render.filepath = str(OUT / (name + '_skeleton.png'))
    bpy.ops.render.render(write_still=True)
    # Composite the rendered skeleton with the matching reference render in
    # Blender's image buffers. Skeleton intentionally remains visible through
    # the body; this diagnoses placement, not skin deformation.
    skeleton = bpy.data.images.load(scene.render.filepath, check_existing=False)
    body = bpy.data.images.load(str(BASE / 'surface_cleanup_v2/review' / (name+'.png')), check_existing=False)
    import numpy as np
    pixels = np.empty(1024*768*4, dtype=np.float32)
    base = np.empty_like(pixels)
    skeleton.pixels.foreach_get(pixels)
    body.pixels.foreach_get(base)
    pixels = pixels.reshape((-1,4)); base = base.reshape((-1,4))
    alpha = pixels[:,3:4]
    base[:,:3] = pixels[:,:3]*alpha + base[:,:3]*(1-alpha)
    result = bpy.data.images.new(name+'_skeleton_overlay', width=1024, height=768, alpha=True)
    result.pixels.foreach_set(base.ravel())
    result.filepath_raw = str(OUT / (name+'_overlay.png'))
    result.file_format = 'PNG'
    result.save()
(OUT / 'review_scope.json').write_text(json.dumps({'runtime_approved':False,
    'scope':'Through-body skeleton placement overlays, no skin weights or animation validation',
    'renders':['front_overlay.png','side_overlay.png']}, indent=2))
print('Skeleton placement overlays complete', flush=True)
