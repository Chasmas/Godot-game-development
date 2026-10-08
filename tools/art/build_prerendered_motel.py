"""Build the Sunset Palms pre-rendered environment pilot in Blender.

Run with:
  blender -b --python tools/art/build_prerendered_motel.py

The scene is deliberately generated from code so materials, lighting and camera
can be reproduced when the gameplay layout changes.  Geometry helpers (mesh
builder, palms, plants) live in tools/art/prerendered_kit.py.

Layout contract (do not move without updating the gameplay level): north wing
centred (0,-10) 24x3 m, side wings at x=+-11.4 (3 x 13.4 m), courtyard slab
(0,-3.4) 24.4x14 m, pool (0,-3) 9x5.3 m, parking lot y>3.6 with stalls every
5 m between stripes at x=-8,-3,2,7,12.  Camera: ortho 31.5, 50 deg elevation,
30 deg azimuth around (0,-1.6,1).
"""

from pathlib import Path
import math
import os
import random
import sys
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prerendered_kit as kit  # noqa: E402
from prerendered_kit import MB, Frame, Z  # noqa: E402


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/prerendered/m01_sunset_palms"
ELDORADO = ROOT / "assets/art/cast3d_rt/eldorado/eldorado.glb"
SEDAN = ROOT / "assets/art/Artwork/3d/prop_sedan80/model.glb"
FORCE_BLENDER_NATIVE_VEHICLES = True
OUT.mkdir(parents=True, exist_ok=True)
QUICK = "--quick" in sys.argv  # half-res, fewer samples, for iteration
# Native low-resolution art source for the final pixel-art treatment.  Keep this
# separate from the master render: the eventual Godot layer can use nearest
# sampling without downscaling the live collision/layout scene.
PIXEL = "--pixel" in sys.argv
PIXEL_HQ = "--pixel_hq" in sys.argv

bpy.ops.wm.read_factory_settings(use_empty=True)
RND = random.Random(1987)


# -- materials --------------------------------------------------------------------

def material(name, color, metallic=0.0, roughness=0.55, emission=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = strength
    return m


def _nodes(mat):
    return mat.node_tree.nodes, mat.node_tree.links, mat.node_tree.nodes.get("Principled BSDF")


def _coords(nodes, kind="Object"):
    tc = nodes.new("ShaderNodeTexCoord")
    return tc.outputs[kind]


def add_surface_detail(mat, scale=6.0, bump=.12, variation=.08, grime=0.0, streaks=0.0):
    """Procedural grain + optional ground grime and vertical rain streaks."""
    nodes, links, bsdf = _nodes(mat)
    pos = _coords(nodes)
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 6.0
    noise.inputs["Roughness"].default_value = .72
    links.new(pos, noise.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    base = tuple(mat.diffuse_color[:3])
    ramp.color_ramp.elements[0].color = (*[max(0, c - variation) for c in base], 1)
    ramp.color_ramp.elements[1].color = (*[min(1, c + variation) for c in base], 1)
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    color = ramp.outputs["Color"]
    if grime or streaks:
        geo = nodes.new("ShaderNodeNewGeometry")
        sep = nodes.new("ShaderNodeSeparateXYZ")
        links.new(geo.outputs["Position"], sep.inputs["Vector"])
        dirt = nodes.new("ShaderNodeMapRange")
        dirt.inputs["From Min"].default_value, dirt.inputs["From Max"].default_value = 0.0, 1.1
        dirt.inputs["To Min"].default_value, dirt.inputs["To Max"].default_value = grime, 0.0
        links.new(sep.outputs["Z"], dirt.inputs["Value"])
        st = nodes.new("ShaderNodeTexNoise")
        st.inputs["Scale"].default_value = 3.0
        st.inputs["Detail"].default_value = 4.0
        mp = nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (5.0, 5.0, .35)
        links.new(geo.outputs["Position"], mp.inputs["Vector"])
        links.new(mp.outputs["Vector"], st.inputs["Vector"])
        sr = nodes.new("ShaderNodeMapRange")
        sr.inputs["From Min"].default_value, sr.inputs["From Max"].default_value = .5, .75
        sr.inputs["To Min"].default_value, sr.inputs["To Max"].default_value = 0.0, streaks
        links.new(st.outputs["Fac"], sr.inputs["Value"])
        add = nodes.new("ShaderNodeMath")
        add.operation = "ADD"
        add.use_clamp = True
        links.new(dirt.outputs["Result"], add.inputs[0])
        links.new(sr.outputs["Result"], add.inputs[1])
        mix = nodes.new("ShaderNodeMixRGB")
        mix.blend_type = "MULTIPLY"
        mix.inputs["Color2"].default_value = (.18, .12, .12, 1)
        links.new(add.outputs["Value"], mix.inputs["Fac"])
        links.new(color, mix.inputs["Color1"])
        color = mix.outputs["Color"]
    links.new(color, bsdf.inputs["Base Color"])
    bump_node = nodes.new("ShaderNodeBump")
    bump_node.inputs["Strength"].default_value = bump
    bump_node.inputs["Distance"].default_value = .08
    links.new(noise.outputs["Fac"], bump_node.inputs["Height"])
    links.new(bump_node.outputs["Normal"], bsdf.inputs["Normal"])
    return bump_node


def wet_ground(mat, scale=.22, wet_color=None, puddle=.56, tiles=None, reflect=0.0, mirror=0.0):
    """Puddle mask: mirror-smooth dark patches over a rough base (+ optional pavers)."""
    nodes, links, bsdf = _nodes(mat)
    pos = _coords(nodes)
    n = nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = 3.0
    n.inputs["Roughness"].default_value = .55
    links.new(pos, n.inputs["Vector"])
    mask = nodes.new("ShaderNodeValToRGB")
    mask.color_ramp.elements[0].position = puddle
    mask.color_ramp.elements[1].position = puddle + .02
    links.new(n.outputs["Fac"], mask.inputs["Fac"])
    grain = nodes.new("ShaderNodeTexNoise")
    grain.inputs["Scale"].default_value = 26.0
    grain.inputs["Detail"].default_value = 8.0
    links.new(pos, grain.inputs["Vector"])
    base = tuple(mat.diffuse_color[:3])
    gr = nodes.new("ShaderNodeValToRGB")
    gr.color_ramp.elements[0].color = (*[c * .7 for c in base], 1)
    gr.color_ramp.elements[1].color = (*[min(1, c * 1.35) for c in base], 1)
    links.new(grain.outputs["Fac"], gr.inputs["Fac"])
    # Preserve an authored albedo instead of replacing it with procedural grain.
    color = bsdf.inputs["Base Color"].links[0].from_socket if bsdf.inputs["Base Color"].is_linked else gr.outputs["Color"]
    if tiles:
        br = nodes.new("ShaderNodeTexBrick")
        br.inputs["Scale"].default_value = 1.0
        br.inputs["Mortar Size"].default_value = .025
        br.inputs["Brick Width"].default_value = tiles
        br.inputs["Row Height"].default_value = tiles
        br.offset = 0.0
        br.inputs["Color1"].default_value = (1, 1, 1, 1)
        br.inputs["Color2"].default_value = (.82, .8, .78, 1)
        br.inputs["Mortar"].default_value = (.45, .42, .42, 1)
        links.new(pos, br.inputs["Vector"])
        mul = nodes.new("ShaderNodeMixRGB")
        mul.blend_type = "MULTIPLY"
        mul.inputs["Fac"].default_value = 1.0
        links.new(color, mul.inputs["Color1"])
        links.new(br.outputs["Color"], mul.inputs["Color2"])
        color = mul.outputs["Color"]
    wet = nodes.new("ShaderNodeMixRGB")
    wet.inputs["Color2"].default_value = (*(wet_color or [c * .45 for c in base]), 1)
    links.new(mask.outputs["Color"], wet.inputs["Fac"])
    links.new(color, wet.inputs["Color1"])
    links.new(wet.outputs["Color"], bsdf.inputs["Base Color"])
    rough = nodes.new("ShaderNodeMapRange")
    rough.inputs["To Min"].default_value = bsdf.inputs["Roughness"].default_value
    rough.inputs["To Max"].default_value = .03
    links.new(mask.outputs["Color"], rough.inputs["Value"])
    links.new(rough.outputs["Result"], bsdf.inputs["Roughness"])
    if mirror:
        # Puddles act as (tinted) mirrors; a planar light probe supplies the
        # actual reflection of the sign, lamps and cars.
        met = nodes.new("ShaderNodeMapRange")
        met.inputs["To Max"].default_value = mirror
        links.new(mask.outputs["Color"], met.inputs["Value"])
        links.new(met.outputs["Result"], bsdf.inputs["Metallic"])
    if reflect:
        # Faked reflection of the neon sign (west, -x) and warm courtyard lights
        # (east): a top-down camera has nothing on screen for SSR to mirror.
        geo = nodes.new("ShaderNodeNewGeometry")
        sep = nodes.new("ShaderNodeSeparateXYZ")
        links.new(geo.outputs["Position"], sep.inputs["Vector"])
        side = nodes.new("ShaderNodeMapRange")
        side.inputs["From Min"].default_value, side.inputs["From Max"].default_value = -12.0, 4.0
        links.new(sep.outputs["X"], side.inputs["Value"])
        tint = nodes.new("ShaderNodeValToRGB")
        tint.color_ramp.elements[0].color = (1.0, .05, .45, 1)
        tint.color_ramp.elements[1].color = (1.0, .45, .12, 1)
        links.new(side.outputs["Result"], tint.inputs["Fac"])
        mott = nodes.new("ShaderNodeTexNoise")
        mott.inputs["Scale"].default_value = 3.5
        mott.inputs["Detail"].default_value = 3.0
        links.new(pos, mott.inputs["Vector"])
        mr = nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value, mr.inputs["From Max"].default_value = .35, .75
        mr.inputs["To Max"].default_value = reflect
        links.new(mott.outputs["Fac"], mr.inputs["Value"])
        amt = nodes.new("ShaderNodeMath")
        amt.operation = "MULTIPLY"
        links.new(mask.outputs["Color"], amt.inputs[0])
        links.new(mr.outputs["Result"], amt.inputs[1])
        links.new(tint.outputs["Color"], bsdf.inputs["Emission Color"])
        links.new(amt.outputs["Value"], bsdf.inputs["Emission Strength"])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = .25
    bump.inputs["Distance"].default_value = .05
    inv = nodes.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    links.new(mask.outputs["Color"], inv.inputs[1])
    links.new(inv.outputs["Value"], bump.inputs["Strength"])
    links.new(grain.outputs["Fac"], bump.inputs["Height"])
    if bsdf.inputs["Normal"].is_linked:
        links.new(bsdf.inputs["Normal"].links[0].from_socket, bump.inputs["Normal"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])


def roof_stains(mat):
    """Darker water-stain blotches and lighter dust patches over the tar roof."""
    nodes, links, bsdf = _nodes(mat)
    src = bsdf.inputs["Base Color"].links[0].from_socket
    n = nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = .45
    n.inputs["Detail"].default_value = 6.0
    links.new(_coords(nodes), n.inputs["Vector"])
    r = nodes.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].position, r.color_ramp.elements[1].position = .35, .7
    r.color_ramp.elements[0].color = (.6, .55, .55, 1)
    r.color_ramp.elements[1].color = (1.2, 1.12, 1.08, 1)
    links.new(n.outputs["Fac"], r.inputs["Fac"])
    mul = nodes.new("ShaderNodeMixRGB")
    mul.blend_type = "MULTIPLY"
    mul.inputs["Fac"].default_value = 1.0
    links.new(src, mul.inputs["Color1"])
    links.new(r.outputs["Color"], mul.inputs["Color2"])
    links.new(mul.outputs["Color"], bsdf.inputs["Base Color"])


M = {
    "asphalt": material("Wet asphalt", (0.05, 0.05, 0.07), roughness=0.5),
    "concrete": material("Warm concrete", (0.36, 0.27, 0.24), roughness=0.85),
    "deck": material("Pool deck pavers", (0.26, 0.19, 0.16), roughness=0.45),
    "stucco": material("Sunset coral stucco", (0.48, 0.12, 0.085), roughness=0.85),
    "stucco_dark": material("Stucco base band", (0.22, 0.08, 0.08), roughness=0.85),
    "trim": material("Cream trim", (0.80, 0.62, 0.45), roughness=0.6),
    "roof": material("Tar & gravel roof", (0.17, 0.15, 0.19), roughness=0.9),
    "parapet": material("Parapet stucco", (0.36, 0.11, 0.10), roughness=0.85),
    "metal": material("Painted dark metal", (0.03, 0.04, 0.05), metallic=0.7, roughness=0.38),
    "steel": material("Galvanised steel", (0.42, 0.44, 0.46), metallic=0.85, roughness=0.42),
    "rail": material("Black wrought iron", (0.012, 0.012, 0.016), metallic=0.6, roughness=0.4),
    "wood": material("Weathered walnut", (0.19, 0.07, 0.035), roughness=0.7),
    "door": material("Teal motel door", (0.02, 0.24, 0.24), roughness=0.45),
    "door_panel": material("Teal door panel", (0.015, 0.17, 0.18), roughness=0.5),
    "glass": material("Window glass", (0.02, 0.05, 0.08), metallic=0.2, roughness=0.08),
    "glow": material("Warm window", (1.0, 0.42, 0.08), emission=(1.0, 0.36, 0.05), strength=1.8),
    "glow_dim": material("Dim window", (0.6, 0.25, 0.06), emission=(1.0, 0.3, 0.05), strength=.8),
    "glow_tv": material("TV-lit window", (0.2, 0.3, 0.6), emission=(0.25, 0.45, 1.0), strength=1.5),
    "curtain": material("Curtain fabric", (0.4, 0.13, 0.04), roughness=0.9, emission=(1.0, 0.3, 0.04), strength=.9),
    "water": material("Pool water", (0.0, 0.32, 0.38), metallic=0.0, roughness=0.06, emission=(0.0, 0.55, 0.62), strength=1.0),
    "tile": material("Pool tile", (0.03, 0.42, 0.48), roughness=0.3),
    "coping": material("Pool coping", (0.66, 0.55, 0.45), roughness=0.6),
    "pink": material("Hot pink neon", (1.0, 0.1, 0.45), emission=(1.0, 0.03, 0.35), strength=22),
    "cyan": material("Cyan neon", (0.2, 0.9, 1.0), emission=(0.05, 0.85, 1.0), strength=18),
    "red_neon": material("Red neon", (1.0, 0.1, 0.1), emission=(1.0, 0.05, 0.06), strength=16),
    "orange_neon": material("Orange neon", (1.0, 0.4, 0.05), emission=(1.0, 0.33, 0.03), strength=16),
    "green_neon": material("Green neon", (0.2, 1.0, 0.5), emission=(0.1, 1.0, 0.45), strength=14),
    "cyan_paint": material("Cyan painted metal", (0.025, 0.27, 0.34), metallic=.25, roughness=.48),
    "amber": material("Amber practical", (1.0, 0.6, 0.25), emission=(1.0, 0.45, 0.12), strength=14),
    "bulb": material("Festoon bulb", (1.0, 0.7, 0.35), emission=(1.0, 0.55, 0.2), strength=26),
    "white_plastic": material("White resin", (0.78, 0.76, 0.72), roughness=0.45),
    "canvas_red": material("Umbrella red", (0.62, 0.06, 0.07), roughness=0.8),
    "canvas_white": material("Umbrella cream", (0.82, 0.76, 0.66), roughness=0.8),
    "towel": material("Towel blue", (0.08, 0.25, 0.55), roughness=0.95),
    "towel2": material("Towel white", (0.85, 0.82, 0.78), roughness=0.95),
    "dumpster": material("Dumpster green", (0.03, 0.17, 0.12), metallic=.4, roughness=.6),
    "yellow": material("Parking stop yellow", (0.75, 0.52, 0.04), roughness=0.7),
    "trunk": material("Palm trunk", (0.28, 0.17, 0.09), roughness=0.9),
    "palm_ring": material("Palm boot", (0.20, 0.11, 0.05), roughness=0.95),
    "nut": material("Coconut", (0.12, 0.08, 0.03), roughness=0.7),
    "frond1": material("Palm frond dark", (0.02, 0.13, 0.07), roughness=0.6),
    "frond2": material("Palm frond", (0.035, 0.21, 0.09), roughness=0.55),
    "frond3": material("Palm frond young", (0.09, 0.26, 0.07), roughness=0.55),
    "dead": material("Dead frond", (0.30, 0.18, 0.07), roughness=0.85),
    "leaf1": material("Leaf dark", (0.015, 0.11, 0.05), roughness=0.5),
    "leaf2": material("Leaf mid", (0.04, 0.24, 0.08), roughness=0.5),
    "bract": material("Bougainvillea", (0.75, 0.03, 0.32), roughness=0.7),
    "flower_or": material("Bird of paradise", (0.95, 0.35, 0.03), roughness=0.6),
    "planter": material("Terracotta planter", (0.42, 0.16, 0.09), roughness=0.85),
    "soil": material("Soil", (0.05, 0.03, 0.02), roughness=1.0),
    "rubber": material("Rubber", (0.012, 0.012, 0.018), roughness=0.8),
    "redcar": material("Oxide red car", (0.32, 0.025, 0.035), metallic=0.65, roughness=0.3),
    "vend": material("Vending front", (0.9, 0.9, 1.0), emission=(0.6, 0.85, 1.0), strength=4),
    "ice": material("Ice machine", (0.75, 0.78, 0.82), metallic=.5, roughness=.35),
    "sign_box": material("Sign cabinet", (0.05, 0.02, 0.06), metallic=.3, roughness=.5),
}

from m01_materials import apply_deck_material
apply_deck_material(M["deck"])

add_surface_detail(M["stucco"], 24, .35, .07, grime=.55, streaks=.35)
add_surface_detail(M["parapet"], 24, .3, .06, grime=0, streaks=.3)
add_surface_detail(M["stucco_dark"], 20, .3, .04)
add_surface_detail(M["concrete"], 12, .18, .05)
add_surface_detail(M["roof"], 40, .5, .05, grime=0, streaks=.0)
roof_stains(M["roof"])
add_surface_detail(M["wood"], 7, .22, .05)
add_surface_detail(M["trunk"], 14, .45, .06)
add_surface_detail(M["dumpster"], 9, .25, .03, grime=.4, streaks=.3)
add_surface_detail(M["planter"], 18, .2, .05)
wet_ground(M["asphalt"], scale=.3, puddle=.55, wet_color=(.4, .38, .45), mirror=.92)
wet_ground(M["deck"], scale=.35, puddle=.62, tiles=0, wet_color=(.22, .16, .13), mirror=.45)

# Show every leaf from both sides; no shadow-casting artefacts on thin planes.
for k in ("frond1", "frond2", "frond3", "dead", "leaf1", "leaf2", "canvas_red", "canvas_white"):
    M[k].use_backface_culling = False

# Pool water: bright turquoise, rippled, with a caustic network in the emission.
_wn, _wl, _wbs = _nodes(M["water"])
_pos = _coords(_wn)
_vor = _wn.new("ShaderNodeTexVoronoi")
_vor.feature = "DISTANCE_TO_EDGE"
_vor.inputs["Scale"].default_value = 2.3
_dist = _wn.new("ShaderNodeTexNoise")
_dist.inputs["Scale"].default_value = 1.2
_dist.inputs["Detail"].default_value = 3.0
_mixv = _wn.new("ShaderNodeMixRGB")
_mixv.inputs["Fac"].default_value = .18
_wl.new(_pos, _mixv.inputs["Color1"])
_wl.new(_dist.outputs["Color"], _mixv.inputs["Color2"])
_wl.new(_pos, _dist.inputs["Vector"])
_wl.new(_mixv.outputs["Color"], _vor.inputs["Vector"])
_cr = _wn.new("ShaderNodeValToRGB")
_cr.color_ramp.elements[0].position = 0.0
_cr.color_ramp.elements[0].color = (.45, 1.0, .95, 1)
_cr.color_ramp.elements[1].position = .07
_cr.color_ramp.elements[1].color = (0.0, .32, .42, 1)
_wl.new(_vor.outputs["Distance"], _cr.inputs["Fac"])
_wl.new(_cr.outputs["Color"], _wbs.inputs["Emission Color"])
_wave = _wn.new("ShaderNodeTexWave")
_wave.inputs["Scale"].default_value = 1.4
_wave.inputs["Distortion"].default_value = 7.0
_wave.inputs["Detail"].default_value = 5.0
_wl.new(_pos, _wave.inputs["Vector"])
_wb = _wn.new("ShaderNodeBump")
_wb.inputs["Strength"].default_value = .25
_wb.inputs["Distance"].default_value = .05
_wl.new(_wave.outputs["Fac"], _wb.inputs["Height"])
_wl.new(_wb.outputs["Normal"], _wbs.inputs["Normal"])

# Pool tile: small mosaic grid.
_tn, _tl, _tb = _nodes(M["tile"])
_br = _tn.new("ShaderNodeTexBrick")
_br.inputs["Scale"].default_value = 1.0
_br.inputs["Brick Width"].default_value = .12
_br.inputs["Row Height"].default_value = .12
_br.inputs["Mortar Size"].default_value = .008
_br.offset = 0.0
_br.inputs["Color1"].default_value = (.03, .42, .48, 1)
_br.inputs["Color2"].default_value = (.02, .33, .42, 1)
_br.inputs["Mortar"].default_value = (.6, .7, .7, 1)
_tl.new(_coords(_tn), _br.inputs["Vector"])
_tl.new(_br.outputs["Color"], _tb.inputs["Base Color"])


# -- small helpers ------------------------------------------------------------------

def cube(name, loc, scale, mat, bevel=0.0):
    mb = MB(name)
    mb.box(loc, scale, mat)
    return mb.build(bevel=bevel)


def point_light(name, loc, color, energy, radius=.15, shadow=False):
    data = bpy.data.lights.new(name, "POINT")
    data.energy, data.color, data.shadow_soft_size = energy, color, radius
    data.use_shadow = shadow
    o = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    o.location = loc
    return o


def spot_light(name, loc, color, energy, target, angle=1.2, radius=.1, shadow=True):
    data = bpy.data.lights.new(name, "SPOT")
    data.energy, data.color, data.shadow_soft_size = energy, color, radius
    data.spot_size, data.spot_blend = angle, .6
    data.use_shadow = shadow
    o = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return o


def area_light(name, loc, color, energy, size, target):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.color, data.shape, data.size = energy, color, "DISK", size
    o = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector(target) - o.location).to_track_quat("-Z", "Y").to_euler()
    return o


WARM = (1.0, .52, .2)


# -- architecture ----------------------------------------------------------------------

def wall_lamp(mb, fr, s, z, lights=True):
    fr.box(mb, s, .03, z, .09, .03, .14, M["metal"])
    fr.box(mb, s, .12, z - .02, .075, .075, .1, M["amber"])
    fr.box(mb, s, .12, z + .1, .1, .1, .02, M["metal"])
    if lights:
        point_light("Wall lamp", fr.p(s, .45, z - .1), WARM, 55, .08)


def window(mb, fr, s, z, w=.68, h=.52, ac=False):
    glow = RND.choice([M["glow"], M["glow"], M["glow_dim"], M["glow_tv"], M["glow"]])
    fr.box(mb, s, .0, z, w + .07, .05, h + .07, M["trim"])
    fr.box(mb, s, .04, z, w, .03, h, M["glass"])
    fr.box(mb, s, .045, z, w - .04, .03, h - .04, glow)
    # half-drawn curtains glow through, venetian-blind slats on some
    cw = RND.uniform(.18, .32)
    fr.box(mb, s - w + cw, .07, z, cw, .012, h - .03, M["curtain"])
    fr.box(mb, s + w - cw * .8, .07, z, cw * .8, .012, h - .03, M["curtain"])
    if RND.random() < .35:
        for k in range(7):
            fr.box(mb, s, .08, z + h - .06 - k * .1, w - .05, .01, .012, M["curtain"])
    fr.box(mb, s, .08, z, .022, .03, h, M["trim"])
    fr.box(mb, s, .1, z - h - .06, w + .12, .1, .035, M["trim"])
    if ac:
        fr.box(mb, s + .25, .2, z - h - .32, .34, .2, .2, M["ice"])
        for k in range(6):
            fr.box(mb, s + .02 + k * .09, .405, z - h - .32, .02, .01, .15, M["metal"])


def door(mb, fr, s, z0, number):
    fr.box(mb, s, 0, z0 + 1.0, .56, .05, 1.02, M["trim"])
    fr.box(mb, s, .04, z0 + .98, .47, .03, .98, M["door"])
    for pz in (.5, 1.38):
        fr.box(mb, s, .075, z0 + pz, .36, .012, .3, M["door_panel"])
    fr.box(mb, s + .36, .1, z0 + .98, .03, .03, .05, M["amber"])
    fr.box(mb, s, .08, z0 + 1.82, .11, .012, .06, M["trim"])  # room number plate
    fr.box(mb, s, .08, z0 + .12, .42, .012, .09, M["steel"])  # kick plate


def facade(fr, name, s0, s1, bays, upper=True, balcony=True, door_skip=(), stair_gap=None, lamps=True):
    """Two-storey motel front between s0..s1 of a wall frame."""
    mb = MB(name + " facade")
    rail = MB(name + " railings")
    pots = MB(name + " potted plants")
    span = s1 - s0
    # base band and floor-line trim
    fr.box(mb, (s0 + s1) / 2, .02, .18, span / 2, .03, .18, M["stucco_dark"])
    bw = span / bays
    number = 1
    for b in range(bays):
        sc = s0 + bw * (b + .5)
        for floor, z0 in ((0, 0.0), (1, 2.45)):
            if floor and not upper:
                continue
            sd, sw = sc - .78, sc + .62
            if (b, floor) not in door_skip:
                door(mb, fr, sd, z0, number)
                wall_lamp(mb, fr, sd - .78, z0 + 1.75, lamps)
                if floor == 0:
                    fr.box(mb, sd, .55, .012, .45, .3, .012, M["rubber"])  # doormat
            window(mb, fr, sw, z0 + 1.35, ac=RND.random() < .4 and floor == 0)
            if RND.random() < .55:
                pp = fr.p(sw + RND.choice((-.95, .85)), .35, z0 + (.06 if floor == 0 else .0))
                pots.cyl(pp, pp + Vector((0, 0, .32)), .16, M["planter"], 12, r2=.2)
                kit.tropical_plant(pots, pp + Vector((0, 0, .3)), RND.uniform(.45, .7), [M["leaf1"], M["leaf2"]], RND, 8,
                                   M["bract"] if RND.random() < .3 else None)
            number += 1
        # downpipe on bay boundary
        if b % 2 == 0:
            ps = s0 + bw * b + .14
            mb.cyl(fr.p(ps, .12, 0), fr.p(ps, .12, 4.75), .055, M["steel"], 10)
            for zz in (.6, 1.8, 3.0, 4.2):
                fr.box(mb, ps, .07, zz, .07, .07, .025, M["steel"])
    # electrical conduit + meter boxes under the walkway
    mb.cyl(fr.p(s0 + .3, .05, 2.15), fr.p(s1 - .3, .05, 2.15), .025, M["steel"], 8)
    fr.box(mb, s0 + bw * .5 + 1.4, .1, 1.6, .2, .1, .3, M["steel"])
    if balcony and upper:
        fr.box(mb, (s0 + s1) / 2, .55, 2.37, span / 2, .55, .08, M["concrete"])
        fr.box(mb, (s0 + s1) / 2, 1.1, 2.33, span / 2, .04, .12, M["trim"])
        fr.box(mb, (s0 + s1) / 2, 1.05, 2.2, span / 2, .05, .05, M["parapet"])
        # support posts
        for b in range(bays + 1):
            ps = min(max(s0 + bw * b, s0 + .08), s1 - .08)
            fr.box(rail, ps, 1.02, 1.12, .055, .055, 1.12, M["rail"])
        # railing with balusters, gap for the stair landing
        gaps = [stair_gap] if stair_gap else []
        segs, cur = [], s0
        for g0, g1 in sorted(gaps):
            segs.append((cur, g0))
            cur = g1
        segs.append((cur, s1))
        for a, b2 in segs:
            mid, hs = (a + b2) / 2, (b2 - a) / 2
            fr.box(rail, mid, 1.04, 3.42, hs, .035, .025, M["rail"])
            fr.box(rail, mid, 1.04, 2.56, hs, .02, .015, M["rail"])
            k = a
            while k <= b2:
                fr.box(rail, k, 1.04, 2.99, .011, .011, .43, M["rail"])
                k += .14
            for k in range(int((b2 - a) / bw * 2) + 1):
                fr.box(rail, a + k * bw / 2, 1.04, 3.0, .03, .03, .45, M["rail"])
    mb.build(bevel=.012)
    rail.build()
    pots.build(smooth=True)


def roof(name, x0, x1, y0, y1, units, seed):
    rnd = random.Random(seed)
    mb = MB(name + " roof")
    cx, cy, hx, hy = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2
    mb.box((cx, cy, 4.69), (hx + .08, hy + .08, .09), M["roof"])
    t, h = .16, .2
    for (px, py, sx, sy) in ((cx, y0 + t / 2, hx + .08, t / 2), (cx, y1 - t / 2, hx + .08, t / 2),
                              (x0 + t / 2, cy, t / 2, hy + .08), (x1 - t / 2, cy, t / 2, hy + .08)):
        mb.box((px, py, 4.78 + h / 2), (sx + .02, sy + .02, h / 2), M["parapet"])
        mb.box((px, py, 4.78 + h + .03), (sx + .05, sy + .05, .03), M["trim"])
    eq = MB(name + " rooftop equipment")
    for (ux, uy) in units:
        rot = rnd.choice((0, math.pi / 2))
        eq.box((ux, uy, 5.15), (.55, .42, .37), M["ice"], rz=rot)
        eq.disc((ux, uy, 5.53), .3, M["metal"], 20)
        eq.disc((ux, uy, 5.535), .3, M["steel"], 20, r_in=.27)
        for k in range(4):
            eq.box((ux, uy, 5.54), (.29, .012, .01), M["steel"], rz=k * math.pi / 4)
        # refrigerant lines running across the roof to the wall edge
        ex = ux + rnd.uniform(-1.2, 1.2)
        eq.cyl((ux + .5, uy, 4.86), (ex, uy, 4.86), .035, M["steel"], 8)
        eq.cyl((ex, uy, 4.86), (ex, uy + rnd.choice((-1, 1)) * 1.1, 4.86), .035, M["steel"], 8)
    for i in range(int(hx * hy / 3)):
        vx, vy = rnd.uniform(x0 + .5, x1 - .5), rnd.uniform(y0 + .5, y1 - .5)
        if rnd.random() < .6:
            eq.cyl((vx, vy, 4.78), (vx, vy, 5.25), .07, M["steel"], 10)
            eq.cyl((vx, vy, 5.25), (vx, vy, 5.32), .13, M["metal"], 10)
        else:
            eq.box((vx, vy, 4.9), (.3, .3, .12), M["metal"], rz=rnd.uniform(0, 1))
    # sheet-metal duct runs and skylights
    for i in range(max(1, int(hx * hy / 9))):
        dx, dy = rnd.uniform(x0 + .8, x1 - .8), rnd.uniform(y0 + .8, y1 - .8)
        if hx > hy:
            eq.box((dx, dy, 4.98), (rnd.uniform(.8, 1.8), .2, .2), M["metal"])
        else:
            eq.box((dx, dy, 4.98), (.2, rnd.uniform(.8, 1.8), .2), M["metal"])
        sx_, sy_ = rnd.uniform(x0 + .7, x1 - .7), rnd.uniform(y0 + .7, y1 - .7)
        eq.box((sx_, sy_, 4.84), (.38, .38, .06), M["trim"])
        eq.box((sx_, sy_, 4.9), (.32, .32, .02), M["glass"])
    # gravel / debris specks and leaves
    for i in range(int(hx * hy * 4)):
        eq.blob((rnd.uniform(x0 + .3, x1 - .3), rnd.uniform(y0 + .3, y1 - .3), 4.785), rnd.uniform(.03, .07),
                rnd.choice((M["concrete"], M["dead"], M["roof"])), .4)
    mb.build(bevel=.02)
    eq.build(bevel=.01)


def staircase(name, x_bottom, x_top, y, width=1.0, top_z=2.45):
    mb = MB(name)
    steps = 13
    run = (x_top - x_bottom) / steps
    rise = top_z / steps
    for i in range(steps):
        x = x_bottom + run * (i + .5)
        mb.box((x, y, rise * (i + 1) - .03), (abs(run) / 2 + .02, width / 2, .03), M["concrete"])
        mb.box((x - run * .45, y, rise * (i + .5)), (.012, width / 2 - .02, rise / 2), M["metal"])
    # stringers
    for sy in (-1, 1):
        a = Vector((x_bottom, y + sy * width / 2, 0))
        b = Vector((x_top, y + sy * width / 2, top_z))
        mb.cyl(a, b, .06, M["metal"], 6)
    # landing joining the balcony, with a post
    lx = x_top + .55
    mb.box((lx, y - .1, top_z - .08), (.6, width / 2 + .1, .08), M["concrete"])
    mb.box((lx + .45, y + width / 2, top_z / 2), (.05, .05, top_z / 2), M["rail"])
    # handrails with posts on the open side
    for sy in (1,):
        yy = y + sy * width / 2
        a = Vector((x_bottom, yy, .95))
        b = Vector((x_top, yy, top_z + .95))
        mb.cyl(a, b, .03, M["rail"], 8)
        mb.cyl(a - Vector((0, 0, .5)), b - Vector((0, 0, .5)), .015, M["rail"], 6)
        for i in range(0, steps + 1, 2):
            p = a.lerp(b, i / steps)
            mb.cyl(p - Vector((0, 0, .95)), p, .018, M["rail"], 6)
        mb.cyl(b, Vector((x_top + 1.1, yy, top_z + .95)), .03, M["rail"], 8)
    mb.build(bevel=.01)


# -- props -------------------------------------------------------------------------

def lounger(mb, x, y, rot, towel=None):
    fr = Frame((x, y, 0), (math.cos(rot), math.sin(rot), 0), (-math.sin(rot), math.cos(rot), 0))
    for sd in (-.33, .33):
        fr.box(mb, .1, sd, .33, .95, .025, .025, M["white_plastic"])
        for ss in (-.85, .55):
            fr.box(mb, ss, sd, .16, .025, .025, .16, M["white_plastic"])
    for k in range(13):
        fr.box(mb, -.95 + k * .1, 0, .36, .035, .33, .012, M["white_plastic"])
    # raised backrest
    import mathutils
    tilt = mathutils.Matrix.Rotation(-.75, 3, fr.n) @ fr.M
    for k in range(7):
        c = fr.p(.85 + math.cos(.75) * k * .09, 0, .4 + math.sin(.75) * k * .09)
        mb.box(c, (.035, .33, .012), M["white_plastic"], M=tilt)
    if towel:
        fr.box(mb, -.3, 0, .39, .55, .28, .012, towel)
        fr.box(mb, -.3, 0, .392, .55, .05, .012, M["towel2"])


def cafe_set(mb, x, y, chairs, umbrella=False, rnd=RND):
    mb.cyl((x, y, .02), (x, y, .74), .05, M["metal"], 10)
    mb.cyl((x, y, 0), (x, y, .04), .28, M["metal"], 16)
    mb.cyl((x, y, .74), (x, y, .78), .5, M["white_plastic"], 24)
    if umbrella:
        mb.cyl((x, y, .78), (x, y, 2.55), .03, M["steel"], 8)
        n = 16
        apex = Vector((x, y, 2.62))
        for i in range(n):
            a0, a1 = i * math.tau / n, (i + 1) * math.tau / n
            r = 1.45
            p0 = Vector((x + math.cos(a0) * r, y + math.sin(a0) * r, 2.12))
            p1 = Vector((x + math.cos(a1) * r, y + math.sin(a1) * r, 2.12))
            mat = M["canvas_red"] if i % 2 else M["canvas_white"]
            q0 = apex.lerp(p0, .62) + Vector((0, 0, .03))
            q1 = apex.lerp(p1, .62) + Vector((0, 0, .03))
            mb.face((mb.add(apex), mb.add(q0), mb.add(q1)), mat)
            mb.face((mb.add(q0), mb.add(p0), mb.add(p1), mb.add(q1)), mat)
            # scalloped valance
            v0, v1 = p0, p1
            mb.face((mb.add(v0), mb.add(v0 - Vector((0, 0, .14))), mb.add((v0 + v1) / 2 - Vector((0, 0, .2))),
                     mb.add(v1 - Vector((0, 0, .14))), mb.add(v1)), mat)
        mb.blob(apex + Vector((0, 0, .04)), .05, M["steel"])
    for a in chairs:
        cx, cy = x + math.cos(a) * .8, y + math.sin(a) * .8
        face = a + math.pi
        fr = Frame((cx, cy, 0), (-math.sin(face), math.cos(face), 0), (math.cos(face), math.sin(face), 0))
        fr.box(mb, 0, 0, .44, .23, .23, .025, M["white_plastic"])
        for sx in (-.2, .2):
            for sd in (-.2, .2):
                fr.box(mb, sx, sd, .22, .018, .018, .22, M["white_plastic"])
        fr.box(mb, 0, -.22, .72, .23, .02, .2, M["white_plastic"])
        for k in range(3):
            fr.box(mb, -.12 + k * .12, -.23, .66, .03, .025, .2, M["white_plastic"])
        for sx in (-.23, .23):
            fr.box(mb, sx, 0, .6, .02, .22, .02, M["white_plastic"])
    # a drink or two
    for k in range(rnd.randint(1, 3)):
        a = rnd.uniform(0, math.tau)
        p = Vector((x + math.cos(a) * .25, y + math.sin(a) * .25, .78))
        mb.cyl(p, p + Vector((0, 0, .14)), .035, rnd.choice((M["glass"], M["amber"], M["cyan"])), 8)


def planter(name, x, y, size, rnd, square=False, flowers=None):
    mb = MB(name)
    if square:
        mb.box((x, y, .32), (size * .5, size * .5, .32), M["planter"])
        mb.box((x, y, .66), (size * .5 + .04, size * .5 + .04, .03), M["concrete"])
        mb.box((x, y, .63), (size * .46, size * .46, .02), M["soil"])
    else:
        mb.cyl((x, y, 0), (x, y, .58), size * .42, M["planter"], 20, r2=size * .5)
        mb.cyl((x, y, .56), (x, y, .64), size * .53, M["planter"], 20)
        mb.disc((x, y, .62), size * .48, M["soil"], 20)
    kit.tropical_plant(mb, (x, y, .62), size * 1.25, [M["leaf1"], M["leaf2"], M["frond2"]], rnd,
                       leaves=int(10 + size * 6), flowers=flowers)
    mb.build(smooth=True)


def bollard(mb, x, y):
    mb.cyl((x, y, 0), (x, y, .62), .085, M["metal"], 14)
    mb.cyl((x, y, .62), (x, y, .82), .075, M["amber"], 14)
    mb.cyl((x, y, .82), (x, y, .88), .095, M["metal"], 14)
    point_light("Bollard light", (x, y, .72), WARM, 45, .06)


def parking_stop(mb, x, y):
    mb.box((x, y, .07), (.95, .12, .07), M["yellow"])
    mb.box((x, y, .145), (.85, .06, .01), M["yellow"])


def trash_can(mb, x, y, mat=None):
    mat = mat or M["steel"]
    mb.cyl((x, y, 0), (x, y, .82), .27, mat, 18, r2=.3)
    for zz in (.2, .5, .78):
        mb.cyl((x, y, zz), (x, y, zz + .03), .31, mat, 18)
    mb.cyl((x, y, .84), (x, y, .9), .32, M["metal"], 18, r2=.28)
    mb.box((x, y, .93), (.12, .03, .03), M["metal"])


def dumpster(mb, x, y, rot=0.0):
    fr = Frame((x, y, 0), (math.cos(rot), math.sin(rot), 0), (-math.sin(rot), math.cos(rot), 0))
    fr.box(mb, 0, 0, .7, 1.05, .62, .55, M["dumpster"])
    fr.box(mb, 0, .05, .2, 1.0, .55, .12, M["dumpster"])
    import mathutils
    for side in (-1, 1):
        lid = mathutils.Matrix.Rotation(.08 * side, 3, fr.u) @ fr.M
        mb.box(fr.p(0, side * .33, 1.3), (1.1, .34, .035), M["dumpster"], M=lid)
    for k in range(5):
        fr.box(mb, -.8 + k * .4, .64, .72, .04, .03, .5, M["dumpster"])
    for s in (-.85, .85):
        for d in (-.45, .45):
            mb.cyl(fr.p(s, d, .08), fr.p(s, d, .16), .09, M["rubber"], 10)
    fr.box(mb, 0, .66, .95, .35, .01, .12, M["trim"])  # stencil plate


def towel_cart(mb, x, y, rot=0.0):
    fr = Frame((x, y, 0), (math.cos(rot), math.sin(rot), 0), (-math.sin(rot), math.cos(rot), 0))
    for zz in (.25, .65, 1.0):
        fr.box(mb, 0, 0, zz, .5, .3, .02, M["steel"])
    for s in (-.48, .48):
        for d in (-.28, .28):
            fr.box(mb, s, d, .55, .02, .02, .5, M["steel"])
            mb.cyl(fr.p(s, d, 0), fr.p(s, d, .08), .05, M["rubber"], 8)
    for zz in (.29, .69):
        for k in range(4):
            fr.box(mb, -.36 + k * .24, 0, zz + .06, .1, .24, .05, M["towel2"] if k % 2 else M["towel"])
    fr.box(mb, -.25, 0, 1.08, .18, .2, .07, M["towel2"])


def life_ring(mb, c, normal):
    n = Vector(normal)
    x, y = kit._perp(n)
    seg = 24
    for i in range(seg):
        a0, a1 = i * math.tau / seg, (i + 1) * math.tau / seg
        mat = M["canvas_red"] if (i // 3) % 2 else M["canvas_white"]
        p0 = Vector(c) + (x * math.cos(a0) + y * math.sin(a0)) * .33
        p1 = Vector(c) + (x * math.cos(a1) + y * math.sin(a1)) * .33
        mb.cyl(p0, p1, .085, mat, 8)


def neon_sign(x, y, facing):
    """Pole sign: cabinet with neon lettering, setting sun, palm and VACANCY box."""
    rot = facing
    u = Vector((math.cos(rot), math.sin(rot), 0))
    n = Vector((-math.sin(rot), math.cos(rot), 0))
    fr = Frame((x, y, 0), u, n)
    mb = MB("Neon sign")
    for s in (-1.7, 1.7):
        mb.box(fr.p(s, 0, 2.6), (.12, .12, 2.6), M["metal"], M=fr.M)
    fr.box(mb, 0, 0, 6.1, 2.75, .22, 1.15, M["sign_box"])
    # neon border tubes on the front face
    d = .26
    for (s, z, hs, hz) in ((0, 7.18, 2.65, .028), (0, 5.02, 2.65, .028), (-2.65, 6.1, .028, 1.1), (2.65, 6.1, .028, 1.1)):
        fr.box(mb, s, d, z, hs, .028, hz, M["cyan"])
    fr.box(mb, 0, d, 6.1, 2.45, .02, .025, M["pink"])
    # setting sun: striped half disc above the cabinet, left side
    sx, sz = 1.3, 7.25
    for k in range(6):
        z0 = sz + k * .2
        r = 1.15
        w = math.sqrt(max(0, r * r - (k * .2 + .1) ** 2))
        fr.box(mb, sx, .05, z0 + .08, w, .03, .07, M["orange_neon"] if k % 2 == 0 else M["pink"])
    # neon palm on the right
    ax = fr.p(-1.7, .1, 7.2)
    pts = [ax + Vector((0, 0, 0)), ax + Vector((.1 * u.x, .1 * u.y, .6)), ax + Vector((.05 * u.x, .05 * u.y, 1.3))]
    mb.tube(pts, [.045, .045, .045], M["green_neon"], seg=6)
    crown = pts[-1]
    for i in range(7):
        a = -math.pi * .1 + i * math.pi * 1.2 / 6
        p = [crown]
        for k in range(1, 5):
            t = k / 4
            p.append(crown + u * math.cos(a) * .7 * t + Z * (math.sin(a) * .7 * t - .35 * t * t) + n * .02)
        mb.tube(p, [.035] * len(p), M["green_neon"], seg=6)
    # VACANCY box below the cabinet
    fr.box(mb, -.9, 0, 4.55, 1.2, .15, .3, M["sign_box"])
    for (s, z, hs, hz) in ((-.9, 4.83, 1.15, .02), (-.9, 4.27, 1.15, .02), (.25, 4.55, .02, .28), (-2.05, 4.55, .02, .28)):
        fr.box(mb, s, .18, z, hs, .02, hz, M["pink"])
    mb.build()
    for text, s, z, size, mat, depth in (("SUNSET", 0, 6.55, .78, M["pink"], .3), ("PALMS", 0, 5.62, .74, M["cyan"], .3),
                                          ("VACANCY", -.9, 4.55, .36, M["red_neon"], .2)):
        curve = bpy.data.curves.new(text, "FONT")
        curve.body, curve.align_x, curve.align_y = text, "CENTER", "CENTER"
        curve.size, curve.extrude, curve.bevel_depth = size, .02, .018
        obj = bpy.data.objects.new(text, curve)
        bpy.context.collection.objects.link(obj)
        obj.location = fr.p(s, depth, z)
        obj.rotation_euler = (math.pi / 2, 0, rot + math.pi)
        obj.data.materials.append(mat)
    point_light("Sign pink spill", fr.p(0, 1.6, 6.0), (1.0, .05, .4), 900, .8)
    point_light("Sign cyan spill", fr.p(0, 1.2, 5.3), (.1, .7, 1.0), 500, .8)
    area_light("Sign ground wash", fr.p(0, 2.5, 4.5), (1.0, .1, .45), 900, 3, fr.p(0, 3.5, 0))


def string_lights(name, start, end, bulbs=15, sag=.65, light_every=3):
    mb = MB(name)
    a, b = Vector(start), Vector(end)
    pts = []
    for i in range(bulbs):
        k = i / (bulbs - 1)
        p = a.lerp(b, k)
        p.z -= math.sin(k * math.pi) * sag
        pts.append(p)
    mb.tube(pts, [.012] * len(pts), M["rail"], seg=5)
    for i, p in enumerate(pts):
        mb.cyl(p, p - Vector((0, 0, .08)), .02, M["metal"], 6)
        mb.blob(p - Vector((0, 0, .14)), .065, M["bulb"], 1.3)
        if i % light_every == 1:
            point_light(name + " glow", p - Vector((0, 0, .25)), (1.0, .55, .22), 40, .05)
    mb.build(smooth=True)


def import_glb(path, name, x, y, rot, length, along_y=True):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    imported = [o for o in bpy.context.scene.objects if o not in before]
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    for o in imported:
        if o.parent is None:
            o.parent = root
    bpy.context.view_layer.update()
    corners = []
    for o in imported:
        if o.type == "MESH":
            corners += [o.matrix_world @ Vector(c) for c in o.bound_box]
    sx = max(v.x for v in corners) - min(v.x for v in corners)
    sy = max(v.y for v in corners) - min(v.y for v in corners)
    zmin = min(v.z for v in corners)
    scale = length / max(sx, sy)
    root.scale = Vector((scale,) * 3)
    extra = 0.0
    if along_y and sx > sy:
        extra = math.pi / 2
    root.rotation_euler[2] = rot + extra
    root.location = (x, y, -zmin * scale + .01)
    return root


def crude_car(name, x, y, rot=0.0):
    mb = MB(name)
    fr = Frame((x, y, 0), (math.cos(rot), math.sin(rot), 0), (-math.sin(rot), math.cos(rot), 0))
    fr.box(mb, 0, 0, .5, .82, 2.3, .3, M["redcar"])
    fr.box(mb, 0, -.1, .95, .72, 1.1, .25, M["glass"])
    mb.build(bevel=.15)


# -- scene ---------------------------------------------------------------------------

def build():
    world = bpy.data.worlds.new("California night")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (.008, .008, .03, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = .5

    cube("Asphalt lot", (0, 4, -.18), (16, 12, .18), M["asphalt"])
    cube("Courtyard slab", (0, -3.4, -.02), (12.2, 7.0, .12), M["deck"], .04)
    # kerb along the parking edge
    cube("Courtyard kerb", (0, 3.55, .05), (12.2, .12, .1), M["concrete"], .02)

    # --- buildings (footprints unchanged) ---
    cube("North motel wing", (0, -10, 2.3), (12, 1.5, 2.3), M["stucco"], .05)
    cube("West wing", (-11.4, -3.5, 2.3), (1.5, 6.7, 2.3), M["stucco"], .05)
    cube("East wing", (11.4, -3.5, 2.3), (1.5, 6.7, 2.3), M["stucco"], .05)
    north = Frame((0, -8.5, 0), (1, 0, 0), (0, 1, 0))
    facade(north, "North wing", -9.9, 9.9, 6, door_skip={(5, 0)}, stair_gap=(8.2, 9.4))
    west = Frame((-9.9, -3.5, 0), (0, -1, 0), (1, 0, 0))   # faces the courtyard and camera
    facade(west, "West wing", -6.7, 5.0, 3)
    east_out = Frame((12.9, -3.5, 0), (0, -1, 0), (1, 0, 0))  # outer wall, seen from camera side
    mb = MB("East wing back wall")
    for k in range(5):
        s = -6.0 + k * 2.6
        for zc in (1.5, 3.9):
            window(mb, east_out, s, zc, w=.35, h=.32, ac=False)
        mb.cyl(east_out.p(s + 1.2, .12, 0), east_out.p(s + 1.2, .12, 4.75), .05, M["steel"], 8)
        east_out.box(mb, s + .5, .25, 2.7, .38, .25, .24, M["ice"])
        for j in range(6):
            east_out.box(mb, s + .25 + j * .1, .505, 2.7, .02, .01, .18, M["metal"])
    east_out.box(mb, 0, .02, .18, 6.7, .03, .18, M["stucco_dark"])
    mb.cyl(east_out.p(-6.6, .08, 3.3), east_out.p(6.6, .08, 3.3), .03, M["steel"], 8)
    mb.build(bevel=.01)
    # south ends of the side wings (face the parking lot)
    for sx, name in ((-11.4, "West"), (11.4, "East")):
        fr = Frame((sx, 3.2, 0), (1, 0, 0), (0, 1, 0))
        mb = MB(name + " wing end")
        fr.box(mb, 0, .02, .18, 1.5, .03, .18, M["stucco_dark"])
        window(mb, fr, -.45, 1.35, w=.5, h=.45)
        window(mb, fr, -.45, 3.75, w=.5, h=.45)
        if name == "West":
            door(mb, fr, .75, 0, 0)
            wall_lamp(mb, fr, .1, 1.9)
            fr.box(mb, .75, .14, 2.25, .5, .02, .12, M["cyan"])  # "OFFICE" light strip
        mb.build(bevel=.01)
    # Low, recessed gallery lights keep the balcony undersides readable and
    # add the warm-vs-cool depth seen in the reference pixel scenes.
    for i, x in enumerate((-8.4, -5.2, -2.0, 1.2, 4.4, 7.6)):
        point_light("North gallery underlight %02d" % i, (x, -7.72, 2.62),
                    (1.0, .24, .08), 42, .22)
    for i, y in enumerate((-6.0, -2.8, .4, 2.0)):
        point_light("West gallery underlight %02d" % i, (-9.62, y, 2.62),
                    (1.0, .28, .10), 36, .2)
    # Rooftop service clutter: thin conduits, vents and a few windblown
    # maintenance crates break up the large dark roof planes.
    roof_props = MB("Rooftop service detail")
    for x, y, w in ((-8.6, -10.9, .7), (-3.8, -10.65, .48), (2.4, -10.95, .58),
                    (-11.8, -1.5, .55), (-11.8, 1.3, .42), (11.8, -4.2, .5),
                    (11.8, .9, .62)):
        roof_props.box((x, y, .18), (w, w * .72, .18), M["metal"], rz=RND.uniform(-.12, .12))
        roof_props.box((x, y, .38), (w * .72, w * .48, .08), M["steel"], rz=RND.uniform(-.12, .12))
    for x, y in ((-6.2, -10.7), (-1.0, -10.4), (4.6, -10.5), (-11.75, -6.0), (11.75, -7.0)):
        roof_props.cyl((x, y, .16), (x, y, .62), .09, M["steel"], 10)
        roof_props.cyl((x, y, .63), (x, y, .68), .14, M["trim"], 10)
    roof_props.build(bevel=.025)
    roof("North", -12, 12, -11.5, -8.5, [(-6.5, -10.2), (-1.0, -10.4), (4.5, -10.1)], 3)
    roof("West", -12.9, -9.9, -10.2, 3.2, [(-11.4, -5.5), (-11.4, 0.2)], 4)
    roof("East", 9.9, 12.9, -10.2, 3.2, [(11.4, -6.0), (11.4, -1.5), (11.4, 1.8)], 5)
    staircase("Balcony stair", 4.6, 8.2, -6.9)

    # bougainvillea draped over balcony rails and wing corners
    bg = MB("Bougainvillea")
    flowers = {"flower": M["bract"], "leaf": M["leaf2"]}
    kit.bougainvillea(bg, [(-9.7, -7.5, 3.2), (-6.8, -7.45, 3.4)], flowers, RND, 120, .3)
    kit.bougainvillea(bg, [(1.3, -7.45, 3.3), (2.9, -7.45, 3.0), (3.2, -7.5, 1.5)], flowers, RND, 90, .25)
    kit.bougainvillea(bg, [(-8.85, -2.0, 3.3), (-8.85, 1.2, 3.4)], flowers, RND, 110, .28)
    kit.bougainvillea(bg, [(-9.75, 3.0, .5), (-9.75, 3.0, 4.2)], flowers, RND, 70, .25)
    kit.bougainvillea(bg, [(9.8, 3.25, .3), (9.6, 3.3, 3.8)], flowers, RND, 60, .25)
    bg.build()

    # --- pool ---
    cube("Pool tile basin", (0, -3.0, .02), (4.5, 2.65, .20), M["tile"], .05)
    cube("Pool water", (0, -3.0, .25), (4.18, 2.32, .06), M["water"])
    pm = MB("Pool coping")
    for ix in range(-9, 10):
        for yy in (-5.52, -.48):
            pm.box((ix * .48, yy, .30), (.225, .19, .075), M["coping"])
    for iy in range(-5, 6):
        for xx in (-4.48, 4.48):
            pm.box((xx, -3 + iy * .47, .30), (.19, .22, .075), M["coping"])
    for ix in range(-16, 17):
        for yy in (-5.26, -.74):
            pm.box((ix * .25, yy, .2), (.115, .025, .075), M["cyan_paint"])
    for i in range(4):
        pm.box((-3.65 + i * .28, -4.6 + i * .12, .12 - i * .035), (.72 - i * .1, .40, .045), M["tile"])
    for x in (-3.6, 3.6):
        pm.box((x, -5.22, .19), (.25, .025, .09), M["metal"])
    # ladder at the east end (camera side)
    for dy in (-.28, .28):
        pts = [Vector((4.75, -3 + dy, .35)), Vector((4.6, -3 + dy, 1.05)), Vector((4.35, -3 + dy, 1.1)), Vector((4.15, -3 + dy, .7)), Vector((4.15, -3 + dy, .1))]
        pm.tube(pts, [.03] * 5, M["steel"], seg=8)
    for z in (.15, .35):
        pm.box((4.15, -3, z), (.03, .26, .02), M["steel"])
    pm.build(bevel=.02)
    for x in (-3.0, 0, 3.0):
        point_light("Pool lamp", (x, -3.0, .4), (.1, .85, 1.0), 260, .8)

    # --- courtyard props ---
    props = MB("Courtyard furniture")
    lounger(props, -5.6, -1.9, 0.0, M["towel"])
    lounger(props, -5.6, -4.3, 0.1)
    lounger(props, 5.6, -2.2, math.pi, M["towel2"])
    lounger(props, 5.6, -4.3, math.pi - .1, M["towel"])
    cafe_set(props, -7.7, -3.1, [0.3, 2.3, 4.3], umbrella=True)
    cafe_set(props, 7.0, -5.1, [0.6, 3.6])
    cafe_set(props, 1.2, 1.5, [.2, 2.2, 4.2], umbrella=True)
    towel_cart(props, .3, -7.05, 0.0)
    trash_can(props, -2.6, -7.1, M["cyan_paint"])
    trash_can(props, -9.3, 2.6, M["steel"])
    trash_can(props, -7.4, 4.3, M["steel"])
    life_ring(props, (-9.85, -2.7, 1.55), (1, 0, 0))
    life_ring(props, (-2.1, -8.45, 1.5), (0, 1, 0))
    props.cyl((-4.9, -.2, 0), (-4.9, -.2, 2.1), .04, M["steel"], 10)  # pool shower
    props.cyl((-4.9, -.2, 2.1), (-4.65, -.2, 2.15), .03, M["steel"], 8)
    props.cyl((-4.65, -.2, 2.15), (-4.65, -.2, 2.0), .08, M["steel"], 10, r2=.12)
    # vending & ice machine under the stair landing
    props.box((8.75, -7.85, 1.0), (.5, .38, 1.0), M["metal"])
    props.box((8.75, -7.46, 1.15), (.4, .02, .72), M["vend"])
    props.box((7.55, -7.95, .72), (.52, .4, .72), M["ice"])
    props.box((7.55, -7.54, 1.15), (.4, .02, .12), M["cyan"])
    dumpster(props, -8.8, 4.55, 0.0)
    for x in (-5.5, -.5, 4.5, 9.5):
        parking_stop(props, x, 4.5)
    for i in range(8):
        bollard(props, -10.2 + i * 2.9, 3.0)
    props.build(bevel=.008)
    point_light("Vending glow", (8.75, -6.9, 1.2), (.5, .8, 1.0), 120, .3)
    point_light("Ice glow", (7.55, -7.0, 1.3), (.2, .8, 1.0), 40, .2)

    string_lights("Courtyard festoon A", (-9.6, -7.2, 3.8), (8.8, 2.6, 4.6), 19, .9)
    string_lights("Courtyard festoon B", (-8.8, 2.6, 4.4), (9.4, -7.2, 3.8), 19, .9)
    string_lights("Balcony festoon", (-9.8, -7.4, 3.5), (8.1, -7.4, 3.5), 25, .25, 4)
    string_lights("West balcony festoon", (-8.85, 1.4, 3.5), (-8.85, -7.3, 3.5), 12, .2, 4)

    # --- vegetation ---
    pal = MB("Palms")
    pmats = {"trunk": M["trunk"], "ring": M["palm_ring"], "nut": M["nut"], "dead": M["dead"],
             "frond": [M["frond1"], M["frond2"], M["frond2"], M["frond3"]]}
    for i, (x, y, h, lx, ly) in enumerate([(-8, -6, 5.8, .25, .1), (8, -6, 5.4, -.3, .15), (-8, 1, 6.2, .2, -.2),
                                            (8, 1, 5.7, -.25, -.1), (-13.6, 9.6, 6.5, .35, .2), (13, 8, 6.0, -.3, .25)]):
        kit.palm(pal, (x, y, 0), h, pmats, seed=i * 7 + 1, lean=(lx, ly), fronds=20, spread=1.05)
        mb = MB(f"Palm well {i}")
        mb.cyl((x, y, 0), (x, y, .12), .75, M["concrete"], 20)
        mb.disc((x, y, .125), .7, M["soil"], 20)
        mb.build()
        spot_light(f"Palm uplight {i}", (x + .9, y + .9, .25), (1.0, .6, .3), 900, (x + lx, y + ly, h * .8), .6, .05, False)
    pal.build(smooth=True)
    for i, (x, y, s, sq, fl) in enumerate([(-7, -1, 1.0, False, M["flower_or"]), (7, -.5, 1.0, False, None),
                                           (-6, -7.1, .9, True, M["bract"]), (3.9, -6.9, .9, True, None),
                                           (-11.2, 4.6, 1.1, True, M["bract"]), (9, 5, 1.1, True, M["flower_or"]),
                                           (-4.6, -7.3, .7, False, None), (-1.0, -7.3, .7, False, M["bract"])]):
        planter(f"Planter {i}", x, y, s, random.Random(40 + i), sq, fl)

    # --- parking lot ---
    detailed = ELDORADO.exists()
    if detailed:
        if FORCE_BLENDER_NATIVE_VEHICLES:
            crude_car("Cass Eldorado (Blender native)", -5.0, 7.5, .05)
        else:
            import_glb(ELDORADO, "Cass Eldorado", -5.0, 7.5, .05, 4.6, along_y=False)
    if SEDAN.exists():
        if FORCE_BLENDER_NATIVE_VEHICLES:
            crude_car("Guest sedan (Blender native)", 2.0, 8.2, -.04)
        else:
            import_glb(SEDAN, "Guest sedan", 2.0, 8.2, -.04, 5.0)
    else:
        crude_car("Guest sedan", 2.0, 8.2, -.04)
    if SEDAN.exists():
        if FORCE_BLENDER_NATIVE_VEHICLES:
            crude_car("Abandoned sedan (Blender native)", 8.7, 7.2, math.pi + .08)
        else:
            import_glb(SEDAN, "Abandoned sedan", 8.7, 7.2, math.pi + .08, 5.0)
    else:
        crude_car("Abandoned sedan", 8.7, 7.2, .08)
    lot = MB("Lot markings")
    for x in (-8, -3, 2, 7, 12):
        lot.box((x, 7.1, .005), (.06, 2.8, .006), M["trim"])
    for i, (x, y, s, r) in enumerate([(-8, 10, 2.3, .12), (5, 11, 1.7, -.08), (11, 4.5, 2.0, .25), (-2, 4.3, 1.3, -.2)]):
        lot.box((x, y, .004), (s, .035, .005), M["roof"], rz=r)
    lot.build()
    # Staging-only arrival approach: a wet access road, gate posts and raised
    # barrier arms complete the motel exterior without changing the Godot
    # entrance trigger or car route.
    approach = MB("Sunset Palms entrance approach")
    # Give the approach camera enough authored road surface to fill the frame;
    # this is staging-only and does not alter the gameplay entrance footprint.
    approach.box((0, 14.0, -.005), (15.8, 8.0, .008), M["asphalt"])
    for x in (-10.8, -5.4, 0.0, 5.4, 10.8):
        approach.box((x, 14.0, .012), (.05, .85, .006), M["trim"])
    # Keep the arrival gate legible in the review crop while leaving the
    # original parking and vehicle route untouched.
    for x in (-6.8, 6.8):
        approach.cyl((x, 12.9, 0), (x, 12.9, 1.25), .16, M["concrete"], 16)
        approach.cyl((x, 12.9, 1.25), (x, 12.9, 1.48), .18, M["amber"], 16)
        approach.box((x * .58, 12.9, 1.18), (3.8, .045, .045), M["metal"], rz=0.02 if x < 0 else -0.02)
    approach.box((0, 12.75, .04), (7.4, .035, .012), M["concrete"])
    # Staging-only gate illumination: keeps the arrival composition readable
    # without changing the gameplay route or any runtime light setup.
    for i, x in enumerate((-5.6, 5.6)):
        point_light(f"Arrival gate amber {i}", (x, 12.55, 1.75), (1.0, .34, .08), 180, .28)
        point_light(f"Arrival lane cyan {i}", (x * .72, 13.72, .55), (.08, .45, 1.0), 75, .18)
    # Small arrival cues keep the approach readable at a glance without
    # competing with the approved pool courtyard: reflective bollards and a
    # pair of worn directional chevrons on the wet lane.
    for x in (-4.8, 4.8):
        approach.cyl((x, 13.55, .18), (x, 13.55, .38), .09, M["amber"], 12)
        approach.box((x, 13.55, .39), (.11, .035, .025), M["metal"])
    for x in (-2.2, 2.2):
        approach.box((x, 14.05, .018), (.55, .07, .006), M["amber"], rz=math.radians(18 if x < 0 else -18))
    approach.build(bevel=.02)
    # wet litter: leaves scattered on the lot and deck
    lit = MB("Litter")
    for i in range(70):
        x, y = RND.uniform(-14, 14), RND.uniform(-7, 14)
        if -4.6 < x < 4.6 and -5.7 < y < -.3:
            continue
        lit.blob((x, y, .01), RND.uniform(.04, .08), RND.choice((M["palm_ring"], M["palm_ring"], M["nut"], M["frond1"])), .15)
    lit.build()
    neon_sign(-10.5, 5.5, math.radians(-25))

    # --- planar reflections for the wet ground (lot and deck) ---
    for nm, loc, sc in (("Lot reflections", (0, 9.5, .01), (16, 6.2, 1)), ("Deck reflections", (0, -3.4, .11), (12.2, 7.0, 1))):
        pd = bpy.data.lightprobes.new(nm, "PLANE")
        po = bpy.data.objects.new(nm, pd)
        bpy.context.collection.objects.link(po)
        po.location, po.scale = loc, sc

    # --- lighting ---
    area_light("Moon key", (-8, 4, 15), (.3, .42, 1.0), 700, 8, (0, -3, 0))
    area_light("Warm courtyard", (2, -3, 9), (1.0, .42, .16), 500, 8, (0, -3, 0))
    area_light("Violet fill", (12, 12, 10), (.45, .2, 1.0), 600, 10, (0, 0, 0))
    for x in (-6.5, -2, 2.5, 7):
        point_light("Walkway amber", (x, -7.6, 2.0), WARM, 120, .4)

    # --- camera (unchanged framing) ---
    cam_data = bpy.data.cameras.new("Courtyard master camera")
    cam = bpy.data.objects.new("Courtyard master camera", cam_data)
    bpy.context.collection.objects.link(cam)
    cam_data.type, cam_data.ortho_scale, cam_data.lens = "ORTHO", 31.5, 50
    target = Vector((0, -1.6, 1.0))
    elev, az = math.radians(50), math.radians(30)
    cam.location = target + Vector((math.cos(elev) * math.sin(az), math.cos(elev) * math.cos(az), math.sin(elev))) * 36
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam_data.clip_end = 200
    scene = bpy.context.scene
    scene.camera = cam
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 64 if PIXEL_HQ else (48 if PIXEL else (24 if QUICK else 96))
    scene.eevee.use_raytracing = True
    scene.eevee.ray_tracing_method = "SCREEN"
    scene.eevee.use_fast_gi = True
    scene.eevee.use_shadows = True
    scene.render.resolution_x, scene.render.resolution_y = ((960, 540) if PIXEL_HQ else (480, 270)) if (PIXEL or PIXEL_HQ) else (1920, 1080)
    scene.render.resolution_percentage = 50 if QUICK else 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.film_transparent = False
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = -.35
    # neon bloom through the compositor
    ng = bpy.data.node_groups.new("Neon glow", "CompositorNodeTree")
    ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    rl = ng.nodes.new("CompositorNodeRLayers")
    gl = ng.nodes.new("CompositorNodeGlare")
    gl.inputs["Type"].default_value = "Bloom"
    gl.inputs["Quality"].default_value = "High"
    gl.inputs["Threshold"].default_value = 2.0
    gl.inputs["Strength"].default_value = .3
    gl.inputs["Size"].default_value = .55
    out = ng.nodes.new("NodeGroupOutput")
    ng.links.new(rl.outputs["Image"], gl.inputs["Image"])
    ng.links.new(gl.outputs["Image"], out.inputs[0])
    scene.compositing_node_group = ng
    scene.render.use_compositing = True
    name = "courtyard_pixel_source_hq.png" if PIXEL_HQ else ("courtyard_pixel_source.png" if PIXEL else ("courtyard_quick.png" if QUICK else "courtyard_master.png"))
    scene.render.filepath = str(OUT / name)
    if not QUICK:
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "sunset_palms_courtyard.blend"))
    bpy.ops.render.render(write_still=True)
    if os.environ.get("M01_APPROACH_DETAIL") == "1":
        # Keep both gate posts, barrier arms and the arrival lane in frame.
        # This is a staging review camera only; the gameplay camera contract
        # remains the unchanged courtyard master camera above.
        cam_data.ortho_scale = 23.0
        approach_target = Vector((0, 13.25, .65))
        approach_az = math.radians(180)
        # Keep the review camera close enough to the authored gate kit that the
        # wet lane and both barrier posts fill the frame.  The previous wide
        # distance made the narrow approach read as an empty black strip.
        cam.location = approach_target + Vector((math.cos(elev) * math.sin(approach_az), math.cos(elev) * math.cos(approach_az), math.sin(elev))) * 13.5
        cam.rotation_euler = (approach_target - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.shift_y = -0.42
        if os.environ.get("M01_APPROACH_4K") == "1":
            scene.render.resolution_x, scene.render.resolution_y = (3840, 2160)
            scene.render.filepath = str(OUT / "entrance_approach_detail_staging_4k.png")
        else:
            scene.render.resolution_x, scene.render.resolution_y = (1280, 720)
            scene.render.filepath = str(OUT / "entrance_approach_detail_staging.png")
        bpy.ops.render.render(write_still=True)


build()
