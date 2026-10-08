"""Create engine-compatible authoring skin and independently reimport its GLB."""
import bpy
import json
import sys
import numpy as np
from pathlib import Path
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT/'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/walk_candidate_v4'
REFINED = '--refined' in sys.argv
SURFACE = '--surface' in sys.argv
OUT = BASE/('native_skin_candidate_v7' if SURFACE else ('native_skin_candidate_v6' if REFINED else 'native_skin_candidate_v4'))
OUT.mkdir(parents=True,exist_ok=True)
source_file = BASE/('shoulder_surface_candidate_v3/dog_doberman_native_skin.blend' if SURFACE else ('native_skin_candidate_v5/dog_doberman_native_skin.blend' if REFINED else 'baked_candidate_v1/dog_doberman_walk_baked.blend'))
bpy.ops.wm.open_mainfile(filepath=str(source_file))
obj = next(o for o in bpy.context.scene.objects if o.type=='MESH')
rig = next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
names = [g.name for g in obj.vertex_groups]
deform = {g.index for g in obj.vertex_groups if g.name in rig.data.bones and rig.data.bones[g.name].use_deform}
rows = []
for vertex in obj.data.vertices:
    # Match the installed glTF exporter's min_influence rule exactly.
    weights = sorted([(g.group,g.weight) for g in vertex.groups if g.group in deform and g.weight>.0001],key=lambda item:item[1],reverse=True)[:4]
    total = sum(weight for _,weight in weights)
    assert total>0.
    rows.append([(index,weight/total) for index,weight in weights])
obj.vertex_groups.clear()
groups = [obj.vertex_groups.new(name=name) for name in names]
for vertex_index,weights in enumerate(rows):
    for group_index,weight in weights:
        groups[group_index].add([vertex_index],weight,'REPLACE')
next(m for m in obj.modifiers if m.type=='ARMATURE').use_deform_preserve_volume = False
source_base = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]

def evaluated(mesh_obj,frame):
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    evaluated_obj = mesh_obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated_obj.to_mesh()
    points = np.array([tuple(evaluated_obj.matrix_world @ v.co) for v in mesh.vertices],dtype=np.float32)
    evaluated_obj.to_mesh_clear()
    return points

source = {frame:evaluated(obj,frame) for frame in range(1,32)}
bpy.context.scene.frame_set(1)
bpy.context.scene.frame_end = 31
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'dog_doberman_native_skin.blend'))
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
rig.select_set(True)
target = OUT/'dog_doberman_native_skin.glb'
bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,
    export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_force_sampling=True,
    export_anim_slide_to_zero=True,export_optimize_animation_size=False,export_apply=False)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=str(target))
imported = next(o for o in bpy.context.scene.objects if o.type=='MESH')
tree = KDTree(len(source_base))
for index,point in enumerate(source_base):
    tree.insert(point,index)
tree.balance()
mapping = []
maximum_base_error = 0.
maximum_weight_error = 0.
for vertex in imported.data.vertices:
    point = imported.matrix_world @ vertex.co
    imported_weights = {imported.vertex_groups[g.group].name:g.weight for g in vertex.groups if g.weight>0.}
    candidates = tree.find_range(point,.000001)
    def attribute_error(candidate):
        _,source_index,distance = candidate
        source_weights = {names[index]:weight for index,weight in rows[source_index]}
        difference = sum(abs(source_weights.get(name,0.)-imported_weights.get(name,0.)) for name in source_weights.keys()|imported_weights.keys())
        return difference,distance
    assert candidates, 'Missing reference vertex'
    candidate = min(candidates,key=attribute_error)
    _,index,distance = candidate
    maximum_weight_error = max(maximum_weight_error,attribute_error(candidate)[0])
    mapping.append(index)
    maximum_base_error = max(maximum_base_error,distance)
assert maximum_base_error<.00001, 'Reimported base geometry differs; animation comparison invalid'
samples = []
for frame in range(1,32):
    # GLB timestamps were shifted to zero; Blender imported frame0 is source1.
    points = evaluated(imported,frame-1)
    error = np.linalg.norm(points-source[frame][mapping],axis=1)
    samples.append({'source_frame':frame,'reimport_frame':frame-1,
        'maximum_mesh_difference_m':float(error.max()),'p99_mesh_difference_m':float(np.quantile(error,.99))})
maximum = max(sample['maximum_mesh_difference_m'] for sample in samples)
report = {'runtime_approved':False,'animation_approved':False,'source_unchanged':True,
    'weights_per_vertex_limit':4,'deformation':'linear','sampled_frames':31,
    'animation_channel_optimization':False,
    'minimum_retained_influence':.0001,
    'source_vertices':len(source_base),'reimport_vertices':len(mapping),
    'maximum_reimport_base_difference_m':maximum_base_error,
    'maximum_reimport_weight_l1_difference':maximum_weight_error,
    'maximum_reimport_animation_difference_m':maximum,
    'scope':'Independent Blender GLB reimport compared with native-skin authoring mesh; Godot visual/anatomy and gameplay validation pending',
    'samples':samples}
(OUT/'roundtrip_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({key:value for key,value in report.items() if key!='samples'}),flush=True)
assert maximum<.00001, 'Animation export does not match engine-compatible authoring source'
