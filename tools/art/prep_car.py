"""Blender (run inside it): Meshy car model -> the game's 3D hero car.

  blender -b --python tools/art/prep_car.py -- <model.glb> <out.glb> [--length 4.6] [--check out.png]

- drops loose fragments (Meshy leaves a few floating bits),
- turns it to face -Y in Blender (glTF +Z, like the cast: the game yaws it the same way),
- scales it to `length` metres, wheels on the ground, centred,
- cuts the driver's door (the car's left side, +X when facing -Y) out of the body
  as its own object "Door", origin on the hinge at its front edge, so the game can
  swing it,
- adds an empty "DriverSeat" where the driver's hips sit.
The source model points its nose at -X (fins at +X): see tools/art/car_probe.py.
"""
import bpy, bmesh, sys, math
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
length = float(argv[argv.index("--length") + 1]) if "--length" in argv else 4.6
check = argv[argv.index("--check") + 1] if "--check" in argv else None
NOCUT = "--nocut" in argv    # diagnostics: keep every face (see --top)
top = argv[argv.index("--top") + 1] if "--top" in argv else None
# door span, as fractions of the car's length from the nose, and its height band
DOOR_FROM, DOOR_TO = 0.37, 0.57
DOOR_Z = (0.08, 0.86)        # up to and including the top rim of the door (seen from above)        # of the car's height (windscreen frame excluded)
DOOR_SIDE = 0.8              # faces further out than this fraction of the half width (seat edges stay)
DOOR_INNER = 0.70            # side-facing walls out from here are the door's inner trim

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in bpy.context.scene.objects:
    o.select_set(o in meshes)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
car = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in [o for o in bpy.context.scene.objects if o.type != "MESH"]:
    bpy.data.objects.remove(o, do_unlink=True)

# 1. loose fragments: keep only islands with a meaningful share of the faces
bm = bmesh.new()
bm.from_mesh(car.data)
# Meshy exports a triangle soup: weld it first or every triangle is its own island
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
bm.faces.ensure_lookup_table()
seen, islands = set(), []
for f in bm.faces:
    if f.index in seen:
        continue
    stack, isl = [f], []
    seen.add(f.index)
    while stack:
        g = stack.pop()
        isl.append(g)
        for e in g.edges:
            for h in e.link_faces:
                if h.index not in seen:
                    seen.add(h.index)
                    stack.append(h)
    islands.append(isl)
total = len(bm.faces)
# the body is the biggest island; anything whose middle sits outside its footprint
# (the stray door-like flaps Meshy floats beside the car) or that is tiny goes
islands.sort(key=len, reverse=True)
main = islands[0]
mx = [v.co.x for f in main for v in f.verts]; my = [v.co.y for f in main for v in f.verts]
pad_x, pad_y = (max(mx) - min(mx)) * 0.02, (max(my) - min(my)) * 0.02
def outside(isl):
    c = sum((f.calc_center_median() for f in isl), Vector()) / len(isl)
    return not (min(mx) - pad_x < c.x < max(mx) + pad_x and min(my) - pad_y < c.y < max(my) + pad_y)
dropped = [isl for isl in islands[1:] if len(isl) < total * 0.004 or outside(isl)]
drop = [f for isl in dropped for f in isl]
bmesh.ops.delete(bm, geom=drop, context="FACES")
bm.to_mesh(car.data)
bm.free()
print("FRAGMENTS dropped", len(drop), "faces in", len(dropped), "islands of", len(islands))

# 2. nose to -Y, length metres, wheels on the ground, centred
car.data.transform(Matrix.Rotation(math.radians(90), 4, "Z"))
xs = [v.co.x for v in car.data.vertices]; ys = [v.co.y for v in car.data.vertices]; zs = [v.co.z for v in car.data.vertices]
k = length / (max(ys) - min(ys))
cx, cy, z0 = (max(xs) + min(xs)) * 0.5, (max(ys) + min(ys)) * 0.5, min(zs)
car.data.transform(Matrix.Scale(k, 4) @ Matrix.Translation((-cx, -cy, -z0)))
xs = [v.co.x for v in car.data.vertices]; ys = [v.co.y for v in car.data.vertices]; zs = [v.co.z for v in car.data.vertices]
# The stray slab Meshy glues outside the passenger side by the windscreen (it reads
# as a giant mirror in game). Located on an overhead render with a metric grid
# (--nocut --top): x < -0.72 m, y -1.1..-0.55 m in this centred frame.
bm = bmesh.new()
bm.from_mesh(car.data)
slab = [] if NOCUT else [f for f in bm.faces if (lambda c: c.x < -0.72 and -1.1 < c.y < -0.55)(f.calc_center_median())]
# ...and the grey quarter-vent bracket it leaves sticking out of the windscreen's
# passenger corner (found with tools/art/car_mark.py, parked view). These
# coordinates are before the re-centring below, which moves x by about +0.15.
slab += [] if NOCUT else [f for f in bm.faces if f not in slab and (lambda c: c.x < -0.66 and -1.25 < c.y < -0.6 and c.z > 0.5)(f.calc_center_median())]
bmesh.ops.delete(bm, geom=slab, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bm.to_mesh(car.data)
bm.free()
print("SLAB faces cut", len(slab))
# centre again across the width: the slab had pushed the bounds out
xs = [v.co.x for v in car.data.vertices]
car.data.transform(Matrix.Translation((-(max(xs) + min(xs)) * 0.5, 0, 0)))
# A thin fin Meshy stands up beside the windscreen on the passenger side: above
# the beltline and out past the windscreen frame, it reads as a huge mirror from
# the game's camera. (Final frame: nose -Y, passenger side -X.)
xs = [v.co.x for v in car.data.vertices]; ys = [v.co.y for v in car.data.vertices]; zs = [v.co.z for v in car.data.vertices]
hw_now, yn_now = max(abs(x) for x in xs), min(ys)
bm = bmesh.new()
bm.from_mesh(car.data)
fin = [] if NOCUT else [f for f in bm.faces if (lambda c: yn_now + 0.22 * length < c.y < yn_now + 0.42 * length and ((c.x < -0.78 * hw_now and c.z > 0.78) or c.x < -0.92 * hw_now))(f.calc_center_median())]
bmesh.ops.delete(bm, geom=fin, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bm.to_mesh(car.data)
bm.free()
print("FIN faces cut", len(fin))
# Cutting the slab and the fin left a ragged hole in the passenger side, which
# reads as a dark jagged shape. Close it, painted with the body's own red.
if not NOCUT:
    bm = bmesh.new()
    bm.from_mesh(car.data)
    region = lambda p: p.x < -0.5 * hw_now and yn_now + 0.18 * length < p.y < yn_now + 0.5 * length
    rim = [e for e in bm.edges if e.is_boundary and region((e.verts[0].co + e.verts[1].co) * 0.5)]
    before = set(bm.faces)
    bmesh.ops.holes_fill(bm, edges=rim, sides=0)
    new_faces = [f for f in bm.faces if f not in before]
    uv = bm.loops.layers.uv.active
    if uv and new_faces:
        # the UV of an untouched red panel next to the hole
        probe = Vector((-0.85 * hw_now, yn_now + 0.3 * length, 0.55))
        ref = min((f for f in before if f.is_valid and region(f.calc_center_median()) and abs(f.normal.x) > 0.6),
                  key=lambda f: (f.calc_center_median() - probe).length, default=None)
        if ref:
            ref_uv = ref.loops[0][uv].uv.copy()
            for f in new_faces:
                for l in f.loops:
                    l[uv].uv = ref_uv
                f.material_index = ref.material_index
    bmesh.ops.recalc_face_normals(bm, faces=new_faces)
    bm.to_mesh(car.data)
    bm.free()
    print("HOLE edges", len(rim), "faces filled", len(new_faces))
xs =[v.co.x for v in car.data.vertices]; ys = [v.co.y for v in car.data.vertices]; zs = [v.co.z for v in car.data.vertices]
half_w, y_nose, height = max(xs), min(ys), max(zs)
print("CAR length", round(max(ys) - min(ys), 2), "width", round(half_w * 2, 2), "height", round(height, 2))
car.name = "Body"

# 3. the driver's door (left side = +X)
y0, y1 = y_nose + DOOR_FROM * length, y_nose + DOOR_TO * length
z_lo, z_hi = DOOR_Z[0] * height, DOOR_Z[1] * height
bm = bmesh.new()
bm.from_mesh(car.data)
def in_door(f):
    c = f.calc_center_median()
    if not (y0 < c.y < y1 and z_lo < c.z < z_hi):
        return False
    # the outer skin, plus the inner trim panel: the door's whole thickness goes,
    # or the open door leaves a wall where the opening should be. Inner faces are
    # the side-facing walls (normal mostly across the car) past the seat's edge.
    return c.x > DOOR_SIDE * half_w or (c.x > DOOR_INNER * half_w and abs(f.normal.x) > 0.55)
door_faces = [f for f in bm.faces if in_door(f)]
print("DOOR faces", len(door_faces))
door_mesh = bpy.data.meshes.new("Door")
dbm = bmesh.new()
vmap = {}
uv_src = bm.loops.layers.uv.active
uv_dst = dbm.loops.layers.uv.new("UVMap") if uv_src else None
for f in door_faces:
    vs = []
    for v in f.verts:
        if v.index not in vmap:
            vmap[v.index] = dbm.verts.new(v.co)
        vs.append(vmap[v.index])
    try:
        nf = dbm.faces.new(vs)
    except ValueError:
        continue
    nf.material_index = f.material_index
    if uv_src:
        for l_src, l_dst in zip(f.loops, nf.loops):
            l_dst[uv_dst].uv = l_src[uv_src].uv
dbm.to_mesh(door_mesh)
dbm.free()
bmesh.ops.delete(bm, geom=door_faces, context="FACES")
bm.to_mesh(car.data)
bm.free()
door = bpy.data.objects.new("Door", door_mesh)
bpy.context.scene.collection.objects.link(door)
for m in car.data.materials:
    door.data.materials.append(m)
# origin on the hinge: the door's front edge, outer side, mid height
hinge = Vector((max(v.co.x for v in door_mesh.vertices), y0, (z_lo + z_hi) * 0.5)) if door_mesh.vertices else Vector((half_w, y0, height * 0.35))
door_mesh.transform(Matrix.Translation(-hinge))
door.location = hinge

# 4. where the driver's hips sit: left half, behind the door's middle
seat = bpy.data.objects.new("DriverSeat", None)
bpy.context.scene.collection.objects.link(seat)
seat.location = (half_w * 0.42, (y0 + y1) * 0.5 + 0.12 * length * 0.2, 0.0)
print("SEAT", tuple(round(v, 2) for v in seat.location), "HINGE", tuple(round(v, 2) for v in hinge))

if top:
    # straight down, 100 px per metre, origin at the image centre: x right, y down = +Y
    sc = bpy.context.scene
    cam = bpy.data.objects.new("topcam", bpy.data.cameras.new("topcam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 6.0
    cam.location = (0, 0, 20)
    cam.rotation_euler = (0, 0, math.radians(180))
    sc.camera = cam
    sun = bpy.data.objects.new("topsun", bpy.data.lights.new("topsun", "SUN"))
    sun.data.energy = 3
    sc.collection.objects.link(sun)
    sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.3, 0.3, 0.35)
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x = sc.render.resolution_y = 600
    sc.render.filepath = top
    door.rotation_euler.z = math.radians(70)   # open: the hole in the body must show from above
    bpy.ops.render.render(write_still=True)
    door.rotation_euler.z = 0.0
    bpy.data.objects.remove(cam)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=False, export_image_format="AUTO", export_extras=True)
print("WROTE", out)

if check:
    sc = bpy.context.scene
    door.rotation_euler.z = math.radians(-65)   # swung open
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = length * 1.15
    sc.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(35), 0, math.radians(135))
    sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.3, 0.3, 0.36)
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x = sc.render.resolution_y = 512
    e = math.radians(50)
    pivot = bpy.data.objects.new("pivot", None)
    sc.collection.objects.link(pivot)
    for o in (car, door, seat):
        o.parent = pivot
    # the game camera: 50 degrees down, looking toward +Y (screen down = -Y)
    for i, yaw in enumerate((0, 90, 180, 270)):
        pivot.rotation_euler.z = math.radians(yaw)
        bpy.context.view_layer.update()
        cam.location = Vector((0, -math.cos(e) * 20, 0.8 + math.sin(e) * 20))
        cam.rotation_euler = (math.radians(90 - 50), 0, 0)
        sc.render.filepath = check.replace(".png", "_%d.png" % i)
        bpy.ops.render.render(write_still=True)
