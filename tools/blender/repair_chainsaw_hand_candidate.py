import bpy,bmesh,json
from pathlib import Path
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path('assets/art/Artwork/3d/cass/rig_newhair.glb').resolve()))
report=[]
for obj in list(bpy.context.scene.objects):
 if obj.type!='MESH':continue
 groups=[obj.vertex_groups[n].index for n in ['LeftHand','RightHand'] if n in obj.vertex_groups]
 if not groups:continue
 bm=bmesh.new();bm.from_mesh(obj.data);deform=bm.verts.layers.deform.active
 selected=[v for v in bm.verts if any(v[deform].get(g,0)>.5 for g in groups)]
 before_vertices=len(bm.verts)
 before=sum(1 for e in bm.edges if e.is_boundary and all(v in selected for v in e.verts))
 bmesh.ops.remove_doubles(bm,verts=selected,dist=.025)
 selected=set(v for v in bm.verts if any(v[deform].get(g,0)>.5 for g in groups))
 edges=[e for e in bm.edges if e.is_boundary and all(v in selected for v in e.verts)]
 fill=bmesh.ops.holes_fill(bm,edges=edges,sides=12)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 after=sum(1 for e in bm.edges if e.is_boundary and all(v in selected for v in e.verts))
 report.append({'mesh':obj.name,'merged_vertices':before_vertices-len(bm.verts),'hand_boundary_before':before,'hand_boundary_after':after,'filled_faces':len(fill['faces'])})
 bm.to_mesh(obj.data);bm.free();obj.data.update()
bpy.ops.export_scene.gltf(filepath=str(Path('build/chainsaw_pose_candidate/cass_hand_repair.glb').resolve()),export_format='GLB',export_animations=False)
Path('build/chainsaw_pose_candidate/hand_repair_report.json').write_text(json.dumps({'approved':False,'repairs':report},indent=2))
