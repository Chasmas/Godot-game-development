extends Node
func _ready()->void:
 Engine.set_meta("skip_tasks",true)
 Engine.set_meta("autoplay",true)
 await get_tree().process_frame
 var saved := SaveManager.data.duplicate(true)
 var saved_path := SaveManager.save_path
 SaveManager.save_path = "user://security_warehouse_south_review_save.json"
 var placeholder := Node.new()
 get_tree().root.add_child(placeholder)
 get_tree().current_scene = placeholder
 Game.campaign_mode = false
 var failures := 0
 var results: Array = []
 for lane in [216.0,232.0]:
  Game.replay_mission("m02_dog_days")
  Game.attempts = 2
  for frame in 90: await get_tree().physics_frame
  var level := get_tree().get_first_node_in_group("level") as Level
  var player := level.player
  player.god_mode = true
  player.input_enabled = false
  player.set_physics_process(false)
  player.respawn_grace = 0.0
  player.global_position = Vector2(lane,344)
  player.velocity = Vector2.ZERO
  var alarms := false
  var peak := 0.0
  var door_swing := 0.0
  for frame in 150:
   player._movement(Vector2.UP,1.0/120.0)
   player.move_and_slide()
   await get_tree().physics_frame
   for node in get_tree().get_nodes_in_group("security_cameras"):
    peak = maxf(peak,node._meter)
    if node._cool > 0: alarms = true
   for node in get_tree().get_nodes_in_group("door"):
    if node is Door and node.global_position.distance_to(Vector2(224,312)) < 40:
     door_swing = maxf(door_swing,absf(node.swing))
  var ok := player.global_position.y < 260 and not alarms and door_swing > .1
  if not ok: failures += 1
  results.append({"lane":lane,"end":[player.global_position.x,player.global_position.y],"camera_alarm":alarms,"peak":peak,"door_swing":door_swing,"passed":ok})
  print("PASS " if ok else "FAIL ",results.back())
 var file := FileAccess.open("res://build/security_warehouse_south_review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"scope":"Two real south-door walking lanes with active AI and normal door pushing, god mode; not full stealth or combat approval","results":results},"  "))
 SaveManager.data = saved
 SaveManager.save_path = saved_path
 print("WAREHOUSE SOUTH ENTRY: ",failures," failures")
 Game.request_quit(1 if failures else 0)