extends Node
func _ready()->void:
 Engine.set_meta("skip_tasks",true)
 Engine.set_meta("autoplay",true)
 await get_tree().process_frame
 var saved := SaveManager.data.duplicate(true)
 var previous_save_path := SaveManager.save_path
 SaveManager.save_path = "user://civilian_cower_staging_review_save.json"
 var placeholder := Node.new()
 get_tree().root.add_child(placeholder)
 get_tree().current_scene = placeholder
 Game.campaign_mode = false
 Game.replay_mission("m01_checkout")
 Game.attempts=2
 for frame in 90: await get_tree().physics_frame
 var level := get_tree().get_first_node_in_group("level") as Level
 level.player.god_mode=true
 level.player.input_enabled=false
 level.player.set_physics_process(false)
 for enemy in level.enemies: enemy.set_physics_process(false)
 var npc := get_tree().get_first_node_in_group("npcs") as NPC
 npc.set_physics_process(false)
 npc._drop_activity()
 npc.visual.cast_sprite.free()
 var cast := CastModel.new()
 if not cast.configure("civilian","res://build/civilian_cower_review/civilian_cower.glb"):
  cast.free()
  SaveManager.data=saved
  SaveManager.save_path=previous_save_path

  Game.request_quit(1)
  return
 npc.visual.cast_sprite=cast
 npc.visual.rig.add_child(cast)
 var exposure := float(OS.get_environment("COWER_STAGE_EXPOSURE")) if not OS.get_environment("COWER_STAGE_EXPOSURE").is_empty() else 1.0
 for node in cast._viewport.get_children():
  if node is DirectionalLight3D: node.light_energy *= exposure
  elif node is WorldEnvironment: node.environment.ambient_light_energy *= exposure
 npc.visual.scale=Vector2.ONE
 npc.visual.pose_override="cower"
 npc.visual.pose_progress=0.0
 level.player.position=npc.position+Vector2(0,40)
 level.camera.snap_to_target()
 level.camera.set_process(false)
 DirAccess.make_dir_recursive_absolute("res://build/civilian_cower_review/motel_motion")
 for frame in 37:
  npc.visual.pose_progress=frame/36.0
  await get_tree().process_frame
  await RenderingServer.frame_post_draw
  var full := get_viewport().get_texture().get_image()
  var center := npc.get_global_transform_with_canvas().origin * Vector2(full.get_size()) / get_viewport().get_visible_rect().size
  var bounds := Rect2i(Vector2i(center)-Vector2i(80,100),Vector2i(160,150))
  var crop := full.get_region(bounds)
  crop.save_png("res://build/civilian_cower_review/motel_motion/%03d.png" % frame)
  if frame in [0,36]: full.save_png("res://build/civilian_cower_review/motel_motion/full_%03d.png" % frame)
 SaveManager.data=saved

 SaveManager.save_path=previous_save_path
 print("COWER MOTEL STAGING: captured; candidate only")
 Game.request_quit(0)