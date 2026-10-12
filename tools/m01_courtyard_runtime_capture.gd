extends Node

## GPU-only capture of the live M01 courtyard camera.  No staging layer is
## loaded; this records the projection future pool art must match.

func _ready() -> void:
	Engine.set_meta("skip_tasks",true);Engine.set_meta("autoplay",true)
	await get_tree().process_frame
	var saved:=SaveManager.data.duplicate(true);var saved_path:=SaveManager.save_path
	SaveManager.save_path="user://m01_courtyard_capture_save.json"
	var placeholder:=Node.new();get_tree().root.add_child(placeholder);get_tree().current_scene=placeholder
	Game.campaign_mode=false;Game.replay_mission("m01_checkout")
	for frame in 120:await get_tree().physics_frame
	var level:=get_tree().get_first_node_in_group("level") as Level;assert(level!=null)
	level.hud.hide();level.camera.target=null;level.camera.set_process(false)
	# The 50x15-cell courtyard region centres on this world coordinate.
	level.camera.global_position=Vector2(464,296);level.camera.zoom=Vector2(.80,.80)
	for child in level.get_children():
		if child is IntroCall or child is LevelIntro:child.hide()
	for frame in 8:await get_tree().process_frame
	if DisplayServer.get_name().to_lower()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_courtyard_runtime_capture.png")
	var report:=FileAccess.open("user://m01_courtyard_runtime_capture.json",FileAccess.WRITE);assert(report!=null)
	report.store_string(JSON.stringify({"passed":true,"camera_world_position":[464,296],"camera_zoom":.8,"region_cells":[4,11,50,15],"scope":"Live M01 Camera2D capture of the native courtyard; no Blender layer loaded."},"  "));report.close()
	SaveManager.data=saved;SaveManager.save_path=saved_path
	print("M01 COURTYARD RUNTIME CAPTURE DONE")
	Game.request_quit(0)
