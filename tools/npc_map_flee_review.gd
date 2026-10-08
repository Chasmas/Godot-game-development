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
  var npcs := get_tree().get_nodes_in_group("npcs")
  var origins := {}
  for npc in npcs:
   npc.set_physics_process(false)
   origins[npc.get_instance_id()] = npc.global_position
  for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
   var travel := {}
   for npc in npcs:
    npc.global_position = origins[npc.get_instance_id()]
    npc.velocity = Vector2.ZERO
    npc.panicking = false
    npc.cowering = false
    travel[npc.get_instance_id()] = 0.0
    npc._on_noise(npc.global_position-direction*30.0,100,&"gunshot",null)
   for frame in 90:
    await get_tree().physics_frame
    for npc in npcs:
     var before:Vector2 = npc.global_position
     npc._physics_process(1.0/120.0)
     travel[npc.get_instance_id()] += before.distance_to(npc.global_position)
   for npc in npcs:
    var distance:float = travel[npc.get_instance_id()]
    var ok:bool = distance > 8.0 and is_finite(npc.global_position.x) and is_finite(npc.global_position.y)
    if not ok: failures += 1
    count += 1
    print("PASS " if ok else "FAIL ",mission," flee ",npc.npc_id," dir=",direction," travelled=",distance)
 SaveManager.data = saved
 print("AUTHORED NPC FLEE REVIEW: ",failures," failures / ",count," routes")
 Game.request_quit(1 if failures else 0)