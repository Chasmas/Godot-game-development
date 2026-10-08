extends Node2D
class GripAttachment extends Node:
	var cast: CastModel
	var visual: CharacterVisual
	var weapon: Node3D
	var reported := false
	var ticks := 0
	func _process(_delta: float) -> void:
		var a := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(cast._hand_bones[0]).origin)
		var b := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(cast._hand_bones[1]).origin)
		ticks += 1
		if not reported or ticks == 29:
			print("GRIP_SPAN metres=", a.distance_to(b), " right=", a, " left=", b)
			reported = true
		var rear := Vector3(-0.47, 0.08, 0)
		var front := Vector3(-0.09, 0.31, 0)
		var axis := front - rear
		var span := b - a
		if span.length() < 0.01: return
		var source_x := axis.normalized()
		var source_z := source_x.cross(Vector3.UP).normalized()
		var source_frame := Basis(source_x, source_z.cross(source_x), source_z)
		var target_x := span.normalized()
		var target_z := target_x.cross(Vector3.UP).normalized()
		var target_frame := Basis(target_x, target_z.cross(target_x), target_z)
		var basis := (target_frame * source_frame.transposed()).scaled(Vector3.ONE * 0.65)
		weapon.global_transform = Transform3D(basis, a - basis * rear)
		visual.weapon_sprite.modulate.a = 0
		if ticks == 29:
			print("SUPPORT_GAP metres=", b.distance_to(weapon.to_global(front)))

func _ready() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1200, 1300)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var actors: Array = []
	var clips := ["powered/chainsaw_aim", "powered/chainsaw_walk", "powered/chainsaw_run", "powered/chainsaw_sneak"]
	for i in 32:
		var visual := CharacterVisual.new()
		stage.add_child(visual)
		visual.setup("cass")
		var model := visual.cast_sprite as CastModel
		var library := load("res://build/chainsaw_pose_candidate/chainsaw_clips.res") as AnimationLibrary
		model._player.add_animation_library("powered", library)
		for clip in library.get_animation_list(): model.clips["powered/" + clip] = true
		visual.set_weapon(DB.weapon(&"chainsaw"))
		visual.idle_fidgets = false
		visual.position = Vector2(75 + (i % 8) * 150, 230 + (i / 8) * 320)
		visual.scale = Vector2.ONE * 4.0
		visual.set_aim((i % 8) * PI * 0.25)
		visual.set_powered_cutting(true)
		visual.pose_override = clips[i / 8]
		visual._face_angle = (i % 8) * PI * 0.25
		var attachment := GripAttachment.new()
		attachment.cast = visual.cast_sprite as CastModel
		attachment.visual = visual
		attachment.weapon = load("res://build/chainsaw_review/chainsaw.glb").instantiate()
		var bounds := AABB()
		var first := true
		for mesh in attachment.weapon.find_children("*", "MeshInstance3D", true, false):
			var transformed: AABB = mesh.transform * mesh.get_aabb()
			bounds = transformed if first else bounds.merge(transformed)
			first = false
		print("WEAPON BOUNDS ", bounds, " root=", attachment.weapon.transform)
		attachment.cast._model.add_child(attachment.weapon)
		add_child(attachment)
		var label := Label.new()
		label.text = clips[i / 8] + " " + str((i % 8) * 45)
		label.position = Vector2(12 + (i % 8) * 150, 280 + (i / 8) * 320)
		stage.add_child(label)
		visual.set_process(false)
		attachment.set_process(false)
		actors.append([visual, attachment])
	var measurements: Array = []
	var failures := 0
	for actor in actors:
		var visual: CharacterVisual = actor[0]
		var cast := visual.cast_sprite as CastModel
		visual.pose_progress = -1.0
		measurements.append({"clip":visual.pose_override,"heading":rad_to_deg(visual.aim_angle),"max_steady_gap_m":0.0,"max_entry_gap_m":0.0,"duration_s":cast._player.get_animation(visual.pose_override).length})
	for frame in 540:
		for index in actors.size():
			var visual: CharacterVisual = actors[index][0]
			var cast := visual.cast_sprite as CastModel
			visual._process_cast(1.0 / 60.0)
			actors[index][1]._process(0.0)
			var left := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(cast._hand_bones[1]).origin)
			var front: Vector3 = actors[index][1].weapon.to_global(Vector3(-0.09, 0.31, 0))
			var key := "max_entry_gap_m" if frame < 20 else "max_steady_gap_m"
			measurements[index][key] = maxf(measurements[index][key], left.distance_to(front))
		await get_tree().process_frame
	for row in measurements:
		if row.max_steady_gap_m > 0.005: failures += 1
	for frame in 5: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png("res://build/chainsaw_pose_candidate/merged_continuous.png")
	var file := FileAccess.open("res://build/chainsaw_pose_candidate/continuous_alignment.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"scope":"Original Cass with added powered AnimationLibrary, 540 real process frames, animation advanced at 60Hz through at least two loops per clip. Entry gaps recorded separately; no input or physical locomotion.","rows":measurements}, "  "))
	print("CHAINSAW CONTINUOUS REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
