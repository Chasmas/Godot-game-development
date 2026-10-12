extends Node

## Campaign coverage gate for normal-level civilians.  Nightmare residents are
## intentionally excluded: they must be derived from saved campaign kills.

const EXPECTED := {"m01_checkout": 2, "m02_dog_days": 3, "m03_prime_time": 3}

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var saved_path := SaveManager.save_path
	SaveManager.save_path = "user://civilian_coverage_review_save.json"
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	var rows: Array = []
	var ids := {}
	var palettes := {}
	for mission in EXPECTED:
		Game.replay_mission(mission)
		for frame in 120: await get_tree().physics_frame
		var level := get_tree().get_first_node_in_group("level") as Level
		assert(level != null, "Normal level failed to load for civilian coverage")
		var residents: Array = []
		for node in level.get_tree().get_nodes_in_group("npcs"):
			if node is NPC and level.is_ancestor_of(node): residents.append(node as NPC)
		assert(residents.size() == int(EXPECTED[mission]), "%s civilian count changed" % mission)
		for resident in residents:
			assert(not ids.has(resident.npc_id), "Civilian ids must be campaign-unique: %s" % resident.npc_id)
			ids[resident.npc_id] = mission
			assert(not palettes.has(resident.palette), "Named civilians need distinct in-game visual variants: %s" % resident.palette)
			palettes[resident.palette] = resident.npc_id
			var cell := Vector2i(floori(resident.global_position.x / 16.0), floori(resident.global_position.y / 16.0))
			assert(level.builder.ch(cell.x, cell.y) == "@", "Civilian spawn must occupy an authored @ cell")
			assert(resident.can_interact(level.player), "Civilian must offer dialogue before combat")
			rows.append({"mission": mission, "id": resident.npc_id, "palette": resident.palette, "cell": [cell.x, cell.y], "line_count": resident.lines.size()})
		level.queue_free()
		for frame in 3: await get_tree().process_frame
	assert(ids.size() == 8, "Normal campaign needs eight distinct civilians")
	assert(palettes.size() == 8, "Normal campaign civilians need eight distinct visual variants")
	var report := FileAccess.open("res://build/civilian_coverage_review.json", FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify({"passed": true, "normal_levels": EXPECTED, "distinct_civilians": ids.size(), "distinct_visual_variants": palettes.size(), "rows": rows, "nightmare_policy": "No M04 civilian is spawned by this review; nightmare victims must derive from prior campaign kills."}, "  "))
	report.close()
	SaveManager.data = saved
	SaveManager.save_path = saved_path
	print("CIVILIAN COVERAGE REVIEW: ", ids.size(), " distinct civilians across normal levels")
	Game.request_quit(0)
