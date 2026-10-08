extends Node
func _ready()->void:
 if Engine.has_meta("skip_tasks"): Engine.remove_meta("skip_tasks")
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
  level.set_process(false)
  level.phase = Level.Phase.CLEAR
  level._escape_pending = false
  level._tasks_sig = ""
  var tasks: Array = level.data.get("tasks",[])
  level._poll_tasks()
  var initially_done := level.tasks_done()
  level._begin_escape()
  var gated:bool = (level.phase == Level.Phase.ESCAPE) if initially_done else (level._escape_pending and not level.exit_car.enabled)
  if not gated: failures += 1
  print("PASS " if gated else "FAIL ",mission," exit obeys current objectives")
  for task in tasks:
   if str(task.get("kind","")) == "collect": level.collected[str(task.item)] = true
   elif str(task.get("kind","")) == "film_cameras":
    for camera in get_tree().get_nodes_in_group("film_cameras"):
     camera.take_damage(DamageInfo.make(DamageInfo.Type.MELEE,player,camera.global_position,Vector2.RIGHT,&"knife",&"melee"))
  level._poll_tasks()
  var unlocked:bool = level.tasks_done() and level.phase == Level.Phase.ESCAPE and level.exit_car.enabled and not level._escape_pending
  if not unlocked: failures += 1
  count += 1
  print("PASS " if unlocked else "FAIL ",mission," completed objective state unlocks exit")
 SaveManager.data = saved
 print("OBJECTIVE EXIT FLOW REVIEW: ",failures," failures / ",count," missions")
 Game.request_quit(1 if failures else 0)