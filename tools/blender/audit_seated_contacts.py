"""Measure evaluated boot soles in production doze, without editing assets."""
import bpy, json, hashlib, sys
from pathlib import Path

def audit(identity):
    source=(Path(sys.argv[sys.argv.index('--source')+1]) if '--source' in sys.argv else Path('assets/art/cast3d_rt')/identity/(identity+'.glb')).resolve()
    sha=hashlib.sha256(source.read_bytes()).hexdigest()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    rig=next((o for o in bpy.data.objects if o.type=='ARMATURE'),None)
    if rig is None: return {'status':'no_armature','source':str(source),'source_unchanged':True}
    actions=[a for a in bpy.data.actions if a.name=='doze']
    if not actions:actions=list(bpy.data.actions) if '--source' in sys.argv else [a for a in bpy.data.actions if 'doze' in a.name.lower()]
    if not actions:
        return {'status':'no_doze_clip','source':str(source),'sha256':sha,'source_unchanged':True}
    assert len(actions)==1, [a.name for a in bpy.data.actions]
    rig.animation_data_create()
    for track in rig.animation_data.nla_tracks: track.mute=True
    rig.animation_data.action=actions[0]
    if hasattr(actions[0],'slots') and len(actions[0].slots):rig.animation_data.action_slot=actions[0].slots[0]
    rows=[]
    for phase in [0,.25,.5,.75]:
        lo,hi=actions[0].frame_range
        bpy.context.scene.frame_set(int(lo+(hi-lo)*phase),subframe=(lo+(hi-lo)*phase)%1)
        bpy.context.view_layer.update()
        dg=bpy.context.evaluated_depsgraph_get()
        feet=[]
        for side in ['Left','Right']:
            names=[side+'Foot',side+'ToeBase']
            points=[]
            for obj in [o for o in bpy.data.objects if o.type=='MESH']:
                groups={g.index for g in obj.vertex_groups if g.name in names}
                indices=[v.index for v in obj.data.vertices if sum(g.weight for g in v.groups if g.group in groups)>.75]
                ev=obj.evaluated_get(dg);mesh=ev.to_mesh()
                points.extend(ev.matrix_world@mesh.vertices[i].co for i in indices)
                ev.to_mesh_clear()
            assert points, side
            feet.append({'side':side,'weighted_boot_vertices':len(points),'hip_joint_height_m':(rig.matrix_world@rig.pose.bones[side+'UpLeg'].head).z,'ankle_joint_height_m':(rig.matrix_world@rig.pose.bones[side+'Foot'].head).z,'sole_min_height_m':min(p.z for p in points),'boot_max_height_m':max(p.z for p in points)})
        hips=rig.matrix_world@rig.pose.bones['Hips'].head
        rows.append({'phase':phase,'hips_height_m':hips.z,'feet':feet})
    report={'source':str(source),'sha256':sha,'source_unchanged':hashlib.sha256(source.read_bytes()).hexdigest()==sha,'runtime_promoted':False,'scope':'Evaluated vertices with foot/toe influence above 0.75; lowest selected boot vertex approximates sole contact; verify visually before correcting animation','rows':rows}
    out=Path(sys.argv[sys.argv.index('--out')+1] if '--out' in sys.argv else 'build/seated_contacts');out.mkdir(parents=True,exist_ok=True)
    (out/(identity+'.json')).write_text(json.dumps(report,indent=2))
    print("SEATED CONTACT",identity,[(f["side"],round(f["sole_min_height_m"],4)) for f in rows[2]["feet"]])
    return report

identities=[sys.argv[sys.argv.index('--identity')+1] if '--identity' in sys.argv else 'guard']
if '--all' in sys.argv:
    identities=[p.name for p in Path('assets/art/cast3d_rt').iterdir() if p.is_dir() and (p/(p.name+'.glb')).exists()]
Path(sys.argv[sys.argv.index('--out')+1] if '--out' in sys.argv else 'build/seated_contacts').mkdir(parents=True,exist_ok=True)
reports=[]
for identity in sorted(identities):
    reports.append({'id':identity,'report':audit(identity)})
(Path(sys.argv[sys.argv.index('--out')+1] if '--out' in sys.argv else 'build/seated_contacts')/'summary.json').write_text(json.dumps({'runtime_approved':False,'casts':reports},indent=2))
