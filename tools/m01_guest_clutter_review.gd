extends Node

const IDS := ["clutter_ashtray","clutter_bottles"]
const WIDTHS := {"clutter_ashtray":9.0,"clutter_bottles":10.0}

func _ready() -> void:
	Engine.set_meta("review_guest_clutter",true)
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
		if id not in IDS: continue
		var visual:=node.get_node_or_null("NativeM01GuestClutter") as Sprite2D
		assert(visual!=null and visual.texture!=null and is_zero_approx(node.self_modulate.a))
		assert(visual.find_children("*","CollisionObject2D",true,false).is_empty())
		var width:=visual.texture.get_image().get_used_rect().size.x*absf(visual.global_scale.x)
		assert(absf(width-float(WIDTHS[id]))<0.01)
		var legacy:=0.0
		if node.texture!=null: legacy=node.texture.get_image().get_used_rect().size.x*absf(node.global_scale.x)
		records.append({"id":id,"position":node.global_position,"width_px":width,"legacy_width_px":legacy})
	assert(records.size()==12)
	if DisplayServer.get_name()!="headless":
		for control in get_tree().root.find_children("*","Control",true,false): control.hide()
		level.camera.set_process(false)
		level.camera.set_physics_process(false)
		level.camera.zoom=Vector2(5,5)
		for index in records.size():
			level.camera.global_position=records[index].position
			for frame in 8: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/m01_guest_clutter_runtime_%d.png"%index)
	var file:=FileAccess.open("res://build/m01_guest_clutter_review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"placements":records,"collision_added":false},"  "))
	print("M01 GUEST CLUTTER REVIEW PASSED: twelve visual-only placements")
	get_tree().quit()
