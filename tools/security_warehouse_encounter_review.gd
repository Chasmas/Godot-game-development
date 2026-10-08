extends Node
var failures := 0
var results: Array = []
func _ready()->void:
 Engine.set_meta("skip_tasks",true)
 Engine.set_meta("autoplay",true)
 process_mode = Node.PROCESS_MODE_ALWAYS
 await get_tree().process_frame
 var saved := SaveManager.data.duplicate(true)
 var saved_path := SaveManager.save_path
 SaveManager.save_path = "user://security_warehouse_encounter_review_save.json"
 var placeholder := Node.new()
 get_tree().root.add_child(placeholder)
 get_tree().current_scene = placeholder
 Game.campaign_mode = false
 for retreat in [true,false]:
  Game.replay_mission("m02_dog_days")
  Game.attempts = 2
  for frame in 90: await get_tree().physics_frame
  var level := get_tree().get_first_node_in_group("level") as Level
  var player := level.player
  player.god_mode = true
  player.input_enabled = false
  player.set_physics_process(false)
  player.respawn_grace = 0.0
  player.global_position = Vector2(488,136)
  player.velocity = Vector2.ZERO
  var camera:SecurityCamera
  for node in get_tree().get_nodes_in_group("security_cameras"):
   if node.global_position.distance_to(Vector2(492,119)) < 2: camera = node
  if camera == null:
   failures += 1
   continue
  camera._meter = 0.0
  camera._cool = 0.0
  camera._t = SecurityCamera.SWEEP_TIME*.75
  camera._aim = camera.base_angle-camera.sweep
  var peak := 0.0
  var alarm_at := -1.0
  var moved_guards := 0
  var positions := {}
  for enemy in level.enemies: positions[enemy.get_instance_id()] = enemy.global_position
  for frame in 300:
   var direction := Vector2.ZERO
   if frame < 54: direction = Vector2.LEFT
   elif retreat and frame < 108: direction = Vector2.RIGHT
   player._movement(direction,1.0/120.0)
   player.move_and_slide()
   await get_tree().physics_frame
   peak = maxf(peak,camera._meter)
   if alarm_at < 0.0 and camera._cool > 0.0: alarm_at = (frame+1)/120.0
  for enemy in level.enemies:
   if enemy.global_position.distance_to(positions[enemy.get_instance_id()]) > 2.0: moved_guards += 1
  var ok := alarm_at < 0.0 if retreat else alarm_at >= .45
  if not ok: failures += 1
  results.append({"retreat":retreat,"alarm_seconds":alarm_at,"peak_detection":peak,"end_position":[player.global_position.x,player.global_position.y],"moving_enemies":moved_guards,"passed":ok})
  print("PASS " if ok else "FAIL ",results.back())
 var file := FileAccess.open("res://build/security_warehouse_encounter_review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"scope":"Two controlled warehouse entry routes with active AI, real collision, god mode and fixed initial camera sweep; not full encounter approval","results":results},"  "))
 SaveManager.data = saved
 SaveManager.save_path = saved_path
 print("WAREHOUSE ENCOUNTER REVIEW: ",failures," failures")
 Game.request_quit(1 if failures else 0)
