extends Node

func _ready() -> void:
	Engine.set_meta("skip_tasks",true);Engine.set_meta("autoplay",true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var saved_path := SaveManager.save_path
	SaveManager.save_path="user://m01_chair_steering_review_save.json"
	var placeholder := Node.new();get_tree().root.add_child(placeholder);get_tree().current_scene=placeholder
	Game.campaign_mode=false;Game.replay_mission("m01_checkout")
	for frame in 120:await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	Dialogue._end(false);Dialogue.set_process(false)
	level.player.input_enabled=false;level.player.set_physics_process(false)
	var sleeper: Enemy
	for enemy in level.enemies:
		enemy.set_physics_process(false)
		if enemy.enemy_id=="e_45,14":sleeper=enemy
	assert(sleeper!=null and sleeper.idle_activity!=null)
	var chair: Node2D=sleeper.idle_activity._chair
	var rows: Array=[]
	for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
		var start: Vector2= chair.global_position-direction*32
		var target: Vector2= chair.global_position+direction*32
		var probe := Enemy.new();probe.enemy_id="chair_steering_probe";probe.idle_action="watch"
		probe.position=start;probe.patrol_points=PackedVector2Array([target])
		level.actors_root.add_child(probe);probe.setup(DB.enemy(&"guard"),level,direction)
		probe._perceive_t=99999
		for other in level.enemies:probe.add_collision_exception_with(other)
		await get_tree().physics_frame
		assert(not probe.test_move(probe.global_transform,Vector2.ZERO),"Steering start must be clear")
		var minimum_clearance := INF;var frames := 0;var walking_seen := false
		for frame in 360:
			await get_tree().physics_frame;frames+=1
			probe._perceive_t=99999
			var local: Vector2= chair.floor_body.to_local(probe.global_position)
			var half := Vector2(.533,.553)*8
			var gap := Vector2(maxf(absf(local.x)-half.x,0),maxf(absf(local.y)-half.y,0)).length()
			minimum_clearance=minf(minimum_clearance,gap)
			if probe.get_real_velocity().length()>5 and probe.visual.cast_sprite.clip.contains("walk"):walking_seen=true
			if probe.global_position.distance_to(target)<8:break
		var remaining := probe.global_position.distance_to(target)
		assert(remaining<8,"Actual controller failed to walk around chair")
		assert(minimum_clearance>Enemy.RADIUS-.6,"Enemy body penetrated chair")
		assert(walking_seen,"Moving enemy must show locomotion")
		rows.append({"direction":[direction.x,direction.y],"frames":frames,"remaining_distance":remaining,"minimum_clearance":minimum_clearance,"walking_seen":walking_seen})
		probe.queue_free();await get_tree().physics_frame
	var report := FileAccess.open("res://build/m01_chair_steering_review.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"scope":"Actual Enemy patrol controller around one M01 sleeping chair; other actors ignored to isolate furniture steering","passed":true,"rows":rows},"  "));report.close()
	SaveManager.data=saved;SaveManager.save_path=saved_path;Dialogue.set_process(true)
	print("M01 CHAIR STEERING: four actual patrol routes completed")
	Game.request_quit(0)
