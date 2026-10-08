extends Node
const Candidate = preload("res://tools/measured_melee_trail_candidate.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("191622")
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var visuals := []
	var trails := []
	var setup_times := []
	var update_times := []
	for index in 16:
		var visual := CharacterVisual.new()
		viewport.add_child(visual)
		visual.position = Vector2(160 + (index % 4) * 320, 155 + (index / 4) * 210)
		visual.scale = Vector2.ONE * 3.0
		visual.setup("cass")
		visual.set_process(false)
		visual.set_weapon(DB.weapon(&"bat"))
		visual.set_aim((index + 0.5) * TAU / 16.0)
		visual.swing(false, false)
		visuals.append(visual)
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var baseline := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	for visual in visuals:
		var trail := Candidate.new()
		viewport.add_child(trail)
		var start := Time.get_ticks_usec()
		trail.configure(visual)
		setup_times.append((Time.get_ticks_usec() - start) / 1000.0)
		trail.set_process(false)
		trails.append(trail)
		check(trail.frames.size() == 65 and trail.frame_offsets.size() == 65, "complete packed direction")
		for pose in 65:
			var texture := trail.frames[pose] as AtlasTexture
			check(texture != null and texture.atlas == Candidate.packed_atlas, "frame shares single atlas")
			var top_left := trail.frame_offsets[pose] - texture.region.size * 0.5 + Vector2(128, 128)
			check(top_left.x >= 0 and top_left.y >= 0 and (top_left + texture.region.size).x <= 256 and (top_left + texture.region.size).y <= 256, "crop retains original canvas origin")
	for pose in 65:
		for index in 16:
			var visual: CharacterVisual = visuals[index]
			visual.cast_sprite._body_init = false
			visual._swing_t = minf(pose / 64.0, 0.995) * visual._swing_dur
			visual._process_cast(0.0)
			var start := Time.get_ticks_usec()
			trails[index]._process(0.0)
			update_times.append((Time.get_ticks_usec() - start) / 1000.0)
		await get_tree().process_frame
		if pose == 40 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png("res://build/melee_trail_review/measured_dense/packed/all_heading_contact.png")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var memory := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) - baseline
	print("Packed texture memory delta bytes=", memory)
	check(DisplayServer.get_name() == "headless" or memory <= 6 * 1024 * 1024, "packed texture memory stays under six MiB")
	var warm_max := 0.0
	for index in range(1, setup_times.size()):
		warm_max = maxf(warm_max, setup_times[index])
	update_times.sort()
	print("Setup cold ms=",setup_times[0]," warm max ms=",warm_max," update p95 ms=",update_times[int(update_times.size() * 0.95)])
	check(warm_max < 2.0, "prewarmed setup stays below two milliseconds")
	for index in 16:
		visuals[index].cancel_attack()
		trails[index]._process(0.0)
		check(trails[index].is_queued_for_deletion(), "cancelled attack releases packed effect")
	print("PACKED TRAIL REVIEW: ",failures," failures")
	Game.request_quit(1 if failures else 0)
