"""Bake muscle fibre color for review-only wound surfaces."""
import bpy
from pathlib import Path
OUT=Path(__file__).resolve().parents[2]/"build/wound_surface_candidates"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.mesh.primitive_plane_add(size=2)
plane=bpy.context.object
m=bpy.data.materials.new("Wet muscle fibres");m.use_nodes=True
n=m.node_tree.nodes;l=m.node_tree.links;p=n.get("Principled BSDF")
p.inputs["Roughness"].default_value=.31
wave=n.new("ShaderNodeTexWave");wave.wave_type="BANDS";wave.bands_direction="X";wave.inputs["Scale"].default_value=12;wave.inputs["Distortion"].default_value=8;wave.inputs["Detail Scale"].default_value=2
noise=n.new("ShaderNodeTexNoise");noise.inputs["Scale"].default_value=25
mix=n.new("ShaderNodeMixRGB");mix.blend_type="MULTIPLY";mix.inputs[0].default_value=.65;l.new(wave.outputs["Color"],mix.inputs[1]);l.new(noise.outputs["Fac"],mix.inputs[2])
ramp=n.new("ShaderNodeValToRGB");ramp.color_ramp.elements[0].position=.12;ramp.color_ramp.elements[0].color=(.035,.001,.003,1);ramp.color_ramp.elements[1].position=.85;ramp.color_ramp.elements[1].color=(.32,.035,.049,1)
l.new(mix.outputs[0],ramp.inputs["Fac"]);l.new(ramp.outputs["Color"],p.inputs["Base Color"])
image=bpy.data.images.new("Wound fibres",width=128,height=128)
t=n.new("ShaderNodeTexImage");t.image=image;n.active=t
plane.data.materials.append(m)
scene=bpy.context.scene;scene.render.engine="CYCLES";scene.cycles.samples=16
scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True
bpy.ops.object.bake(type="DIFFUSE")
image.filepath_raw=str(OUT/"wound_fibres.png");image.file_format="PNG";image.save()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"wound_material.blend"))
