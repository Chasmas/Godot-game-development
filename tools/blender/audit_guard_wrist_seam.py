"""Read-only geometric seam and wrist texture diagnostic on the staged mesh."""
import bpy,bmesh,json
from pathlib import Path
source=Path('build/guard_smooth_locomotion_v8/guard.glb')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source.resolve()))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.shape_keys)
bm=bmesh.new();bm.from_mesh(body.data)
# glTF splits UV/normal seams. Weld a diagnostic copy only, never the asset.
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001)
rows=[]
for side in ('Right','Left'):
 name=side+'Hand';inverse=arm.data.bones[name].matrix_local.inverted()@arm.matrix_world.inverted()@body.matrix_world
 edges=[e for e in bm.edges if e.is_boundary and all(abs((inverse@v.co).y-1)<.05 for v in e.verts)]
 group=body.vertex_groups[name].index
 vertices=[v for v in body.data.vertices if any(g.group==group and g.weight>.05 for g in v.groups) and abs((inverse@v.co).y-1)<.05]
 key=body.data.shape_keys.key_blocks['WeaponGrip']
 delta=max(((key.data[v.index].co-v.co).length for v in vertices),default=0)
 colours=[]
 images={}
 for polygon in body.data.polygons:
  material=body.data.materials[polygon.material_index]
  textures=[n.image for n in material.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
  if not textures:continue
  image=textures[0]
  if image.name not in images:images[image.name]=image.pixels[:]
  pixels=images[image.name];width,height=image.size
  for li in polygon.loop_indices:
   vertex=body.data.vertices[body.data.loops[li].vertex_index]
   p=inverse@vertex.co
   if not any(g.group==group and g.weight>.05 for g in vertex.groups) or not -.5<p.y<3:continue
   uv=body.data.uv_layers.active.data[li].uv
   x=min(width-1,int(uv.x%1*width));y=min(height-1,int(uv.y%1*height))
   colours.append(pixels[(y*width+x)*4:(y*width+x)*4+3])
 rows.append({'side':side,'cut_ring_vertices':len(vertices),'cut_ring_boundary_edges_after_diagnostic_weld':len(edges),'max_cut_ring_morph_displacement_native_units':delta,'wrist_texture_samples':len(colours),'dark_or_green_samples':sum(max(c)<.35 or c[1]>c[0]*1.1 for c in colours)})
bm.free()
report={'approved':False,'source':str(source),'rows':rows,'scope':'Rest cut ring and nearest UV texels only; not a full topology or texture approval.'}
(source.parent/'wrist_seam_report.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
