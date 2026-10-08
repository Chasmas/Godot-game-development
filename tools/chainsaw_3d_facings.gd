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
		var basis := cast._model.global_transform.basis.orthonormalized() * Basis(Vector3.UP, -PI * 0.5)
		basis = basis.scaled(Vector3.ONE * 0.65)
		weapon.global_transform = Transform3D(basis, a - basis * rear)
		visual.weapon_sprite.modulate.a = 0
		if ticks == 29:
			print("SUPPORT_GAP metres=", b.distance_to(weapon.to_global(front)))

func _ready() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1200, 700)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	for i in 8:
		var visual := CharacterVisual.new()
		stage.add_child(visual)
		visual.setup("cass")
		if OS.get_environment("CHAINSAW_POSE_MODEL") != "":
			visual.cast_sprite.free()
			var model := CastModel.new()
			assert(model.configure("cass", OS.get_environment("CHAINSAW_POSE_MODEL")))
			visual.cast_sprite = model
			visual.rig.add_child(model)
		visual.set_weapon(DB.weapon(&"chainsaw"))
		visual.idle_fidgets = false
		visual.position = Vector2(150 + (i % 4) * 300, 230 + (i / 4) * 320)
		visual.scale = Vector2.ONE * 6.0
		visual.set_aim(i * PI * 0.25)
		visual.set_powered_cutting(true)
		visual.pose_override = "aim"
		visual._face_angle = i * PI * 0.25
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
		label.text = str(i * 45) + " degrees"
		label.position = Vector2(110 + (i % 4) * 300, 280 + (i / 4) * 320)
		stage.add_child(label)
	for i in 30: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(OS.get_environment("CHAINSAW_POSE_IMAGE") if OS.get_environment("CHAINSAW_POSE_IMAGE") != "" else "res://build/chainsaw_3d_facings.png")
	Audio.shutdown()
	get_tree().quit()
