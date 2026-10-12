extends Node

func _ready() -> void:
	Engine.set_meta("review_guest_ice_buckets",true)
	Engine.set_meta("skip_tasks",true)
	Engine.set_meta("autoplay",true)
	await get_tree().process_frame
	var placeholder:=Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene=placeholder
	Game.replay_mission("m01_checkout")
	for frame in 120: await get_tree().physics_frame
	var level:=get_tree().get_first_node_in_group("level") as Level
	assert(level!=null and is_instance_valid(level.player))
	Dialogue._end(false)
	get_tree().paused=false
	var records: Array=[]
	for node in level.get_node("Decor").get_children():
		if not node is Sprite2D: continue
		var id:=str(node.get_meta("decor_asset_id",""))
		if id not in ["motel_ice_bucket","motel_ice_bucket_full"]: continue
		var visual:=node.get_node_or_null("NativeM01GuestIceBucket") as Sprite2D
		assert(visual!=null and visual.texture!=null and is_zero_approx(node.self_modulate.a))
		assert(visual.find_children("*","CollisionObject2D",true,false).is_empty())
		var width:=visual.texture.get_image().get_used_rect().size.x*visual.global_scale.x
		assert(absf(width-12.0)<0.01)
		records.append({"id":id,"position":node.global_position,"width_px":width})
	assert(records.size()==3)
	if DisplayServer.get_name()!="headless":
		for control in get_tree().root.find_children("*","Control",true,false): control.hide()
		level.camera.set_process(false)
		level.camera.set_physics_process(false)
		level.camera.zoom=Vector2(5,5)
		for index in records.size():
			level.camera.global_position=records[index].position
			for frame in 8: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/m01_guest_ice_buckets_runtime_%d.png"%index)
	var file:=FileAccess.open("res://build/m01_guest_ice_buckets_review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"placements":records,"collision_added":false},"  "))
	print("M01 GUEST ICE BUCKETS REVIEW PASSED: three visual-only placements, 12px footprint")
	get_tree().quit()
