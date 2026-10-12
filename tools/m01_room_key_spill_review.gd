extends Node
func _ready()->void:
	Engine.set_meta("skip_tasks",true);await get_tree().process_frame
	var p:=Node.new();get_tree().root.add_child(p);get_tree().current_scene=p;Game.campaign_mode=false;Game.replay_mission("m01_checkout")
	for i in 120:await get_tree().physics_frame
	var level:=get_tree().get_first_node_in_group("level") as Level;assert(level!=null);var count:=0
	for n in level.get_node("Decor").get_children():
		if n is Sprite2D and str(n.get_meta("decor_asset_id",""))=="motel_room_key_spill":
			var a:=n as Sprite2D;var v:=a.get_node_or_null("NativeM01RoomKeySpill") as Sprite2D;assert(v!=null and v.texture!=null and v.visible);assert(v.find_children("*","CollisionObject2D",true,false).is_empty());assert(is_zero_approx(a.self_modulate.a));count+=1
	assert(count==7)
	if DisplayServer.get_name()!="headless":
		level.hud.hide();for x in get_tree().root.find_children("*","Control",true,false):(x as Control).hide()
		level.camera.set_process(false);level.camera.set_physics_process(false);level.camera.global_position=Vector2(552,216);level.camera.zoom=Vector2(7,7)
		for i in 8:await get_tree().process_frame
		await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("res://build/m01_room_key_spill_runtime.png")
	var f:=FileAccess.open("res://build/m01_room_key_spill_runtime_review.json",FileAccess.WRITE);f.store_string(JSON.stringify({"runtime_approved":true,"placements":count,"collision_added":false}));f.close();print("M01 ROOM KEY SPILL REVIEW: %d native visual-only placements"%count);Game.request_quit(0)
