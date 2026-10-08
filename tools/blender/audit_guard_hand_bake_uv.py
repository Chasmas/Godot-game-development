"""Read-only hand UV coverage diagnostic for the staged wrist bake."""
import bpy,json,os
from pathlib import Path
root=Path(os.environ.get('GUARD_UV_AUDIT_ROOT','build/guard_hand_blend_v29'))
bpy.ops.wm.open_mainfile(filepath=str((root/'guard_hand_skin_review.blend').resolve()))
body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.shape_keys)
slot=next(i for i,m in enumerate(body.data.materials) if m.name=='GuardHandSkin_ImageGen_v1')
image=next(n.image for n in body.data.materials[slot].node_tree.nodes if n.type=='TEX_IMAGE')
width,height=image.size;pixels=image.pixels[:]
body.data.calc_loop_triangles();uv=body.data.uv_layers.active.data
rows=[]
for tri in body.data.loop_triangles:
 if body.data.polygons[tri.polygon_index].material_index!=slot:continue
 a,b,c=[uv[i].uv for i in tri.loops]
 area=abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))*.5*width*height
 point=(a+b+c)/3
 x=min(width-1,max(0,int(point.x*width)));y=min(height-1,max(0,int(point.y*height)))
 color=pixels[(y*width+x)*4:(y*width+x)*4+3]
 if area<.5 or max(color)<.05:
  p,q,r=[body.data.vertices[i].co for i in tri.vertices]
  rows.append({'polygon':tri.polygon_index,'texel_area':area,'mesh_area':(q-p).cross(r-p).length*.5,'centroid_rgb':list(color)})
report={'approved':False,'resolution':[width,height],'small_or_dark_triangles':rows,'scope':'UV triangle area and centroid sample only; not a full raster coverage or seam audit.'}
(root/'uv_coverage_review.json').write_text(json.dumps(report,indent=2))
print('UV_REVIEW',len(rows),'small/dark triangles')
