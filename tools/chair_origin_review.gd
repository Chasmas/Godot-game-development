extends Node2D

func _ready() -> void:
	add_child(Effects.new())
	var guard := Enemy.new()
	guard.idle_action = "snooze"
	guard.scale = Vector2(4, 4)
	add_child(guard)
	guard.set_physics_process(false)
	guard.setup(DB.enemy(&"guard"), self, Vector2.RIGHT)
	for frame in 12:
		await get_tree().process_frame
	assert(guard.idle_activity != null)
	var chair := guard.idle_activity._chair
	var model := chair.get_child(0) as PropModel
	assert(model != null)
	var imported := model._viewport.get_child(1) as Node3D
	# Camera/light children precede the prop; find the actual geometry root.
	for child in model._viewport.get_children():
		if child is Node3D and not child.find_children("*", "MeshInstance3D", true, false).is_empty():
			imported = child
	assert(imported != null)
	var bounds := model._aabb(imported)
	var top := bounds.end.y * imported.scale.y + imported.position.y
	var lowest := bounds.position.y * imported.scale.y + imported.position.y
	print("CHAIR_BOUNDS ", bounds, " scale=", imported.scale, " pos=", imported.position, " top=", top, " bottom=", lowest)
	assert(absf(top - .9) < .001)
	assert(absf(lowest) < .001)
	var cast := guard.visual.cast_sprite as CastModel
	assert(cast != null and cast.clip == "doze")
	var pelvis := guard.visual.rig.to_global(cast.seat_point())
	var lift := Vector2(0, -.45 * sin(deg_to_rad(CastModel.ELEVATION)) * 16) * chair.global_scale
	assert((chair.global_position + lift).distance_to(pelvis) < .05)
	var seated_transform := chair.global_transform
	guard._set_state(Enemy.State.SUSPICIOUS)
	assert(guard.idle_activity == null)
	for frame in 4:
		await get_tree().process_frame
	assert(is_instance_valid(chair) and chair.is_inside_tree())
	assert(chair.global_position.distance_to(seated_transform.origin) < .05)
	assert(chair.global_transform.x.distance_to(seated_transform.x) < .001)
	assert(chair.global_transform.y.distance_to(seated_transform.y) < .001)
	var probe := CharacterBody2D.new()
	probe.collision_layer=0;probe.collision_mask=Layers.LOW
	var probe_shape := CollisionShape2D.new()
	var probe_circle := CircleShape2D.new();probe_circle.radius=Player.RADIUS
	probe_shape.shape=probe_circle;probe.add_child(probe_shape);add_child(probe)
	await get_tree().physics_frame
	var blocked_sides := 0
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		var contact := KinematicCollision2D.new()
		if probe.test_move(Transform2D(0,chair.global_position+direction*60),-direction*60,contact) and contact.get_collider()==chair.floor_body:
			blocked_sides+=1
	assert(blocked_sides==4,"Chair must block a player-radius body from every side")
	assert(chair.floor_body.get_collision_exceptions().has(guard),"Occupant must be able to stand up")
	guard.position+=Vector2(100,0)
	chair._process(0.0)
	assert(not chair.floor_body.get_collision_exceptions().has(guard),"Occupant exception must expire after leaving")
	print("CHAIR SOLID: four sides blocked; occupant exception expires after exit")
	print("CHAIR_ORIGIN: top=", top, " floor=", lowest, "; wake preserves chair")
	Game.request_quit(0)
