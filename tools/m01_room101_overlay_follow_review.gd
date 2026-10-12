extends Node

## Staging-only proof that the approved Room 101 3D candidate can follow the
## real M01 Camera2D coordinate system. It does not register a runtime option,
## alter the level scene or replace the production 2D room.

const ROOM_ORIGIN := Vector2(176, 432)
const CANDIDATE := "res://assets/art/prerendered/m01_sunset_palms/staging/room_101_shared_3d_v21/room.glb"

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	await get_tree().process_frame
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.attempts = 2
	Game.replay_mission("m01_checkout")
	var level: Level
	for frame in 120:
		await get_tree().process_frame
		level = get_tree().get_first_node_in_group("level") as Level
		if level != null and is_instance_valid(level.player): break
	assert(level != null and is_instance_valid(level.player))
	Dialogue._end(false)
	get_tree().paused = false
	level.set_process(false)
	level.player.set_physics_process(false)
	for enemy in level.enemies: enemy.set_physics_process(false)
	level.camera.set_process(false)
	level.camera.set_physics_process(false)
	level.camera.zoom = Vector2(3, 3)
	level.camera.reset_smoothing()

	# Hide the 2D scene only for this isolated review. The overlay itself is a
	# CanvasLayer, so it remains visible and receives the actual follow camera.
	level.hide()
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false): layer.hide()
	var overlay := Visual3DOverlay.new()
	overlay.name = "Room101OverlayFollowReview"
	get_tree().root.add_child(overlay)
	overlay.setup(level, level.camera, level.data)
	# The shared overlay builds exterior showcase props too. They are unrelated
	# to this isolated room-follow proof and would contaminate the capture.
	overlay.props.hide()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(CANDIDATE, state) == OK)
	var room := document.generate_scene(state) as Node3D
	room.name = "Room101CandidateV21"
	room.position = Vector3(ROOM_ORIGIN.x / 16.0, 0.0, ROOM_ORIGIN.y / 16.0)
	overlay.world.add_child(room)
	preload("res://scripts/player/cast_gltf_materials.gd").prepare(room, BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC)
	assert(preload("res://tools/m01_room_101_cutaway.gd").apply(room) > 0)
	for light in room.find_children("*", "Light3D", true, false):
		light.light_energy = .6
		if light is OmniLight3D: light.omni_range = 3.0
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-60, -20, 0)
	fill.light_energy = .7
	overlay.world.add_child(fill)
	var actor := (load("res://assets/art/cast3d_rt/cass/cass.glb") as PackedScene).instantiate() as Node3D
	overlay.world.add_child(actor)
	(actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer).play("idle")

	var samples: Array = []
	for point in [Vector2(232, 472), Vector2(248, 464), Vector2(184, 480)]:
		level.player.global_position = point
		level.camera.global_position = point
		actor.position = Vector3(point.x / 16.0, 0.0, point.y / 16.0)
		for frame in 8: await get_tree().process_frame
		var screen := overlay.camera.unproject_position(actor.global_position)
		var origin := overlay.camera.project_ray_origin(screen)
		var ray := overlay.camera.project_ray_normal(screen)
		var floor := origin + ray * (-origin.y / ray.y)
		var reconstructed := Vector2(floor.x, floor.z) * 16.0
		assert(reconstructed.distance_to(point) < .02, "Overlay camera must map back to the live M01 floor")
		await RenderingServer.frame_post_draw
		var capture := "res://build/m01_room101_overlay_follow_%d_%d.png" % [int(point.x), int(point.y)]
		get_viewport().get_texture().get_image().save_png(capture)
		samples.append({"point": [point.x, point.y], "roundtrip_error_px": reconstructed.distance_to(point), "capture": capture})
	var report := FileAccess.open("res://build/m01_room101_overlay_follow.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"runtime_promoted": false, "scope": "Actual Camera2D to staging 3D Room 101 overlay follow proof; no production option or compositing approval", "samples": samples}, "\t"))
	print("M01 ROOM101 OVERLAY FOLLOW REVIEW PASSED")
	Game.request_quit(0)
