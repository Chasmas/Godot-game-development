extends Node

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/staging/bed_family_v1/"

func _ready() -> void:
	var saved_postfx: Dictionary={}
	if OS.get_environment("M01_REVIEW_CLEAR_VHS")=="1":
		# Isolated art-direction trial; preserve the user's actual settings.
		for parameter in {"scanline_strength":.08,"grain":.012,"chroma":.3,"vignette":.22,"bloom":.25}:
			saved_postfx[parameter]=PostFX.mat.get_shader_parameter(parameter)
			PostFX.mat.set_shader_parameter(parameter,{"scanline_strength":.08,"grain":.012,"chroma":.3,"vignette":.22,"bloom":.25}[parameter])
	Engine.set_meta("skip_tasks",true)
	Engine.set_meta("autoplay",true)
	Engine.set_meta("review_m01_nightstands",true)
	if OS.get_environment("M01_REVIEW_RUNTIME_RUGS")=="1":Engine.set_meta("review_m01_runtime_rugs",true)
	if OS.get_environment("M01_REVIEW_DRESSERS")=="1":Engine.set_meta("review_m01_dressers",true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var saved_path := SaveManager.save_path
	SaveManager.save_path="user://m01_native_bed_review_save.json"
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene=placeholder
	Game.campaign_mode=false
	Game.replay_mission("m01_checkout")
	for frame in 120: await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	if OS.get_environment("M01_REVIEW_WALLS")=="1":load("res://tools/m01_wall_candidate.gd").attach(level)
	Dialogue._end(false)
	Dialogue.set_process(false)
	level.player.input_enabled=false
	level.player.set_physics_process(false)
	level.player.visual.update_move(Vector2.ZERO,0)
	for enemy in level.enemies:
		enemy.set_physics_process(false)
		enemy.visual.update_move(Vector2.ZERO,0)
	var chair_layout: Array=[]
	var chair_circulation: Node=load("res://tools/m01_architecture_game_review.gd").new()
	for enemy in level.enemies:
		if enemy.idle_activity==null or enemy.idle_activity._chair==null:continue
		var chair: Node2D=enemy.idle_activity._chair
		if not "floor_body" in chair or chair.floor_body==null:continue
		var body: StaticBody2D=chair.floor_body
		var shape := body.get_child(0) as CollisionShape2D
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape=shape.shape;query.transform=shape.global_transform
		query.collision_mask=Layers.WORLD|Layers.LOW|Layers.PROP
		query.exclude=[body.get_rid()]
		var blockers: Array=[]
		for hit in level.get_world_2d().direct_space_state.intersect_shape(query):
			blockers.append(str(hit.collider.get_path()))
		var door_hits: int=chair_circulation.chair_door_arc_hits(chair.global_position,get_tree(),Vector2(8.53,8.85))
		var player_contacts := 0
		var ignored_occupant: bool=level.player.get_collision_exceptions().has(enemy)
		level.player.add_collision_exception_with(enemy)
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			var from := Transform2D(0,chair.global_position+direction*28)
			if level.player.test_move(from,Vector2.ZERO):continue
			var contact := KinematicCollision2D.new()
			if level.player.test_move(from,-direction*28,contact) and contact.get_collider()==body:
				player_contacts+=1
		if not ignored_occupant:level.player.remove_collision_exception_with(enemy)
		assert(player_contacts>0,"Assembled chair must block actual Cass from an accessible side")
		assert(blockers.is_empty() and door_hits==0,"Sleeping chair overlaps furnishing or a reachable door swing")
		var reserved: Array[Vector2i]=level._reserve_navigation_obstacles()
		for cell in reserved:level.nav.set_point_solid(cell,false)
		var routes_checked := 0
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			var start := level.nearest_open_point(chair.global_position+direction*32,enemy.position)
			var path: PackedVector2Array=level.get_nav_path(start,chair.global_position)
			for cell in reserved:assert(not level.nav.is_point_solid(cell),"Dynamic query changed static navigation")
			if path.is_empty():continue
			for point in path:
				var cell := Vector2i(floori(point.x/16),floori(point.y/16))
				assert(not reserved.has(cell),"NPC route crosses a sleeping chair")
			routes_checked+=1
		assert(routes_checked>0,"Chair approach must retain a reachable projected destination")
		chair_layout.append({"enemy_id":enemy.enemy_id,"position":[chair.global_position.x,chair.global_position.y],"solid_overlap_free":blockers.is_empty(),"blockers":blockers,"actual_player_contact_directions":player_contacts,"navigation_routes_checked":routes_checked,"reachable_door_arc_hits":door_hits})
	chair_circulation.free()
	var chair_report := FileAccess.open("res://build/m01_sleeping_chair_layout.json",FileAccess.WRITE)
	chair_report.store_string(JSON.stringify({"chairs":chair_layout,"scope":"Assembled M01 physics footprints, reachable door arcs and dynamic navigation routes; actual NPC steering playtest remains pending"},"  "));chair_report.close()
	var cast_states: Array=[]
	for enemy in level.enemies:
		var vis: CharacterVisual=enemy.visual
		var cast := vis.cast_sprite
		if cast==null:continue
		cast_states.append({"id":enemy.enemy_id,"look":enemy.look,"position":[enemy.position.x,enemy.position.y],"clip":cast.clip,"idle_pose":vis.idle_activity_pose,"weapon_visible":vis.weapon_sprite.visible,"visual_scale":[vis.scale.x,vis.scale.y],"rig_scale":[vis.rig.scale.x,vis.rig.scale.y],"cast_scale":[cast.scale.x,cast.scale.y],"hand": [cast.grip().x,cast.grip().y],"weapon":str(enemy.weapon.data.id) if enemy.weapon else ""})
	var cast_report := FileAccess.open("res://build/m01_live_cast_states.json",FileAccess.WRITE)
	cast_report.store_string(JSON.stringify(cast_states,"  "));cast_report.close()
	level.hud.hide()
	for child in level.get_children():
		if child is IntroCall or child is LevelIntro: child.hide()
	level.camera.set_process(false)
	level.camera.set_physics_process(false)
	level.camera.global_position=Vector2(390,116)
	level.camera.zoom=Vector2(2.5,2.5)
	var contract: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"contract.json"))
	var placements: Array=[]
	var nightstand_physics: Array=[]
	var circulation_helper: Node=load("res://tools/m01_architecture_game_review.gd").new()
	for body in level.props_root.get_children():
		if not body is StaticBody2D or not str(body.name).begins_with("CandidateNightstand_"): continue
		var shape := body.get_child(0) as CollisionShape2D
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape=shape.shape
		query.transform=body.global_transform
		query.collision_mask=Layers.WORLD|Layers.LOW|Layers.PROP
		query.exclude=[body.get_rid()]
		var blockers: Array=[]
		for hit in level.get_world_2d().direct_space_state.intersect_shape(query):
			blockers.append(str(hit.collider.get_path()))
		query.collision_mask=0xFFFFFFFF
		var actor_overlaps: Array=[]
		for hit in level.get_world_2d().direct_space_state.intersect_shape(query):
			if hit.collider is CharacterBody2D:
				actor_overlaps.append(str(hit.collider.get_path()))
		assert(actor_overlaps.is_empty(),"Nightstand occupies a live actor footprint")
		var point := PhysicsPointQueryParameters2D.new()
		point.position=body.global_position;point.collision_mask=Layers.LOW
		var hits := level.get_world_2d().direct_space_state.intersect_point(point)
		assert(hits.any(func(hit):return hit.collider==body),"Nightstand collider must be registered")
		# Isolate this collider to prove it stops movement from each side.
		# This checks the object volume; room traversal is a separate gate.
		var circle := CircleShape2D.new();circle.radius=Player.RADIUS
		var sweep := PhysicsShapeQueryParameters2D.new();sweep.shape=circle
		sweep.collision_mask=Layers.LOW
		var excluded: Array[RID]=[]
		for other in level.find_children("*","CollisionObject2D",true,false):
			if other!=body:excluded.append(other.get_rid())
		sweep.exclude=excluded
		var fractions: Array=[]
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			sweep.transform=Transform2D(0,body.global_position+direction*30)
			sweep.motion=-direction*30
			var motion := level.get_world_2d().direct_space_state.cast_motion(sweep)
			assert(motion[0]<.9,"Movement must stop before entering nightstand centre")
			fractions.append(motion[0])
		var clear_approaches: int=circulation_helper.clear_chair_approaches(level,body.global_position,13.0)
		# This existing helper uses a larger 13.88x13.4 occupied rectangle,
		# conservatively enclosing the cabinet's measured 10.4x8 footprint.
		var door_arc_hits: int=circulation_helper.chair_door_arc_hits(body.global_position,get_tree())
		var exact_door_arc_hits: int=circulation_helper.chair_door_arc_hits(body.global_position,get_tree(),(shape.shape as RectangleShape2D).size+Vector2(3,3))
		nightstand_physics.append({"position":[body.position.x,body.position.y],"registered_solid":true,"actor_overlap_free":actor_overlaps.is_empty(),"actor_overlaps":actor_overlaps,
			"overlap_free":blockers.is_empty(),"blockers":blockers,"four_sides_safe_fractions":fractions,
			"clear_player_approaches":clear_approaches,"conservative_door_arc_hits":door_arc_hits,
			"measured_footprint_with_leaf_thickness_hits":exact_door_arc_hits})
	circulation_helper.free()
	var nearby_dressing: Array=[]
	# Inventory every dresser source before replacing drawings or reserving nav.
	# A visible cabinet must have a placement-specific physical contract.
	var dresser_inventory: Array=[]
	var rug_inventory: Array=[]
	var rug_geometry_review: Array=[]
	var rug_rooms: Array=Dressing._find_rooms(level.builder)
	# Audit visual ownership before replacing any damageable TV. Sharing a
	# room does not prove two objects are duplicates: record positions first.
	var television_ownership: Array=[]
	for prop in level.props_root.get_children():
		if not prop is BreakableProp or prop.kind!="tv":continue
		var tv_room := -1
		for room in rug_rooms:
			if room.cells.has(Vector2i(floori(prop.position.x/16),floori(prop.position.y/16))):tv_room=room.id;break
		var cabinets: Array=[]
		for cabinet in level.props_root.get_children():
			if not str(cabinet.name).begins_with("CandidateDresser_"):continue
			for room in rug_rooms:
				if room.id==tv_room and room.cells.has(Vector2i(floori(cabinet.position.x/16),floori(cabinet.position.y/16))):
					cabinets.append({"name":str(cabinet.name),"position":[cabinet.position.x,cabinet.position.y],"distance_px":prop.position.distance_to(cabinet.position)})
		television_ownership.append({"position":[prop.position.x,prop.position.y],"room_id":tv_room,"damageable":prop.is_in_group("damageable"),"same_room_cabinets":cabinets})
	var ownership_report := FileAccess.open("res://build/m01_television_ownership_review.json",FileAccess.WRITE)
	ownership_report.store_string(JSON.stringify({"televisions":television_ownership,"replacements_applied":false},"  "))
	ownership_report.close()
	for child in level.get_children():
		if not child is Sprite2D or not (str(child.name).begins_with("CandidateWovenRug_") or str(child.name).begins_with("NativeWovenRug_")):continue
		# ImageTexture has no resource path: record the authored orientation
		# explicitly on the candidate instead of inferring it from pixels.
		var vertical := bool(child.get_meta("rug_vertical",false))
		var footprint := Vector2(.75,1.576)*16 if vertical else Vector2(1.576,.75)*16
		var bounds := Rect2(child.position-footprint*.5,footprint)
		var cells: Array[Vector2i]=[]
		for y in range(floori(bounds.position.y/16),ceili(bounds.end.y/16)):
			for x in range(floori(bounds.position.x/16),ceili(bounds.end.x/16)):cells.append(Vector2i(x,y))
		var room_id := -1
		for room in rug_rooms:
			if room.cells.has(Vector2i(floori(child.position.x/16),floori(child.position.y/16))):room_id=room.id;break
		var spills: Array=[]
		for cell in cells:
			var matching := false
			for room in rug_rooms:
				if room.id==room_id and room.cells.has(cell):matching=true;break
			if not matching:spills.append([cell.x,cell.y])
		var image: Image=child.texture.get_image()
		var alpha_spill := 0;var visible_pixels := 0
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x,y).a<.05:continue
				visible_pixels+=1
				var projected: Vector2=child.position+(Vector2(x+.5,y+.5)+child.offset)*child.scale
				var cell := Vector2i(floori(projected.x/16),floori(projected.y/16))
				var same_room := false
				for room in rug_rooms:
					if room.id==room_id and room.cells.has(cell):same_room=true;break
				if not same_room:alpha_spill+=1
		rug_geometry_review.append({"name":str(child.name),"position":[child.position.x,child.position.y],"footprint_px":[footprint.x,footprint.y],"room_id":room_id,"outside_room_cells":spills,"visible_source_pixels":visible_pixels,"projected_alpha_pixels_outside_room":alpha_spill})
		assert(room_id>=0 and spills.is_empty(),"Woven rug footprint must stay inside one authored room")
		if alpha_spill>0:print("RUG ALPHA SPILL: %s at %s: %d pixels" % [child.name,child.position,alpha_spill])
	for dressing_layer in level.get_children():
		if dressing_layer is Dressing.ClutterLayer:
			for item in dressing_layer.items:
				if str(item[0])=="rug_big":rug_inventory.append({"position":[item[1].x,item[1].y],"rotation":float(item[2])})
				if str(item[0])!="dresser_tv":continue
				var position: Vector2=item[1]
				dresser_inventory.append({"source":"room_kit","position":[position.x,position.y],"rotation":float(item[2])})
	for child in level.get_node("Decor").get_children():
		if child is Sprite2D and child.visible and child.get_meta("decor_asset_id","")=="hq_motel_dresser":
			dresser_inventory.append({"source":"decor","position":[child.position.x,child.position.y],"rotation":child.rotation})
	var dresser_report := FileAccess.open("res://build/m01_dresser_integrated_review.json" if Engine.has_meta("review_m01_dressers") else "res://build/m01_dresser_inventory.json",FileAccess.WRITE)
	var dresser_bodies: Array=[]
	for body in level.props_root.get_children():
		if not body is StaticBody2D or not str(body.name).begins_with("CandidateDresser_"):continue
		var shape := body.get_child(0) as CollisionShape2D
		var query := PhysicsShapeQueryParameters2D.new();query.shape=shape.shape
		query.transform=body.global_transform;query.collision_mask=Layers.WORLD|Layers.LOW|Layers.PROP;query.exclude=[body.get_rid()]
		var overlaps := level.get_world_2d().direct_space_state.intersect_shape(query)
		assert(overlaps.is_empty(),"Dresser overlaps a solid object")
		var circle := CircleShape2D.new();circle.radius=Player.RADIUS
		var sweep := PhysicsShapeQueryParameters2D.new();sweep.shape=circle;sweep.collision_mask=Layers.LOW
		var excluded: Array[RID]=[]
		for other in level.find_children("*","CollisionObject2D",true,false):
			if other!=body:excluded.append(other.get_rid())
		sweep.exclude=excluded
		var fractions: Array=[];var player_contacts := 0
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			sweep.transform=Transform2D(0,body.global_position+direction*40)
			sweep.motion=-direction*40
			var result := level.get_world_2d().direct_space_state.cast_motion(sweep)
			assert(result[0]<.9,"Dresser must stop player-radius motion on all four sides")
			fractions.append(result[0])
			var from := Transform2D(0,body.global_position+direction*32)
			if level.player.test_move(from,Vector2.ZERO):continue
			var contact := KinematicCollision2D.new()
			if level.player.test_move(from,-direction*32,contact) and contact.get_collider()==body:player_contacts+=1
		assert(player_contacts>0,"Actual player body must contact the dresser from an accessible side")
		# Solid-only checks miss actors spawned inside newly placed furniture.
		query.collision_mask = 0xFFFFFFFF
		var actor_overlaps: Array = []
		for hit in level.get_world_2d().direct_space_state.intersect_shape(query, 128):
			if hit.collider is CharacterBody2D:
				actor_overlaps.append({"path":str(hit.collider.get_path()),"position":[hit.collider.global_position.x,hit.collider.global_position.y],"script":hit.collider.get_script().resource_path})
		assert(actor_overlaps.is_empty(), "Dresser occupies a live actor footprint")
		dresser_bodies.append({"position":[body.position.x,body.position.y],"overlap_free":true,"four_side_safe_fractions":fractions,"actual_player_contact_directions":player_contacts,"actor_overlap_free":actor_overlaps.is_empty(),"actor_overlaps":actor_overlaps})
	if Engine.has_meta("review_m01_dressers"):assert(dresser_bodies.size()==7)
	var dresser_circulation: Node=load("res://tools/m01_architecture_game_review.gd").new()
	var dresser_nav_helper: RefCounted=load("res://tools/m01_nightstand_candidate.gd").new()
	var original_components: Dictionary=dresser_nav_helper.components(level.nav)
	var reserved_dresser_cells: Array[Vector2i]=[]
	var authored_rooms: Array=Dressing._find_rooms(level.builder)
	for entry in dresser_inventory:
		var centre := Vector2(entry.position[0],entry.position[1])
		if centre==Vector2(843,632):
			# The east-wall cabinet cannot fit this narrow room with its long
			# axis north/south. Test a south-wall layout facing into the room.
			entry["rotation"]=PI
		if centre==Vector2(360,437):entry["rotation"]=0.0
		var source_cell := Vector2i(floori(centre.x/16),floori(centre.y/16))
		var source_room_cells: Array[Vector2i]=[]
		for room in authored_rooms:
			if room.cells.has(source_cell):source_room_cells=room.cells;break
		assert(not source_room_cells.is_empty(),"Dresser source must belong to an authored room")
		var quarter := posmod(roundi(float(entry.rotation)/(PI*.5)),4)
		var footprint := Vector2(1.62,.5)*16
		if quarter%2==1:footprint=Vector2(footprint.y,footprint.x)
		var rectangle := RectangleShape2D.new();rectangle.size=footprint
		var query := PhysicsShapeQueryParameters2D.new();query.shape=rectangle
		query.transform=Transform2D(0,centre);query.collision_mask=Layers.WORLD|Layers.LOW|Layers.PROP
		var blockers: Array=[]
		for hit in level.get_world_2d().direct_space_state.intersect_shape(query):blockers.append(str(hit.collider.get_path()))
		entry["candidate_footprint_px"]=[footprint.x,footprint.y]
		entry["current_position_blockers"]=blockers
		entry["reachable_door_arc_hits"]=dresser_circulation.chair_door_arc_hits(centre,get_tree(),footprint+Vector2(3,3))
		var proposals: Array=[]
		# Search only nearby authored floor: this is a placement proposal, not
		# permission to move a cabinet into another room or remove a prop.
		for offset_y in range(-64,65,8):
			for offset_x in range(-64,65,8):
				var proposed := centre+Vector2(offset_x,offset_y)
				if centre==Vector2(360,437) and proposed.y<445:continue
				var bounds := Rect2(proposed-footprint*.5,footprint)
				var valid_floor := true
				for corner in [bounds.position,bounds.end,Vector2(bounds.position.x,bounds.end.y),Vector2(bounds.end.x,bounds.position.y)]:
					var cell := Vector2i(floori(corner.x/16),floori(corner.y/16))
					if not source_room_cells.has(cell) or not level.nav.is_in_boundsv(cell) or level.nav.is_point_solid(cell):valid_floor=false
				if not valid_floor:continue
				query.transform=Transform2D(0,proposed)
				if not level.get_world_2d().direct_space_state.intersect_shape(query).is_empty():continue
				if dresser_circulation.chair_door_arc_hits(proposed,get_tree(),footprint+Vector2(3,3))>0:continue
				var approaches: int=dresser_circulation.clear_chair_approaches(level,proposed,footprint.length()*.5+Player.RADIUS+1)
				if approaches==0:continue
				proposals.append({"position":[proposed.x,proposed.y],"distance":proposed.distance_to(centre),"clear_player_approaches":approaches})
		proposals.sort_custom(func(a,b):return float(a.distance)<float(b.distance))
		var selected: Dictionary={}
		for proposal in proposals:
			var proposed := Vector2(proposal.position[0],proposal.position[1])
			var bounds := Rect2(proposed-footprint*.5,footprint)
			var reserved: Array[Vector2i]=[]
			for y in range(floori(bounds.position.y/16),ceili(bounds.end.y/16)):
				for x in range(floori(bounds.position.x/16),ceili(bounds.end.x/16)):
					var cell := Vector2i(x,y)
					if not level.nav.is_point_solid(cell):
						level.nav.set_point_solid(cell,true);reserved.append(cell)
			var after: Dictionary=dresser_nav_helper.components(level.nav)
			var mapped: Dictionary={}
			for cell in original_components:
				if not after.has(cell):continue
				var old_component: int=original_components[cell]
				if not mapped.has(old_component):mapped[old_component]={}
				mapped[old_component][after[cell]]=true
			var splits := false
			for component in mapped:
				if mapped[component].size()>1:splits=true
			if not splits:
				selected=proposal.duplicate(true)
				selected["newly_reserved_cells"]=reserved.size()
				reserved_dresser_cells.append_array(reserved)
				break
			for cell in reserved:level.nav.set_point_solid(cell,false)
		entry["selected_navigation_safe_proposal"]=selected
		entry["placement_proposals"]=proposals.slice(0,5)
		entry["proposal_scope"]="All footprint corners remain in original authored room; actual physics, reachable door arcs, player approach and cumulative navigation checked; visual composition pending"
	dresser_circulation.free()
	for cell in reserved_dresser_cells:level.nav.set_point_solid(cell,false)
	dresser_nav_helper=null
	dresser_report.store_string(JSON.stringify({"runtime_approved":false,"placements":dresser_inventory,"rugs":rug_inventory,"rug_geometry":rug_geometry_review,"integrated_bodies":dresser_bodies,"assembled_navigation":Engine.get_meta("m01_dresser_navigation_review",{})},"  "))
	var decorative_beds: Array=[]
	for child in level.get_node("Decor").get_children():
		if child is Sprite2D and child.get_meta("decor_asset_id","")=="hq_motel_bed":
			var frame: Dictionary=contract.frames[0]
			var image := Image.load_from_file(DIRECTORY+str(frame.file))
			assert(image!=null)
			child.texture=ImageTexture.create_from_image(image)
			child.centered=false
			child.offset=-Vector2(frame.floor_anchor_px[0],frame.floor_anchor_px[1])
			var physical_scale := 30.0/2.16
			child.scale=Vector2.ONE*physical_scale/float(contract.pixels_per_metre)
			child.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			var body := StaticBody2D.new()
			body.name="ReviewedDecorativeBedCollider"
			body.position=child.position
			body.collision_layer=Layers.LOW
			body.collision_mask=0
			var shape := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size=Vector2(1.72,2.16)*physical_scale
			shape.shape=rectangle
			body.add_child(shape)
			level.props_root.add_child(body)
			var overlap_query := PhysicsShapeQueryParameters2D.new()
			overlap_query.shape=rectangle
			overlap_query.collision_mask=Layers.WORLD|Layers.LOW|Layers.PROP
			overlap_query.exclude=[body.get_rid()]
			var authored_position: Vector2 = child.position
			var offsets: Array[Vector2]=[Vector2.ZERO]
			for distance in [8,16,24,32]:
				for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
					offsets.append(direction*distance)
			var cleared := false
			for offset in offsets:
				overlap_query.transform=Transform2D(0,authored_position+offset)
				if level.get_world_2d().direct_space_state.intersect_shape(overlap_query).is_empty():
					body.position=authored_position+offset
					child.position=body.position
					cleared=true
					break
			if not cleared:
				# Never present an intersecting collider as a finished placement.
				# Keep the evidence and remove this invalid visual from the proof.
				overlap_query.transform=Transform2D(0,authored_position)
				var blockers: Array=[]
				for hit in level.get_world_2d().direct_space_state.intersect_shape(overlap_query):
					blockers.append(str(hit.collider.get_path()))
				decorative_beds.append({"original_position":[authored_position.x,authored_position.y],
					"solid_overlap_free":false,"blockers":blockers,
					"candidate_removed":true,"action_required":"Redesign this room placement before integration"})
				child.hide()
				body.queue_free()
				continue
			var bounds := Rect2(body.position-rectangle.size*.5,rectangle.size)
			var reserved: Array=[]
			for y in range(floori(bounds.position.y/16),ceili(bounds.end.y/16)):
				for x in range(floori(bounds.position.x/16),ceili(bounds.end.x/16)):
					if level.nav.is_in_boundsv(Vector2i(x,y)):
						level.nav.set_point_solid(Vector2i(x,y),true)
						reserved.append([x,y])
			decorative_beds.append({"position":[child.position.x,child.position.y],"physical_body_present":true,
				"original_position":[authored_position.x,authored_position.y],"solid_overlap_free":cleared,
				"footprint_px":[rectangle.size.x,rectangle.size.y],"reserved_cells":reserved,
				"action_required":"Check wall overlap and door/player traversal before runtime approval"})
	for layer in level.get_children():
		if layer is Furnish.FurnitureLayer or layer is Dressing.ClutterLayer:
			for item in layer.items:
				var centre: Vector2=item[1].get_center() if item[1] is Rect2 else item[1]
				if centre.distance_to(Vector2(80,144))<40:
					nearby_dressing.append({"kind":str(item[0]),"position":[centre.x,centre.y],"layer":str(layer.name)})
	for object in get_tree().get_nodes_in_group("furniture"):
		if not object is Furniture or object.kind!="bed": continue
		var body := object as Furniture
		# Original beds use a west-facing headboard. Preserve that layout while
		# testing the same physical model at a uniform scale (no image stretch).
		var index := 1
		var footprint := Vector2(2.16,1.72) if index==1 else Vector2(1.72,2.16)
		var physical_scale := minf((body.rect_size.x-2)/footprint.x,(body.rect_size.y-2)/footprint.y)
		var frame: Dictionary=contract.frames[index]
		var texture := load(DIRECTORY+str(frame.file)) as Texture2D
		assert(texture!=null)
		var sprite := body.get_node_or_null("NativeBlenderBed") as Sprite2D
		if sprite==null:
			sprite=Sprite2D.new()
			body.add_child(sprite)
		sprite.texture=texture
		sprite.centered=false
		sprite.offset=-Vector2(frame.floor_anchor_px[0],frame.floor_anchor_px[1])
		sprite.scale=Vector2.ONE*physical_scale/float(contract.pixels_per_metre)
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.light_mask=body.light_mask
		body.self_modulate.a=0
		var shape := body.get_child(0) as CollisionShape2D
		assert(shape!=null and shape.shape is RectangleShape2D)
		var collider := (shape.shape as RectangleShape2D).size
		var rendered_footprint := footprint*physical_scale
		assert(collider.x>=rendered_footprint.x-.001 and collider.y>=rendered_footprint.y-.001)
		var query := PhysicsPointQueryParameters2D.new()
		query.position=body.global_position
		query.collision_mask=Layers.LOW
		var hits := level.get_world_2d().direct_space_state.intersect_point(query)
		assert(hits.any(func(hit): return hit.collider==body),"Bed must retain solid footprint")
		placements.append({"position":[body.position.x,body.position.y],"facing_index":index,
			"footprint_px":[rendered_footprint.x,rendered_footprint.y],"collider_px":[collider.x,collider.y]})
	assert(not placements.is_empty())
	var furniture_exposure := 1.0
	if not OS.get_environment("M01_REVIEW_FURNITURE_EXPOSURE").is_empty():
		furniture_exposure=clampf(float(OS.get_environment("M01_REVIEW_FURNITURE_EXPOSURE")),.25,1.0)
	for body in level.props_root.get_children():
		if body is StaticBody2D and str(body.name).begins_with("CandidateNightstand_"):
			for child in body.get_children():
				if child is Sprite2D:child.modulate=Color(furniture_exposure,furniture_exposure,furniture_exposure)
	for body in get_tree().get_nodes_in_group("furniture"):
		if body is Furniture and body.has_node("NativeBlenderBed"):
			body.get_node("NativeBlenderBed").modulate=Color(furniture_exposure,furniture_exposure,furniture_exposure)
	if DisplayServer.get_name() != "headless":
		for frame in 12: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_native_bed_candidate.png")
		for review in [
			["west_rooms",Vector2(176,112)],
			["east_rooms",Vector2(848,72)],
			["southwest_rooms",Vector2(304,584)],
			["southeast_rooms",Vector2(800,584)]]:
			level.camera.global_position=review[1]
			level.camera.zoom=Vector2(3,3)
			for frame in 8:await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/m01_bedside_%s_exposure_%s_walls_%s_dressers_%s.png" % [review[0],str(furniture_exposure),str(Engine.has_meta("m01_combined_wall_review")),str(Engine.has_meta("review_m01_dressers"))])
		if Engine.has_meta("review_m01_dressers"):
			for body in level.props_root.get_children():
				if not body is StaticBody2D or not str(body.name).begins_with("CandidateDresser_"):continue
				level.camera.global_position=body.global_position+Vector2(0,12)
				level.camera.zoom=Vector2(5,5)
				for frame in 8:await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://build/m01_%s_composition.png" % str(body.name).to_lower())
				if str(body.name)=="CandidateDresser_3" and Engine.has_meta("m01_combined_wall_review"):
					var mask := OS.get_environment("M01_NATIVE_WALL_LIGHT_MASK")
					get_viewport().get_texture().get_image().save_png("res://build/m01_wall_lighting_mask%s.png" % mask)
					var postfx_visible: bool=PostFX.rect.visible
					PostFX.rect.hide()
					for frame in 8:await get_tree().process_frame
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png("res://build/m01_wall_lighting_mask%s_no_postfx.png" % mask)
					PostFX.rect.visible=postfx_visible
			# Capture identical framing with/without walls: identify projection
			# occlusion before changing placement or compromising physical volume.
			for review in [["north",Vector2(560,64)],["west",Vector2(219,72)]]:
				level.camera.global_position=review[1];level.camera.zoom=Vector2(5,5)
				for frame in 8:await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://build/m01_dresser_%s_walls.png" % review[0])
				var hidden: Array[CanvasItem]=[]
				for name in ["Walls","WallArt","WallDressing"]:
					var node := level.get_node_or_null(name) as CanvasItem
					if node!=null and node.visible:hidden.append(node);node.hide()
				for frame in 8:await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://build/m01_dresser_%s_no_walls.png" % review[0])
				for node in hidden:node.show()
	var report := FileAccess.open("res://build/m01_native_bed_review.json",FileAccess.WRITE)
	var nightstand_count := int(Engine.get_meta("m01_nightstand_candidate_count",0))
	assert(nightstand_count>0,"Bedside candidate must actually be placed")
	report.store_string(JSON.stringify({"runtime_approved":false,"legacy_nightstands_pending":Engine.get_meta("m01_nightstand_skipped",[]),"nightstand_navigation":Engine.get_meta("m01_nightstand_navigation_review",{}),"nightstand_count":nightstand_count,"nightstand_physics":nightstand_physics,"placements":placements,"nearby_dressing":nearby_dressing,"legacy_decorative_beds":decorative_beds,
		"scope":"Staging furniture assembly: original bed colliders retained; bedside volumes, four-side isolated sweeps, live actor overlap and navigation connectivity checked. Full visual composition and lighting approval remain pending."},"  "))
	SaveManager.data=saved
	SaveManager.save_path=saved_path
	Dialogue.set_process(true)
	for parameter in saved_postfx:PostFX.mat.set_shader_parameter(parameter,saved_postfx[parameter])
	print("M01 BED REVIEW: %d coherent beds; uniform scale; original solid colliders retained" % placements.size())
	print("M01 NIGHTSTAND REVIEW: %d coherent cabinets with solid footprints, original drawings removed before baking" % nightstand_count)
	Game.request_quit(0)
