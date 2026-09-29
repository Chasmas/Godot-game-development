extends Node
## Dev probe: where a level's frame goes. PERF_MISSION, PERF_OFF=setting,...
## Uncapped frame time; then each script class hidden / stopped in turn.

func _all() -> Array:
	var out: Array = []
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		stack.append_array(nd.get_children())
		out.append(nd)
	return out

func _key(nd: Node) -> String:
	var sc: Script = nd.get_script()
	if sc == null:
		return nd.get_class()
	if sc.resource_path == "":
		return "inner(" + nd.get_parent().get_class() + ">" + nd.get_class() + ")"
	return sc.resource_path.get_file()

var quiet := false
func _measure() -> Array:
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for i in 15:
		await get_tree().process_frame
	var gpu := 0.0
	var cpu := 0.0
	var t0 := Time.get_ticks_usec()
	var s := 0.0
	var n := 90
	for i in n:
		await get_tree().process_frame
		s += Performance.get_monitor(Performance.TIME_PROCESS)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
	if not quiet:
		print("PERF   render gpu %.2f ms  render cpu %.2f ms" % [gpu / n, cpu / n])
	return [(Time.get_ticks_usec() - t0) / 1000.0 / n, s / n * 1000.0, cpu / n, gpu / n, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await get_tree().process_frame
	for k in OS.get_environment("PERF_OFF").split(",", false):
		SaveManager.settings[k] = false
	SaveManager.settings["vsync"] = false
	SaveManager.settings["fullscreen"] = OS.get_environment("PERF_FS") == "1"
	SaveManager.apply_video_settings()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var ph := Node.new()
	get_tree().root.add_child(ph)
	get_tree().current_scene = ph
	Game.campaign_mode = false
	Game.start_mission(OS.get_environment("PERF_MISSION") if OS.get_environment("PERF_MISSION") != "" else "m01_checkout")
	for i in 400:
		await get_tree().process_frame
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if OS.get_environment("PERF_POS") != "":
		var v := OS.get_environment("PERF_POS").split(",")
		p.global_position = Vector2(float(v[0]), float(v[1])) * 16.0
	var base: Array = await _measure()
	print("PERF base frame %.2f ms  process %.2f ms  draw_calls %d  nodes %d" % [base[0], base[1], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	var lights: Array = []
	var shadowed := 0
	var occl := 0
	for nd in _all():
		if nd is Light2D:
			lights.append(nd)
			if (nd as Light2D).shadow_enabled:
				shadowed += 1
		if nd is LightOccluder2D:
			occl += 1
	print("PERF lights %d (shadowed %d), occluders %d" % [lights.size(), shadowed, occl])
	if OS.get_environment("PERF_CLASSES") == "1":
		lights.clear()
	for l in lights:
		(l as Light2D).shadow_enabled = false
	var m1: Array = await _measure()
	print("PERF no shadows: frame %.2f" % m1[0])
	for l in lights:
		(l as Light2D).enabled = false
	var m2: Array = await _measure()
	print("PERF no lights: frame %.2f" % m2[0])
	for nd in _all():
		if nd is CanvasModulate:
			(nd as CanvasModulate).visible = false
	var m3: Array = await _measure()
	print("PERF no canvas modulate: frame %.2f" % m3[0])
	var names := {}
	for nd in _all():
		if nd is CanvasItem and _key(nd).begins_with("inner(Node2D>Node2D"):
			var k2 := str(nd.get_parent().name) + "/" + str(nd.name).rstrip("0123456789@")
			names[k2] = names.get(k2, 0) + 1
	var groups := {}
	for nd in _all():
		if nd is CanvasItem and _key(nd).begins_with("inner(Node2D>Node2D"):
			var pn := str(nd.get_parent().name)
			var g := pn if not pn.begins_with("@") else ("anon<" + str(nd.get_parent().get_parent().name) + ">")
			if pn == "Level":
				g = "Level/" + str(nd.name)
			if not groups.has(g):
				groups[g] = []
			groups[g].append(nd)
	quiet = true
	var b2: Array = await _measure()
	for g in groups:
		for nd in groups[g]:
			nd.visible = false
		var mm: Array = await _measure()
		for nd in groups[g]:
			nd.visible = true
		print("PERF group %-30s x%-3d  cpu %.2f  gpu %.2f  calls %d" % [g, groups[g].size(), b2[2] - mm[2], b2[3] - mm[3], b2[4] - mm[4]])
	if OS.get_environment("PERF_CLASSES") != "1":
		get_tree().quit()
		return
	var counts := {}
	for nd in _all():
		if nd is CanvasItem and nd.get_script() != null:
			counts[_key(nd)] = counts.get(_key(nd), 0) + 1
	var ks := counts.keys()
	var res: Array = []
	for k in ks:
		var off: Array = []
		for nd in _all():
			if nd is CanvasItem and _key(nd) == k and (nd as CanvasItem).visible:
				(nd as CanvasItem).visible = false
				off.append(nd)
		quiet = true
		var m: Array = await _measure()
		for nd in off:
			if is_instance_valid(nd):
				nd.visible = true
		res.append([base[2] - m[2], k, counts[k], base[4] - m[4], base[3] - m[3]])
	res.sort_custom(func(a, b): return a[0] > b[0])
	for r in res.slice(0, 20):
		print("  hide %-50s x%-4d saves cpu %.2f ms  gpu %.2f ms  draw calls %d" % [r[1], r[2], r[0], r[4], r[3]])
	get_tree().quit()
