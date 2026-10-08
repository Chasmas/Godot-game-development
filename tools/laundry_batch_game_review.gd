extends Node

func _ready() -> void:
 Engine.set_meta("skip_tasks",true)
 Engine.set_meta("autoplay",true)
 await get_tree().process_frame
 var saved := SaveManager.data.duplicate(true)
 var saved_path := SaveManager.save_path
 SaveManager.save_path = "user://laundry_batch_review_save.json"
 var placeholder := Node.new()
 get_tree().root.add_child(placeholder)
 get_tree().current_scene = placeholder
 Game.campaign_mode = false
 Game.replay_mission("m01_checkout")
 Game.attempts = 2
 for frame in 90: await get_tree().physics_frame
 var level := get_tree().get_first_node_in_group("level") as Level
 level.player.input_enabled = false
 level.player.set_physics_process(false)
 level.player.global_position = Vector2(136,488)
 for enemy in level.enemies: enemy.set_physics_process(false)
 for enemy in level.enemies:
  if enemy.is_snoozing() and enemy.visual.cast_sprite is CastModel:
   print("SEAT_DIAGNOSTIC actor=",enemy.global_position," aim=",enemy.visual.aim_angle," rig=",enemy.visual.rig.rotation," body=",enemy.visual.cast_sprite._body_angle," chair_yaw=",enemy.idle_activity._chair.get_child(0).yaw)
 var found := false
 for child in level.props_root.get_children():
  if str(child.get_meta("rendered_decor_id","")) == "laundry_service_bench": found = true
 if not found:
  push_error("Production laundry service bench missing")
  SaveManager.data = saved
  SaveManager.save_path = saved_path
  Game.request_quit(1)
  return
 for frame in 2: await get_tree().physics_frame
 if OS.get_environment("LAUNDRY_BENCH_COLLISION_REVIEW") == "1":
  var failures := 0
  var player := level.player
  for route in [[Vector2(120,440),Vector2.DOWN],[Vector2(120,512),Vector2.UP]]:
   player.global_position = route[0]
   player.velocity = Vector2.ZERO
   for frame in 90:
    player._movement(route[1],1.0/120.0)
    player.move_and_slide()
    await get_tree().physics_frame
   var travelled: float = (player.global_position-route[0]).dot(route[1])
   if travelled < 65: failures += 1
   print("PASS " if travelled >= 65 else "FAIL ","bench passage start=",route[0]," end=",player.global_position)
  player.global_position = Vector2(140,502)
  player.velocity = Vector2.ZERO
  for frame in 35:
   player._movement(Vector2.UP,1.0/120.0)
   player.move_and_slide()
   await get_tree().physics_frame
  var stopped := player.global_position.y >= 489 and player.global_position.y < 494
  if not stopped: failures += 1
  print("PASS " if stopped else "FAIL ","bench walking collision at ",player.global_position)
  SaveManager.data = saved
  SaveManager.save_path = saved_path
  print("LAUNDRY BENCH COLLISION REVIEW: ",failures," failures")
  Game.request_quit(1 if failures else 0)
  return
 level.camera.set_process(false)
 level.camera.set_physics_process(false)
 level.camera.zoom = Vector2.ONE*4
 level.camera.global_position = Vector2(112,468)
 for frame in 8: await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://build/laundry_batch_game_review.png")
 SaveManager.data = saved
 SaveManager.save_path = saved_path
 print("LAUNDRY BATCH GAME REVIEW: actual production service bench")
 Game.request_quit(0)
