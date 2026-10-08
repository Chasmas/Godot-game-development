extends Node

func _ready() -> void:
	var requested := OS.get_environment("CANINE_REVIEW_CLIP")
	var clip := requested if requested in ["idle", "walk", "trot"] else "trot"
	var stage := SubViewport.new()
	stage.size = Vector2i(1024, 400)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var background := ColorRect.new()
	background.color = Color("191622")
	background.size = Vector2(stage.size)
	stage.add_child(background)
	var players: Array[AnimationPlayer] = []
	for index in 4:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var err := document.append_from_file("res://build/canine_review/shepherd/shepherd_%s_candidate.glb" % clip, state)
		if err != OK:
			push_error("Canine GLB import failed: " + str(err))
			get_tree().quit(1)
			return
		var model := document.generate_scene(state)
		var view := SubViewport.new()
		view.size = Vector2i(128, 128)
		view.transparent_bg = true
		view.own_world_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		stage.add_child(view)
		view.add_child(model)
		model.position.y = 0.6912
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 2.56
		view.add_child(camera)
		camera.position = Vector3(2, 2.9, 2)
		camera.look_at(Vector3(0, 0.6, 0))
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-55, -35, 0)
		light.light_energy = 1.4
		view.add_child(light)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color(0.5, 0.5, 0.6)
		environment.environment.ambient_light_energy = 0.6
		view.add_child(environment)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var name: StringName = Array(player.get_animation_list()).filter(func(n): return n != "RESET")[0]
		player.play(name)
		players.append(player)
		if index == 0:
			var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			player.seek(0.0, true)
			player.advance(0.000001)
			var beginning: Array[Transform3D] = []
			for bone in skeleton.get_bone_count():
				beginning.append(skeleton.get_bone_pose(bone))
			player.seek(player.get_animation(name).length, true)
			player.advance(0.0)
			for bone in skeleton.get_bone_count():
				var finish := skeleton.get_bone_pose(bone)
				if beginning[bone].origin.distance_to(finish.origin) > 0.001 or beginning[bone].basis.get_rotation_quaternion().angle_to(finish.basis.get_rotation_quaternion()) > 0.002:
					push_error("Canine " + clip + " loop seam: " + skeleton.get_bone_name(bone))
					get_tree().quit(1)
					return
			print("CANINE ", clip.to_upper(), " SEAM: all bone poses match")
		player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
		player.play(name)
		player.seek(float(index) / 4.0 * player.get_animation(name).length, true)
		player.advance(0.00001)
		var image := TextureRect.new()
		image.texture = view.get_texture()
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.position = Vector2(index * 256, 0)
		image.size = Vector2(256, 256)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stage.add_child(image)
		var native := TextureRect.new()
		native.texture = view.get_texture()
		native.position = Vector2(index * 256 + 64, 250)
		native.size = Vector2(128, 128)
		stage.add_child(native)
	for frame in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := stage.get_texture().get_image().save_png("res://build/canine_review/shepherd/godot_%s_review.png" % clip)
	if OS.get_environment("CANINE_CAPTURE_MOTION") == "1":
		DirAccess.make_dir_recursive_absolute("res://build/canine_review/shepherd/motion_" + clip)
		for frame in 24:
			for index in players.size():
				var duration := players[index].get_animation(players[index].assigned_animation).length
				players[index].seek(fposmod(float(frame) / 24.0 + float(index) / 4.0, 1.0) * duration, true)
				players[index].advance(0.000001)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var saved := stage.get_texture().get_image().save_png("res://build/canine_review/shepherd/motion_%s/%02d.png" % [clip, frame])
			if saved != OK:
				get_tree().quit(saved)
				return
		print("CANINE MOTION CAPTURE: 24 frames")
	print("CANINE GODOT REVIEW: ", result)
	stage.queue_free()
	await get_tree().process_frame
	get_tree().quit(result)
