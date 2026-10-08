extends Node2D
class GripAttachment extends Node:
	var cast: CastModel
	var visual: CharacterVisual
	var weapon: Node3D
	var reported := false
	var ticks := 0
	func rotate_bone_to(bone: int, direction: Vector3, wanted: Vector3) -> void:
		var skeleton := cast._skeleton
		var global_pose := skeleton.get_bone_global_pose(bone)
		var delta := Basis(Quaternion(direction.normalized(), wanted.normalized()))
		var parent := skeleton.get_bone_parent(bone)
		var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		var local := parent_basis.inverse() * delta * global_pose.basis
		skeleton.set_bone_pose_rotation(bone, local.orthonormalized().get_rotation_quaternion())
	func fit_hand(side: String, target_world: Vector3) -> void:
		var skeleton := cast._skeleton
		var upper := skeleton.find_bone(side + "Arm")
		var lower := skeleton.find_bone(side + "ForeArm")
		var hand := skeleton.find_bone(side + "Hand")
		if mini(upper, mini(lower, hand)) < 0: return
		var root := skeleton.get_bone_global_pose(upper).origin
		var elbow := skeleton.get_bone_global_pose(lower).origin
		var wrist := skeleton.get_bone_global_pose(hand).origin
		var target := skeleton.to_local(target_world)
		var length1 := root.distance_to(elbow)
		var length2 := elbow.distance_to(wrist)
		var distance := root.distance_to(target)
		if minf(length1, minf(length2, distance)) < 0.001: return
		var axis := (target-root).normalized()
		distance = clampf(distance, absf(length1-length2)+0.001, length1+length2-0.001)
		var along := (length1*length1-length2*length2+distance*distance)/(2*distance)
		var height := sqrt(maxf(0.0,length1*length1-along*along))
		# Keep elbows below and slightly outside the shoulders through animation blends.
		var outward := Vector3.RIGHT if side == "Right" else Vector3.LEFT
		var pole_world := cast._model.global_transform.basis.orthonormalized() * (Vector3.DOWN + outward * .35)
		var pole := skeleton.global_transform.basis.inverse() * pole_world
		var bend := pole-axis*pole.dot(axis)
		if bend.length_squared() < .000001: bend = axis.cross(Vector3.UP)
		var wanted_elbow := root+axis*along+bend.normalized()*height
		rotate_bone_to(upper, elbow-root, wanted_elbow-root)
		elbow = skeleton.get_bone_global_pose(lower).origin
		wrist = skeleton.get_bone_global_pose(hand).origin
		rotate_bone_to(lower,wrist-elbow,target-elbow)
	func orient_hand(side: String) -> void:
		var skeleton := cast._skeleton
		var hand := skeleton.find_bone(side+"Hand")
		var parent := skeleton.get_bone_parent(hand)
		# Hand longitudinal axis follows the tool; palm faces down onto handle.
		var finger_world := (weapon.global_transform.basis.x if side=="Left" else weapon.global_transform.basis.z).normalized()
		var palm_world := -weapon.global_transform.basis.y.normalized()
		var finger := (skeleton.global_transform.basis.inverse()*finger_world).normalized()
		var palm := (skeleton.global_transform.basis.inverse()*palm_world).normalized()
		var across := finger.cross(palm).normalized()
		var desired := Basis(across,finger,across.cross(finger)).orthonormalized()
		var local := skeleton.get_bone_global_pose(parent).basis.inverse()*desired
		skeleton.set_bone_pose_rotation(hand,local.orthonormalized().get_rotation_quaternion())
	func palm_offset(side := "Left") -> Vector3:
		# Rest-hand palm centre: 6 cm along fingers, 3.5 cm toward curled grip centre.
		var finger := (weapon.global_transform.basis.x if side=="Left" else weapon.global_transform.basis.z).normalized()
		return finger*.06-weapon.global_transform.basis.y.normalized()*(.039 if side=="Left" else .041)
	func clamp_grip(side: String, anchor: Vector3) -> void:
		var skeleton := cast._skeleton
		var upper := skeleton.find_bone(side+"Arm")
		var lower := skeleton.find_bone(side+"ForeArm")
		var hand := skeleton.find_bone(side+"Hand")
		var root := skeleton.to_global(skeleton.get_bone_global_pose(upper).origin)
		var elbow := skeleton.to_global(skeleton.get_bone_global_pose(lower).origin)
		var wrist := skeleton.to_global(skeleton.get_bone_global_pose(hand).origin)
		var reach := root.distance_to(elbow)+elbow.distance_to(wrist)-0.0015
		var target := weapon.to_global(anchor)-palm_offset(side)
		var offset := target-root
		if offset.length()>reach:
			weapon.global_position += root+offset.normalized()*reach-target
	func _process(_delta: float) -> void:
		var a := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(cast._hand_bones[0]).origin)
		var b := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(cast._hand_bones[1]).origin)
		ticks += 1
		if not reported or ticks == 29:
			print("GRIP_SPAN metres=", a.distance_to(b), " right=", a, " left=", b)
			reported = true
		var rear := Vector3(-0.47, 0.13, 0)
		var front := Vector3(-0.09, 0.31, 0)
		var axis := front - rear
		var span := b - a
		if span.length() < 0.01: return
		var source_x := axis.normalized()
		var source_z := source_x.cross(Vector3.UP).normalized()
		var target_x := span.normalized()
		var target_z := target_x.cross(Vector3.UP).normalized()
		var source_frame := Basis(source_x, source_z.cross(source_x), source_z)
		var target_frame := Basis(target_x, target_z.cross(target_x), target_z)
		var basis := (target_frame*source_frame.transposed()).scaled(Vector3.ONE*.65)
		if visual.pose_override == "powered/chainsaw_raise" or OS.get_environment("CHAINSAW_SUPPORT_IK") == "1":
			basis = (cast._model.global_transform.basis.orthonormalized()*Basis(Vector3.UP,-PI*.5)).scaled(Vector3.ONE*.65)
		weapon.global_transform = Transform3D(basis, a - basis * rear)
		if OS.get_environment("CHAINSAW_SUPPORT_IK") == "1": weapon.global_position += palm_offset("Right")
		if OS.get_environment("CHAINSAW_SUPPORT_IK") == "1" and visual.pose_override != "powered/chainsaw_raise":
			# Old blended wrist tracks may rise above the shoulders. Keep the tool
			# below chest height before solving both arms against its grips.
			var skeleton := cast._skeleton
			var shoulder := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("RightArm")).origin)
			var rear_height := weapon.to_global(rear).y
			weapon.global_position.y -= maxf(0.0,rear_height-(shoulder.y-.24))
			for iteration in 4:
				clamp_grip("Left", front)
				clamp_grip("Right", rear)
			fit_hand("Left",weapon.to_global(front)-palm_offset())
			fit_hand("Right",weapon.to_global(rear)-palm_offset("Right"))
			orient_hand("Left")
			orient_hand("Right")
		visual.weapon_sprite.modulate.a = 0
		if ticks == 29:
			print("SUPPORT_GAP metres=", b.distance_to(weapon.to_global(front)))

func _ready() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1200, 700)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var actors: Array = []
	for i in 1:
		var visual := CharacterVisual.new()
		stage.add_child(visual)
		visual.setup("cass")
		var cast := visual.cast_sprite as CastModel
		if OS.get_environment("CHAINSAW_GRIP_MESH") == "1":
			var donor: Node3D = load(OS.get_environment("CHAINSAW_HAND_MODEL") if not OS.get_environment("CHAINSAW_HAND_MODEL").is_empty() else "res://build/chainsaw_pose_candidate/cass_grip_mesh.glb").instantiate()
			var donor_skeleton: Skeleton3D = donor.find_children("*","Skeleton3D",true,false)[0]
			assert(donor_skeleton.get_bone_count()==cast._skeleton.get_bone_count())
			for bone in donor_skeleton.get_bone_count():
				assert(donor_skeleton.get_bone_name(bone)==cast._skeleton.get_bone_name(bone))
			var replaced := 0
			for mesh in cast._model.find_children("*","MeshInstance3D",true,false):
				for replacement in donor.find_children("*","MeshInstance3D",true,false):
					if mesh.name==replacement.name:
						mesh.mesh=replacement.mesh
						replaced += 1
			print("GRIP_MESH replacements=",replaced)
			assert(replaced > 0)
			donor.free()
		var library := load("res://build/chainsaw_pose_candidate/chainsaw_clips.res") as AnimationLibrary
		cast._player.add_animation_library("powered", library)
		for clip in library.get_animation_list(): cast.clips["powered/"+clip] = true
		visual.set_weapon(DB.weapon(&"chainsaw"))
		visual.idle_fidgets = false
		visual.position = Vector2(600,460)
		visual.scale = Vector2.ONE*18
		visual.set_aim(i*PI*.25)
		visual._face_angle = visual.aim_angle
		visual.pose_override = "powered/chainsaw_raise"
		visual.set_process(false)
		var attachment := GripAttachment.new()
		attachment.cast = cast
		attachment.visual = visual
		attachment.weapon = load("res://build/chainsaw_review/chainsaw.glb").instantiate()
		cast._model.add_child(attachment.weapon)
		add_child(attachment)
		attachment.set_process(false)
		actors.append([visual,attachment])
	var rows: Array = []
	var failures := 0
	for target in ["aim", "walk", "run", "sneak"]:
		for frame in 28:
			for actor in actors:
				var visual: CharacterVisual = actor[0]
				visual.pose_override = "powered/chainsaw_raise"
				visual.pose_progress = minf(float(frame)/27,.995)
				visual.cast_sprite._body_init = false
				visual._process_cast(0.0)
				actor[1]._process(0.0)
			await get_tree().process_frame
		var tips: Array = []
		for actor in actors:
			tips.append(actor[1].weapon.to_global(Vector3(.505,.08,0)))
			actor[0].pose_override = "powered/chainsaw_"+target
			actor[0].pose_progress = -1.0
		var maximum := 0.0
		var steady := 0.0
		var boundary_jump := 0.0
		var palm_angle := 0.0
		for frame in 40:
			for i in actors.size():
				var visual: CharacterVisual = actors[i][0]
				visual._process_cast(1.0/60.0)
				actors[i][1]._process(0.0)
				var cast := visual.cast_sprite as CastModel
				var left := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(cast._hand_bones[1]).origin)
				var front: Vector3 = actors[i][1].weapon.to_global(Vector3(-.09,.31,0))
				var right := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(cast._hand_bones[0]).origin)
				var rear: Vector3 = actors[i][1].weapon.to_global(Vector3(-.47,.13,0))
				var offset: Vector3 = actors[i][1].palm_offset()
				var gap := maxf((left+offset).distance_to(front),(right+actors[i][1].palm_offset("Right")).distance_to(rear))
				maximum = maxf(maximum,gap)
				for side in ["Left", "Right"]:
					var hand := cast._skeleton.find_bone(side+"Hand")
					var hand_basis := (cast._skeleton.global_transform.basis*cast._skeleton.get_bone_global_pose(hand).basis).orthonormalized()
					var palm_target: Vector3 = -actors[i][1].weapon.global_transform.basis.y.normalized()
					palm_angle = maxf(palm_angle,rad_to_deg(hand_basis.z.angle_to(palm_target)))
				if frame >= 20: steady = maxf(steady,gap)
				if frame == 0: boundary_jump = maxf(boundary_jump,tips[i].distance_to(actors[i][1].weapon.to_global(Vector3(.505,.08,0))))
			await get_tree().process_frame
			if target == "sneak" and frame in [0,4,8,12]:
				await RenderingServer.frame_post_draw
				stage.get_texture().get_image().save_png("res://build/chainsaw_grip_closeup/sneak_blend_%02d.png"%frame)
		if maximum > .015 or steady > .005 or boundary_jump > .05 or palm_angle > 1.0: failures += 1
		rows.append({"target":target,"max_palm_angle_deg":palm_angle,"max_blend_gap_m":maximum,"max_steady_gap_m":steady,"first_frame_tip_jump_m":boundary_jump})
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png("res://build/chainsaw_grip_closeup/raise_to_"+target+".png")
	var file := FileAccess.open("res://build/chainsaw_grip_closeup/transition_alignment.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"scope":"Raise-to-four-carry transitions, eight headings, 40real process frames each; both palm contact gap limits blend15mm/steady5mm, first-frame tip jump50mm","rows":rows},"  "))
	print("CHAINSAW TRANSITION REVIEW: ",failures," failures")
	Game.request_quit(1 if failures else 0)

