"""Native static can/hand mesh audit; does not approve animation integration."""
import bpy, json, math, os
from pathlib import Path
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_ray_tri

folder = Path(os.environ.get('GRIP_AUDIT_DIR','build/consumable_grip_sculpt_v4')).resolve()
bpy.ops.wm.open_mainfile(filepath=str(folder/'guard_grip.blend'))
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
frame = arm.matrix_world @ arm.data.bones['RightHand'].matrix_local
bodies = [o for o in bpy.context.scene.objects if o.type == 'MESH' and 'RightHand' in o.vertex_groups]
axes = frame.to_3x3().normalized()
prop_frame = Matrix((axes.col[1],axes.col[2],axes.col[0])).transposed().to_4x4()
prop_frame.translation = frame @ Vector((-5.75,9,-4.1))
with bpy.data.libraries.load(str(Path('build/idle_consumables_candidate/can.blend').resolve()),link=False) as (source,destination):
    destination.objects = source.objects
props = []
for obj in destination.objects:
    if obj is None or obj.type not in {'MESH','CURVE','FONT'}: continue
    bpy.context.scene.collection.objects.link(obj)
    obj.matrix_world = prop_frame @ obj.matrix_world
    props.append(obj)
bpy.context.view_layer.update()
deps = bpy.context.evaluated_depsgraph_get()
def triangles(objects):
    vertices,faces = [],[]
    for obj in objects:
        evaluated = obj.evaluated_get(deps)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        offset = len(vertices)
        vertices.extend(evaluated.matrix_world @ v.co for v in mesh.vertices)
        faces.extend(tuple(offset+i for i in face.vertices) for face in mesh.loop_triangles)
        evaluated.to_mesh_clear()
    return vertices,faces
hv,hf = triangles(bodies)
pv,pf = triangles(props)
hand_bvh = BVHTree.FromPolygons(hv,hf,all_triangles=True)
prop_bvh = BVHTree.FromPolygons(pv,pf,all_triangles=True)
pairs = hand_bvh.overlap(prop_bvh)
def crosses(first,second):
    for i in range(3):
        start,end = first[i],first[(i+1)%3]
        delta = end-start
        if delta.length < 1e-9: continue
        hit = intersect_ray_tri(*second,delta.normalized(),start,True)
        if hit is not None and -1e-7 <= (hit-start).dot(delta.normalized()) <= delta.length+1e-7:
            return True
    return False
crossings = []
for hi,pi in pairs:
    hand = [hv[i] for i in hf[hi]]
    prop = [pv[i] for i in pf[pi]]
    if crosses(hand,prop) or crosses(prop,hand): crossings.append([hi,pi])
inside = []
for body in bodies:
    group = body.vertex_groups['RightHand'].index
    inverse = frame.inverted() @ body.matrix_world
    for vertex in body.data.vertices:
        if not any(g.group==group and g.weight>.8 for g in vertex.groups): continue
        p = inverse @ vertex.co
        if -5.75<p.x<5.75 and math.hypot(p.y-9,p.z+4.1)<3.2: inside.append(vertex.index)
report = {'approved':False,'scope':'Static native evaluated full-body versus actual can meshes; bidirectional edge-triangle crossings. Coplanar contacts and animated state transitions remain unvalidated.',
    'hand_triangles':len(hf),'can_triangles':len(pf),'bvh_candidate_pairs':len(pairs),
    'surface_crossing_pairs':len(crossings),'strong_hand_vertices_inside_cylinder':len(inside),
    'crossings':crossings[:100]}
(folder/'mesh_contact.json').write_text(json.dumps(report,indent=2))
print('GRIP_MESH_AUDIT',json.dumps({k:v for k,v in report.items() if k!='crossings'}))
