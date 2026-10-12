extends Node

func _ready() -> void:
	Engine.set_meta("skip_tasks",true)
	Engine.set_meta("autoplay",true)
	await get_tree().process_frame
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene=placeholder
	Game.campaign_mode=false
	Game.attempts=2
	Game.replay_mission("m01_checkout")
	var level: Level
	for frame in 120:
		await get_tree().process_frame
		level=get_tree().get_first_node_in_group("level") as Level
		if level!=null and is_instance_valid(level.player):break
	assert(level!=null and is_instance_valid(level.player))
	Dialogue._end(false)
	get_tree().paused=false
	level.set_process(false)
	for body in level.find_children("*","CollisionObject2D",true,false):
		body.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	level.process_mode=Node.PROCESS_MODE_DISABLED
	var player := level.player
	var television: BreakableProp
	for prop in level.props_root.get_children():
		if prop is BreakableProp and prop.get_meta("native_tv_dresser", false): television = prop
	assert(television != null and television.position == Vector2(200,440), "Room101 TV/cabinet must face into room from north")
	assert(not level.nav.is_point_solid(Vector2i(12,30)), "Former TV location must be available to navigation")
	assert(level.nav.is_point_solid(Vector2i(12,27)), "New cabinet footprint must reserve navigation")
	player.set_physics_process(false)
	for enemy in level.enemies:enemy.set_physics_process(false)
	for layer in get_tree().root.find_children("*","CanvasLayer",true,false):layer.hide()
	level.camera.set_process(false)
	level.camera.set_physics_process(false)
	level.camera.global_position=Vector2(240,464)
	level.camera.zoom=Vector2(3,3)
	level.camera.reset_smoothing()
	level.camera.force_update_scroll()
	for frame in 6:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_room101_production_layout.png")
	var results: Array=[]
	for route in [{"label":"south_door","start":Vector2(240,520),"motion":Vector2(0,-48)}, {"label":"east_door","start":Vector2(296,464),"motion":Vector2(32,0)}]:
		player.position=route.start
		await get_tree().physics_frame
		var collision := player.move_and_collide(route.motion)
		results.append({"route":route.label,"clear":collision==null,"collider":str(collision.get_collider().name) if collision else "", "collider_class":collision.get_collider().get_class() if collision else "", "collider_parent":str(collision.get_collider().get_parent().name) if collision else "", "collider_position":str(collision.get_collider().global_position) if collision else ""})
	var window: GlassWindow
	for pane in get_tree().get_nodes_in_group("glass"):
		if pane is GlassWindow and pane.global_position.distance_to(Vector2(192,504))<12:window=pane
	assert(window!=null,"Must locate actual101 south window")
	player.position=Vector2(184,480)
	await get_tree().physics_frame
	var intact_contact := player.move_and_collide(Vector2(0,40))
	print(JSON.stringify({"routes":results,"mask":player.collision_mask,"window_contact":str(intact_contact.get_collider().get_parent().name) if intact_contact else "none"}))
	assert(intact_contact!=null and intact_contact.get_collider()==window,"Intact glass must stop walking")
	window.shatter(Vector2.DOWN)
	player.position=Vector2(184,480)
	var original_mask := player.collision_mask
	player.collision_mask=original_mask & ~Layers.LOW
	await get_tree().physics_frame
	var dive_contact := player.move_and_collide(Vector2(0,40))
	player.collision_mask=original_mask
	results.append({"route":"broken_window_dive_mask","clear":dive_contact==null,"collider":str(dive_contact.get_collider().name) if dive_contact else ""})
	var report := FileAccess.open("res://build/m01_room101_access_review.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"scope":"Actual M01 Player geometry sweeps; dash mask only, no input/animation proof; new art not integrated","intact_window_blocks":true,"routes":results},"\t"))
	for result in results:assert(result.clear,"Existing room route blocked: %s"%str(result))
	if not await _review_visual_bridge(level):
		Game.request_quit(1)
		return
	var damage := DamageInfo.make(DamageInfo.Type.MELEE, player, television.global_position, Vector2.UP, &"hands", &"melee")
	television.take_damage(damage)
	assert(television.is_broken and television.hp <= 0, "Relocated TV must remain destructible")
	var screen := television.find_children("*", "Polygon2D", false, false)[0] as Polygon2D
	assert(is_zero_approx(float((screen.material as ShaderMaterial).get_shader_parameter("strength"))), "Destroyed CRT must stop glowing")
	print("M01 ROOM101 ACCESS REVIEW PASSED")
	Game.request_quit(0)

func _review_visual_bridge(level: Level) -> bool:
	# Keep the loaded mission's physics, but show only the candidate room here.
	level.hide()
	level.hud.hide()
	PostFX.rect.hide()
	for layer in get_tree().root.find_children("*","CanvasLayer",true,false):layer.hide()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var candidate_path := OS.get_environment("ROOM101_CANDIDATE")
	if candidate_path.is_empty(): candidate_path = "res://assets/art/prerendered/m01_sunset_palms/staging/room_101_shared_3d_v1/room.glb"
	assert(document.append_from_file(candidate_path,state)==OK)
	var room := document.generate_scene(state)
	get_tree().root.add_child(room)
	preload("res://scripts/player/cast_gltf_materials.gd").prepare(room,BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC)
	assert(preload("res://tools/m01_room_101_cutaway.gd").apply(room)>0)
	var chair_body: StaticBody2D
	for body in level.props_root.get_children():
		if body is StaticBody2D and body.get_meta("native_armchair",false) and body.position.distance_to(Vector2(200,472))<1:chair_body=body
	assert(chair_body!=null)
	var chair_shape := chair_body.get_child(0) as CollisionShape2D
	var chair_root: Node3D
	for node in room.find_children("*","Node3D",true,false):
		if str(node.name).to_lower().replace("_"," ").contains("armchair runtime review101 placement"):chair_root=node
	assert(chair_root!=null)
	var chair_min := Vector3(INF,INF,INF)
	var chair_max := Vector3(-INF,-INF,-INF)
	var chair_parts: Array=[]
	for mesh in chair_root.find_children("*","MeshInstance3D",true,false):
		# Soft stitched piping is cosmetic; compare the solid upholstered body.
		if str(mesh.name).to_lower().contains("piping"):continue
		var part_min := Vector3(INF,INF,INF)
		var part_max := Vector3(-INF,-INF,-INF)
		for surface in mesh.mesh.get_surface_count():
			var vertices: PackedVector3Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point: Vector3=mesh.global_transform*vertex
				chair_min=chair_min.min(point);chair_max=chair_max.max(point)
				part_min=part_min.min(point);part_max=part_max.max(point)
		chair_parts.append({"name":str(mesh.name),"min":[part_min.x,part_min.y,part_min.z],"max":[part_max.x,part_max.y,part_max.z]})
	var part_report := FileAccess.open("res://build/m01_room101_chair_export_parts.json",FileAccess.WRITE)
	part_report.store_string(JSON.stringify(chair_parts,"\t"))
	var chair_visual_centre := Vector2((chair_min.x+chair_max.x)*.5,(chair_min.z+chair_max.z)*.5)*16+Vector2(176,432)
	var chair_visual_size := Vector2(chair_max.x-chair_min.x,chair_max.z-chair_min.z)*16
	var chair_collision_size := (chair_shape.shape as RectangleShape2D).size
	if absf(sin(chair_shape.global_rotation)) > .5:
		chair_collision_size=Vector2(chair_collision_size.y,chair_collision_size.x)
	var chair_report := FileAccess.open("res://build/m01_room101_chair_fit.json",FileAccess.WRITE)
	chair_report.store_string(JSON.stringify({"runtime_promoted":false,"scope":"Actual exported solid upholstery/legs vertices against production collider; cosmetic stitched piping excluded","visual_centre":str(chair_visual_centre),"collision_centre":str(chair_shape.global_position),"centre_error_pixels":chair_visual_centre.distance_to(chair_shape.global_position),"visual_size":str(chair_visual_size),"collision_size":str(chair_collision_size)},"\t"))
	assert(chair_visual_centre.distance_to(chair_shape.global_position)<.05)
	assert(chair_visual_size.distance_to(chair_collision_size)<.1)
	var bed: Furniture
	for furniture in get_tree().get_nodes_in_group("furniture"):
		if furniture is Furniture and furniture.kind=="bed" and furniture.global_position.distance_to(Vector2(272,464))<1:bed=furniture
	assert(bed!=null,"Must match101 actual bed body")
	var bed_root: Node3D
	for child in room.find_children("*","Node3D",true,false):
		if str(child.name).to_lower().replace("_"," ").contains("motel bed101 placement"):bed_root=child
	assert(bed_root!=null,"Must identify candidate bed hierarchy")
	var minimum := Vector3(INF,INF,INF)
	var maximum := Vector3(-INF,-INF,-INF)
	for mesh in bed_root.find_children("*","MeshInstance3D",true,false):
		var bounds: AABB=mesh.get_aabb()
		for corner in 8:
			var point: Vector3=mesh.global_transform*bounds.get_endpoint(corner)
			minimum=minimum.min(point)
			maximum=maximum.max(point)
	var visual_centre := Vector2((minimum.x+maximum.x)*.5,(minimum.z+maximum.z)*.5)*16+Vector2(176,432)
	var visual_size := Vector2(maximum.x-minimum.x,maximum.z-minimum.z)*16
	assert(visual_centre.distance_to(bed.global_position)<.1)
	assert(visual_size.x<=bed.rect_size.x+.1 and visual_size.y<=bed.rect_size.y+.1,"Bed art must fit existing collision footprint")
	var bed_shape := bed.find_children("*","CollisionShape2D",true,false)[0] as CollisionShape2D
	var original_shape := bed_shape.shape
	var original_size := (original_shape as RectangleShape2D).size
	var contact_shape := original_shape.duplicate() as RectangleShape2D
	contact_shape.size=visual_size-Vector2(2,2)
	bed_shape.shape=contact_shape
	await get_tree().physics_frame
	var contacts: Array=[]
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		# Radius-eight Cass fits the vertical wall/bed gap at its midpoint.
		# Starting 26 pixels out embeds her in the bordering room wall.
		var approach_distance := 23.5 if direction.y != 0 else 26.0
		level.player.global_position=bed.global_position+direction*approach_distance
		print("BED BEFORE local=%s global=%s parent=%s parent_transform=%s bed=%s processing=%s mask=%s"%[level.player.position,level.player.global_position,level.player.get_parent().name,level.player.get_parent().global_transform,bed.global_position,level.player.is_physics_processing(),level.player.collision_mask])
		await get_tree().physics_frame
		print("BED AFTER local=%s global=%s bed=%s"%[level.player.position,level.player.global_position,bed.global_position])
		var contact := level.player.move_and_collide(-direction*approach_distance)
		if contact==null or contact.get_collider()!=bed:
			print("BED CONTACT FAILURE direction=%s collider=%s position=%s"%[direction,str(contact.get_collider().get_parent().name) if contact else "none",level.player.position])
			bed_shape.shape=original_shape
			return false
		var expected_distance := (contact_shape.size.x if direction.x!=0 else contact_shape.size.y)*.5+Player.RADIUS
		var measured_distance := absf((level.player.global_position-bed.global_position).dot(direction))
		assert(absf(measured_distance-expected_distance)<.15,"Contact must align with candidate rectangle")
		contacts.append({"direction":[direction.x,direction.y],"contact_error_pixels":absf(measured_distance-expected_distance)})
	bed_shape.shape=original_shape
	await get_tree().physics_frame
	var navigation_rows: Array=[]
	var static_rows: Array=[]
	for y in range(26,33):
		var row := ""
		for x in range(10,21):row += "#" if level.nav.is_point_solid(Vector2i(x,y)) else "."
		static_rows.append({"y":y,"x_start":10,"solid":row})
	var reservations := level._reserve_navigation_obstacles()
	var nearby_reservations: Array=[]
	for cell in reservations:
		if cell.x>=10 and cell.x<=20 and cell.y>=26 and cell.y<=32:nearby_reservations.append([cell.x,cell.y])
	for cell in reservations:level.nav.set_point_solid(cell,false)
	print(JSON.stringify({"static101":static_rows,"reserved101":nearby_reservations}))
	var barrier_bodies: Array=[]
	for shape in level.find_children("*","CollisionShape2D",true,false):
		if shape.disabled or not shape.shape is RectangleShape2D:continue
		var half: Vector2=shape.shape.size*.5
		var rectangle := Rect2(shape.to_global(-half),half*2)
		if not rectangle.intersects(Rect2(256,432,16,64)):continue
		var body := shape.get_parent() as CollisionObject2D
		if body==null or body.collision_layer & (Layers.WORLD|Layers.LOW|Layers.PROP)==0:continue
		barrier_bodies.append({"name":str(body.name),"script":body.get_script().resource_path if body.get_script() else "", "furnish_id":body.get_meta("furnish_id",""),"position":str(body.global_position),"size":str(shape.shape.size)})
	print("101 BARRIER BODIES "+JSON.stringify(barrier_bodies))
	var moved_nightstands: Array=[]
	for body in level.props_root.get_children():
		if body.has_meta("native_nightstand") and body.position in [Vector2(230,440),Vector2(214,488)]:
			var old_position: Vector2=body.position
			# Production layout already places this pair at the tested positions.
			assert(not level.nav.is_point_solid(Vector2i(16,floori(old_position.y/16))))
			moved_nightstands.append({"from":str(old_position),"to":str(body.position)})
	assert(moved_nightstands.size()==2)
	var clearance_shape := CircleShape2D.new()
	clearance_shape.radius=Enemy.RADIUS
	var clearance_query := PhysicsShapeQueryParameters2D.new()
	clearance_query.shape=clearance_shape
	clearance_query.collision_mask=Layers.WORLD|Layers.LOW|Layers.GLASS|Layers.PIT|Layers.PROP
	await get_tree().physics_frame
	for route in [{"from":Vector2(232,520),"to":Vector2(328,456)}, {"from":Vector2(328,456),"to":Vector2(232,520)}, {"from":Vector2(248,464),"to":Vector2(296,440)}]:
		var path := level.get_nav_path(route.from,route.to)
		assert(not path.is_empty(),"Room101 connections need actual navigation paths")
		var previous: Vector2=route.from
		var minimum_gap := INF
		var checked_positions := 0
		for point in path:
			var samples := maxi(1,ceili(previous.distance_to(point)/2.0))
			for sample in range(samples+1):
				var position := previous.lerp(point,float(sample)/samples)
				clearance_query.transform=Transform2D(0,position)
				var obstacles := level.get_world_2d().direct_space_state.intersect_shape(clearance_query)
				if not obstacles.is_empty():
					print("101 NAV COLLISION position=%s collider=%s"%[position,str(obstacles[0].collider.name)])
					return false
				checked_positions+=1
				var relative := (position-bed.global_position).abs()-original_size*.5
				var gap := Vector2(maxf(relative.x,0),maxf(relative.y,0)).length()
				minimum_gap=minf(minimum_gap,gap)
			previous=point
		assert(minimum_gap>=Enemy.RADIUS-.1,"Navigation must preserve enemy radius near bed")
		var path_points: Array=[]
		for point in path:path_points.append([point.x,point.y])
		navigation_rows.append({"from":[route.from.x,route.from.y],"to":[route.to.x,route.to.y],"waypoints":path.size(),"path":path_points,"minimum_bed_gap_pixels":minimum_gap,"all_obstacle_clearance_samples":checked_positions})
	var navigation_report := FileAccess.open("res://build/m01_room101_navigation_review.json",FileAccess.WRITE)
	navigation_report.store_string(JSON.stringify({"runtime_promoted":false,"scope":"Actual M01 navigation paths and sampled bed clearance; not live enemy steering","rows":navigation_rows},"\t"))
	# The live bridge owns a paused presentation fixture.  Navigation is sampled above
	# against the actual mission physics; autonomous guard steering is covered by the
	# dedicated movement regression, where the world is allowed to simulate normally.
	# Do not wait on an AI timer here: dialogue/presentation pauses would make an
	# otherwise complete access and collision review appear to hang.
	var steering_report := FileAccess.open("res://build/m01_room101_enemy_steering.json",FileAccess.WRITE)
	steering_report.store_string(JSON.stringify({"runtime_promoted":false,"scope":"Navigation clearance sampled against actual M01 collision world. Guard steering remains covered by the dedicated NPC movement regression; this isolated art bridge intentionally does not advance AI.","routes_checked":navigation_rows.size()},"\t"))
	var camera := room.find_children("*","Camera3D",true,false)[0] as Camera3D
	camera.current=true
	level.player.visual_projection_camera=camera
	level.player.visual_projection_origin=Vector2(176,432)
	level.player.global_position=Vector2(248,464)
	var projection := preload("res://scripts/systems/locked_floor_projection.gd")
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(-1,-1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,1).normalized(),Vector2(1,1).normalized()]:
		var movement: Vector2=level.player.project_screen_input(direction*.5)
		assert(absf(movement.length()-.5)<.001,"Preserve analog input magnitude")
		var start := camera.unproject_position(projection.to_world(level.player.global_position,Vector2(176,432)))
		var end := camera.unproject_position(projection.to_world(level.player.global_position+movement*8,Vector2(176,432)))
		assert((end-start).normalized().dot(direction)>.999)
		var mapped_mouse: Vector2=level.player.projected_mouse_point(end)
		assert(mapped_mouse.distance_to(level.player.global_position+movement*8)<.02)
	var controller_samples: Array=[]
	var laser_probe := Upgrades.LaserBeam.new()
	laser_probe.player=level.player
	level.player.add_child(laser_probe)
	laser_probe.set_process(false)
	var laser_checks := 0
	for movement in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(-1,-1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,1).normalized(),Vector2(1,1).normalized()]:
		for aim in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(-1,-1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,1).normalized(),Vector2(1,1).normalized()]:
			level.player.aim_dir=aim
			level.player.visual.update_move(movement*92.04,1.0/120)
			level.player.visual.set_aim(aim.angle())
			var beam := laser_probe.sample_beam()
			assert(not beam.is_empty())
			var floor_delta: Vector2=beam.floor_to-beam.floor_from
			var visual_delta: Vector2=beam.visual_to-beam.visual_from
			assert(floor_delta.distance_to(visual_delta)<.001)
			if floor_delta.length()>.01:assert(floor_delta.normalized().dot(aim)>.999)
			laser_checks+=1
	laser_probe.queue_free()
	var laser_report := FileAccess.open("res://build/m01_room101_laser_pairing.json",FileAccess.WRITE)
	laser_report.store_string(JSON.stringify({"runtime_3d_laser_integrated":false,"scope":"Actual LaserBeam ray/muzzle endpoint pairing across independent move/aim visual updates; not 3D barrel alignment or continuous render approval","checks":laser_checks},"\t"))
	var steady_speeds: Dictionary={}
	level.player.input_enabled=true
	for stance in ["walk","sneak","sprint"]:
		Input.action_release("sneak");Input.action_release("sprint")
		if stance!="walk":Input.action_press(stance)
		level.player.velocity=Vector2.ZERO
		level.player._adrenaline_t=0
		level.player._stagger=0
		level.player._winded=false
		level.player.stamina=level.player.STAMINA_MAX
		var command: Vector2=level.player.project_screen_input(Vector2.RIGHT)
		for tick in 240:level.player._movement(command,1.0/120)
		steady_speeds[stance]=level.player.velocity.length()
	Input.action_release("sneak");Input.action_release("sprint")
	assert(absf(float(steady_speeds.sneak)/float(steady_speeds.walk)-level.player.data.sneak_mult)<.001)
	assert(absf(float(steady_speeds.sprint)/float(steady_speeds.walk)-level.player.data.sprint_mult)<.001)
	level.player.velocity=Vector2.ZERO
	var speed_report := FileAccess.open("res://build/m01_room101_stance_speeds.json",FileAccess.WRITE)
	speed_report.store_string(JSON.stringify({"runtime_promoted":false,"scope":"Actual Player movement velocity solver under projected input; not sustained physical travel or gait contact","speeds_pixels_per_second":steady_speeds},"\t"))
	var actions := ["move_left","move_right","move_up","move_down"]
	level.player.input_enabled=true
	for stance in ["walk","sneak","sprint"]:
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(-1,-1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,1).normalized(),Vector2(1,1).normalized()]:
			level.player.global_position=Vector2(248,464)
			level.player.velocity=Vector2.ZERO
			level.player._locked_t=0
			level.player._stagger=0
			for action in actions:Input.action_release(action)
			if stance!="walk":Input.action_press(stance)
			if direction.x<0:Input.action_press("move_left")
			if direction.x>0:Input.action_press("move_right")
			if direction.y<0:Input.action_press("move_up")
			if direction.y>0:Input.action_press("move_down")
			var before := level.player.global_position
			for tick in 3:
				await get_tree().physics_frame
				level.player._physics_process(1.0/120)
			var after := level.player.global_position
			var screen_before := camera.unproject_position(projection.to_world(before,Vector2(176,432)))
			var screen_after := camera.unproject_position(projection.to_world(after,Vector2(176,432)))
			var alignment := (screen_after-screen_before).normalized().dot(direction)
			assert(after.distance_to(before)>.01 and alignment>.99)
			for action in actions:Input.action_release(action)
			Input.action_release("sneak");Input.action_release("sprint")
			for tick in 30:
				await get_tree().physics_frame
				level.player._physics_process(1.0/120)
			assert(level.player.velocity.length()<.01)
			controller_samples.append({"stance":stance,"direction":str(direction),"distance_pixels":after.distance_to(before),"screen_alignment":alignment,"stopped_velocity":level.player.velocity.length()})
	var controller_report := FileAccess.open("res://build/m01_room101_controller_projection.json",FileAccess.WRITE)
	controller_report.store_string(JSON.stringify({"runtime_promoted":false,"scope":"Actual Player input/physics callbacks; short displacement and settled braking, not gait/laser/dash approval","samples":controller_samples},"\t"))
	level.player.visual_projection_camera=null
	assert(level.player.project_screen_input(Vector2(.3,.4))==Vector2(.3,.4),"Default input unchanged")
	for light in room.find_children("*","Light3D",true,false):
		light.light_energy=.6
		if light is OmniLight3D:light.omni_range=3
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-60,-20,0)
	fill.light_energy=.7
	room.add_child(fill)
	var actor := (load("res://assets/art/cast3d_rt/cass/cass.glb") as PackedScene).instantiate() as Node3D
	room.add_child(actor)
	(actor.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer).play("idle")
	var mapping_samples: Array=[]
	for point in [Vector2(232,472),Vector2(248,464),Vector2(184,480)]:
		level.player.position=point
		await get_tree().physics_frame
		var local_floor := (level.player.global_position-Vector2(176,432))/16.0
		actor.position=Vector3(local_floor.x,0,local_floor.y)
		var screen := camera.unproject_position(actor.global_position)
		var origin := camera.project_ray_origin(screen)
		var ray := camera.project_ray_normal(screen)
		var ground := origin+ray*(-origin.y/ray.y)
		var reconstructed := Vector2(ground.x,ground.z)*16.0+Vector2(176,432)
		assert(reconstructed.distance_to(level.player.global_position)<.02,"Camera floor must map to actual mission player")
		for frame in 8:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var capture := "res://build/m01_room101_live_%d_%d.png"%[int(point.x),int(point.y)]
		get_viewport().get_texture().get_image().save_png(capture)
		mapping_samples.append({"actual_player_position":[point.x,point.y],"roundtrip_error_pixels":reconstructed.distance_to(point),"capture":capture})
	var mapping_report := FileAccess.open("res://build/m01_room101_live_bridge.json",FileAccess.WRITE)
	mapping_report.store_string(JSON.stringify({"runtime_promoted":false,"scope":"Loaded actual M01 physics/player mapped to isolated visual candidate; not full-map rendering or input conversion","bed_visual_size_pixels":[visual_size.x,visual_size.y],"bed_actual_collision_size_pixels":[original_size.x,original_size.y],"candidate_collision_size_pixels":[contact_shape.size.x,contact_shape.size.y],"candidate_contacts":contacts,"bed_body_size_pixels":[bed.rect_size.x,bed.rect_size.y],"bed_centre_error_pixels":visual_centre.distance_to(bed.global_position),"samples":mapping_samples},"\t"))

	return true
