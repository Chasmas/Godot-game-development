extends Node

func _ready() -> void:
	Engine.set_meta("skip_tasks",true);Engine.set_meta("autoplay",true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true);var saved_path := SaveManager.save_path
	SaveManager.save_path="user://m01_beds_runtime_review_save.json"
	var placeholder := Node.new();get_tree().root.add_child(placeholder);get_tree().current_scene=placeholder
	Game.campaign_mode=false;Game.replay_mission("m01_checkout")
	for frame in 120:await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	assert(level.floor_root.has_node("NativeM01Ground"),"Approved ground must remain active after furniture changes")
	Dialogue._end(false);Dialogue.set_process(false)
	level.player.input_enabled=false;level.player.set_physics_process(false)
	for enemy in level.enemies:enemy.set_physics_process(false)
	var rows: Array=[];var textures: Dictionary={}
	for object in get_tree().get_nodes_in_group("furniture"):
		if not object is Furniture or object.kind!="bed" or not level.is_ancestor_of(object):continue
		var sprite := object.get_node_or_null("NativeBlenderBed") as Sprite2D
		assert(sprite!=null and sprite.texture!=null and sprite.visible)
		assert(is_equal_approx(sprite.scale.x,sprite.scale.y),"Bed image must never stretch")
		var shape := object.get_child(0) as CollisionShape2D
		assert(shape.shape.size.is_equal_approx(object.rect_size-Vector2(2,2)))
		assert(object.collision_layer==Layers.LOW)
		textures[sprite.texture.get_instance_id()]=true
		var contacts := 0
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			var from := Transform2D(0,object.global_position+direction*40)
			if level.player.test_move(from,Vector2.ZERO):continue
			var contact := KinematicCollision2D.new()
			if level.player.test_move(from,-direction*40,contact) and contact.get_collider()==object:contacts+=1
		assert(contacts>0,"Functional bed must stop actual player movement")
		rows.append({"position":[object.position.x,object.position.y],"player_contact_sides":contacts,"uniform_scale":sprite.scale.x})
	assert(rows.size()==10 and textures.size()==1)
	for child in level.get_node("Decor").get_children():
		assert(child.get_meta("decor_asset_id","")!="hq_motel_bed")
	if DisplayServer.get_name()!="headless":
		level.hud.hide();level.camera.set_process(false)
		for child in level.get_children():
			if child is IntroCall or child is LevelIntro:child.hide()
		level.camera.global_position=Vector2(540,420);level.camera.zoom=Vector2(1.5,1.5)
		for frame in 8:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_native_beds_runtime.png")
	var report := FileAccess.open("res://build/m01_native_beds_runtime_review.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":true,"beds":rows,"shared_texture_count":textures.size(),"scope":"Production M01 beds, actual player collision sweeps, no staging metadata"},"  "));report.close()
	SaveManager.data=saved;SaveManager.save_path=saved_path;Dialogue.set_process(true)
	print("M01 RUNTIME BEDS: ten shared Blender beds, isotropic scale and player collision verified")
	Game.request_quit(0)
