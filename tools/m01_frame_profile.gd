extends Node

func sample(label: String) -> Dictionary:
	for frame in 30: await get_tree().process_frame
	var timings: Array[float] = []
	var process_ms := 0.0
	var physics_ms := 0.0
	var calls := 0.0
	for frame in 240:
		if Dialogue.active: Dialogue._end(false)
		Dialogue.root.hide()
		var start := Time.get_ticks_usec()
		await get_tree().process_frame
		timings.append(float(Time.get_ticks_usec()-start)/1000.0)
		process_ms+=Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
		physics_ms+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
		calls+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	timings.sort()
	return {"label":label,"samples":240,"median_ms":timings[120],"p95_ms":timings[228],"process_mean_ms":process_ms/240,"physics_mean_ms":physics_ms/240,"draw_calls_mean":calls/240}

func _ready() -> void:
	Engine.set_meta("skip_tasks",true)
	Engine.set_meta("autoplay",true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var saved_path := SaveManager.save_path
	SaveManager.save_path="user://m01_frame_profile_save.json"
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene=placeholder
	Game.campaign_mode=false
	Game.replay_mission("m01_checkout")
	for frame in 120: await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	level.player.set_physics_process(false)
	level.player.visual.update_move(Vector2.ZERO,0)
	for enemy in level.enemies:
		enemy.set_physics_process(false)
		enemy.visual.update_move(Vector2.ZERO,0)
	for child in level.get_children():
		if child is IntroCall or child is LevelIntro: child.queue_free()
	level.hud.hide()
	Dialogue._end(false)
	Dialogue.set_process(false)
	level.camera.set_process(false)
	level.camera.set_physics_process(false)
	level.camera.position=Vector2(470,260)
	level.camera.zoom=Vector2.ONE*1.5
	var results: Array = []
	results.append(await sample("native_scene"))
	PostFX.rect.hide()
	results.append(await sample("diagnostic_postfx_disabled"))
	PostFX.rect.show()
	var lights := level.find_children("*","PointLight2D",true,false)
	var light_states: Array[bool] = []
	for light in lights:
		light_states.append(light.enabled)
		light.enabled=false
	results.append(await sample("diagnostic_2d_lights_disabled"))
	for i in lights.size(): lights[i].enabled=light_states[i]
	var casts: Array = []
	for actor in [level.player]+level.enemies:
		if actor.visual.cast_sprite is CastModel:
			casts.append(actor.visual.cast_sprite)
	var live := 0
	for cast in casts:
		if cast._viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS: live+=1
		cast.hide()
		cast._viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	# Diagnostic only: suppress the character visuals that drive viewport updates.
	for actor in [level.player]+level.enemies: actor.visual.set_process(false)
	results.append(await sample("diagnostic_character_viewports_disabled"))
	for cast in casts:
		assert(cast._viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Diagnostic viewports must stay disabled")
	var file := FileAccess.open("res://build/m01_frame_profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Frozen actors; native scene, then diagnostic render suppression. No gameplay or visual-quality approval.","cast_models":casts.size(),"live_cast_viewports":live,"results":results},"\t"))
	file.close()
	SaveManager.data=saved
	SaveManager.save_path=saved_path
	Dialogue.set_process(true)
	print("M01 FRAME PROFILE: ",JSON.stringify(results))
	Game.request_quit(0)
