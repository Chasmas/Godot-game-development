extends Node
func _ready()->void:
 Engine.set_meta("skip_tasks",true)
 Engine.set_meta("autoplay",true)
 process_mode = Node.PROCESS_MODE_ALWAYS
 await get_tree().process_frame
 var saved := SaveManager.data.duplicate(true)
 var saved_path := SaveManager.save_path
 SaveManager.save_path = "user://security_warehouse_response_review_save.json"
 var placeholder := Node.new()
 get_tree().root.add_child(placeholder)
 get_tree().current_scene = placeholder
 Game.campaign_mode = false
 Game.replay_mission("m02_dog_days")
 Game.attempts = 2
 for frame in 90: await get_tree().physics_frame
 var level := get_tree().get_first_node_in_group("level") as Level
 var player := level.player
 player.god_mode = true
 player.input_enabled = false
 player.set_physics_process(false)
 player.global_position = Vector2(440,136)
 var camera:SecurityCamera
 for node in get_tree().get_nodes_in_group("security_cameras"):
  if node.global_position.distance_to(Vector2(492,119)) < 2: camera = node
 if camera == null:
  SaveManager.data = saved
  SaveManager.save_path = saved_path
  Game.request_quit(1)
  return
 var responders := camera._alarm_responders(player.global_position)
 responders.resize(mini(3,responders.size()))
 var report: Array = []
 camera._raise_alarm(player)
 for enemy in responders:
  report.append({"start":[enemy.global_position.x,enemy.global_position.y],"goal":[enemy._goal.x,enemy._goal.y],"closest_to_goal":enemy.global_position.distance_to(enemy._goal),"start_distance":enemy.global_position.distance_to(enemy._goal),"initial_state":enemy.state})
 # Move only the test player away after the report: guards must investigate
 # their reported location rather than continue chasing a visible target.
 player.global_position = Vector2(900,850)
 for frame in 960:
  await get_tree().physics_frame
  for i in responders.size():
   var enemy := responders[i]
   var goal := Vector2(report[i].goal[0],report[i].goal[1])
   report[i].closest_to_goal = minf(report[i].closest_to_goal,enemy.global_position.distance_to(goal))
 var failures := 0
 if responders.is_empty(): failures += 1
 for i in responders.size():
  var enemy := responders[i]
  report[i].end = [enemy.global_position.x,enemy.global_position.y]
  report[i].end_state = enemy.state
  report[i].arrived = report[i].closest_to_goal < 24.0
  if not report[i].arrived: failures += 1
  print("PASS " if report[i].arrived else "FAIL ",report[i])
 var file := FileAccess.open("res://build/security_warehouse_response_review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"scope":"Actual authored guards responding to real camera alarm; player moved away after report, AI active, 8 seconds observed","responders":report,"failures":failures},"  "))
 SaveManager.data = saved
 SaveManager.save_path = saved_path
 print("WAREHOUSE RESPONSE REVIEW: ",failures," failures / ",responders.size()," responders")
 Game.request_quit(1 if failures else 0)
