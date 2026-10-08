extends Node
func _ready()->void:
 Engine.set_meta("skip_tasks",true)
 Engine.set_meta("autoplay",true)
 await get_tree().process_frame
 var saved := SaveManager.data.duplicate(true)
 var saved_path := SaveManager.save_path
 SaveManager.save_path = "user://motel_art_baseline_review_save.json"
 var placeholder := Node.new()
 get_tree().root.add_child(placeholder)
 get_tree().current_scene = placeholder
 Game.campaign_mode = false
 Game.replay_mission("m01_checkout")
 Game.attempts = 2
 for frame in 90: await get_tree().physics_frame
 var level := get_tree().get_first_node_in_group("level") as Level
 level.player.god_mode = true
 level.player.input_enabled = false
 level.player.set_physics_process(false)
 for enemy in level.enemies: enemy.set_physics_process(false)
 DirAccess.make_dir_recursive_absolute("res://build/motel_art_baseline")
 level.camera.set_process(false)
 for point in [Vector2(472,280),Vector2(136,456)]:
  level.player.global_position = point
  level.camera.snap_to_target()
  for frame in 8: await get_tree().process_frame
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://build/motel_art_baseline/view_%d_%d.png" % [point.x,point.y])
 SaveManager.data = saved
 SaveManager.save_path = saved_path
 print("MOTEL ART BASELINE: 2 actual gameplay captures")
 Game.request_quit(0)
