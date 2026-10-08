"""Build staging-only Blender interiors for M01 Sunset Palms."""
from pathlib import Path
import math
import os
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ.get('M01_INTERIOR_OUT', str(ROOT/'assets/art/prerendered/m01_sunset_palms/staging'))); OUT.mkdir(parents=True,exist_ok=True)
RENDER_DIR=OUT/'4k' if os.environ.get('M01_INTERIOR_4K')=='1' else OUT
RENDER_DIR.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(n,c,metal=0,rough=.55,emit=None):
 m=bpy.data.materials.new(n); m.diffuse_color=(*c,1); m.use_nodes=True; b=m.node_tree.nodes.get('Principled BSDF'); b.inputs['Base Color'].default_value=(*c,1); b.inputs['Roughness'].default_value=rough; b.inputs['Metallic'].default_value=metal
 if emit: b.inputs['Emission Color'].default_value=(*emit,1); b.inputs['Emission Strength'].default_value=3
 return m
M={'wall':mat('wall',(.1,.13,.2),rough=.72),'trim':mat('trim',(.42,.18,.1),rough=.5),'floor':mat('floor',(.22,.14,.12),rough=.75),'tile':mat('tile',(.16,.22,.28),rough=.65),'wood':mat('wood',(.28,.1,.07),rough=.72),'metal':mat('metal',(.08,.11,.15),.65,.32),'cyan':mat('cyan',(.03,.35,.55),emit=(.03,.55,1)),'amber':mat('amber',(.8,.2,.03),emit=(1,.18,.02)),'green':mat('green',(.06,.25,.12),rough=.9),'paper':mat('paper',(.7,.55,.34),rough=.8),'grout':mat('grout',(.035,.045,.07),rough=.9),'accent':mat('accent',(.55,.12,.08),rough=.48)}
def add_surface_variation(ma, scale=5.0, amount=.12):
 nodes=ma.node_tree.nodes; links=ma.node_tree.links; bs=nodes.get('Principled BSDF'); tex=nodes.new('ShaderNodeTexCoord'); noise=nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=scale; noise.inputs['Detail'].default_value=4.0; ramp=nodes.new('ShaderNodeValToRGB'); base=tuple(ma.diffuse_color[:3]); ramp.color_ramp.elements[0].color=(*[max(0,c-amount) for c in base],1); ramp.color_ramp.elements[1].color=(*[min(1,c+amount) for c in base],1); links.new(tex.outputs['Generated'],noise.inputs['Vector']); links.new(noise.outputs['Fac'],ramp.inputs['Fac']); links.new(ramp.outputs['Color'],bs.inputs['Base Color'])
 bump=nodes.new('ShaderNodeTexNoise'); bump.name=ma.name+' micro-bump'; bump.inputs['Scale'].default_value=scale*1.35; bump.inputs['Detail'].default_value=3.0
 bump_out=nodes.new('ShaderNodeBump'); bump_out.inputs['Strength'].default_value=.16; bump_out.inputs['Distance'].default_value=.06
 links.new(tex.outputs['Generated'],bump.inputs['Vector']); links.new(bump.outputs['Fac'],bump_out.inputs['Height']); links.new(bump_out.outputs['Normal'],bs.inputs['Normal'])
for _name,_scale in [('wall',3.2),('floor',7.0),('wood',12.0),('metal',18.0),('tile',9.0)]: add_surface_variation(M[_name],_scale,.09 if _name!='wall' else .07)

# -- 2026-10-06 authored detail pass (Claude, continuing the handoff) ------------
# The courtyard master's own mesh kit (batched MB geometry, real palms/plants) so
# interiors reach the same authored density; patterned materials for wallpaper,
# carpet, bedspreads and wood grain; practical lamps that cast light pools.
import random, sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
import prerendered_kit as kit
from m01_detergent import bottle as detergent_bottle
RND = random.Random(1988)
def pattern_mat(n, c1, c2, kind, scale, rough=.7, bump=.05):
 """Two-colour procedural pattern: 'stripes' (wallpaper), 'carpet', 'floral', 'grain', 'check'."""
 m = mat(n, c1, rough=rough); nodes = m.node_tree.nodes; links = m.node_tree.links; bs = nodes.get('Principled BSDF')
 tc = nodes.new('ShaderNodeTexCoord').outputs['Object']
 if kind == 'stripes':
  t = nodes.new('ShaderNodeTexWave'); t.wave_type = 'BANDS'; t.bands_direction = 'X'; t.inputs['Scale'].default_value = scale; t.inputs['Distortion'].default_value = 0.0; fac = t.outputs['Fac']
 elif kind == 'grain':
  t = nodes.new('ShaderNodeTexWave'); t.wave_type = 'BANDS'; t.bands_direction = 'X'; t.inputs['Scale'].default_value = scale; t.inputs['Distortion'].default_value = 6.0; t.inputs['Detail'].default_value = 4.0; fac = t.outputs['Fac']
 elif kind == 'check':
  t = nodes.new('ShaderNodeTexChecker'); t.inputs['Scale'].default_value = scale; fac = t.outputs['Fac']
 else:  # carpet / floral: cellular blotches with a fine weave
  t = nodes.new('ShaderNodeTexVoronoi'); t.inputs['Scale'].default_value = scale; fac = t.outputs['Distance']
 links.new(tc, t.inputs['Vector'])
 ramp = nodes.new('ShaderNodeValToRGB'); ramp.color_ramp.elements[0].color = (*c1, 1); ramp.color_ramp.elements[1].color = (*c2, 1)
 if kind in ('stripes', 'check'): ramp.color_ramp.interpolation = 'CONSTANT'; ramp.color_ramp.elements[1].position = .5
 if kind == 'floral': ramp.color_ramp.elements[0].position = .32; ramp.color_ramp.elements[1].position = .36
 links.new(fac, ramp.inputs['Fac'])
 weave = nodes.new('ShaderNodeTexNoise'); weave.inputs['Scale'].default_value = scale * 9; weave.inputs['Detail'].default_value = 8.0; links.new(tc, weave.inputs['Vector'])
 mix = nodes.new('ShaderNodeMixRGB'); mix.blend_type = 'OVERLAY'; mix.inputs['Fac'].default_value = .25
 links.new(ramp.outputs['Color'], mix.inputs['Color1']); links.new(weave.outputs['Fac'], mix.inputs['Color2']); links.new(mix.outputs['Color'], bs.inputs['Base Color'])
 b = nodes.new('ShaderNodeBump'); b.inputs['Strength'].default_value = bump; links.new(weave.outputs['Fac'], b.inputs['Height']); links.new(b.outputs['Normal'], bs.inputs['Normal'])
 return m
M.update({
 'wallpaper': pattern_mat('wallpaper stripes', (.16, .2, .24), (.2, .26, .3), 'stripes', 9.0, rough=.8),
 'wallpaper_warm': pattern_mat('wallpaper warm', (.32, .16, .12), (.38, .2, .15), 'stripes', 7.0, rough=.8),
 'carpet': pattern_mat('motel carpet', (.24, .09, .1), (.12, .2, .22), 'carpet', 6.0, rough=.95, bump=.12),
 'lobby_floor': pattern_mat('lobby terrazzo check', (.42, .36, .3), (.2, .16, .14), 'check', 2.0, rough=.35),
 'laundry_floor': pattern_mat('laundry tile', (.36, .38, .38), (.28, .3, .31), 'check', 4.0, rough=.4),
 'bedspread': pattern_mat('floral bedspread', (.95, .45, .12), (.06, .32, .34), 'floral', 7.0, rough=.9, bump=.15),
 'bedspread2': pattern_mat('floral bedspread 2', (.85, .16, .4), (.95, .7, .25), 'floral', 7.0, rough=.9, bump=.15),
 'grainwood': pattern_mat('veneer grain', (.3, .13, .06), (.42, .2, .09), 'grain', 4.0, rough=.55, bump=.08),
 'vinyl_orange': mat('orange vinyl', (.75, .25, .06), rough=.35),
 'vinyl_teal': mat('teal vinyl', (.05, .38, .4), rough=.35),
 'chrome': mat('chrome', (.8, .8, .82), metal=1.0, rough=.18),
 'brass': mat('brass', (.75, .5, .18), metal=1.0, rough=.3),
 'cream': mat('cream plastic', (.82, .76, .62), rough=.5),
 'shade': mat('lamp shade', (.95, .8, .55), rough=.6, emit=(1, .62, .3)),
 'crt': mat('crt glow', (.05, .3, .45), emit=(.25, .6, 1.0)),
 'glass': mat('dark glass', (.04, .06, .08), rough=.05),
 'pillow': mat('pillow', (.88, .86, .8), rough=.85),
 'towel_w': mat('white towel', (.9, .9, .86), rough=.95),
 'red': mat('red enamel', (.7, .05, .05), rough=.4),
 'pot': mat('terracotta', (.55, .24, .12), rough=.8),
 'soil': mat('soil', (.08, .05, .03), rough=1.0),
 'neon_pink': mat('neon pink', (1, .1, .5), emit=(1, .1, .55)),
 'paperw': mat('paper white', (.85, .82, .72), rough=.8),
 'scuff': mat('floor scuff', (.2, .12, .12), rough=.9),
 'puddle': mat('walkway puddle', (.05, .06, .08), rough=.02),
 'tube': mat('fluorescent tube', (.8, 1, .9), emit=(.75, 1, .85)),
 'steam': mat('steam puff', (.75, .8, .82), rough=1.0),
 'wall_service': pattern_mat('service wall tiles', (.42, .5, .46), (.34, .42, .39), 'check', 6.0, rough=.3),
 'carpet_teal': pattern_mat('teal guest carpet', (.04, .22, .25), (.08, .34, .36), 'carpet', 6.0, rough=.95, bump=.12),
})
from m01_materials import apply_generated_material
# Eight ceramic tiles across a 2.4m repeat: approximately 30cm per tile.
apply_generated_material(M['laundry_floor'], 'laundry_tiles_albedo_v1.png', 1/2.4, .4)
M['tube'].node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value = 8
_st = M['steam'].node_tree.nodes.get('Principled BSDF'); _st.inputs['Alpha'].default_value = .35
if hasattr(M['steam'], 'surface_render_method'):
 M['steam'].surface_render_method = 'DITHERED'
M['shade'].node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value = 6
# polished / damp hard floors catch the practical lights, like the wet pool deck
for _k, _r in (('lobby_floor', .08), ('laundry_floor', .38)):
 M[_k].node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value = _r
 M[_k].node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value = .8
M['plinth'] = mat('architectural plinth', (.085,.115,.16), rough=.84, emit=(.008,.012,.02))
add_surface_variation(M['plinth'], 3.0, .025)
M['staging_floor'] = mat('staging surround floor', (.075,.12,.18), rough=.88, emit=(.018,.032,.055))
M['crt'].node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value = 4
M['neon_pink'].node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value = 9
PLANT = {'trunk': M['wood'], 'ring': M['wood'], 'frond': [mat('frond a', (.05, .3, .1), rough=.7), mat('frond b', (.08, .38, .14), rough=.7), mat('frond c', (.04, .24, .12), rough=.7)], 'dead': mat('frond dry', (.35, .25, .1), rough=.9), 'nut': M['wood']}
MB = kit.MB('M01 interior authored props')
MESHY = ROOT/'assets/art/Artwork/3d'
FORCE_BLENDER_NATIVE = True
def native_prop(pid, x, y, h, rot=0.0, width=None):
 """Simple authored Blender geometry used when external GLB props are disabled."""
 if pid == 'int_armchair':
  return armchair(x, y, rot, M['vinyl_teal'])
 w = width or max(.28, h * .42)
 depth = max(.22, h * .28)
 material = M.get('wood', M['floor'])
 if 'lamp' in pid or 'vending' in pid or 'machine' in pid or 'cooler' in pid: material = M.get('metal', material)
 if 'chair' in pid or 'couch' in pid: material = M.get('vinyl_teal', material)
 if 'bed' in pid: material = M.get('bedspread', material)
 if 'cart' in pid or 'rack' in pid: material = M.get('metal', material)
 ob = cube(pid + '_blender_native', (x, y, max(.05, h * .5)), (w * .5, depth * .5, max(.05, h * .5)), material)
 ob.rotation_euler[2] = rot
 ob.name = pid + '_blender_native'
 return ob
def prop(pid, x, y, h, rot=0.0, fallback=None, width=None):
 """Place a prop using authored Blender geometry only for this staging pass."""
 path = MESHY/pid/'model.glb'
 if FORCE_BLENDER_NATIVE or not path.exists():
  if fallback: return fallback()
  return native_prop(pid, x, y, h, rot, width)
 before = set(bpy.data.objects)
 bpy.ops.import_scene.gltf(filepath=str(path))
 new = [o for o in bpy.data.objects if o not in before]
 meshes = [o for o in new if o.type == 'MESH']
 for o in new:
  if o.type != 'MESH': o.select_set(False)
 bpy.ops.object.select_all(action='DESELECT')
 for o in meshes: o.select_set(True)
 bpy.context.view_layer.objects.active = meshes[0]
 if len(meshes) > 1: bpy.ops.object.join()
 ob = bpy.context.view_layer.objects.active
 for o in new:
  if o.name in bpy.data.objects and o != ob and o.type != 'MESH': bpy.data.objects.remove(o, do_unlink=True)
 ob.parent = None
 bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
 pts = [v.co for v in ob.data.vertices]
 lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
 hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
 k = (width / max(hi.x - lo.x, 1e-4)) if width else (h / max(hi.z - lo.z, 1e-4))
 ob.location = Vector((0, 0, 0))
 import mathutils
 ob.data.transform(mathutils.Matrix.Translation(Vector((-(lo.x+hi.x)/2, -(lo.y+hi.y)/2, -lo.z))))
 ob.scale = (k, k, k); ob.rotation_euler = (0, 0, rot); ob.location = (x, y, .1)
 ob.name = pid
 for ms in ob.material_slots:
  if ms.material: unify_material(ms.material)
 return ob

def unify_material(m):
 """Bring a Meshy texture into the scene's house look so modelled and
 procedural props read as one set: same grain/bump as add_surface_variation,
 matte finish, saturation pulled toward the palette, no baked highlights."""
 if not m.use_nodes or getattr(m, '_unified', False): return
 nodes = m.node_tree.nodes; links = m.node_tree.links; bs = nodes.get('Principled BSDF')
 if bs is None: return
 src = bs.inputs['Base Color'].links[0].from_socket if bs.inputs['Base Color'].links else None
 if src is None: return
 hsv = nodes.new('ShaderNodeHueSaturation'); hsv.inputs['Saturation'].default_value = .82; hsv.inputs['Value'].default_value = .92
 links.new(src, hsv.inputs['Color'])
 tc = nodes.new('ShaderNodeTexCoord'); grain = nodes.new('ShaderNodeTexNoise'); grain.inputs['Scale'].default_value = 40.0; grain.inputs['Detail'].default_value = 6.0
 links.new(tc.outputs['Object'], grain.inputs['Vector'])
 ov = nodes.new('ShaderNodeMixRGB'); ov.blend_type = 'OVERLAY'; ov.inputs['Fac'].default_value = .18
 links.new(hsv.outputs['Color'], ov.inputs['Color1']); links.new(grain.outputs['Fac'], ov.inputs['Color2'])
 links.new(ov.outputs['Color'], bs.inputs['Base Color'])
 for l in list(bs.inputs['Roughness'].links): links.remove(l)
 bs.inputs['Roughness'].default_value = .65
 if not bs.inputs['Normal'].links:
  b = nodes.new('ShaderNodeBump'); b.inputs['Strength'].default_value = .12; links.new(grain.outputs['Fac'], b.inputs['Height']); links.new(b.outputs['Normal'], bs.inputs['Normal'])

def wall_prop(pid, x, y, z, h, fallback=None):
 ob = prop(pid, x, y, h, fallback=fallback)
 if ob: ob.location.z = z
 return ob

def plight(loc, colour, energy, radius=.25):
 bpy.ops.object.light_add(type='POINT', location=loc); l = bpy.context.object; l.data.energy = energy; l.data.color = colour; l.data.shadow_soft_size = radius
 l.data.use_shadow = energy >= 90   # only the key practicals cast shadows (EEVEE shadow budget)

def cube(n,loc,scale,ma,bevel=.03):
 bpy.ops.mesh.primitive_cube_add(location=loc); o=bpy.context.object; o.name=n; o.scale=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(ma)
 if bevel: q=o.modifiers.new('soft edges','BEVEL'); q.width=bevel; q.segments=2
 return o
def cyl(n,loc,r,depth,ma,verts=12):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=depth,location=loc); o=bpy.context.object; o.name=n; o.data.materials.append(ma); return o
def room(n,c,s,f,wallm=None):
 wallm = wallm or M['wall']
 x,y=c; w,d=s; cube(n+' floor',(x,y,0),(w/2,d/2,.08),f,.02)
 # baseboard + skirting shadow line all round
 for (bx,by,hx,hy) in ((x,y+d/2-.13,w/2-.1,.02),(x-w/2+.13,y,.02,d/2-.1),(x+w/2-.13,y,.02,d/2-.1)):
  MB.box((bx,by,.16),(hx,hy,.08),M['trim'])
 # Generated ceramic albedo supplies its own 30cm joints. Overlaying the old
 # metre-wide seam geometry creates an unrelated second grid over the tiles.
 cube(n+' floor border',(x,y-d/2+.18,.095),(w/2-.18,.035,.012),M['accent'],.006)
 cube(n+' back wall',(x,y+d/2,1.8),(w/2,.12,1.8),wallm,.04); cube(n+' left wall',(x-w/2,y,1.8),(.12,d/2,1.8),wallm,.04); cube(n+' right wall',(x+w/2,y,1.8),(.12,d/2,1.8),wallm,.04)
 # Wall dado, cap rail and vertical pilasters break up the flat planes.
 cube(n+' wall dado',(x,y+d/2-.14,.55),(w/2-.16,.035,.18),M['trim'],.01)
 cube(n+' wall cap',(x,y+d/2-.15,2.85),(w/2-.14,.045,.06),M['trim'],.01)
 for px in (-w*.38,w*.38): cube(n+' wall pilaster',(x+px,y+d/2-.16,1.55),(.06,.05,1.18),M['trim'],.012)
def bed(x,y,a):
 # double bed: plinth, quilted floral spread with a turned-down sheet, two
 # pillows, padded vinyl headboard with buttons, a folded throw at the foot
 spread = M['bedspread'] if a is M['cyan'] else M['bedspread2']
 MB.box((x,y,.16),(1.0,.74,.12),M['grainwood']); MB.box((x,y,.38),(.96,.7,.1),M['pillow'])
 MB.box((x,y-.12,.5),(.99,.6,.035),spread)
 for i in range(5):  # quilting ridges
  MB.box((x-.8+i*.4,y-.12,.535),(.015,.6,.008),M['grout'])
 MB.box((x,y+.48,.5),(.97,.12,.03),M['pillow'])
 for dx in (-.45,.45): MB.box((x+dx,y+.52,.56),(.36,.13,.07),M['pillow'])
 MB.box((x,y+.8,.85),(1.04,.07,.48),M['vinyl_teal'] if a is M['cyan'] else M['vinyl_orange'])
 for bx in range(5):
  for bz in range(2): MB.blob((x-.7+bx*.35,y+.72,.7+bz*.28),.025,M['brass'])
 MB.box((x,y-.63,.56),(.9,.1,.04),M['towel_w'])
def cabinet(x,y):
 # veneer dresser: drawers with brass pulls
 MB.box((x,y,.45),(.4,.26,.45),M['grainwood'])
 for k in range(3):
  MB.box((x,y-.265,.2+k*.27),(.36,.01,.11),M['wood'])
  MB.cyl((x-.08,y-.29,.2+k*.27),(x+.08,y-.29,.2+k*.27),.012,M['brass'],6)
def palm(x,y):
 # potted kentia palm from the courtyard kit (real fronds, not paddles)
 MB.cyl((x,y,0),(x,y,.42),.22,M['pot'],14,r2=.27); MB.disc((x,y,.4),.24,M['soil'],14)
 kit.palm(MB,(x,y,.4),1.15,PLANT,seed=int(x*7+y*13)&255,fronds=12,spread=.45)
def nightstand(x,y,phone=False):
 MB.box((x,y,.3),(.22,.2,.3),M['grainwood']); MB.box((x,y-.2,.36),(.18,.01,.08),M['wood'])
 MB.cyl((x,y,.6),(x,y,.64),.07,M['brass'],10); MB.cyl((x,y,.64),(x,y,.86),.02,M['brass'],6)
 MB.cyl((x,y,.82),(x,y,1.0),.15,M['shade'],14,r2=.1)
 plight((x,y-.05,.9),(1,.55,.25),45,.15)
 if phone:
  MB.box((x+.1,y-.05,.65),(.07,.08,.03),M['cream']); MB.box((x+.1,y-.05,.7),(.075,.025,.018),M['cream'])
def tv_dresser(x,y):
 MB.box((x,y,.38),(.7,.24,.38),M['grainwood'])
 for k in range(2): MB.box((x,y-.245,.2+k*.36),(.64,.01,.14),M['wood'])
 MB.box((x,y,.98),(.3,.24,.22),M['metal']); MB.box((x,y-.245,.98),(.22,.01,.16),M['crt'])
 MB.cyl((x+.1,y,1.2),(x+.32,y+.05,1.6),.008,M['chrome'],5); MB.cyl((x-.1,y,1.2),(x-.3,y+.08,1.58),.008,M['chrome'],5)
 plight((x,y-.6,1.0),(.3,.6,1.0),55,.3)
def armchair(x,y,rot=0.0,m=None):
 from m01_upholstery import armchair as authored_armchair
 return authored_armchair(x, y, rot, m or M['vinyl_orange'], M['grainwood'], M['trim'])
def side_table_set(x,y):
 MB.cyl((x,y,0),(x,y,.6),.04,M['chrome'],8); MB.cyl((x,y,.6),(x,y,.63),.32,M['grainwood'],18)
 MB.box((x-.1,y,.65),(.12,.09,.012),M['paperw'],rz=.3)   # magazine
 MB.cyl((x+.12,y+.05,.63),(x+.12,y+.05,.66),.06,M['glass'],10)   # ashtray
 for k in range(2): MB.cyl((x+.05+k*.07,y-.12,.63),(x+.05+k*.07,y-.12,.75),.025,M['red'],8)   # soda cans
def small_plant(x,y,size=.55):
 MB.cyl((x,y,0),(x,y,.3),.14,M['pot'],12,r2=.17); MB.disc((x,y,.29),.15,M['soil'],12)
 kit.tropical_plant(MB,(x,y,.3),size,PLANT['frond'],RND,leaves=9)
def clutter(x,y):
 # a lived-in cluster: shoes, a bag, a paperback
 for i,c in enumerate((M['wood'],M['wood'])): MB.box((x+i*.14,y,.05),(.05,.12,.04),c,rz=.2*i)
 MB.box((x+.4,y+.05,.15),(.18,.1,.14),M['vinyl_teal'],rz=-.3); MB.box((x+.4,y+.05,.3),(.12,.02,.02),M['chrome'],rz=-.3)
 MB.box((x+.2,y-.25,.03),(.09,.13,.02),M['red'],rz=.6)
def washer(x,y):
 MB.box((x,y,.45),(.3,.3,.45),M['cream']); MB.box((x,y+.1,.94),(.3,.2,.06),M['metal'])
 MB.cyl((x,y-.3,.5),(x,y-.33,.5),.2,M['chrome'],18); MB.cyl((x,y-.33,.5),(x,y-.34,.5),.16,M['glass'],18)
 for k in range(3): MB.cyl((x-.15+k*.15,y+.1,1.0),(x-.15+k*.15,y+.1,1.03),.03,M['chrome'],8)
 MB.box((x+.18,y-.31,.85),(.04,.01,.03),M['amber'])
def laundry_cart_full(x,y):
 MB.box((x,y,.45),(.38,.26,.25),M['paperw']); MB.box((x,y,.2),(.36,.24,.02),M['metal'])
 for sx in (-1,1):
  for sy in (-1,1): MB.cyl((x+sx*.32,y+sy*.2,.04),(x+sx*.32,y+sy*.2,.2),.02,M['metal'],6)
 for i in range(6): MB.blob((x-.25+i*.1,y+RND.uniform(-.15,.15),.72),.11,M['towel_w'] if i%3 else M['cyan'],.6)
def shelf_unit(x,y):
 for z in (.2,.6,1.0,1.4): MB.box((x,y,z),(.5,.18,.015),M['metal'])
 for sx in (-1,1): MB.box((x+sx*.5,y,.8),(.015,.18,.8),M['metal'])
 for z in (.2,.6,1.0):
  for i in range(4):
   if (i+int(z*10))%3==0: MB.cyl((x-.36+i*.24,y,z+.015),(x-.36+i*.24,y,z+.2),.05,[M['cyan'],M['amber'],M['red']][i%3],8)
   else: MB.box((x-.36+i*.24,y,z+.07),(.1,.14,.055),M['towel_w'])
def vending(x,y):
 MB.box((x,y,.9),(.42,.36,.9),M['red']); MB.box((x-.08,y-.365,1.05),(.28,.01,.6),M['neon_pink'])
 for k in range(6): MB.box((x+.3,y-.365,.7+k*.13),(.06,.012,.04),M['chrome'])
 MB.box((x,y-.37,.25),(.3,.012,.08),M['glass'])
 plight((x,y-.8,1.0),(1,.15,.35),80,.4)
def couch(x,y,m):
 # The reception camera looks in from the lower side of the room: keep the
 # backrest on that side so the sofa reads as a back-facing landmark instead
 # of presenting its cushions to the camera.
 MB.box((x,y,.3),(.84,.32,.12),m); MB.box((x,y-.28,.62),(.84,.08,.3),m)
 for s in (-1,1): MB.box((x+s*.9,y,.48),(.07,.36,.18),m)
 for i in range(3): MB.box((x-.6+i*.6,y-.02,.44),(.28,.3,.04),m)
 for s in (-1,1): MB.cyl((x+s*.76,y-.28,0),(x+s*.76,y-.28,.18),.02,M['chrome'],6)
def luggage_cart(x,y):
 MB.box((x,y,.22),(.5,.3,.04),M['red'])
 for s in (-1,1):
  MB.cyl((x+s*.48,y,.22),(x+s*.48,y,1.55),.025,M['brass'],8)
 MB.tube([Vector((x-.48,y,1.55)),Vector((x,y,1.75)),Vector((x+.48,y,1.55))],[.025,.025,.025],M['brass'],6)
 for sx in (-1,1):
  for sy in (-1,1): MB.cyl((x+sx*.42,y+sy*.24,.06),(x+sx*.42,y+sy*.24,.07),.07,M['metal'],10)
 MB.box((x-.15,y,.42),(.25,.14,.18),M['wood']); MB.box((x+.2,y,.38),(.2,.12,.14),M['vinyl_teal']); MB.cyl((x+.05,y,.6),(x+.05,y,.78),.13,M['cream'],12)
def key_board(x,y):
 MB.box((x,y,1.45),(.45,.03,.32),M['grainwood'])
 for r in range(3):
  for c in range(6):
   MB.cyl((x-.36+c*.145,y-.03,1.65-r*.2),(x-.36+c*.145,y-.07,1.65-r*.2),.01,M['brass'],5)
   if (r*6+c)%4: MB.box((x-.36+c*.145,y-.07,1.58-r*.2),(.025,.01,.045),[M['red'],M['cyan'],M['amber']][(r+c)%3])
def lamp(x,y):
 cyl('wall lamp',(x,y,1.45),.09,.22,M['amber'],10); bpy.ops.object.light_add(type='POINT',location=(x,y,1.5)); l=bpy.context.object; l.data.energy=110; l.data.color=(1,.32,.06); l.data.shadow_soft_size=.5
def ceiling_fixture(x,y):
 cyl('ceiling fixture',(x,y,3.15),.11,.08,M['metal'],12); cyl('ceiling glow',(x,y,3.08),.07,.035,M['amber'],12)
 bpy.ops.object.light_add(type='POINT',location=(x,y,2.95)); l=bpy.context.object; l.data.energy=70; l.data.color=(1,.45,.15); l.data.shadow_soft_size=.35
def wall_art(x,y,colour,accent):
 cube('framed wall art',(x,y,1.75),(.34,.035,.25),M['wood'],.018); cube('wall art print',(x,y-.04,1.75),(.27,.012,.18),colour,.008); cube('wall art accent',(x+.08,y-.06,1.78),(.035,.012,.08),accent,.004)
def towel_stack(x,y):
 for i,c in enumerate((M['cyan'],M['paper'],M['accent'])): cube('folded towel',(x,y,.84+i*.09),(.22,.16,.035),c,.012)
def door_detail(x,y,label,accent):
 cube('interior door',(x,y,1.25),(.46,.06,1.18),M['wood'],.035)
 cube('door inset',(x,y-.065,1.25),(.32,.018,.72),M['wall'],.012)
 cube('door sign',(x,y-.09,2.0),(.24,.018,.08),accent,.006)
 cube('door label',(x,y-.1,2.0),(.14,.01,.025),M['paper'],.002)
 cyl('door handle',(x+.28,y-.1,1.22),.045,.08,M['metal'],10)
def wear_cluster(x,y,accent):
 # Small authored wear marks break the procedural surfaces without cluttering the lane.
 for i in range(3):
  cube('floor wear mark',(x+i*.18,y+(i%2)*.12,.105),(.055,.018,.004),accent,.002)
 cube('wall notice sticker',(x,y,1.15),(.12,.012,.08),accent,.004)
def text_sign(body,x,y,z,colour,size=.34):
 curve=bpy.data.curves.new(body+' sign curve','FONT'); curve.body=body; curve.align_x='CENTER'; curve.size=size; curve.extrude=.012; curve.bevel_depth=.004
 obj=bpy.data.objects.new(body+' sign',curve); bpy.context.collection.objects.link(obj); obj.location=(x,y,z); obj.rotation_euler=(math.pi/2,0,0); obj.data.materials.append(colour)
def conduit_run(x,y,length,vertical=False):
 if vertical:
  cube('service conduit',(x,y,1.45),(.035,.035,length/2),M['metal'],.012)
  for z in (1.0,1.9): cube('conduit clamp',(x-.06,y,z),(.08,.05,.025),M['accent'],.006)
 else:
  cube('service conduit',(x,y,1.45),(length/2,.035,.035),M['metal'],.012)
  for dx in (-length*.28,length*.28): cube('conduit clamp',(x+dx,y,1.45),(.025,.08,.06),M['accent'],.006)
def lobby_props(x,y):
 cube('luggage trolley',(x,y,.5),(.38,.22,.05),M['metal'],.012)
 for dx in (-.28,.28): cyl('trolley wheel',(x+dx,y-.02,.18),.06,.06,M['metal'],10)
 cube('trolley handle',(x,y+.18,.88),(.34,.025,.025),M['metal'],.01)
 cyl('fire extinguisher',(x+.55,y,.55),.09,.42,M['accent'],12); cube('extinguisher label',(x+.55,y-.1,.62),(.045,.012,.09),M['amber'],.004)
def laundry_props(x,y):
 cube('linen shelf',(x,y,1.25),(.48,.16,.05),M['wood'],.012)
 for z in (1.45,1.75): cube('linen shelf rail',(x,y,z),(.48,.035,.035),M['metal'],.008)
 for i,c in enumerate((M['paper'],M['cyan'],M['accent'])): cube('linen bundle',(x-.3+i*.3,y-.08,1.52),(.1,.1,.12),c,.012)
 for dx in (-.26,.26): cyl('floor drain',(x+dx,y-.52,.11),.09,.012,M['metal'],12)
def hotel_fixture(x,y):
 cube('air conditioner',(x,y,2.35),(.36,.12,.22),M['metal'],.025)
 for i in range(3): cube('air vent',(x-.18+i*.18,y-.13,2.35),(.045,.012,.07),M['cyan'],.004)
 cube('luggage rack',(x,y,.34),(.42,.18,.035),M['metal'],.012)
 for dx in (-.32,.32): cube('luggage rack leg',(x+dx,y,.2),(.025,.025,.16),M['metal'],.006)
def bathroom_nook(x,y):
 cube('bathroom vanity',(x,y,.55),(.34,.22,.08),M['wood'],.02)
 cube('bathroom basin',(x,y-.04,.67),(.2,.12,.035),M['paper'],.01)
 cube('bathroom mirror',(x,y-.1,1.25),(.28,.018,.32),M['cyan'],.012)
 cube('bathroom towel rail',(x+.35,y-.1,.95),(.025,.035,.22),M['metal'],.008)
 for dz in (.82,1.02): cube('bathroom towel',(x+.35,y-.14,dz),(.08,.018,.06),M['accent'],.006)

def authored(k,x,y,w,d):
 """Authored micro-prop dressing per zone (2026-10-06 pass). Keeps the middle of
 each room and the doorway lanes clear for play; clusters sit against walls."""
 if k=='guest':
  bx,by=x-.7,y-.25
  prop('int_nightstand_lamp',bx-1.35,by+.5,1.0,fallback=lambda:nightstand(bx-1.3,by+.45,phone=True)); prop('int_nightstand_lamp',bx+1.35,by+.5,1.0,fallback=lambda:nightstand(bx+1.3,by+.45))
  plight((bx-1.35,by+.4,.95),(1,.55,.25),45,.15); plight((bx+1.35,by+.4,.95),(1,.55,.25),45,.15)
  prop('int_tv_dresser',x+w*.24,y+d/2-.45,1.3,fallback=lambda:tv_dresser(x+w*.24,y+d/2-.45)); plight((x+w*.24,y+d/2-1.0,1.0),(.3,.6,1.0),55,.3)
  prop('int_armchair',x+w*.34,y-d*.18,.9,rot=2.5,fallback=lambda:armchair(x+w*.34,y-d*.18,rot=2.5)); side_table_set(x+w*.22,y-d*.08)
  small_plant(x-w*.43,y-d*.33,.5); clutter(bx-.3,by-1.05)
  prop('int_suitcase_pile',x-w*.43,y+d*.22,.6,rot=1.5708)
  # a towel on the chair, a lit cigarette pack and keys on the dresser
  MB.box((x+w*.34,y-d*.18,.48),(.2,.15,.02),M['towel_w'],rz=.4)
  MB.box((x+w*.24-.45,y+d/2-.45,.79),(.05,.03,.012),M['brass']); MB.box((x+w*.24+.45,y+d/2-.45,.79),(.04,.06,.015),M['red'])
 elif k=='laundry':
  for i in range(3): (lambda i: prop('int_washing_machine',x-w*.3+i*.62,y+.05,.95,fallback=lambda:washer(x-w*.3+i*.62,y+.05)))(i)
  prop('int_laundry_cart',x+w*.27,y-.45,.85,rot=.3,fallback=lambda:laundry_cart_full(x+w*.27,y-.45)); prop('int_linen_shelf',x+w*.12,y+d/2-.4,1.7,fallback=lambda:shelf_unit(x+w*.12,y+d/2-.4))
  # mop bucket and a wet-floor sign by the door
  MB.cyl((x+w*.3,y-d*.12,0),(x+w*.3,y-d*.12,.3),.17,M['metal'],12,r2=.2); MB.cyl((x+w*.3,y-d*.12,.3),(x+w*.42,y-d*.1,1.3),.015,M['wood'],6)
  MB.disc((x+w*.12,y-d*.12,.101),.35,M['puddle'],18)
  # A-frame wet-floor sign: two yellow boards leaning together, a black band
  import mathutils as _mu
  for _s in (-1,1):
   _R=_mu.Matrix.Rotation(.5,3,'Z')@_mu.Matrix.Rotation(_s*.28,3,'X'); MB.box(Vector((x+w*.14,y-d*.28,.32))+_R@Vector((0,_s*.08,0)),(.15,.012,.3),M['amber'],M=_R); MB.box(Vector((x+w*.14,y-d*.28,.42))+_R@Vector((0,_s*.093,0)),(.13,.004,.04),M['grout'],M=_R)
  small_plant(x+w*.4,y+d*.1,.4)
  # density pass: a second cart and shelf, baskets of laundry, towels dropped
  # on the floor, a trash can, posters and a clock on the tiled wall

  prop('int_linen_shelf',x-w*.38,y+d*.33,1.5,rot=1.5708)
  for bi,(bx,byy) in enumerate(((x-w*.18,y-d*.08),(x+w*.02,y-d*.1))):
   MB.cyl((bx,byy,0),(bx,byy,.32),.2,M['cyan'] if bi else M['amber'],14,r2=.23)
   for j in range(9): MB.blob((bx+RND.uniform(-.14,.14),byy+RND.uniform(-.14,.14),.36+RND.uniform(0,.14)),RND.uniform(.08,.13),[M['towel_w'],M['bedspread'],M['pillow'],M['vinyl_teal']][j%4],.7)
  for j in range(3): MB.box((x+RND.uniform(-w*.2,w*.2),y-d*.05+RND.uniform(-.2,.2),.1),(.18,.12,.012),M['towel_w'],rz=RND.uniform(0,3))
  MB.cyl((x+w*.42,y-d*.38,0),(x+w*.42,y-d*.38,.5),.15,M['metal'],12,r2=.17)
  for j,px in enumerate((-.3,.0,.28)):
   MB.box((x+px*w,y+d/2-.15,1.95),(.16,.012,.22),[M['amber'],M['cyan'],M['paperw']][j]); MB.box((x+px*w,y+d/2-.16,2.05),(.1,.006,.03),M['grout'])
  MB.cyl((x+w*.42,y+d/2-.15,2.4),(x+w*.42,y+d/2-.18,2.4),.13,M['cream'],16)
 elif k=='lobby':
  prop('int_lobby_couch',x-w*.28,y-d*.27,.85,rot=1.5708,width=1.45,fallback=lambda:couch(x-w*.12,y-d*.38,M['vinyl_teal']))
  prop('int_luggage_cart',x+w*.38,y+d*.05,1.6,fallback=lambda:luggage_cart(x+w*.33,y-d*.12)); prop('int_vending_machine',x-w*.38,y+d*.28,1.8,fallback=lambda:vending(x-w*.38,y+d*.28)); plight((x-w*.38,y+d*.28-.8,1.0),(1,.15,.35),80,.4)
  prop('int_water_cooler',x+w*.42,y-d*.32,1.3)
  wall_prop('int_key_rack',x+w*.12,y+d/2-.3,1.05,.9,fallback=lambda:key_board(x+w*.12,y+d/2-.2))
  MB.box((x-w*.12,y-d*.25,.1),(.95,.55,.008),M['bedspread2']); MB.box((x-w*.12,y-d*.25,.104),(.85,.47,.006),M['carpet'])
  small_plant(x+w*.4,y+d*.2,.6); small_plant(x-w*.42,y-d*.42,.5)
  # bell, register and a ledger on the counter
  MB.cyl((x+.35,y-.4,1.35),(x+.35,y-.4,1.4),.07,M['brass'],12); MB.box((x-.3,y-.35,1.47),(.18,.14,.12),M['metal']); MB.box((x+.05,y-.45,1.36),(.16,.11,.012),M['paperw'],rz=.2)
  plight((x,y-.5,1.9),(1,.6,.3),70,.3)
 else:
  small_plant(x,y,.5)
 night_dressing(k,x,y,w,d)

def neon_text(body,x,y,z,col_mat,col_rgb,size=.3,energy=60):
 text_sign(body,x,y,z,col_mat,size); plight((x,y-.4,z),col_rgb,energy,.4)

def window_glow(x,y,col):
 # a window in the back wall with light spilling in through the curtain gap
 MB.box((x,y,1.6),(.42,.02,.5),M['glass']); MB.box((x,y-.01,1.6),(.06,.015,.5),M['neon_pink'] if col[0]>.8 else M['cyan'])
 # pleated curtains: a row of thin folds each side, a valance and a tie-back
 for s in (-1,1):
  for f in range(5): MB.box((x+s*(.26+f*.045),y-.05-(f%2)*.02,1.55),(.025,.02,.68),M['bedspread2'] if f%2 else M['vinyl_orange'])
 MB.box((x,y-.07,2.18),(.6,.03,.07),M['grainwood'])
 MB.box((x,y-.03,1.05),(.42,.06,.02),M['trim'])   # sill
 bpy.ops.object.light_add(type='SPOT',location=(x,y-.15,2.0)); l=bpy.context.object; l.data.energy=120; l.data.color=col; l.data.spot_size=1.1; l.data.spot_blend=.6
 l.rotation_euler=(math.radians(-55),0,0)

def night_dressing(k,x,y,w,d):
 """Pool-courtyard bar: practical light pools, neon, reflective floors, wall
 clutter, so the interiors read as the same night as the courtyard."""
 back=y+d/2-.16
 # framed prints, a clock, a notice and a wall calendar on every back wall
 for i,dx in enumerate((-.2,.2)):
  MB.box((x+dx*w,back-.02,2.25),(.34,.02,.24),M['brass'])
  MB.box((x+dx*w,back-.035,2.25),(.3,.008,.2),[M['bedspread'],M['vinyl_teal']][i])
  MB.box((x+dx*w,back-.042,2.25),(.12,.004,.08),[M['amber'],M['cream']][i])
 MB.cyl((x-w*.05,back-.02,2.55),(x-w*.05,back-.05,2.55),.12,M['cream'],16)
 # side walls: a picture rail with prints, outlets, a thermostat, a coat hook
 for sx in (-1,1):
  wx=x+sx*(w/2-.15)
  for j,yy in enumerate((y-d*.25,y+d*.1)):
   MB.box((wx,yy,1.9),(.015,.18,.13),M['grainwood']); MB.box((wx-sx*.012,yy,1.9),(.006,.14,.1),[M['vinyl_teal'],M['bedspread'],M['vinyl_orange'],M['amber']][(j+sx+1)%4])
  MB.box((wx,y-d*.4,.45),(.012,.05,.04),M['cream']); MB.box((wx,y+d*.35,1.5),(.012,.06,.08),M['cream'])
 # floor wear: scuffs along the walking line and near the door
 for i in range(4):
  MB.box((x+RND.uniform(-w*.4,w*.4),y+RND.uniform(-d*.45,d*.1),.101),(RND.uniform(.05,.09),.02,.001),M['scuff'],rz=RND.uniform(0,3.1))
 # tall corner plant, a trash bin, a floor lamp pool
 small_plant(x+(0.0 if k=='lobby' else w*.43),y-d*.42,.45)
 MB.cyl((x-w*.44,y+d*.05,0),(x-w*.44,y+d*.05,.32),.1,M['metal'],10,r2=.12)
 if k=='guest':
  window_glow(x-w*.2,back,(1,.15,.5))
  # floor lamp by the armchair: a warm pool on the carpet
  MB.cyl((x+w*.32,y-d*.05,0),(x+w*.32,y-d*.05,1.35),.018,M['brass'],6); MB.cyl((x+w*.32,y-d*.05,1.3),(x+w*.32,y-d*.05,1.55),.2,M['shade'],14,r2=.13)
  plight((x+w*.32,y-d*.05,1.3),(1,.55,.22),95,.2)
  # fringed rug under the bed foot
  MB.box((x-.7,y-1.25,.1),(.8,.38,.01),M['bedspread2'])
  for i in range(12): MB.box((x-1.45+i*.135,y-1.65,.1),(.015,.04,.005),M['cream'])
 elif k=='laundry':
  neon_text('LAUNDRY',x,back-.05,2.4,M['cyan'],(.2,.7,1.0),.26,70)
  # hanging work light, a pipe run with valves, a sagging clothes line
  # identity: a cold service room - buzzing green-white fluorescent tubes,
  # steam from the dryers, damp tiles (not the courtyard's warm palette)
  for ty in (y+d*.15,y-d*.2):
   MB.box((x,ty,2.9),(w*.3,.03,.012),M['chrome']); MB.box((x,ty,2.87),(w*.28,.02,.012),M['tube'])
   bpy.ops.object.light_add(type='AREA',location=(x,ty,2.8)); _l=bpy.context.object; _l.data.energy=55; _l.data.color=(.75,1.0,.85); _l.data.shape='RECTANGLE'; _l.data.size=w*.55; _l.data.size_y=.15
  for i in range(4): MB.cyl((x-w*.4+i*.3,back-.08,2.7),(x-w*.4+i*.3,back-.2,2.7),.04,M['red'],8)
  # authored laundry clutter: detergent boxes, baskets, bottles and damp floor
  # Four readable detergent bottles: coloured body, pale label, neck and cap.
  # They sit on an explicit service shelf so the props never read as floating.
  MB.box((x-w*.20,y-d*.05,.53),(w*.24,.18,.035),M['metal'])
  MB.box((x-w*.20,y-d*.20,.60),(w*.24,.025,.05),M['metal'])
  for i in range(4):
   bx=x-w*.38+i*.24
   detergent_bottle(bx,y-d*.05,.565,[(.40,.59,.61),(.78,.67,.48),(.63,.25,.19),(.74,.73,.62)][i])
  for i in range(3):
   bx=x+w*.18+i*.23
   MB.cyl((bx,y+d*.08,.06),(bx,y+d*.08,.32),.12,[M['vinyl_teal'],M['red'],M['cream']][i],12,r2=.15)
   MB.cyl((bx,y+d*.08,.31),(bx,y+d*.08,.36),.13,M['metal'],12,r2=.13)
  for i in range(3):
   MB.box((x-w*.28+i*.38,y-d*.32,.104),(.28,.10,.003),M['puddle'],rz=(-.15+i*.25))
  # loose folded towels and a damp laundry trail: visual density only, kept
  # against the service edges so the playable transition remains clear.
  for i,(tx,ty,rz) in enumerate(((-.62,-.92,-.18),(-.28,-1.05,.12),(.46,.92,-.22))):
   MB.box((x+tx,y+ty,.16),(.16,.12,.035),M['towel_w'] if i != 1 else M['cyan'],rz=rz)
   MB.box((x+tx,y+ty+.015,.205),(.12,.085,.018),M['paperw'],rz=rz)
  for i in range(4):
   MB.box((x-.75+i*.42,y+.58,.108),(.12,.018,.004),M['puddle'],rz=(-.2+i*.1))
 elif k=='lobby':
  neon_text('OFFICE',x-w*.2,back-.05,2.45,M['neon_pink'],(1,.15,.55),.3,90)
  window_glow(x+w*.3,back,(.25,.6,1.0))
  # brochure rack, a rubber plant, an ashtray stand by the couch
  MB.box((x-w*.42,y-d*.1,.65),(.06,.26,.65),M['grainwood'])
  for i in range(6): MB.box((x-w*.4,y-d*.1-.2+i*.08,.6+(i%3)*.3),(.01,.05,.08),[M['cyan'],M['amber'],M['red']][i%3])
  MB.cyl((x+w*.1,y-d*.42,0),(x+w*.1,y-d*.42,.65),.02,M['chrome'],6); MB.cyl((x+w*.1,y-d*.42,.65),(x+w*.1,y-d*.42,.7),.12,M['chrome'],12)

def zone(n,c,s,k):
 floor_m = {'guest': M['carpet'], 'laundry': M['laundry_floor'], 'lobby': M['lobby_floor']}.get(k, M['floor'])
 wall_m = {'guest': M['wallpaper'], 'lobby': M['wallpaper_warm'], 'laundry': M['wall_service']}.get(k, M['wall'])
 room(n,c,s,floor_m,wall_m); x,y=c; w,d=s
 authored(k,x,y,w,d)
 ceiling_fixture(x-w*.22,y+d*.18); ceiling_fixture(x+w*.22,y+d*.18)
 if k=='guest':
  # room identity: the door, its number and a wall AC; the rest is in authored()/night_dressing()
  cube('room number plaque',(x+w*.34,y+d/2-.18,1.05),(.18,.03,.12),M['amber'],.01); cube('room door peephole',(x+w*.34,y+d/2-.22,1.48),(.035,.018,.035),M['metal'],.004); door_detail(x-w*.34,y+d/2-.16,'ROOM',M['amber'])
  bed_mat = M['vinyl_teal'] if n == 'Ground floor guest wing' else M['cyan']
  prop('int_motel_bed',x-.7,y-.25,0,width=2.1,fallback=lambda:bed(x-.7,y-.25,bed_mat))
  wall_prop('int_room_ac',x+w*.05,y+d/2-.3,2.05,.55)
  # authored guest-room dressing: TV dresser, luggage and a second practical
  # lamp make the room read as lived-in without narrowing the central route.
  prop('int_tv_dresser',x+w*.28,y+d*.34,.85,rot=math.pi,fallback=lambda:MB.box((x+w*.28,y+d*.34,.45),(.48,.22,.45),M['grainwood']))
  prop('int_suitcase_pile',x-w*.38,y-d*.28,.62,rot=.12,fallback=lambda:MB.box((x-w*.38,y-d*.28,.28),(.34,.22,.28),M['vinyl_orange']))
  prop('int_nightstand_lamp',x-.7+w*.22,y-.25-d*.05,.48,rot=math.pi/2)
  # mirror over the dresser and a desk with a chair by the window
  MB.box((x+w*.24,y+d/2-.2,1.85),(.45,.02,.32),M['grainwood']); MB.box((x+w*.24,y+d/2-.22,1.85),(.4,.008,.27),M['glass'])
  MB.box((x-w*.2,y+d*.3,.7),(.5,.22,.03),M['grainwood']); MB.box((x-w*.2-.42,y+d*.3,.35),(.03,.2,.35),M['grainwood']); MB.box((x-w*.2+.42,y+d*.3,.35),(.03,.2,.35),M['grainwood'])
  MB.box((x-w*.2+.1,y+d*.3,.75),(.14,.1,.02),M['paperw'],rz=.2); MB.cyl((x-w*.2-.25,y+d*.3,.73),(x-w*.2-.25,y+d*.3,.85),.04,M['cream'],8)
  # round rug under the reading corner, a jacket thrown over the chair arm, shoes, a paper bag
  room_carpet = M['carpet_teal'] if n == 'Ground floor guest wing' else M['bedspread']
  MB.disc((x+w*.3,y-d*.12,.1),.85,room_carpet,28); MB.disc((x+w*.3,y-d*.12,.104),.7,M['carpet'],28)
  MB.box((x+w*.36,y-d*.12,.62),(.22,.1,.03),M['vinyl_orange'],rz=.8)
  for j in range(2): MB.box((x+w*.15+j*.12,y-d*.38,.05),(.05,.12,.045),M['wood'],rz=.3+j*.4)

  # Give the ground-floor room its own identity instead of duplicating the
  # north room: a teal throw, a framed artwork and a travel trunk keep the
  # circulation unchanged while making the two rooms read as authored spaces.
  if n == 'Ground floor guest wing':
   MB.disc((x+w*.3,y-d*.12,.108),.56,M['vinyl_teal'],28)
   MB.box((x-w*.34,y+d/2-.205,1.72),(.28,.018,.22),M['cyan'],rz=.08)
   MB.box((x+w*.38,y-d*.34,.22),(.26,.16,.22),M['vinyl_teal'],rz=.12)
   # Strong visual identity: cool coastal room with a cyan wall panel and
   # travel-board props, while the central circulation stays unchanged.
   MB.box((x-w*.18,y+d/2-.21,1.92),(.42,.018,.28),M['cyan'],rz=-.04)
   MB.box((x-w*.18,y+d/2-.23,1.92),(.34,.008,.2),M['glass'],rz=-.04)
   MB.box((x+w*.08,y-d*.34,.16),(.34,.2,.16),M['cyan'],rz=.08)
   for j in range(3): MB.box((x+w*.08-.18+j*.18,y-d*.34,.36),(.055,.04,.08),[M['amber'],M['paperw'],M['accent']][j],rz=.08)
  else:
   # North room identity: warm terracotta rug and framed floral art.
   MB.disc((x+w*.3,y-d*.12,.108),.58,M['bedspread2'],28)
   MB.box((x-w*.18,y+d/2-.21,1.92),(.42,.018,.28),M['amber'],rz=.04)

  lamp(x-w*.37,y+d*.25); palm(x+w*.44,y+d*.36)
 elif k=='laundry':
  # folding table with stacked towels, real steel pipework with valves on the back wall
  MB.box((x,y+d*.3,.8),(w*.32,.25,.03),M['cream']); [MB.cyl((x+sx*w*.3,y+d*.3+sy*.2,0),(x+sx*w*.3,y+d*.3+sy*.2,.8),.025,M['metal'],6) for sx in (-1,1) for sy in (-1,1)]
  [MB.box((x-w*.22+i*.22,y+d*.3,.86+k*.07),(.09,.13,.03),[M['towel_w'],M['vinyl_teal'],M['towel_w'],M['bedspread2']][(i+k)%4]) for i in range(4) for k in range(3-(i%2))]
  MB.cyl((x-w*.45,y+d/2-.22,2.6),(x+w*.45,y+d/2-.22,2.6),.05,M['chrome'],10); MB.cyl((x-w*.45,y+d/2-.32,2.4),(x+w*.45,y+d/2-.32,2.4),.035,M['metal'],10)
  [MB.cyl((x+px*w,y+d/2-.22,2.6),(x+px*w,y+d/2-.22,1.0),.035,M['chrome'],8) for px in (-.38,.38)]; [MB.cyl((x+px*w,y+d/2-.3,2.6),(x+px*w,y+d/2-.38,2.6),.07,M['red'],8) for px in (-.2,.15)]
 elif k=='lobby':
  prop('int_reception_desk',x,y-.15,1.2,width=w*.56,fallback=lambda:cube('reception desk',(x,y-.15,.7),(w*.28,.38,.65),M['wood'])); text_sign('SUNSET PALMS',x,y+d/2-.26,2.18,M['amber'],.28)
  prop('int_key_rack',x-w*.36,y+d*.12,.72,rot=math.pi/2)
  # Keep the trolley fully inside the reception footprint; its wheels and
  # handle previously crossed the right staging wall in the 3/4 review crop.
  prop('int_luggage_cart',x-w*.28,y-d*.28,1.0,rot=math.pi/2)
  prop('int_water_cooler',x-w*.05,y-d*.34,1.05,rot=math.pi/2)
  # waiting area: two armchairs and a coffee table facing the couch, a floor lamp
  prop('int_armchair',x+w*.20,y-d*.10,.85,rot=-1.5708-.35)
  # One chair is deliberately turned toward the upper wall, showing its
  # back to the camera as in a lived-in reception rather than a mirrored pair.
  prop('int_armchair',x+w*.20,y-d*.48,.85,rot=1.5708)
  prop('int_coffee_table',x-w*.15,y-d*.27,.45,width=.9)
  MB.cyl((x-w*.42,y-d*.05,0),(x-w*.42,y-d*.05,1.4),.018,M['brass'],6); MB.cyl((x-w*.42,y-d*.05,1.35),(x-w*.42,y-d*.05,1.6),.2,M['shade'],14,r2=.13); plight((x-w*.42,y-d*.05,1.35),(1,.55,.22),90,.2)
  for _px in (x-w*.42, x+w*.42): cyl('reception wall sconce',(_px,y+d/2-.25,1.82),.07,.14,M['amber'],10)
  palm(x-w*.3,y+d*.22); palm(x-w*.05,y+d*.22); lamp(x-w*.4,y+d*.3); lamp(x+w*.10,y+d*.3)
 else: cube('service table',(x,y,.65),(w*.28,.28,.12),M['wood']); cabinet(x-w*.28,y+.15); lamp(x+w*.35,y+d*.25)
zone('North guest wing',(-6,-5.4),(9,4.2),'guest'); zone('West service transition',(-12,-1),(4,6),'laundry'); zone('Reception core',(10.2,-4.4),(5,6.8),'lobby'); zone('Ground floor guest wing',(1,4.2),(10,5.5),'guest')
# Pool-style neon-noir lighting pass: cool ambient plus warm practical pools.
for _loc,_col,_energy in [((-6,-5,3),(.05,.22,1.0),70),((-12,-1,3),(0.08,.28,1.0),60),((10,-4,3),(.08,.22,1.0),60),((1,4,3),(.05,.24,1.0),70)]:
 bpy.ops.object.light_add(type='AREA',location=_loc); _l=bpy.context.object; _l.data.energy=_energy; _l.data.color=_col; _l.data.shape='RECTANGLE'; _l.data.size=4.0; _l.data.size_y=2.0
for _loc in [(-7,-4.5,1.5),(-5,-6,1.4),(-12,-2,1.5),(9.3,-4.8,1.5),(11,-3.5,1.4),(0,4,1.4)]:
 bpy.ops.object.light_add(type='POINT',location=_loc); _l=bpy.context.object; _l.data.energy=90; _l.data.color=(1.0,.18,.04); _l.data.shadow_soft_size=.7

cube('transition corridor',(0,-3.03,.03),(1.25,4.47,.06),M['tile'],.02)
# overhead service spine: visual dressing only, kept above the playable lane
for _cy in (-6.0,-3.0,0.0):
 MB.box((0,_cy,2.72),(1.05,.045,.045),M['metal'],.012)
 MB.cyl((-.72,_cy,2.72),(.72,_cy,2.72),.028,M['chrome'],8)
 for _cx in (-.72,0.0,.72):
  MB.box((_cx,_cy-.055,2.63),(.035,.012,.08),M['cyan'] if _cx==0 else M['amber'],.004)
for y in (-6,-3,0): lamp(-1.05,y)
# warm caged walkway lights: real pools of light down the corridor
for _ly in (-6.0,-3.0,0.0): plight((0,_ly,2.4),(1,.6,.3),110,.3)
bpy.ops.object.camera_add(location=(0,-17,27)); cam=bpy.context.object; cam.name='M01 interiors staging camera'; cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.type='ORTHO'; cam.data.ortho_scale=31; bpy.context.scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=(0,0,18)); bpy.context.object.data.energy=260; bpy.context.object.data.shape='DISK'; bpy.context.object.data.size=18
sc=bpy.context.scene; sc.render.engine='BLENDER_EEVEE'; sc.render.resolution_x=3840 if os.environ.get('M01_INTERIOR_4K')=='1' else 1200; sc.render.resolution_y=2160 if os.environ.get('M01_INTERIOR_4K')=='1' else 800; sc.render.resolution_percentage=100; sc.render.image_settings.file_format='PNG'; sc.render.film_transparent=False; sc.world=bpy.data.worlds.new('M01 staging world'); sc.world.color=(.004,.003,.009); sc.render.filepath=str(RENDER_DIR/'m01_interiors_transitions_staging.png')
sc.view_settings.view_transform='AgX'; sc.view_settings.look='AgX - Medium High Contrast'; sc.view_settings.exposure=-.35
# the courtyard master's render treatment, so interiors and exterior are one image set
sc.eevee.taa_render_samples=96; sc.eevee.use_raytracing=True; sc.eevee.ray_tracing_method='SCREEN'; sc.eevee.use_fast_gi=True; sc.eevee.use_shadows=True
_ng=bpy.data.node_groups.new('Neon glow','CompositorNodeTree'); _ng.interface.new_socket('Image',in_out='OUTPUT',socket_type='NodeSocketColor')
_rl=_ng.nodes.new('CompositorNodeRLayers'); _gl=_ng.nodes.new('CompositorNodeGlare'); _gl.inputs['Type'].default_value='Bloom'; _gl.inputs['Quality'].default_value='High'; _gl.inputs['Threshold'].default_value=2.0; _gl.inputs['Strength'].default_value=.3; _gl.inputs['Size'].default_value=.55
_go=_ng.nodes.new('NodeGroupOutput'); _ng.links.new(_rl.outputs['Image'],_gl.inputs['Image']); _ng.links.new(_gl.outputs['Image'],_go.inputs[0]); sc.compositing_node_group=_ng; sc.render.use_compositing=True
for _o in bpy.data.objects:
 if _o.type=='LIGHT' and (os.environ.get('M01_INTERIOR_4K')=='1' or (_o.data.type in ('POINT','SPOT') and _o.data.energy<140)): _o.data.use_shadow=False
sc.world.use_nodes=True; _bg=sc.world.node_tree.nodes.get('Background'); _bg.inputs['Color'].default_value=(.012,.018,.03,1); _bg.inputs['Strength'].default_value=.3
# continuous architectural plinth: keeps the staging map coherent instead of floating rooms
cube('M01 staging surround floor',(0,-1.0,-.24),(18.5,11.5,.06),M['staging_floor'],.04)
cube('M01 interior architectural plinth',(0,-1.0,-.12),(15.8,8.8,.08),M['plinth'],.08)
# perimeter coping and recessed transition strips tie the room islands together
for _sx in (-15.5,15.5): cube('plinth side coping',(_sx,-1.0,.02),(.08,8.5,.12),M['trim'],.03)
for _sy in (-9.4,7.4): cube('plinth end coping',(0,_sy,.02),(15.5,.08,.12),M['trim'],.03)
for _px in (-7.8,-3.0,5.0,13.0):
 MB.box((_px,-1.0,.035),(.025,7.8,.01),M['grout'])
for _py in (-7.0,-4.8,-2.6,-.4,1.8,4.0,6.2):
 MB.box((0,_py,.036),(15.5,.018,.01),M['grout'])
for _dx,_dy in ((-8.8,-7.0),(4.8,1.8),(8.6,-1.0),(-2.0,5.8)):
 MB.box((_dx,_dy,.04),(.24,.07,.012),M['trim'])
# corridor runner carpet and a plant at each end of it
cube('corridor runner',(0,-3.0,.065),(.55,4.3,.012),M['carpet'],.005)
small_plant(.85,.8,.45)
# corridor identity: the motel's covered walkway - ice machine and soda alcove,
# extinguisher cabinet, room-number arrows, caged wall lights, water stains
prop('int_ice_machine',-.9,-4.5,1.2,rot=1.5708,fallback=lambda:(MB.box((-1.05,-4.5,.6),(.18,.3,.6),M['chrome']), MB.box((-.86,-4.5,.95),(.01,.22,.15),M['cyan'])))
MB.box((-1.05,-4.5,1.25),(.2,.32,.06),M['metal']); MB.box((-1.0,-4.5,.2),(.12,.22,.02),M['glass'])
plight((-.6,-4.5,1.0),(.5,.85,1.0),60,.3)
prop('int_vending_machine',.95,-2.2,1.8,rot=-1.5708,fallback=lambda:vending(1.0,-2.2)); plight((.4,-2.2,1.0),(1,.15,.35),80,.4)
MB.box((-1.12,.7,1.0),(.04,.18,.28),M['red']); MB.box((-1.07,.7,1.0),(.005,.13,.22),M['glass'])
MB.cyl((-1.02,.7,.82),(-1.02,.7,1.12),.07,M['red'],10)
for i,yy in enumerate((-5.4,-3.0,-.6)):
 MB.box((-1.12,yy,1.9),(.02,.32,.08),M['cream']); MB.box((-1.09,yy,1.9),(.005,.24,.04),[M['red'],M['cyan'],M['amber']][i])
for yy in (-6.5,-4.0,-1.5):
 MB.box((1.15,yy,.11),(.03,.6,.01),M['grout'])            # skirting grime line
for i in range(9):
 MB.disc((RND.uniform(-.8,.8),RND.uniform(-7,1),.071),RND.uniform(.12,.3),M['puddle'],12)   # puddles / stains
MB.box((.95,-.3,.25),(.18,.12,.25),M['metal']); MB.cyl((.95,-.3,.5),(.95,-.3,.52),.13,M['metal'],10)   # trash can
MB.box((-.9,-6.9,.4),(.25,.18,.4),M['wood']); MB.box((-.9,-6.9,.82),(.22,.15,.02),M['towel_w'])          # towel crate
# the walkway reads from above: posts and a rail along both edges, concrete
# expansion joints, a housekeeping cart and a bench mid-way, potted plants, mats
for _sx in (-1.2,1.2):
 for _py in range(-7,2):
  MB.cyl((_sx,_py,.06),(_sx,_py,.95),.03,M['metal'],6)
 MB.box((_sx,-2.95,.95),(.035,4.3,.025),M['trim'])
for _py in range(-7,1): MB.box((0,_py+.5,.065),(1.2,.012,.004),M['grout'])
# housekeeping cart, parked against the left rail
MB.box((-.75,-1.0,.55),(.22,.5,.45),M['metal'])
for _k in range(3): MB.box((-.75,-1.0,.25+_k*.3),(.2,.47,.012),M['trim'])
for _k in range(5): MB.box((-.75,-1.35+_k*.15,.95),(.15,.06,.05),[M['towel_w'],M['cyan'],M['towel_w'],M['bedspread'],M['towel_w']][_k])
MB.cyl((-.75,-.5,1.0),(-.75,-.5,1.25),.06,M['amber'],8); MB.box((-.75,-1.0,.38),(.18,.3,.12),M['paperw'])
# bench and an ashtray bin mid-way on the right
MB.box((.85,-5.2,.38),(.18,.6,.05),M['grainwood']); MB.box((.98,-5.2,.6),(.04,.6,.2),M['grainwood'])
for _by in (-5.7,-4.7): MB.box((.85,_by,.18),(.15,.03,.18),M['metal'])
MB.cyl((.85,-4.2,0),(.85,-4.2,.55),.11,M['chrome'],10); MB.cyl((.85,-4.2,.55),(.85,-4.2,.58),.13,M['grout'],10)
# doormats at each room door and planters
for _my in (-6.2,-3.8,-1.4):
 MB.box((-.55,_my,.07),(.32,.22,.008),M['carpet'])
for _py in (-3.0,.6): small_plant(-.85,_py,.55)
small_plant(.9,-6.8,.6)
# Shared transition dressing: service markers, drain grates, cable covers and
# small motel wayfinding decals make the open plinth feel authored like the
# pool deck while keeping every playable lane clear.
for _gx,_gy in ((-10.0,-7.8),(6.8,6.1),(12.8,-.8)):
 MB.box((_gx,_gy,.08),(.22,.12,.012),M['metal'])
 for _i in range(4): MB.box((_gx-.12+_i*.08,_gy,.095),(.012,.08,.004),M['grout'])
for _bx,_by in ((-10.0,5.8),(7.0,-7.2),(13.1,4.8)):
 MB.box((_bx,_by,.25),(.16,.1,.25),M['metal']); MB.box((_bx,_by-.11,.42),(.11,.012,.06),M['cyan'])
for _sx,_sy in ((-8.2,-1.0),(5.6,-1.0),(8.0,2.6)):
 MB.box((_sx,_sy,.075),(.28,.025,.006),M['amber'],rz=math.radians(35))
# Small maintenance details: exposed drain elbows and slow condensation drips
# give the shared walkway the same lived-in density as the courtyard while
# staying above the walkable centerline.
for _px,_py in ((1.28,-5.6),(1.28,-2.4),(-1.28,-.2)):
 MB.cyl((_px,_py,1.28),(_px,_py,1.82),.028,M['metal'],8)
 MB.cyl((_px,_py,1.82),(_px-.12,_py,1.82),.028,M['metal'],8)
 MB.cyl((_px-.12,_py,1.78),(_px-.12,_py,1.60),.012,M['cyan'],8)
 MB.disc((_px-.12,_py,.075),.07,M['puddle'],10)
MB.build(bevel=.01)
# Final shadow-budget pass after every authored practical light exists. The
# tiny decorative fixtures stay visible but do not consume Eevee shadow atlas
# slots, keeping the 4K review renders deterministic.
for _o in bpy.data.objects:
 if _o.type=='LIGHT' and _o.data.type in ('POINT','SPOT') and _o.data.energy<140: _o.data.use_shadow=False
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'m01_interiors_transitions_staging.blend')); bpy.ops.render.render(write_still=True)
# Close-up proof at the requested 3/4 readability scale.
cam.location=(15.5,-15.5,16.0); cam.rotation_euler=(Vector((10.2,-4.4,0.7))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.ortho_scale=10.4; sc.render.resolution_x=3840 if os.environ.get('M01_INTERIOR_4K')=='1' else 960; sc.render.resolution_y=2160 if os.environ.get('M01_INTERIOR_4K')=='1' else 540
# This close-up looks through the exterior edge; omit that unlit backside in
# the staging crop while keeping the wall in the full map and runtime.
_reception_right_wall=bpy.data.objects.get('Reception core right wall')
if _reception_right_wall: _reception_right_wall.hide_render=True
sc.render.filepath=str(RENDER_DIR/'m01_reception_detail_staging.png'); bpy.ops.render.render(write_still=True)
if _reception_right_wall: _reception_right_wall.hide_render=False
# Service-transition detail proof.
cam.location=(-12,-13.5,16.0); cam.rotation_euler=(Vector((-12,-1,0.5))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.ortho_scale=8.0; sc.render.filepath=str(RENDER_DIR/'m01_service_transition_detail_staging.png'); bpy.ops.render.render(write_still=True)

















