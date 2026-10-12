extends Node
var failures: Array[String] = []
func _ready() -> void:
	Engine.set_meta("skip_tasks", true); await get_tree().process_frame
	var p := Node.new(); get_tree().root.add_child(p); get_tree().current_scene = p; Game.campaign_mode = false; Game.replay_mission("m01_checkout")
	for i in 120: await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	check(level != null,"M01 booted")
	if level == null: finish(); return
	Dialogue._end(false); Dialogue.set_process(false); level.player.input_enabled = false; level.player.set_physics_process(false)
	for enemy in level.enemies: enemy.set_physics_process(false)
	var machines: Array[BreakableProp] = []
	for node in level.props_root.get_children():
		if node is BreakableProp and (node as BreakableProp).kind == "arcade": machines.append(node)
	check(machines.size() == 2,"M01 retains two arcade BreakableProp instances")
	var rows: Array = []
	for machine in machines:
		var visual := machine.get_node_or_null("NativeM01ArcadeMachine") as Sprite2D
		check(visual != null,"intact arcade has native visual")
		if visual == null: continue
		check(visual.texture != null,"native arcade visual has approved texture"); check(visual.find_children("*","CollisionObject2D",true,false).is_empty(),"native arcade visual adds no collider"); check(machine.collision_layer == Layers.PROP,"legacy arcade collision remains on PROP layer")
		rows.append({"position":[machine.global_position.x,machine.global_position.y],"collision_layer":machine.collision_layer,"intact_visual":visual.visible})
	if DisplayServer.get_name() != "headless" and not machines.is_empty():
		level.hud.hide()
		for control in get_tree().root.find_children("*","Control",true,false): (control as Control).hide()
		level.camera.set_process(false); level.camera.set_physics_process(false); level.camera.global_position=machines[0].global_position; level.camera.zoom=Vector2(7,7)
		for i in 10: await get_tree().process_frame
		await RenderingServer.frame_post_draw; get_viewport().get_texture().get_image().save_png("res://build/m01_arcade_machine_runtime.png")
	if not machines.is_empty():
		var tested:=machines[0];var visual:=tested.get_node_or_null("NativeM01ArcadeMachine") as Sprite2D;var layer:=tested.collision_layer
		tested._break(DamageInfo.make(DamageInfo.Type.MELEE,level.player,tested.global_position,Vector2.RIGHT),true)
		for i in 2: await get_tree().process_frame
		check(tested.is_broken,"arcade retains original damage transition");check(visual != null and not visual.visible,"native intact arcade visual hides after break");check(tested.collision_layer == layer,"broken arcade preserves solid collision")
	var f:=FileAccess.open("res://build/m01_arcade_machine_runtime_review.json",FileAccess.WRITE);f.store_string(JSON.stringify({"runtime_approved":failures.is_empty(),"expected_placements":2,"placements":rows,"damage_transition_checked":not machines.is_empty(),"scope":"M01 native intact arcade visuals; original BreakableProp collision, health, sound, and broken drawing retained."},"  "));f.close();Dialogue.set_process(true);finish()
func check(ok:bool,label:String)->void:
	if ok:print("  ok   ",label)
	else:print("  FAIL ",label);failures.append(label)
func finish()->void:print("M01 ARCADE MACHINE REVIEW: %d failures"%failures.size());Game.request_quit(1 if not failures.is_empty() else 0)
