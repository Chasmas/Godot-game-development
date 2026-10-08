extends Node
var failures := 0
var results:Array = []
func _ready()->void:
 Engine.set_meta("skip_tasks",true)
 Engine.set_meta("autoplay",true)
 await get_tree().process_frame
 var saved := SaveManager.data.duplicate(true)
 var saved_path := SaveManager.save_path
 SaveManager.save_path = "user://security_break_response_review_save.json"
 var placeholder := Node.new()
 get_tree().root.add_child(placeholder)
 get_tree().current_scene = placeholder
 Game.campaign_mode = false
 for mission in ["m01_checkout","m02_dog_days","m03_prime_time"]:
  for index in 3:
   Game.replay_mission(mission)
   Game.attempts = 2
   for frame in 90: await get_tree().physics_frame
   var level := get_tree().get_first_node_in_group("level") as Level
   level.player.god_mode = true
   level.player.input_enabled = false
   level.player.set_physics_process(false)
   level.player.global_position = Vector2(-500,-500)
   var cameras := get_tree().get_nodes_in_group("security_cameras")
   for node in cameras: node.set_physics_process(false)
   if index >= cameras.size():
    failures += 1
    continue
   var camera := cameras[index] as SecurityCamera
   var report_point := camera.global_position + Vector2.from_angle(camera.base_angle)*20.0
   var responders := camera._alarm_responders(report_point)
   responders.resize(mini(2,responders.size()))
   camera.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC,level.player,camera.global_position,Vector2.RIGHT))
   var samples:Array = []
   for enemy in responders:
    samples.append({"start":[enemy.global_position.x,enemy.global_position.y],"goal":[enemy._goal.x,enemy._goal.y],"closest":enemy.global_position.distance_to(enemy._goal),"initial_state":enemy.state})
   for frame in 960:
    await get_tree().physics_frame
    for i in responders.size():
     var point := Vector2(samples[i].goal[0],samples[i].goal[1])
     samples[i].closest = minf(samples[i].closest,responders[i].global_position.distance_to(point))
   for i in responders.size():
    samples[i].arrived = samples[i].closest < 24.0
    samples[i].end_state = responders[i].state
    if not samples[i].arrived: failures += 1
   var disabled := camera._broken and camera.collision_layer == 0 and not camera.can_see_point(report_point)
   if not disabled: failures += 1
   results.append({"mission":mission,"mount":[camera.position.x,camera.position.y],"disabled":disabled,"responders":samples})
   print("BREAK RESPONSE ",results.back())
 var file := FileAccess.open("res://build/security_break_response_review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"scope":"All nine actual surveillance mounts, real damage and active AI, eight seconds per mount; no combat balance approval","results":results,"failures":failures},"  "))
 SaveManager.data = saved
 SaveManager.save_path = saved_path
 print("CAMERA BREAK RESPONSE: ",failures," failures / ",results.size()," mounts")
 Game.request_quit(1 if failures else 0)
