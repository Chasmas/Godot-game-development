extends SceneTree

func _initialize() -> void:
	call_deferred("_probe")

func _probe() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(args[0], state)
	if error != OK:
		push_error("GLB import failed: %s" % error)
		quit(3)
		return
	var scene := document.generate_scene(state)
	root.add_child(scene)
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	var skeletons := scene.find_children("*", "Skeleton3D", true, false)
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	if players.size() != 1 or skeletons.size() != 1 or meshes.is_empty():
		quit(4)
		return
	var player: AnimationPlayer = players[0]
	var clips: Array = []
	for clip_name in player.get_animation_list():
		if clip_name == "RESET":
			continue
		var clip := player.get_animation(clip_name)
		player.play(clip_name)
		for time in [0.0, 0.6, 1.2, 1.8, 2.4]:
			player.seek(time, true)
		clips.append({"name": clip_name, "length": clip.length, "tracks": clip.get_track_count()})
	var report := {"runtime_approved": false, "scope": "Headless GLTF import and animation seek; visual playback and skin deformation not validated", "clips": clips, "bones": skeletons[0].get_bone_count(), "meshes": meshes.size(), "blend_shapes": meshes[0].mesh.get_blend_shape_count()}
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(0 if clips.size() == 1 and report.blend_shapes == 1 else 5)
