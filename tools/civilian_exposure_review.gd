extends Node
func _ready()->void:
 Engine.set_meta("skip_tasks",true)
 Engine.set_meta("autoplay",true)
 await get_tree().process_frame
 var saved := SaveManager.data.duplicate(true)
 var saved_path := SaveManager.save_path
 SaveManager.save_path="user://civilian_exposure_review_save.json"
 var placeholder := Node.new()
 get_tree().root.add_child(placeholder)
 get_tree().current_scene=placeholder
 Game.campaign_mode=false
 DirAccess.make_dir_recursive_absolute("res://build/civilian_exposure_review")
 var captures := 0
 for mission in ["m01_checkout","m03_prime_time"]:
  Game.replay_mission(mission)
  Game.attempts=2
  for frame in 90: await get_tree().physics_frame
  var level := get_tree().get_first_node_in_group("level") as Level
  level.player.god_mode=true
  level.player.input_enabled=false
  level.player.set_physics_process(false)
  for enemy in level.enemies: enemy.set_physics_process(false)
  for npc in get_tree().get_nodes_in_group("npcs"):
   npc.set_physics_process(false)
   npc._drop_activity()
   var cast := npc.visual.cast_sprite as CastModel
   if cast == null: continue
   var lights := {}
   for node in cast._viewport.get_children():
    if node is DirectionalLight3D: lights[node]=node.light_energy
    elif node is WorldEnvironment: lights[node]=node.environment.ambient_light_energy
   level.player.global_position=npc.global_position+Vector2(0,40)
   level.camera.snap_to_target()
   level.camera.set_process(false)
   for on in [true,false]:
    level.set_zone_lights(level.zone_at(npc.global_position),on)
    for exposure in [1.0,.55]:
     for node in lights:
      if node is DirectionalLight3D: node.light_energy=lights[node]*exposure
      else: node.environment.ambient_light_energy=lights[node]*exposure
     for frame in 12: await get_tree().process_frame
     await RenderingServer.frame_post_draw
     var full := get_viewport().get_texture().get_image()
     var center: Vector2 = npc.get_global_transform_with_canvas().origin*Vector2(full.get_size())/get_viewport().get_visible_rect().size
     var crop := full.get_region(Rect2i(Vector2i(center)-Vector2i(80,110),Vector2i(160,150)))
     crop.save_png("res://build/civilian_exposure_review/%s_%s_%s_%s.png" % [mission,npc.npc_id,str(on),str(exposure)])
     captures+=1
   level.set_zone_lights(level.zone_at(npc.global_position),true)
 SaveManager.data=saved
 SaveManager.save_path=saved_path
 print("CIVILIAN EXPOSURE: ",captures," native captures")
 Game.request_quit(0 if captures==16 else 1)