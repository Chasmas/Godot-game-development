"""Derive a Blender cutaway layout from the authoritative playable M01 grid.

This is a projection/anchor review, not a finished art plate or nav replacement.
"""
from pathlib import Path
import hashlib
import json
import sys
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from m01_imagegen_materials import apply_reviewed_source
from m01_layout_data import floor_grid
SOURCE = ROOT / 'levels/m01_sunset_palms.json'
OUT = ROOT / 'assets/art/prerendered/m01_sunset_palms/staging/layout_reconstruction_v1'
OUT.mkdir(parents=True, exist_ok=True)
raw = SOURCE.read_bytes()
level = json.loads(raw.decode('utf-8'))
rows = level['map']
width, height = max(map(len, rows)), len(rows)
METRES_PER_CELL = .5
bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, colour, source=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (*colour, 1)
    if source:
        apply_reviewed_source(mat, source)
    return mat

wall = material('ImageGen stucco cutaway', (.7, .4, .3), 'stucco')
skirting = material('ImageGen walnut wall skirting', (.3,.15,.06), 'walnut')
cap = material('ImageGen cream wall remate', (.8,.75,.65), 'painted_metal')
ground = material('ImageGen ground candidate', (.2, .2, .2), 'asphalt')
door = material('ImageGen walnut door anchor', (.4, .2, .1), 'walnut')
window = material('Window placement marker', (.06, .35, .5))
pool = material('ImageGen pool basin candidate', (.1, .5, .6), 'pool_tiles')
floor_materials = {
    '.': material('ImageGen guest carpet', (.1,.2,.2), 'carpet'),
    ',': material('ImageGen service ceramic', (.5,.6,.5), 'bathroom_tiles'),
    '_': material('ImageGen reception ceramic', (.5,.5,.4), 'reception_floor'),
    ':': ground,
    '=': material('ImageGen deck paving', (.5,.4,.3), 'deck'),
    '"': material('ImageGen walkway paving', (.5,.4,.3), 'deck'),
    '~': pool,
}
resolved_floors = floor_grid(rows)

def char(x, y):
    return rows[y][x] if 0 <= y < height and 0 <= x < len(rows[y]) else '#'

def box(name, x, y, sx, sy, z, material):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z / 2))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (sx, sy, z)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj

anchors = []
walls = 0
trim_geometry = {skirting: ([], []), cap: ([], [])}
cap_cells = set()
skirting_edges = {}

def trim_box(mat, centre, dimensions):
    vertices, faces = trim_geometry[mat]
    index = len(vertices)
    cx,cy,cz = centre
    hx,hy,hz = (value*.5 for value in dimensions)
    vertices.extend((cx+dx*hx,cy+dy*hy,cz+dz*hz)
        for dx,dy,dz in ((-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                         (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)))
    faces.extend(tuple(index+i for i in face) for face in
        ((0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)))

for y, row in enumerate(rows):
    for x, glyph in enumerate(row):
        px, py = (x + .5) * METRES_PER_CELL, -(y + .5) * METRES_PER_CELL
        if glyph == '#':
            # Skip deep solid filler; retain every wall cell touching map space.
            if all(char(x + dx, y + dy) == '#' for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))):
                continue
            box(f'Wall_{x}_{y}', px, py, .5, .5, .65, wall)
            cap_cells.add((x,y))
            # Keep trim entirely inside the wall footprint; do not narrow lanes.
            for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
                adjacent = char(x+dx,y+dy)
                if adjacent in '# DLW%':
                    continue
                edge_key = (dx,dy,x if dx else y)
                skirting_edges.setdefault(edge_key,set()).add(y if dx else x)
            walls += 1
        elif glyph in 'DLW%':
            box(f'Opening_{glyph}_{x}_{y}', px, py, .46, .46, .15,
                door if glyph in 'DL' else window)
        if glyph in 'DLW%PXOB^':
            anchors.append({'glyph': glyph, 'cell': [x,y],
                'godot_center_px': [x*16+8,y*16+8], 'blender_center_m': [px,py,0]})
# One floor mesh per material avoids thousands of separate floor objects.
remaining = set(cap_cells)
covered = set()
cap_rectangles = []
while remaining:
    x,y = min(remaining, key=lambda cell:(cell[1],cell[0]))
    end_x = x
    while (end_x+1,y) in remaining:
        end_x += 1
    end_y = y
    while all((xx,end_y+1) in remaining for xx in range(x,end_x+1)):
        end_y += 1
    rectangle = {(xx,yy) for yy in range(y,end_y+1) for xx in range(x,end_x+1)}
    assert not (covered & rectangle)
    covered.update(rectangle)
    remaining.difference_update(rectangle)
    cap_rectangles.append([x,y,end_x+1,end_y+1])
    trim_box(cap, ((x+end_x+1)*.25,-(y+end_y+1)*.25,.65),
        ((end_x-x+1)*.5,(end_y-y+1)*.5,.035))
assert covered == cap_cells
skirting_runs = 0
for (dx,dy,fixed), indices in sorted(skirting_edges.items()):
    remaining_indices = set(indices)
    while remaining_indices:
        start = end = min(remaining_indices)
        while end+1 in remaining_indices:
            end += 1
        remaining_indices.difference_update(range(start,end+1))
        along = (start+end+1)*.25
        fixed_centre = (fixed+.5)*.5
        centre = (fixed_centre+dx*.244,-along,.075) if dx else (along,-fixed_centre-dy*.244,.075)
        size = (.012,(end-start+1)*.5,.11) if dx else ((end-start+1)*.5,.012,.11)
        trim_box(skirting,centre,size)
        skirting_runs += 1
for mat, (vertices,faces) in trim_geometry.items():
    mesh = bpy.data.meshes.new(mat.name+' geometry')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(mat.name+' authored detail', mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    bevel = obj.modifiers.new('Fine moulding edges', 'BEVEL')
    bevel.width = .004
    bevel.segments = 2
for glyph, mat in floor_materials.items():
    vertices, faces = [], []
    for y, row in enumerate(resolved_floors):
        for x, value in enumerate(row):
            if value != glyph:
                continue
            i = len(vertices)
            vertices.extend(((x*.5,-y*.5,.018),((x+1)*.5,-y*.5,.018),
                ((x+1)*.5,-(y+1)*.5,.018),(x*.5,-(y+1)*.5,.018)))
            faces.append((i+3,i+2,i+1,i))
    mesh = bpy.data.meshes.new(f'Floor_{glyph}_cells')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(f'Floor_{glyph}_resolved_from_game',mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
centre = Vector((width*.25, -height*.25, 0))
bpy.ops.object.camera_add(location=centre + Vector((0, 0, 45)))
camera = bpy.context.object
camera.rotation_euler = (0, 0, 0)
camera.data.type = 'ORTHO'
camera.data.ortho_scale = width*.5 + 2
scene = bpy.context.scene
scene.camera = camera
scene.render.engine = 'CYCLES'
scene.cycles.samples = 8
scene.render.resolution_x = 1024
scene.render.resolution_y = round(1024 * height / width)
scene.render.resolution_percentage = 100
scene.world = bpy.data.worlds.new('Layout review world')
scene.world.color = (.25,.25,.25)
bpy.ops.object.light_add(type='AREA', location=centre + Vector((-5,-3,20)))
bpy.context.object.data.energy = 2500
bpy.context.object.data.shape = 'DISK'
bpy.context.object.data.size = 20
scene.render.filepath = str(OUT / 'layout_topdown.png')
scene['runtime_approved'] = False
scene['source_level_sha256'] = hashlib.sha256(raw).hexdigest()
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'layout_reconstruction.blend'))
bpy.ops.render.render(write_still=True)
camera.location = (5,-6,10)
camera.rotation_euler = (Vector((9,-3,.2))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale = 8
scene.render.resolution_x = 960
scene.render.resolution_y = 540
scene.render.filepath = str(OUT / 'wall_finish_detail.png')
bpy.ops.render.render(write_still=True)
(OUT / 'layout_contract.json').write_text(json.dumps({
    'source': str(SOURCE.relative_to(ROOT)), 'source_sha256': hashlib.sha256(raw).hexdigest(),
    'grid_size': [width,height], 'godot_cell_size_px': 16,
    'blender_cell_size_m': METRES_PER_CELL, 'transform': 'x_m=x_px/32; y_m=-y_px/32',
    'visible_wall_cells': walls, 'opening_and_objective_anchors': anchors,
    'cap_rectangles': cap_rectangles, 'skirting_continuous_runs': skirting_runs,
    'cap_cell_coverage_verified': covered == cap_cells,
    'zones': level.get('zones', {}), 'camera_placements': level.get('cameras', []),
    'resolved_floor_grid': resolved_floors,
    'runtime_approved': False, 'layout_changed': False,
    'limitations': ['Material scale and seams remain unapproved; grid parity requires runtime comparison.',
        'Opening markers are not final door/window geometry.',
        'Godot actor projection and occlusion require independent validation.'],
}, indent=2), encoding='utf-8')
print(f'M01_LAYOUT_RECONSTRUCTION: walls={walls}, anchors={len(anchors)}')
