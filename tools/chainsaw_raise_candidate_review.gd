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
		if visual.pose_override == "powered/chainsaw_raise":
			basis = (cast._model.global_transform.basis.orthonormalized() * Basis(Vector3.UP, -PI * 0.5)).scaled(Vector3.ONE * 0.65)
		weapon.global_transform = Transform3D(basis, a - basis * rear)
		visual.weapon_sprite.modulate.a = 0
		if ticks == 29:
			print("SUPPORT_GAP metres=", b.distance_to(weapon.to_global(front)))

func _ready() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1200, 700)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var actors: Array = []
	for i in 8:
		var visual := CharacterVisual.new()
		stage.add_child(visual)
		visual.setup("cass")
		var cast := visual.cast_sprite as CastModel
		var library := load("res://build/chainsaw_pose_candidate/chainsaw_clips.res") as AnimationLibrary
		cast._player.add_animation_library("powered", library)
		for clip in library.get_animation_list(): cast.clips["powered/"+clip] = true
		visual.set_weapon(DB.weapon(&"chainsaw"))
		visual.idle_fidgets = false
		visual.position = Vector2(150 + (i%4)*300, 230+(i/4)*320)
		visual.scale = Vector2.ONE*6
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
	for frame in 28:
		for i in actors.size():
			var visual: CharacterVisual = actors[i][0]
			visual.pose_progress = minf(float(frame)/27, .995)
			visual.cast_sprite._body_init = false
			visual._process_cast(0.0)
			actors[i][1]._process(0.0)
			var cast := visual.cast_sprite as CastModel
			var left := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(cast._hand_bones[1]).origin)
			rows.append({"heading":i*45,"frame":frame,"progress":visual.pose_progress,"gap_m":left.distance_to(actors[i][1].weapon.to_global(Vector3(-.09,.31,0)))})
		await get_tree().process_frame
		if frame in [0,9,18,27]:
			await RenderingServer.frame_post_draw
			stage.get_texture().get_image().save_png("res://build/chainsaw_pose_candidate/raise_%02d.png"%frame)
	var file := FileAccess.open("res://build/chainsaw_pose_candidate/raise_alignment.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Authored raise on original Cass, eight headings, 28 driven frames; initial separation expected while left reaches front handle","rows":rows},"  "))
	print("CHAINSAW RAISE REVIEW: ",rows.size()," samples")
	Game.request_quit()
