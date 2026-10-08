extends RefCounted

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/staging/nightstand_family_v1/"

static func components(nav: AStarGrid2D) -> Dictionary:
	var labels: Dictionary={}
	var component := 0
	for y in range(nav.region.position.y,nav.region.end.y):
		for x in range(nav.region.position.x,nav.region.end.x):
			var start := Vector2i(x,y)
			if nav.is_point_solid(start) or labels.has(start):continue
			component+=1
			var queue: Array[Vector2i]=[start];labels[start]=component
			var index := 0
			while index<queue.size():
				var current := queue[index];index+=1
				# With ONLY_IF_NO_OBSTACLES diagonals, four-neighbour flood
				# has exactly the same connectivity as the live nav grid.
				for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var next: Vector2i=current+direction
					if nav.is_in_boundsv(next) and not nav.is_point_solid(next) and not labels.has(next):
						labels[next]=component;queue.append(next)
	return labels

static func build(level: Node, layer: Dressing.ClutterLayer) -> void:
	var before := components(level.nav)
	var contract: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"contract.json"))
	var frame: Dictionary=contract.frames[0]
	var texture := load(DIRECTORY+str(frame.file)) as Texture2D
	assert(texture!=null,"Nightstand render must be an imported texture")
	var extra_visuals: Dictionary={}
	for child in level.get_node("Decor").get_children():
		if child is Sprite2D and child.get_meta("decor_asset_id","")=="motel_bedside_lamp":
			var position: Vector2=child.position
			extra_visuals[position]=child
			layer.items.append(["nightstand",position,0.0,0])
	var remaining: Array=[]
	var count := 0
	var skipped: Array=[]
	var placement_trace: Array=[]
	for item in layer.items:
		if str(item[0])!="nightstand":
			remaining.append(item)
			continue
		var position: Vector2=item[1]
		var original_position := position
		# Move these two bedside pieces away from the measured door sweep.
		# Keep the authored glow registered to the same physical lamp position.
		if position==Vector2(262,600) or position==Vector2(790,600):
			position+=Vector2(-32,0)
			var pools := level.get_node_or_null("LightPools") as Dressing.ClutterLayer
			if pools!=null:
				for pool in pools.items:
					if str(pool[0])=="glow" and (pool[1] as Vector2).distance_to(original_position)<.01:
						pool[1]=position
		if position==Vector2(808,480):
			# The original lamp straddles two nav rows at the narrow passage.
			# Seat its real cabinet wholly in the room-side row instead.
			position+=Vector2(0,8)
			for light in level.get_tree().get_nodes_in_group("lights"):
				if light is Node2D and light.global_position.distance_to(original_position)<.01:
					light.global_position+=Vector2(0,8)
		var footprint := Vector2(.65,.5)*16
		var rectangle := RectangleShape2D.new()
		rectangle.size=footprint
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape=rectangle
		query.transform=Transform2D(0,position)
		query.collision_mask=Layers.WORLD|Layers.LOW|Layers.PROP
		var overlaps: Array=level.get_world_2d().direct_space_state.intersect_shape(query)
		if not overlaps.is_empty():
			var blockers: Array=[]
			for overlap in overlaps:blockers.append(str(overlap.collider.get_path()))
			skipped.append({"position":[original_position.x,original_position.y],"blockers":blockers,
				"action_required":"Redesign placement before replacing remaining legacy drawing"})
			remaining.append(item)
			continue
		var body := StaticBody2D.new()
		body.name="CandidateNightstand_%d" % count
		body.position=position;body.collision_layer=Layers.LOW;body.collision_mask=0
		var shape := CollisionShape2D.new();shape.shape=rectangle;body.add_child(shape)
		var sprite := Sprite2D.new();sprite.texture=texture;sprite.centered=false
		sprite.offset=-Vector2(frame.floor_anchor_px[0],frame.floor_anchor_px[1])
		sprite.scale=Vector2.ONE*16/float(contract.pixels_per_metre)
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		body.add_child(sprite);body.z_index=-1;level.props_root.add_child(body)
		if extra_visuals.has(original_position):extra_visuals[original_position].hide()
		var bounds := Rect2(position-footprint*.5,footprint)
		for y in range(floori(bounds.position.y/16),ceili(bounds.end.y/16)):
			for x in range(floori(bounds.position.x/16),ceili(bounds.end.x/16)):
				if level.nav.is_in_boundsv(Vector2i(x,y)):level.nav.set_point_solid(Vector2i(x,y),true)
		var current := components(level.nav)
		var mapped: Dictionary={}
		for cell in before:
			if not current.has(cell):continue
			if not mapped.has(before[cell]):mapped[before[cell]]={}
			mapped[before[cell]][current[cell]]=true
		var splits: Array=[]
		for component in mapped:
			if mapped[component].size()>1:splits.append(component)
		placement_trace.append({"position":[position.x,position.y],"split_components_after_placement":splits})
		count+=1
	layer.items=remaining
	Engine.set_meta("m01_nightstand_candidate_count",count)
	Engine.set_meta("m01_nightstand_skipped",skipped)
	var after := components(level.nav)
	var surviving_components: Dictionary={}
	var removed_cells := 0
	for cell in before:
		if not after.has(cell):
			removed_cells+=1;continue
		var original: int=before[cell]
		if not surviving_components.has(original):surviving_components[original]={}
		surviving_components[original][after[cell]]=true
	var split_components: Array=[]
	for original in surviving_components:
		if surviving_components[original].size()>1:split_components.append(original)
	Engine.set_meta("m01_nightstand_navigation_review",{"newly_reserved_cells":removed_cells,
		"placement_trace":placement_trace,
		"split_original_components":split_components,"passed":split_components.is_empty(),
		"scope":"Exact nav connectivity before/after bedside volumes; physical player-radius clearance and dynamic doors pending"})
