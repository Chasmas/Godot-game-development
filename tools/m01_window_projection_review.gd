extends Node

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/staging/window_strip_family_v1/"

func _frame(contract: Dictionary, window: GlassWindow) -> Dictionary:
	var orientation := "horizontal" if window.size.x >= window.size.y else "vertical"
	var span := roundi(window.size.x if orientation == "horizontal" else window.size.y)
	for candidate in contract.frames:
		if str(candidate.orientation) == orientation and int(candidate.span_px) == span:
			return candidate
	return {}

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var saved_path := SaveManager.save_path
	SaveManager.save_path = "user://m01_window_projection_review_save.json"
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.replay_mission("m01_checkout")
	for frame in 120:
		await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	assert(level != null)
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "contract.json"))
	assert(not bool(contract.get("runtime_approved", false)))
	var rows: Array = []
	var candidates: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("glass"):
		if not node is GlassWindow or not level.is_ancestor_of(node):
			continue
		var window := node as GlassWindow
		var frame := _frame(contract, window)
		assert(not frame.is_empty(), "Every live M01 window needs a matching staging span")
		var sprite := Sprite2D.new()
		sprite.name = "ReviewWindowFrame"
		sprite.texture = load(DIRECTORY + str(frame.file)) as Texture2D
		assert(sprite.texture != null)
		sprite.centered = false
		sprite.offset = -Vector2(frame.floor_anchor_px[0], frame.floor_anchor_px[1])
		sprite.scale = Vector2.ONE * 16.0 / float(frame.pixels_per_metre)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.light_mask = window.light_mask
		window.add_child(sprite)
		window.set_meta("review_window_visual_override", true)
		window.queue_redraw()
		candidates.append({"window":window,"sprite":sprite})
		rows.append({"position":[window.global_position.x,window.global_position.y],"span_px":frame.span_px,
			"orientation":frame.orientation,"texture":frame.file,"uniform_scale":sprite.scale.x})
	assert(rows.size() == 20)
	# Destroy one actual window: the review sprite must be hidden and the
	# production damaged frame/collision must take over again.
	var selected: Dictionary = candidates[0]
	var selected_window := selected.window as GlassWindow
	var selected_sprite := selected.sprite as Sprite2D
	selected_window.shatter(Vector2.DOWN)
	selected_sprite.hide()
	selected_window.remove_meta("review_window_visual_override")
	selected_window.queue_redraw()
	assert(selected_window.broken and selected_window.collision_layer == Layers.LOW)
	assert(not selected_sprite.visible)
	if DisplayServer.get_name().to_lower() != "headless":
		# Capture the largest live span rather than the mission spawn, and keep
		# transient mission UI out of this environment-placement review.
		var capture_window: GlassWindow = null
		for entry in candidates:
			var candidate_window := entry.window as GlassWindow
			if capture_window == null or candidate_window.size.x > capture_window.size.x:
				capture_window = candidate_window
		assert(capture_window != null)
		level.hud.hide()
		level.camera.target = null
		level.camera.set_process(false)
		level.camera.global_position = capture_window.global_position
		level.camera.zoom = Vector2(3.0, 3.0)
		for child in level.get_children():
			if child is IntroCall or child is LevelIntro:
				child.hide()
		for frame in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_window_projection_review.png")
	var report := FileAccess.open("user://m01_window_projection_review.json", FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify({"passed":true,"runtime_approved":false,"windows":rows,
		"broken_state_handoff":true,"scope":"Review-only span-aware window sprites on every live M01 GlassWindow; original collision and damaged drawing remain authoritative."}, "  "))
	report.close()
	SaveManager.data = saved
	SaveManager.save_path = saved_path
	print("M01 WINDOW PROJECTION: 20 review-only span-aware frames; damaged-state handoff verified")
	Game.request_quit(0)
