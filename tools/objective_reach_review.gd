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
  var objectives: Array = level._boss_props.duplicate()
  if level.exit_car != null: objectives.append(level.exit_car)
  for object in objectives:
   object.enabled = true
   if object.has_method("can_interact") and not object.can_interact(player): continue
   var found := false
   for distance in [12.0,18.0,21.0]:
    for direction in 32:
     player.global_position = object.global_position + Vector2.from_angle(direction*TAU/32.0)*distance
     for frame in 1: await get_tree().physics_frame
     if player._overlaps(Layers.WORLD | Layers.DOOR | Layers.LOW | Layers.PROP): continue
     if player._nearest_interactable() == object:
      found = true
      break
    if found: break
   if not found: failures += 1
   count += 1
   print("PASS " if found else "FAIL ",mission," reachable interactive ",object.get_script().resource_path," at ",object.position)
 SaveManager.data = saved
 print("UNLOCKED OBJECTIVE REACH REVIEW: ",failures," failures / ",count," objects")
 Game.request_quit(1 if failures else 0)