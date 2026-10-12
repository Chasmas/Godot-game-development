extends Node
func _ready()->void:
	Engine.set_meta("skip_tasks",true);await get_tree().process_frame
	var p:=Node.new();get_tree().root.add_child(p);get_tree().current_scene=p;Game.campaign_mode=false;Game.replay_mission("m01_checkout")
	for i in 120:await get_tree().physics_frame
	var level:=get_tree().get_first_node_in_group("level") as Level;assert(level!=null)
	var anchors:Array[Sprite2D]=[]
	for node in level.get_node("Decor").get_children():
		if node is Sprite2D and str(node.get_meta("decor_asset_id",""))=="motel_palm_planter":anchors.append(node)
	assert(anchors.size()==4)
	for anchor in anchors:
		var visual:=anchor.get_node_or_null("NativeM01PalmPlanter") as Sprite2D;assert(visual!=null and visual.texture!=null and visual.visible);assert(visual.find_children("*","CollisionObject2D",true,false).is_empty());assert(is_zero_approx(anchor.self_modulate.a))
	if DisplayServer.get_name()!="headless":
		level.hud.hide()
		for control in get_tree().root.find_children("*","Control",true,false):(control as Control).hide()
		level.camera.set_process(false);level.camera.set_physics_process(false);level.camera.global_position=anchors[0].global_position;level.camera.zoom=Vector2(7,7)
		for i in 8:await get_tree().process_frame
		await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("res://build/m01_palm_planter_runtime.png")
	var f:=FileAccess.open("res://build/m01_palm_planter_runtime_review.json",FileAccess.WRITE);f.store_string(JSON.stringify({"runtime_approved":true,"placements":4,"collision_added":false}));f.close();print("M01 PALM PLANTER REVIEW: 4 native visual-only placements");Game.request_quit(0)
