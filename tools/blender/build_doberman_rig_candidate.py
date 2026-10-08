"""Author a quadruped skeleton pilot; no automatic gameplay promotion."""
import bpy
import json
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman'
SOURCE = BASE / 'surface_cleanup_v2/dog_doberman_surface_candidate.glb'
OUT = BASE / 'rig_candidate_v2'
OUT.mkdir(parents=True, exist_ok=True)
contacts = json.loads((BASE / 'surface_cleanup_v2/review/paw_contact_measurements.json').read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
points = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
lo = Vector(tuple(min(p[a] for p in points) for a in range(3)))
hi = Vector(tuple(max(p[a] for p in points) for a in range(3)))
scale = .88 / (hi.z - lo.z)
origin = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
for obj in meshes:
    world = obj.matrix_world.copy()
    for vertex in obj.data.vertices:
        vertex.co = (world @ vertex.co - origin) * scale
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)
    obj.data.update()
bpy.ops.object.select_all(action='DESELECT')
armature = bpy.data.armatures.new('Doberman quadruped skeleton')
rig = bpy.data.objects.new('DOBERMAN_RIG_CANDIDATE', armature)
bpy.context.collection.objects.link(rig)
rig.show_in_front = True
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
records = []
def bone(name, head, tail, parent=None, deform=True):
    item = armature.edit_bones.new(name)
    item.head, item.tail = head, tail
    item.use_deform = deform
    if parent:
        item.parent = armature.edit_bones[parent]
    records.append({'name': name, 'head_m': list(head), 'tail_m': list(tail),
                    'parent': parent, 'deform': deform})

bone('root', (0, 0, 0), (0, 0, .1), deform=False)
bone('pelvis', (0, .27, .48), (0, .1, .48), 'root')
bone('spine', (0, .1, .48), (0, -.12, .51), 'pelvis')
bone('chest', (0, -.12, .51), (0, -.26, .55), 'spine')
bone('neck', (0, -.26, .55), (0, -.37, .73), 'chest')
bone('head', (0, -.37, .73), (0, -.46, .79), 'neck')
bone('jaw', (0, -.40, .715), (0, -.54, .715), 'head')
bone('tail_1', (0, .34, .55), (0, .42, .40), 'pelvis')
bone('tail_2', (0, .42, .40), (0, .52, .29), 'tail_1')
bone('tail_3', (0, .52, .29), (0, .59, .245), 'tail_2')
for sign_name, sign in [('negative_x', -1), ('positive_x', 1)]:
    x = .085 * sign
    for pair in ['front', 'rear']:
        key = pair + '_' + sign_name
        contact = Vector(contacts['paw_regions'][key]['contact_target_m'])
        if pair == 'front':
            joints = [(x, -.25, .52), (x, -.23, .30), (contact.x, -.26, .08)]
            parent = 'chest'
        else:
            joints = [(x, .27, .49), (x, .27, .29), (contact.x, .39, .12)]
            parent = 'pelvis'
        bone(key + '_upper', joints[0], joints[1], parent)
        bone(key + '_lower', joints[1], joints[2], key + '_upper')
        bone(key + '_paw', joints[2], (contact.x, contact.y, .02), key + '_lower')
        bone(key + '_contact', contact, contact + Vector((0, 0, .06)), 'root', deform=False)
bpy.ops.object.mode_set(mode='OBJECT')
rig['status'] = 'Skeleton placement pilot; unbound mesh, no runtime approval'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'dog_doberman_skeleton_candidate.blend'))
report = {'source': str(SOURCE.relative_to(ROOT)), 'runtime_approved': False,
          'rig_approved': False, 'mesh_bound': False, 'animation_clips': [],
          'bones': records, 'normalized_height_m': .88,
          'scope': 'Authored skeleton and measured paw targets; joint placement needs visual review before weights',
          'next': 'Inspect bones over mesh from front/profile; bind reviewed weights, test jaw and leg poses then locomotion'}
(OUT / 'rig_audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'bones': len(records), 'mesh_bound': False, 'runtime_approved': False}))
