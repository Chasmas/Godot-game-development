"""Audit the existing shoulder-refined walk without regenerating its animation."""
import bpy
import json
import sys
import numpy as np
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT/'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman'
OUT = BASE/'walk_candidate_v3'
NATIVE = '--native-body' in sys.argv
if NATIVE:
    OUT = BASE/'walk_candidate_v4/native_skin_candidate_v5'
bpy.ops.wm.open_mainfile(filepath=str(OUT/('dog_doberman_native_skin.blend' if NATIVE else 'dog_doberman_walk_candidate.blend')))
meta = json.loads((BASE/('walk_candidate_v4' if NATIVE else 'walk_candidate_v2')/'walk_audit.json').read_text())
rig = next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
obj = next(o for o in bpy.context.scene.objects if o.type=='MESH')
source = np.array([v.co[:] for v in obj.data.vertices])
masks = {key: ((source[:,2]<.06) &
    (source[:,0]<-.025 if 'negative_x' in key else source[:,0]>.025) &
    (source[:,1]<-.13 if key.startswith('front') else source[:,1]>.13))
    for key in meta['footfall_phase_offsets']}
previous = {}
slip = 0.
endpoint = 0.
minimum_z = 1.
first = None
for frame in range(1,32):
    t = (frame-1)/30
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    graph = bpy.context.evaluated_depsgraph_get()
    evaluated_rig = rig.evaluated_get(graph)
    evaluated_obj = obj.evaluated_get(graph)
    mesh = evaluated_obj.to_mesh()
    points = np.empty(len(mesh.vertices)*3,dtype=np.float32)
    mesh.vertices.foreach_get('co',points)
    points = points.reshape(-1,3)
    evaluated_obj.to_mesh_clear()
    if first is None:
        first = points.copy()
    minimum_z = min(minimum_z,float(points[:,2].min()))
    for key, phase in meta['footfall_phase_offsets'].items():
        paw = evaluated_rig.pose.bones[key+'_paw']
        control = evaluated_rig.pose.bones[key+'_contact']
        rest = rig.data.bones[key+'_paw']
        desired = control.matrix.translation + (rest.tail_local-rest.head_local)
        endpoint = max(endpoint,(paw.tail-desired).length)
        q = (t+phase)%1.
        duty = meta.get('leg_stance_fractions',{}).get(key,meta['stance_fraction'])
        planted = q < duty
        soles = points[masks[key]].copy()
        soles[:,1] -= meta['matching_forward_speed_m_per_s']*t
        if key in previous:
            old_q, old_planted, old_soles = previous[key]
            if planted and old_planted and q>=old_q:
                slip = max(slip,float(np.linalg.norm(soles-old_soles,axis=1).max()))
        previous[key] = q,planted,soles
seam = float(np.linalg.norm(points-first,axis=1).max())
report = {'runtime_approved':False,'animation_approved':False,'sampled_frames':31,
    'maximum_paw_endpoint_error_m':endpoint,'maximum_planted_sole_slip_per_frame_m':slip,
    'minimum_full_cycle_mesh_height_m':minimum_z,'mesh_loop_seam_m':seam,
    'scope':'Existing shoulder-refined Blender animation, all integer-frame contacts; no export or visual playback approval'}
(OUT/'contact_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report),flush=True)
