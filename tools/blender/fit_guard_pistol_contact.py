"""Build-only vertex clearance fit in the actual authored dual aim pose."""
import bpy,json
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
out=Path('build/guard_pistol_contact_fit').resolve();out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path('build/guard_remodeled_morph_review/guard.glb').resolve()))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
actions=[a for a in bpy.data.actions if a.name.split('.')[0]=='aim_dual']
assert actions, 'Missing aim_dual action'
arm.animation_data_clear();arm.animation_data_create();arm.animation_data.action=actions[0]
bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
bodies=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.shape_keys and 'WeaponGrip' in o.data.shape_keys.key_blocks]
assert bodies
original_objects=set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=str(Path('build/held_pistol_candidate/pistol.glb').resolve()))
gun_objects=[o for o in bpy.context.scene.objects if o not in original_objects]
critical=[o for o in gun_objects if o.type=='MESH' and o.name.startswith(('Polymer grip','Receiver','Slide','Trigger guard','Curved trigger'))]
assert len(critical)>=5
reports=[]
for side in ('Right','Left'):
    pb=arm.pose.bones[side+'Hand']
    hand=arm.matrix_world@pb.matrix;axes=hand.to_3x3().normalized()
    x,y,z=axes.col
    basis=Matrix((y,z,x)).transposed() if side=='Right' else Matrix((y,-z,-x)).transposed()
    attachment=basis.to_4x4();attachment.translation=hand.translation+y*.06+z*.039
    surfaces=[]
    for obj in critical:
        transform=attachment@obj.matrix_world
        vertices=[transform@v.co for v in obj.data.vertices]
        faces=[list(p.vertices) for p in obj.data.polygons]
        bounds=([min(v[a] for v in vertices) for a in range(3)],[max(v[a] for v in vertices) for a in range(3)])
        surfaces.append((obj.name,BVHTree.FromPolygons(vertices,faces),bounds))
    hits={};moved=0;max_shift=0.0
    for body in bodies:
        group=body.vertex_groups[side+'Hand'].index
        rest=arm.matrix_world@pb.bone.matrix_local
        pose_from_mesh=hand@rest.inverted()@body.matrix_world
        mesh_from_pose=pose_from_mesh.inverted()
        native_from_mesh=pb.bone.matrix_local.inverted()@arm.matrix_world.inverted()@body.matrix_world
        key=body.data.shape_keys.key_blocks['WeaponGrip']
        for vertex in body.data.vertices:
            weight=next((g.weight for g in vertex.groups if g.group==group),0)
            if weight<.99 or (native_from_mesh@vertex.co).y<5:continue
            point=pose_from_mesh@key.data[vertex.index].co;initial=point.copy()
            for iteration in range(5):
                changed=False
                for name,surface,(lower,upper) in surfaces:
                    if any(point[a]<lower[a]-.0005 or point[a]>upper[a]+.0005 for a in range(3)):continue
                    nearest,normal,index,distance=surface.find_nearest(point)
                    if nearest is not None and (point-nearest).dot(normal)<-.00005:
                        point=nearest+normal*.0005
                        hits[name]=hits.get(name,0)+1;changed=True
                if not changed:break
            shift=(point-initial).length
            if shift>.00001:
                key.data[vertex.index].co=mesh_from_pose@point
                moved+=1;max_shift=max(max_shift,shift)
    reports.append({'side':side,'moved_vertices':moved,'max_shift_m':max_shift,'part_hits':hits})
# Retain original rest skeleton when exporting a mesh-only source for merge.
arm.animation_data_clear()
for pb in arm.pose.bones:pb.matrix_basis.identity()
for body in bodies:
    for key in body.data.shape_keys.key_blocks:
        if key.name!='Basis':key.value=0
for obj in gun_objects:bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'guard.blend'))
bpy.ops.export_scene.gltf(filepath=str(out/'guard.glb'),export_format='GLB',export_animations=False)
(out/'report.json').write_text(json.dumps({'approved':False,'rows':reports,
    'scope':'Vertex-only clearance fit at dual aim frame0. Signed nearest normals assume closed outward parts; triangle crossings, anatomy and animation still unverified.'},indent=2))
print(reports)
