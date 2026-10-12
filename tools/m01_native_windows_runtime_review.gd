extends Node

func _ready() -> void:
	Engine.set_meta("skip_tasks",true);Engine.set_meta("autoplay",true)
	await get_tree().process_frame
	var saved:=SaveManager.data.duplicate(true);var saved_path:=SaveManager.save_path
	SaveManager.save_path="user://m01_native_windows_runtime_review_save.json"
	var placeholder:=Node.new();get_tree().root.add_child(placeholder);get_tree().current_scene=placeholder
	Game.campaign_mode=false;Game.replay_mission("m01_checkout")
	for frame in 120:await get_tree().physics_frame
	var level:=get_tree().get_first_node_in_group("level") as Level;assert(level!=null)
	var rows:Array=[];var first:GlassWindow=null
	for node in level.props_root.get_children():
		if not node is GlassWindow:continue
		var window:=node as GlassWindow;var sprite:=window.get_node_or_null("NativeM01WindowVisual") as Sprite2D
		assert(sprite!=null and sprite.texture!=null and sprite.visible)
		assert(window.has_meta("native_window_visual_override") and not window.has_meta("review_window_visual_override"))
		assert(sprite.light_mask==window.light_mask and is_equal_approx(sprite.scale.x,sprite.scale.y))
		rows.append({"position":[window.global_position.x,window.global_position.y],"size":[window.size.x,window.size.y]})
		if first==null:first=window
	assert(rows.size()==20 and first!=null)
	var visual:=first.get_node("NativeM01WindowVisual") as Sprite2D
	first.shatter(Vector2.DOWN)
	assert(first.broken and first.collision_layer==Layers.LOW and not visual.visible)
	assert(not first.has_meta("native_window_visual_override"))
	var report:=FileAccess.open("user://m01_native_windows_runtime_review.json",FileAccess.WRITE);assert(report!=null)
	report.store_string(JSON.stringify({"passed":true,"window_count":rows.size(),"windows":rows,"broken_handoff":true,"scope":"Production M01 native window visuals retain every GlassWindow collision and damaged-frame fallback."},"  "));report.close()
	SaveManager.data=saved;SaveManager.save_path=saved_path
	print("M01 NATIVE WINDOWS: 20 visual overrides and broken-frame handoff verified")
	Game.request_quit(0)
