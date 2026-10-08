extends Node
## Renders a rigged Meshy character (anim_<name>.glb) as directional sprite frames
## seen from a fixed oblique camera, so the figure never has to be rotated in game.
## Each direction is the model turned on the spot; the camera, scale and light stay
## fixed, so every character rendered here shares one look.
##
## Non-headless (needs the GPU):
##   CAST3D_ID=guard godot --path . res://tools/art/render_cast_oblique.tscn --display-driver windows --audio-driver Dummy
## Optional: CAST3D_ONLY=idle,aim  CAST3D_DIRS=16  CAST3D_ELEV=50
## Writes raw frames + raw_meta.json to C:/tmp_shots/oblique_render/<id>/ for
## tools/art/pack_cast_oblique.py.

const SRC := "res://assets/art/Artwork/3d/%s/"
const OUT := "C:/tmp_shots/oblique_render/%s/"
const RENDER_PX := 256       ## packed at half this: 2x supersampling
const METERS := 2.56         ## frame height in metres (vertical ortho size)
const FPS := 12.0

var viewport: SubViewport
var camera: Camera3D
var pivot: Node3D

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var id := OS.get_environment("CAST3D_ID")
	if id.is_empty():
		id = "guard"
	var dirs := int(OS.get_environment("CAST3D_DIRS")) if OS.get_environment("CAST3D_DIRS") != "" else 16
	var elev := deg_to_rad(float(OS.get_environment("CAST3D_ELEV")) if OS.get_environment("CAST3D_ELEV") != "" else 50.0)
	var only := OS.get_environment("CAST3D_ONLY").split(",", false)
	_build_stage(elev)
	var out := OUT % id
	DirAccess.make_dir_recursive_absolute(out)
	var meta := {"render_px": RENDER_PX, "meters": METERS, "fps": FPS, "directions": dirs,
		"elevation": rad_to_deg(elev), "anims": {}}
	var origin := camera.unproject_position(Vector3.ZERO)
	meta["origin"] = [origin.x, origin.y]
	var src := ProjectSettings.globalize_path(SRC % id)
	for file in DirAccess.get_files_at(src):
		if not (file.begins_with("anim_") and file.ends_with(".glb")):
			continue
		var anim_name := file.trim_prefix("anim_").trim_suffix(".glb")
		if not only.is_empty() and not anim_name in only:
			continue
		meta.anims[anim_name] = await _render_anim(src + file, anim_name, out, dirs, origin)
		print("rendered ", anim_name, " frames=", meta.anims[anim_name].frames)
	var f := FileAccess.open(out + "raw_meta.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, " "))
	f.close()
	print("render_cast_oblique done: ", out)
	get_tree().quit()

func _build_stage(elev: float) -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(RENDER_PX, RENDER_PX)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.78, 0.8, 0.9)
	env.environment.ambient_light_energy = 0.75
	viewport.add_child(env)
	# key light from the upper left of the screen, like the painted props
	var key := DirectionalLight3D.new()
	key.light_energy = 1.15
	viewport.add_child(key)
	key.look_at_from_position(Vector3(-2, 4, 1.5), Vector3.ZERO)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.35
	fill.light_color = Color(0.55, 0.65, 1.0)
	viewport.add_child(fill)
	fill.look_at_from_position(Vector3(2, 1, -2), Vector3.ZERO)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = METERS
	camera.near = 0.1
	camera.far = 100.0
	viewport.add_child(camera)
	# screen down is world +Z (toward the camera), screen right is world +X
	var target := Vector3(0, 0.82, 0)
	camera.look_at_from_position(target + Vector3(0, sin(elev), cos(elev)) * 30.0, target)
	pivot = Node3D.new()
	viewport.add_child(pivot)

func _render_anim(path: String, anim_name: String, out: String, dirs: int, origin: Vector2) -> Dictionary:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		push_error("cannot read " + path)
		return {}
	var model: Node3D = doc.generate_scene(state)
	pivot.add_child(model)
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var clip := ""
	for n in player.get_animation_list():
		if n != "RESET":
			clip = n
	var anim := player.get_animation(clip)
	var hips := _bone(skel, ["Hips", "mixamorig:Hips", "pelvis"])
	var hand_r := _bone(skel, ["RightHand", "mixamorig:RightHand", "hand_r"])
	var hand_l := _bone(skel, ["LeftHand", "mixamorig:LeftHand", "hand_l"])
	var frames := maxi(1, int(round(anim.length * FPS)))
	var hands := []
	DirAccess.make_dir_recursive_absolute(out + anim_name)
	player.play(clip)
	player.pause()
	for d in dirs:
		var theta := TAU * float(d) / float(dirs)   # game angle: 0 right, PI/2 down
		var row := []
		for i in frames:
			player.seek(float(i) / FPS, true)
			# follow the hips so travelling moves stay centred on the ground point
			model.position = Vector3.ZERO
			pivot.rotation = Vector3.ZERO
			var hp := model.to_local(skel.to_global(skel.get_bone_global_pose(hips).origin))
			model.position = Vector3(-hp.x, 0, -hp.z)
			pivot.rotation.y = PI * 0.5 - theta
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png("%s%s/d%02d_f%03d.png" % [out, anim_name, d, i])
			var pr := camera.unproject_position(skel.to_global(skel.get_bone_global_pose(hand_r).origin)) - origin
			var pl := camera.unproject_position(skel.to_global(skel.get_bone_global_pose(hand_l).origin)) - origin
			row.append([[pr.x, pr.y], [pl.x, pl.y]])
		hands.append(row)
	model.queue_free()
	await get_tree().process_frame
	return {"frames": frames, "fps": FPS, "hands": hands, "length": anim.length}

func _bone(skel: Skeleton3D, names: Array) -> int:
	for n in names:
		var i := skel.find_bone(n)
		if i >= 0:
			return i
	for i in skel.get_bone_count():
		for n in names:
			if skel.get_bone_name(i).to_lower().ends_with(str(n).to_lower()):
				return i
	push_error("bone not found: %s in %s" % [names, skel.get_concatenated_bone_names()])
	return 0
