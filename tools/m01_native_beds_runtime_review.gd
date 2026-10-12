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
	assert(level.walls_root.has_node("NativeM01Walls"),"Approved M01 wall plate must remain active after furniture changes")
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
	var nightstands: Array=[];var nightstand_textures: Dictionary={}
	for object in level.props_root.get_children():
		if not object is StaticBody2D or not str(object.name).begins_with("NativeNightstand_"):continue
		assert(object.collision_layer==Layers.LOW)
		var shape := object.get_child(0) as CollisionShape2D
		assert(shape!=null and shape.shape is RectangleShape2D)
		assert((shape.shape as RectangleShape2D).size.is_equal_approx(Vector2(.65,.5)*16.0))
		var sprite := object.get_child(1) as Sprite2D
		assert(sprite!=null and sprite.texture!=null and sprite.visible)
		nightstand_textures[sprite.texture.get_instance_id()]=true
		var contacts := 0
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			var from := Transform2D(0,object.global_position+direction*30)
			if level.player.test_move(from,Vector2.ZERO):continue
			var contact := KinematicCollision2D.new()
			if level.player.test_move(from,-direction*30,contact) and contact.get_collider()==object:contacts+=1
		assert(contacts>0,"Native bedside cabinet must stop the actual player body")
		nightstands.append({"position":[object.position.x,object.position.y],"player_contact_sides":contacts})
	assert(nightstands.size()==13 and nightstand_textures.size()==1,"All gameplay-safe M01 bedside cabinets must be native runtime solids")
	for object in level.props_root.get_children():
		assert(not str(object.name).begins_with("CandidateNightstand_"),"Staging nightstand must not leak into runtime")
	for layer in level.get_children():
		if layer is Dressing.ClutterLayer:
			assert(not layer.items.any(func(item): return str(item[0])=="nightstand"),"Legacy nightstand drawing must be removed")
	var dressers: Array=[];var dresser_textures: Dictionary={}
	for object in level.props_root.get_children():
		if not object is StaticBody2D or not str(object.name).begins_with("NativeDresser_"):continue
		assert(object.collision_layer==Layers.LOW)
		var shape := object.get_child(0) as CollisionShape2D
		assert(shape!=null and shape.shape is RectangleShape2D)
		var sprite := object.get_child(1) as Sprite2D
		assert(sprite!=null and sprite.texture!=null and sprite.visible)
		dresser_textures[sprite.texture.get_instance_id()]=true
		var contacts := 0
		# Dense furniture can occupy every cardinal test origin while leaving a
		# diagonal walkable approach.  Probe several real player-sized starts;
		# only a free start whose first collision is this body counts.
		for radius in [32.0, 40.0, 48.0, 56.0, 64.0]:
			for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN, Vector2(-1,-1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,1).normalized(),Vector2(1,1).normalized()]:
				var origin: Vector2 = object.global_position + direction * radius
				var from := Transform2D(0, origin)
				if level.player.test_move(from, Vector2.ZERO): continue
				var contact := KinematicCollision2D.new()
				if level.player.test_move(from, object.global_position - origin, contact) and contact.get_collider() == object:
					contacts += 1
		print("M01 dresser contact probe position=%s contacts=%d" % [object.global_position, contacts])
		assert(contacts>0,"Native dresser must stop the actual player body from an accessible side")
		dressers.append({"position":[object.position.x,object.position.y],"player_contact_sides":contacts})
	assert(dressers.size()==6 and not dresser_textures.is_empty(),"All gameplay-safe M01 CRT dressers must be native runtime solids")
	for object in level.props_root.get_children():
		assert(not str(object.name).begins_with("CandidateDresser_"),"Staging dresser must not leak into runtime")
	var retained_legacy_dressers := 0
	for layer in level.get_children():
		if layer is Dressing.ClutterLayer:
			var legacy_dressers: Array = layer.items.filter(func(item): return str(item[0]) == "dresser_tv")
			for item in legacy_dressers:
				assert((item[1] as Vector2).distance_to(Vector2(411,136)) < .01, "Only the proven cramped dresser may remain legacy")
			retained_legacy_dressers += legacy_dressers.size()
	assert(retained_legacy_dressers == 1, "Exactly one cramped dresser remains legacy rather than a native solid")
	var rugs: Array=[]
	var rug_rooms: Array=Dressing._find_rooms(level.builder)
	for object in level.get_children():
		if not object is Sprite2D or not str(object.name).begins_with("NativeWovenRug_"):continue
		assert(object.texture!=null and object.visible,"Native woven rug requires a visible production texture")
		assert(is_equal_approx(object.scale.x,object.scale.y),"Rug image must retain its authored aspect ratio")
		var room_id := -1
		for room in rug_rooms:
			if room.cells.has(Vector2i(floori(object.position.x/16.0),floori(object.position.y/16.0))):
				room_id=room.id
				break
		assert(room_id>=0,"Rug anchor must be inside an authored room")
		var alpha_spill := 0
		var visible_pixels := 0
		var image: Image=object.texture.get_image()
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x,y).a<.05:continue
				visible_pixels+=1
				var projected: Vector2=object.position+(Vector2(x+.5,y+.5)+object.offset)*object.scale
				var cell := Vector2i(floori(projected.x/16.0),floori(projected.y/16.0))
				if not rug_rooms[room_id].cells.has(cell):alpha_spill+=1
		assert(visible_pixels>0 and alpha_spill==0,"Visible woven rug pixels must remain in the anchored room")
		rugs.append({"position":[object.position.x,object.position.y],"room_id":room_id,"visible_source_pixels":visible_pixels,"projected_alpha_pixels_outside_room":alpha_spill})
	assert(rugs.size()==10,"All ten guest-room rug landmarks must use the native runtime family")
	for layer in level.get_children():
		if layer is Dressing.ClutterLayer:
			assert(not layer.items.any(func(item): return str(item[0])=="rug_big"),"Legacy rug drawing must be removed")
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
	# Headless runs can mount res:// read-only.  This is a transient test
	# artifact, so put it in Godot's guaranteed writable review location.
	var report := FileAccess.open("user://m01_native_beds_runtime_review.json",FileAccess.WRITE)
	assert(report != null, "M01 bed review needs a writable report location")
	report.store_string(JSON.stringify({"passed":true,"beds":rows,"shared_texture_count":textures.size(),"native_nightstands":nightstands,"nightstand_shared_texture_count":nightstand_textures.size(),"native_dressers":dressers,"dresser_texture_count":dresser_textures.size(),"native_rugs":rugs,"scope":"Production M01 beds, bedside cabinets, CRT dressers and woven rugs. Furniture collision uses actual player sweeps; rugs are verified as walkable in-room visuals with no legacy draw path."},"  "));report.close()
	SaveManager.data=saved;SaveManager.save_path=saved_path;Dialogue.set_process(true)
	print("M01 RUNTIME FURNITURE: ten beds, 13 bedside cabinets, six CRT dressers and ten woven rugs verified")
	Game.request_quit(0)

