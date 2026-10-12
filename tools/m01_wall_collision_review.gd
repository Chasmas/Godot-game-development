extends Node

func _ready() -> void:
	Engine.set_meta("skip_tasks",true)
	Engine.set_meta("autoplay",true)
	await get_tree().process_frame
	var placeholder:=Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene=placeholder
	Game.campaign_mode=false
	Game.replay_mission("m01_checkout")
	var level: Level
	for frame in 180:
		await get_tree().process_frame
		level=get_tree().get_first_node_in_group("level") as Level
		if level!=null and is_instance_valid(level.player):break
	assert(level!=null and is_instance_valid(level.player))
	Dialogue._end(false)
	get_tree().paused=false
	var player:=level.player
	var state:=player.get_world_2d().direct_space_state
	var ray:=PhysicsRayQueryParameters2D.new()
	ray.collision_mask=player.collision_mask
	ray.exclude=[player.get_rid()]
	var starts: Array[Vector2]=[player.global_position,Vector2(208,464),Vector2(224,300),Vector2(400,464)]
	var hit: Dictionary={}
	for origin in starts:
		for direction in 32:
			ray.from=origin
			ray.to=origin+Vector2.from_angle(direction*TAU/32)*320
			var candidate:=state.intersect_ray(ray)
			if not candidate.is_empty() and candidate.collider is StaticBody2D:
				hit=candidate
				break
		if not hit.is_empty():break
	assert(not hit.is_empty(),"A real M01 solid wall must be available for collision review")
	var normal: Vector2=hit.normal
	player.global_position=hit.position+normal*(Player.RADIUS+3.0)
	player.velocity=Vector2.ZERO
	var before:=player.global_position
	var blocked:=false
	for tick in 120:
		player.velocity=-normal*80.0
		player.move_and_slide()
		blocked=blocked or player.get_slide_collision_count()>0
	var after:=player.global_position
	# Positive only if the centre reached the opposite side of the impact plane.
	var penetration: float=(after-hit.position).dot(-normal)
	assert(blocked,"Cass must collide with an M01 solid wall")
	assert(penetration<=0.02,"Cass must not cross a wall")
	assert(after.distance_to(before)<12.0,"Cass may only close the intentional pre-wall gap")
	var cast:=player.visual.cast_sprite as CastModel
	assert(cast!=null)
	print("M01 WALL COLLISION PASSED radius=",Player.RADIUS," start=",before," end=",after," penetration=",penetration)
	Game.request_quit(0)
