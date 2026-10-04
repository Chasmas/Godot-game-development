extends Node
func _ready() -> void:
 Engine.set_meta("autoplay", true)
 Engine.set_meta("trailer", true)
 Game.force_intro_calls = false
 await get_tree().process_frame
 var placeholder := Node.new()
 get_tree().root.add_child(placeholder)
 get_tree().current_scene = placeholder
 var mid := OS.get_environment("GALLERY_MISSION")
 Game.start_mission(mid)
 for i in 140:
  if Dialogue.active: Dialogue._end()
  var player := get_tree().get_first_node_in_group("player") as Player
  if player: player.god_mode = true
  await get_tree().process_frame
 var level := get_tree().get_first_node_in_group("level") as Level
 if level == null:
  push_error("Mission did not load: " + mid)
  get_tree().quit(1)
  return
 var points := {"m01_checkout": Vector2(510, 340), "m02_dog_days": Vector2(590, 330), "m03_prime_time": Vector2(560, 330), "m04_sweet_dreams": Vector2(585, 280)}
 var probe := Node2D.new()
 level.add_child(probe)
 probe.global_position = points.get(mid, Vector2(500,300))
 level.camera.target = probe
 level.camera.zoom_bias = float(OS.get_environment("GALLERY_ZOOM")) if OS.get_environment("GALLERY_ZOOM") != "" else 1.0
 if OS.get_environment("GALLERY_AT") == "player":
  probe.global_position = (get_tree().get_first_node_in_group("player") as Node2D).global_position
 level.camera.snap_to_target()
 if level.hud: level.hud.visible = false
 for i in 20: await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(OS.get_environment("GALLERY_OUT"))
 print("GALLERY mission=",mid," floor=",level.data.get("layout_revision")," pixelart=",ArtLib.sprite("palm") != null)
 get_tree().quit()
