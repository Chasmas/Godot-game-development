extends Node
var _candidate: CharacterVisual
var _palm_shifts := [0.0, 0.0]
var _wrist_forward_dots := [0.0, 0.0]
var _native_guns: Array[Node3D] = []
var _review_clip := "aim_dual"
var _review_phase := -1.0
var _pistol_path := "res://build/held_pistol_candidate/pistol.glb"
func _weapon_clip(value: String) -> bool:
	return value in ["aim_dual", "armed_dual_walk", "armed_dual_run", "reload_dual"]
func _process(_delta: float) -> void:
	if _candidate == null or OS.get_environment("GUARD_DUAL_PALM") != "1":
		return
	var cast := _candidate.cast_sprite as CastModel
	if _review_phase >= 0.0:
		cast.play_sample(_review_clip, 0.0, _review_phase)
	if OS.get_environment("GUARD_DUAL_PRODUCTION_RENDERER") == "1":
		_candidate._update_native_pistols()
	for node in cast._model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var shape := mesh.find_blend_shape_by_name("WeaponGrip")
		if shape >= 0:
			mesh.set_blend_shape_value(shape, 1.0 if _weapon_clip(cast.clip) else 0.0)
	for side in 2:
		var bone: int = cast._hand_bones[side]
		var hand := cast._skeleton.global_transform * cast._skeleton.get_bone_global_pose(bone)
		# Review the actual palm centre, nine centimetres beyond the wrist.
		var offset := Vector3(0, 0.09, 0)
		if OS.get_environment("GUARD_DUAL_SIDE_PISTOL") == "1":
			offset = Vector3(0, 0.08, 0.04)
		var palm := hand.origin + hand.basis.orthonormalized() * offset
		var forward := hand.origin + hand.basis.orthonormalized().y * 0.05
		var direction := (cast._camera.unproject_position(forward) - cast._camera.unproject_position(hand.origin)).normalized()
		_wrist_forward_dots[side] = direction.dot(Vector2.RIGHT.rotated(cast._facing_angle))
		var point := ((cast._camera.unproject_position(palm) - cast._origin) * cast.world_scale).rotated(-cast._facing_angle)
		var sprite := _candidate.weapon_sprite if side == 0 else _candidate.weapon_sprite2
		if not _native_guns.is_empty() and OS.get_environment("GUARD_DUAL_PRODUCTION_RENDERER") != "1":
			var axes := hand.basis.orthonormalized()
			# glTF converts Blender Z-up to local Y-up. Apply that conversion
			# before mapping the contact-fit frame into Godot hand axes.
			var basis := Basis(axes.y, -axes.x, axes.z) if side == 0 else Basis(axes.y, axes.x, -axes.z)
			if OS.get_environment("GUARD_DUAL_NATURAL_WRIST") == "1":
				basis = Basis(axes.y, axes.x, -axes.z) if side == 0 else Basis(axes.y, -axes.x, axes.z)
			var depth := -0.039 if OS.get_environment("GUARD_DUAL_ROTATED_GRASP") == "1" else 0.039
			_native_guns[side].global_transform = Transform3D(basis, hand.origin + axes.y * 0.06 + axes.z * depth)
			_native_guns[side].visible = _weapon_clip(cast.clip)
			# Visibility is also used by CharacterVisual to select armed clips.
			# Suppress drawing only while the native weapon is visible.
			sprite.self_modulate.a = 0.0 if _weapon_clip(cast.clip) else 1.0
		_palm_shifts[side] = point.distance_to(cast.grip(side == 1))
		sprite.position = point

func _ready() -> void:
	if not OS.get_environment("GUARD_DUAL_PISTOL_PATH").is_empty():
		_pistol_path = OS.get_environment("GUARD_DUAL_PISTOL_PATH")
	process_priority = 100
	if OS.get_environment("GUARD_DUAL_CLIP") != "":
		_review_clip = OS.get_environment("GUARD_DUAL_CLIP")
	if OS.get_environment("GUARD_DUAL_PHASE") != "":
		_review_phase = clampf(float(OS.get_environment("GUARD_DUAL_PHASE")), 0.0, 1.0)
	var stage:=SubViewport.new()
	stage.size=Vector2i(1200,600)
	stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var background:=ColorRect.new()
	background.color=Color("191622")
	background.size=Vector2(stage.size)
	stage.add_child(background)
	for index in 2:
		var visual:=CharacterVisual.new()
		stage.add_child(visual)
		visual.position=Vector2(300+600*index,450)
		visual.scale=Vector2.ONE*10
		visual.setup("guard")
		if index==1:
			visual.cast_sprite.free()
			var cast:=CastModel.new()
			var path := OS.get_environment("GUARD_DUAL_CANDIDATE")
			if path=="":path="res://build/guard_drink_only_combined/guard.glb"
			if not cast.configure("guard",path):
				get_tree().quit(1)
				return
			visual.cast_sprite=cast
			visual.rig.add_child(cast)
			_candidate = visual
			if OS.get_environment("GUARD_DUAL_PRODUCTION_RENDERER") == "1":
				if not visual.attach_native_dual_pistols(_pistol_path):
					get_tree().quit(1)
					return
				_native_guns = cast._held_pistols
			elif OS.get_environment("GUARD_DUAL_NATIVE_PISTOL") == "1":
				for side in 2:
					var document := GLTFDocument.new()
					var state := GLTFState.new()
					if document.append_from_file(_pistol_path, state) != OK:
						get_tree().quit(1)
						return
					var gun := document.generate_scene(state) as Node3D
					cast._viewport.add_child(gun)
					_native_guns.append(gun)
		visual.idle_fidgets=false
		visual.set_weapon(DB.weapon(&"pistol"),true)
		visual.pose_override = _review_clip
		if index == 1 and OS.get_environment("GUARD_DUAL_SIDE_PISTOL") == "1":
			for sprite in [visual.weapon_sprite, visual.weapon_sprite2]:
				sprite.texture = SpriteLib.weapon_side("pistol")
				sprite.flip_v = false
				sprite.offset = Vector2(-8, -13)
				sprite.scale *= 0.55
		visual.set_aim(deg_to_rad(float(OS.get_environment("GUARD_DUAL_ANGLE"))))
		if OS.get_environment("GUARD_DUAL_SETTLED_START") == "1":
			visual._face_angle = visual.aim_angle
			var cast := visual.cast_sprite as CastModel
			cast._body_angle = visual.aim_angle
			cast._body_init = true
		var label:=Label.new()
		label.text="Current runtime guard" if index==0 else "Dual-pistol pose candidate"
		label.position=Vector2(80+600*index,540)
		stage.add_child(label)
	for frame in 30:await get_tree().process_frame
	if OS.get_environment("GUARD_DUAL_PALM") == "1":
		for shift in _palm_shifts:
			if shift < 0.1:
				push_error("Palm review failed to move weapon beyond wrist")
				get_tree().quit(1)
				return
		print("Palm socket shifts in game pixels: ", _palm_shifts)
		print("Wrist forward vs weapon screen direction: ", _wrist_forward_dots)
		var debug_cast := _candidate.cast_sprite as CastModel
		print("MODEL angle=", debug_cast._body_angle, " rotation=", debug_cast._model.rotation, " camera_basis=", debug_cast._camera.global_basis)
		for bone_index in debug_cast._hand_bones:
			var transform := debug_cast._skeleton.global_transform * debug_cast._skeleton.get_bone_global_pose(bone_index)
			print("HAND forward world=", transform.basis.orthonormalized().y)
		for side in _native_guns.size():
			var gun := _native_guns[side]
			var grip := gun.find_child("Polymer grip", true, false) as Node3D
			var slide := gun.find_child("Slide", true, false) as Node3D
			var hand := debug_cast._skeleton.global_transform * debug_cast._skeleton.get_bone_global_pose(debug_cast._hand_bones[side])
			if grip and slide:
				var inverse := hand.basis.orthonormalized().inverse()
				print("GUN_HAND_FRAME side=", side, " grip=", inverse * (grip.global_position-hand.origin), " slide=", inverse * (slide.global_position-hand.origin))
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png("res://build/guard_dual_asset_comparison"+OS.get_environment("GUARD_DUAL_SUFFIX")+".png")
	if not _native_guns.is_empty() and OS.get_environment("GUARD_DUAL_NATIVE_CLOSEUP") == "1":
		var cast := _candidate.cast_sprite as CastModel
		var side := clampi(int(OS.get_environment("GUARD_DUAL_CLOSEUP_SIDE")), 0, 1)
		var target := _native_guns[side].global_position
		var camera_direction := cast._camera.global_basis.z
		cast._viewport.size = Vector2i(768, 768)
		cast._camera.size = 0.3
		cast._camera.look_at_from_position(target + camera_direction * 30.0, target)
		for frame in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		cast._viewport.get_texture().get_image().save_png("res://build/guard_native_pistol_closeup"+OS.get_environment("GUARD_DUAL_SUFFIX")+".png")
	if OS.get_environment("GUARD_DUAL_PALM") == "1":
		var checked := 0
		_review_phase = -1.0
		for action in ["smoke", "drink", "aim_dual", "armed_dual_walk", "armed_dual_run", "reload_dual"]:
			_candidate.pose_override = action
			for frame in 15: await get_tree().process_frame
			var cast := _candidate.cast_sprite as CastModel
			for gun in _native_guns:
				if gun.visible != _weapon_clip(action) or absf(gun.global_basis.determinant() - 1.0) > 0.001:
					push_error("Native pistol lifecycle/basis failed during " + action)
					get_tree().quit(1)
					return
			for node in cast._model.find_children("*", "MeshInstance3D", true, false):
				var mesh := node as MeshInstance3D
				var shape := mesh.find_blend_shape_by_name("WeaponGrip")
				if shape >= 0:
					checked += 1
					var expected := 1.0 if _weapon_clip(action) else 0.0
					if not is_equal_approx(mesh.get_blend_shape_value(shape), expected):
						push_error("Weapon grasp persisted in wrong activity: " + action)
						get_tree().quit(1)
						return
		print("WeaponGrip transition checks: ", checked)
		if OS.get_environment("GUARD_DUAL_PRODUCTION_RENDERER") == "1":
			for left in [false, true]:
				var cast := _candidate.cast_sprite as CastModel
				var points := cast.native_pistol_points(left)
				assert(points.size() == 2)
				assert(_candidate.muzzle_tip_global(left).distance_to(_candidate.rig.to_global(points[0])) < 0.001)
				assert(_candidate.muzzle_global(left).distance_to(_candidate.rig.to_global(points[1])) < 0.001)
			_candidate.set_weapon(DB.weapon(&"pistol"), false)
			var native_cast := _candidate.cast_sprite as CastModel
			for gun in _native_guns: assert(not gun.visible)
			assert(native_cast.native_pistol_points().is_empty())
			assert(is_equal_approx(_candidate.weapon_sprite.self_modulate.a, 1.0))
			_candidate.set_weapon(DB.weapon(&"pistol"), true)
			for gun in _native_guns: assert(gun.visible)
			if not native_cast._magazine_parts[0].is_empty():
				_candidate.pose_override = "reload_dual"
				_candidate.pose_progress = 0.25
				for frame in 3: await get_tree().process_frame
				for pair in native_cast._magazine_parts[0]:
					assert(pair[0].position.distance_to(pair[1]) > 0.1)
				_candidate.pose_override = "aim_dual"
				_candidate.pose_progress = 0.0
				for frame in 3: await get_tree().process_frame
				for parts in native_cast._magazine_parts:
					for pair in parts: assert(pair[0].position.distance_to(pair[1]) < 0.001)
				print("Native magazine extraction/reset checks passed")
			_candidate.set_weapon(null)
			for gun in _native_guns: assert(not gun.visible)
			assert(native_cast.native_pistol_points().is_empty())
			for frame in 3: await get_tree().process_frame
			for gun in _native_guns: assert(not gun.visible)
			assert(is_equal_approx(_candidate.weapon_sprite.self_modulate.a, 1.0))
			print("Native renderer muzzle/drop checks passed")
	stage.queue_free()
	await get_tree().process_frame
	get_tree().quit()
