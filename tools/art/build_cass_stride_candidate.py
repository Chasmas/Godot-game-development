"""Non-production humanoid foot-contact study; defaults to Cass."""
from pathlib import Path
import bpy, math, json, argparse, sys
from mathutils import Vector, Quaternion
ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--cast', default='cass')
parser.add_argument('--gait', choices=['walk','run','sneak'], default='walk')
parser.add_argument('--profile', choices=['study','grounded','preserved'], default='study')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
CAST = args.cast
GAIT = args.gait
PROFILE = {'walk':(1.0,.55,.6,.12,.03), 'run':(.65,.80,.4,.18,.015), 'sneak':(1.4,.35,.72,.045,.18)}[GAIT]
if args.profile == 'grounded':
    PROFILE = {'walk':(.9,.95,.6,.10,.03), 'run':(.65,1.05,.4,.18,.015), 'sneak':(1.2,.60,.65,.045,.18)}[GAIT]
elif args.profile == 'preserved':
    PROFILE = {'walk':(.9,.70,.55,.085,.02), 'run':(.65,.80,.4,.16,.015), 'sneak':(1.2,.40,.65,.04,.18)}[GAIT]
duration, stride, stance_fraction, swing_height, pelvis_minimum = PROFILE
OUT = ROOT / 'build/locomotion_candidates' / CAST
if args.profile != 'study': OUT = OUT / args.profile
if GAIT != 'walk': OUT = OUT / GAIT
OUT.mkdir(parents=True, exist_ok=True)
assert (ROOT / f'assets/art/cast3d_rt/{CAST}/{CAST}.glb').is_file()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / f'assets/art/cast3d_rt/{CAST}/{CAST}.glb'))
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
# Imported glTF tails are 100 times the joint spacing. Correct lengths without
# changing heads or rest axes, so existing mesh binding and poses stay intact.
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for side in ['Left', 'Right']:
    for suffix, child_suffix in [('UpLeg', 'Leg'), ('Leg', 'Foot')]:
        bone = arm.data.edit_bones[side + suffix]
        child = arm.data.edit_bones[side + child_suffix]
        bone.length = (child.head - bone.head).length
    arm.data.edit_bones[side + 'Foot'].length *= .01
bpy.ops.object.mode_set(mode='OBJECT')
scene = bpy.context.scene
CYCLE_FRAMES = round(duration*240)
scene.render.fps = 240
tracks = list(arm.animation_data.nla_tracks)
for track in tracks: track.mute = True
source = next((s.action for t in tracks for s in t.strips if t.name == GAIT or s.action.name == GAIT), None)
if source is None:
    source = next(s.action for t in tracks for s in t.strips if t.name == 'walk' or s.action.name == 'walk')
idle = next(s.action for t in tracks for s in t.strips if t.name == 'idle' or s.action.name == 'idle')
arm.animation_data.action = idle
first, last = source.frame_range
scene.frame_set(int(idle.frame_range[0]))
bpy.context.view_layer.update()
balanced = {pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones
            if pb.name in ['Hips', 'Spine', 'Spine01', 'Spine02', 'neck', 'Head']}
if GAIT != 'walk':
    lean = math.radians(8 if GAIT == 'run' else 12)
    for name, angle in [('Spine02',lean), ('neck',-lean*.5)]:
        rest_rotation = (arm.matrix_world @ arm.data.bones[name].matrix_local).to_quaternion()
        local_rotation = rest_rotation.inverted() @ Quaternion((1,0,0),angle) @ rest_rotation
        balanced[name] = balanced[name] @ local_rotation.to_matrix().to_4x4()
leg_heads = [arm.matrix_world @ arm.data.bones[side+'UpLeg'].head_local for side in ['Left','Right']]
leg_reaches = [(arm.data.bones[side+'UpLeg'].length+arm.data.bones[side+'Leg'].length)*.01*.985 for side in ['Left','Right']]
feet = [arm.pose.bones.get(side + 'Foot') for side in ['Left', 'Right']]
assert all(feet), 'Both foot bones are required'
rest = [arm.matrix_world @ foot.head for foot in feet]
sole_rotations = [(arm.matrix_world @ foot.matrix).to_quaternion() for foot in feet]
arm.animation_data.action = source
source_poses = []
for frame in range(CYCLE_FRAMES+1):
    source_frame = first + (last-first) * frame / CYCLE_FRAMES
    scene.frame_set(math.floor(source_frame), subframe=source_frame-math.floor(source_frame))
    source_poses.append({pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones})
arm.animation_data_clear()
neutral_forward = sum(p.y for p in rest) / 2
for side, point in enumerate(rest):
    point.x = leg_heads[side].x
    point.y = neutral_forward
print('Armature transform:', arm.matrix_world)
for side in ['Left', 'Right']:
    for suffix in ['UpLeg', 'Leg', 'Foot']:
        pb = arm.pose.bones.get(side + suffix)
        print('Leg geometry:', pb.name, 'head', tuple(pb.head), 'tail', tuple(pb.tail), 'length', pb.length)
targets = []
constraints = []
hip_target = bpy.data.objects.new('balanced pelvis target', None)
scene.collection.objects.link(hip_target)
hip_target.matrix_world = arm.matrix_world @ arm.data.bones['Hips'].matrix_local @ balanced['Hips']
hip_constraint = arm.pose.bones['Hips'].constraints.new('COPY_TRANSFORMS')
hip_constraint.target = hip_target
hip_constraint.owner_space = 'WORLD'
hip_constraint.target_space = 'WORLD'
for side, foot in enumerate(feet):
    target = bpy.data.objects.new(foot.name + ' stride contact target', None)
    scene.collection.objects.link(target)
    target.rotation_mode = 'QUATERNION'
    target.rotation_quaternion = sole_rotations[side]
    ik = foot.constraints.new('IK')
    ik.target = target
    # use_tail=False solves the foot head through its parents: shin and thigh.
    # A third link includes the pelvis and lets foot IK rotate the whole body.
    ik.chain_count = 2
    ik.use_tail = False
    ik.use_stretch = False
    pole = bpy.data.objects.new(foot.name+' knee direction', None)
    scene.collection.objects.link(pole)
    pole.location = Vector((leg_heads[side].x, leg_heads[side].y-.8, .45))
    ik.pole_target = pole
    ik.pole_angle = math.pi*.5
    targets.append(target)
    constraints.append(ik)
    rotation = foot.constraints.new('COPY_ROTATION')
    rotation.target = target
    rotation.owner_space = 'WORLD'
    rotation.target_space = 'WORLD'
    constraints.append(rotation)
poses = []
contacts = []
actual_contacts = []
pelvis_drops = []
arm.animation_data_create()
evaluation_action = bpy.data.actions.new('contact_evaluation')
arm.animation_data.action = evaluation_action
for frame in range(CYCLE_FRAMES+1):
    phase = frame / CYCLE_FRAMES
    sampled = source_poses[frame]
    if phase > .8:
        blend = (phase-.8)/.2
        blend = blend*blend*(3-2*blend)
        sampled = {name: matrix.lerp(source_poses[0][name], blend) for name,matrix in sampled.items()}
    for name, matrix in sampled.items():
        arm.pose.bones[name].matrix_basis = matrix
    for name, matrix in balanced.items():
        arm.pose.bones[name].matrix_basis = matrix
    for pb in arm.pose.bones:
        pb.keyframe_insert('location', frame=frame)
        pb.keyframe_insert('rotation_quaternion', frame=frame)
        pb.keyframe_insert('scale', frame=frame)
    scene.frame_set(frame)
    for side, target in enumerate(targets):
        cycle = (phase + side * .5) % 1
        if cycle < stance_fraction:
            forward = stride * (.5 - cycle / stance_fraction)
            lift = 0
        else:
            swing = (cycle - stance_fraction) / (1-stance_fraction)
            forward = stride * (-.5 + swing * swing * (3 - 2 * swing))
            lift = swing_height * math.sin(math.pi * swing)
        target.location = rest[side] + Vector((0, -forward, lift))
    required_drop = pelvis_minimum
    for head, reach, target in zip(leg_heads, leg_reaches, targets):
        horizontal = Vector((head.x-target.location.x, head.y-target.location.y)).length
        vertical_reach = math.sqrt(max(.001, reach*reach-horizontal*horizontal))
        required_drop = max(required_drop, head.z-target.location.z-vertical_reach)
    pelvis_drops.append(required_drop)
    hip_target.matrix_world = arm.matrix_world @ arm.data.bones['Hips'].matrix_local @ balanced['Hips']
    hip_target.location.z -= required_drop
    arm.update_tag(refresh={'OBJECT', 'DATA'})
    bpy.context.view_layer.update()
    evaluated = arm.evaluated_get(bpy.context.evaluated_depsgraph_get())
    pose = {pb.name: evaluated.convert_space(pose_bone=pb, matrix=pb.matrix.copy(), from_space='POSE', to_space='LOCAL') for pb in evaluated.pose.bones}
    pose.update({name: matrix.copy() for name, matrix in balanced.items() if name!='Hips'})
    poses.append(pose)
    contacts.append([[*target.location] for target in targets])
    actual_contacts.append([[*(evaluated.matrix_world @ evaluated.pose.bones[foot.name].head)] for foot in feet])
for foot in feet:
    for constraint in list(foot.constraints): foot.constraints.remove(constraint)
arm.pose.bones['Hips'].constraints.remove(hip_constraint)
arm.animation_data_create()
arm.animation_data.action = None
candidate = bpy.data.actions.new(GAIT+'_contact_candidate')
arm.animation_data.action = candidate
for frame, pose in enumerate(poses):
    for pb in arm.pose.bones:
        pb.matrix_basis = pose[pb.name]
        pb.keyframe_insert('location', frame=frame)
        pb.keyframe_insert('rotation_quaternion', frame=frame)
        pb.keyframe_insert('scale', frame=frame)
scene.frame_start = 0
scene.frame_end = CYCLE_FRAMES
errors = [(Vector(actual_contacts[f][s]) - Vector(contacts[f][s])).length for f in range(CYCLE_FRAMES+1) for s in range(2)]
baked_errors = []
seam_poses = {}
for frame in range(CYCLE_FRAMES+1):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    evaluated = arm.evaluated_get(bpy.context.evaluated_depsgraph_get())
    for side, foot in enumerate(feet):
        baked_errors.append(((evaluated.matrix_world @ evaluated.pose.bones[foot.name].head) - Vector(contacts[frame][side])).length)
    if frame in (0,CYCLE_FRAMES):
        seam_poses[frame] = {pb.name: pb.matrix.copy() for pb in evaluated.pose.bones}
seam_position = max((seam_poses[0][name].translation-seam_poses[CYCLE_FRAMES][name].translation).length*.01 for name in seam_poses[0])
seam_angles = [seam_poses[0][name].to_quaternion().rotation_difference(seam_poses[CYCLE_FRAMES][name].to_quaternion()).angle for name in seam_poses[0]]
# q and -q describe the same orientation: compare the shortest physical angle.
seam_rotation = max(min(angle, abs(2*math.pi-angle)) for angle in seam_angles)
print('Loop seam, metres / radians:', seam_position, seam_rotation)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / (GAIT+'_contact_candidate.blend')))
(OUT / 'review.json').write_text(json.dumps({'runtime_approved': False, 'contact_gate_passed': max(baked_errors) < .001, 'source': 'Existing Cass rig and walk upper-body pose', 'duration_seconds': duration, 'stance_fraction': .6, 'stride_metres': stride, 'max_ik_error_metres': max(errors), 'max_baked_error_metres': max(baked_errors), 'foot_targets': contacts, 'actual_contacts': actual_contacts, 'pending': ['Re-solve legs against the corrected baked hip pose; current evaluated and baked transforms differ', 'Inspect knee direction and ankle rotation', 'Validate turns, backward motion, armed variants, run and sneak', 'Export candidate and compare gameplay at matched travel speed']}, indent=2))
print('Foot target errors, IK / baked:', max(errors), max(baked_errors))
print('CASS STRIDE CANDIDATE BUILT; staging only')
report_path = OUT / 'review.json'
report = json.loads(report_path.read_text())
report['cast'] = CAST
report['gait'] = GAIT
report['profile'] = args.profile
report['native_speed_px_s'] = stride/stance_fraction/duration*16.0
report['duration_seconds'] = duration
report['stride_metres'] = stride
report['stance_fraction'] = stance_fraction
report['source'] = f'Existing {CAST} rig and {GAIT} upper-body pose'
report['loop_seam_metres'] = seam_position
report['loop_seam_radians'] = seam_rotation
report['loop_gate_passed'] = seam_position < .001 and seam_rotation < .001
report['pelvis_drop_range_metres'] = [min(pelvis_drops),max(pelvis_drops)]
report['pending'][0] = 'Evaluate knee flexion, planted sole contact and arm posture visually before runtime approval'
report_path.write_text(json.dumps(report, indent=2))
assert report['contact_gate_passed'] and report['loop_gate_passed'], 'Candidate must pass bake gates before review export'
bpy.ops.export_scene.gltf(filepath=str(OUT / (GAIT+'_contact_candidate.glb')), export_format='GLB',
                         export_animation_mode='ACTIVE_ACTIONS', export_cameras=False,
                         export_lights=False, export_frame_range=True,
                         export_optimize_animation_size=False)
