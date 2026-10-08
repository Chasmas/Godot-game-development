extends Node
func _ready()->void:
 Engine.set_meta("skip_tasks",true)
 Engine.set_meta("autoplay",true)
 await get_tree().process_frame
 var saved := SaveManager.data.duplicate(true)
 var placeholder := Node.new()
 get_tree().root.add_child(placeholder)
 get_tree().current_scene = placeholder
 Game.campaign_mode = false
 var failures := 0
 var count := 0
 for mission in ["m01_checkout","m02_dog_days","m03_prime_time","m04_sweet_dreams"]:
  Game.replay_mission(mission)
  Game.attempts = 2
  for frame in 90: await get_tree().physics_frame
  var level := get_tree().get_first_node_in_group("level") as Level
  var player := level.player
  player.god_mode = true
  player.set_physics_process(false)
  for enemy in level.enemies: enemy.set_physics_process(false)
  for switch in level.switches:
   player.global_position = switch.global_position - Vector2.from_angle(switch.rotation-PI*.5)*12.0
   for frame in 2: await get_tree().physics_frame
   var ok:bool = player._nearest_interactable() == switch
   if not ok: failures += 1
   count += 1
   print("PASS " if ok else "FAIL ",mission," wall switch accessible from room ",switch.position)
 SaveManager.data = saved
 print("AUTHORED SWITCH REACH REVIEW: ",failures," failures / ",count," switches")
 Game.request_quit(1 if failures else 0)