"""Build review-only wound geometry on audited closed cut contours."""
import bpy,json,os
from pathlib import Path
from mathutils import Vector
from mathutils.geometry import tessellate_polygon
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/os.environ.get("WOUND_CANDIDATE_OUTPUT","build/wound_surface_candidates");OUT.mkdir(parents=True,exist_ok=True)
report=json.loads((ROOT/os.environ.get("WOUND_CANDIDATE_LOOPS","build/sever_wound_loops.json")).read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
material=bpy.data.materials.new("Exposed wet muscle");material.use_nodes=True
nodes=material.node_tree.nodes;links=material.node_tree.links
p=nodes.get("Principled BSDF");p.inputs["Roughness"].default_value=.31
noise=nodes.new("ShaderNodeTexNoise");noise.inputs["Scale"].default_value=95
ramp=nodes.new("ShaderNodeValToRGB");ramp.color_ramp.elements[0].color=(.055,.001,.006,1);ramp.color_ramp.elements[1].color=(.38,.025,.047,1)
links.new(noise.outputs["Fac"],ramp.inputs["Fac"]);links.new(ramp.outputs["Color"],p.inputs["Base Color"])
bump=nodes.new("ShaderNodeBump");bump.inputs["Strength"].default_value=.25;bump.inputs["Distance"].default_value=.002
links.new(noise.outputs["Fac"],bump.inputs["Height"]);links.new(bump.outputs["Normal"],p.inputs["Normal"])
manifest=[]
geometry=[]
for cut in report["cuts"]:
 objects=[]
 for region in cut["regions"]:
  for index,loop in enumerate(region["closed_loops"]):
   vertices=[Vector(v) for v in loop]
   triangles=tessellate_polygon([vertices])
   faces=[tuple(v if isinstance(v,int) else min(range(len(vertices)),key=lambda i:(vertices[i]-v).length_squared) for v in triangle) for triangle in triangles]
   if not faces:continue
   geometry.append({"look":cut["look"],"part":cut["part"],"mesh":region["mesh"],"vertices":loop,"faces":faces})
   mesh=bpy.data.meshes.new("Contour wound");mesh.from_pydata(loop,[],faces);mesh.materials.append(material)
   obj=bpy.data.objects.new(f"{cut['look']}_{cut['part']}_{region['mesh']}_{index}",mesh);bpy.context.scene.collection.objects.link(obj);objects.append(obj)
 manifest.append({"look":cut["look"],"part":cut["part"],"surfaces":len(objects),"ambiguous_components":sum(len(r["ambiguous_components"]) for r in cut["regions"])})
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"wound_surfaces.blend"))
(OUT/"review.json").write_text(json.dumps({"status":"candidate","scope":"Rest-space triangulated closed contour geometry; ambiguous borders omitted. Skin binding, missing border reconstruction, orientation, visual review and integration pending.","cuts":manifest},indent=2),encoding="utf-8")
print("Built",sum(c["surfaces"] for c in manifest),"closed contour wound candidates")

(OUT/"geometry.json").write_text(json.dumps(geometry),encoding="utf-8")
