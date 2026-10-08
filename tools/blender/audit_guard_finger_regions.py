"""Find separated distal finger components without modifying source art."""
import bpy, json
from pathlib import Path
from collections import defaultdict

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path('build/guard_dual_wrist_isolated/guard.glb').resolve()))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
arm.animation_data_clear()
for bone in arm.pose.bones: bone.matrix_basis.identity()
report={}
for body in bpy.context.scene.objects:
    if body.type!='MESH':continue
    for name in ('RightHand','LeftHand'):
        group=body.vertex_groups.get(name)
        if group is None:continue
        inverse=(arm.matrix_world@arm.data.bones[name].matrix_local).inverted()@body.matrix_world
        coords={v.index:inverse@v.co for v in body.data.vertices
                if next((g.weight for g in v.groups if g.group==group.index),0)>.5}
        # glTF splits vertices at UV/normal seams. Join coincident points in
        # the diagnostic graph only; never weld the textured source mesh.
        buckets={};canonical={}
        for index,point in coords.items():
            key=tuple(round(float(axis),3) for axis in point)
            canonical[index]=buckets.setdefault(key,index)
        unique={canonical[i]:point for i,point in coords.items()}
        trials=[]
        for cutoff in (9,10,11,12,13,14,15,16,17,18,19):
            selected={i for i,p in unique.items() if p.y>cutoff}
            graph=defaultdict(list)
            for edge in body.data.edges:
                a,b=edge.vertices
                if a not in canonical or b not in canonical:continue
                a,b=canonical[a],canonical[b]
                if a in selected and b in selected:
                    graph[a].append(b);graph[b].append(a)
            components=[]
            while selected:
                seed=selected.pop();stack=[seed];found=[seed]
                while stack:
                    for neighbor in graph[stack.pop()]:
                        if neighbor in selected:
                            selected.remove(neighbor);stack.append(neighbor);found.append(neighbor)
                if len(found)<6:continue
                points=[unique[i] for i in found]
                components.append({'count':len(found),
                    'min':[min(p[a] for p in points) for a in range(3)],
                    'max':[max(p[a] for p in points) for a in range(3)],
                    'mean':[sum(p[a] for p in points)/len(points) for a in range(3)]})
            trials.append({'cutoff':cutoff,'regions':sorted(components,key=lambda c:c['count'],reverse=True)})
        report[name]=trials
out=Path('build/guard_finger_regions');out.mkdir(exist_ok=True)
report['_assessment']={
    'approved':False,
    'coincident_vertex_tolerance_native_cm':.001,
    'source_modified':False,
    'four_distinct_distal_finger_regions_found':False,
    'finding':'Both hands retain a single main distal component across Y cutoffs 13..19cm. A second proximal region has thumb-like bounds. Graph connectivity alone does not define anatomical digits.',
    'next_action':'Replace uniform cylindrical warp with digit segmentation/remodeling; current WeaponGrip is not suitable for production.'}
(out/'report.json').write_text(json.dumps(report,indent=2))
for name,trials in report.items():
    if name.startswith('_'):continue
    print(name,[(t['cutoff'],[r['count'] for r in t['regions']]) for t in trials])
