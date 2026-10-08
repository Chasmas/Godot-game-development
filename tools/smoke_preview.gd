extends Node2D
func _ready() -> void:
 RenderingServer.set_default_clear_color(Color("171523"))
 for i in 4:
  var v := CharacterVisual.new()
  add_child(v)
  v.setup("cass")
  v.set_process(false)
  v.idle_fidgets = true
  v._still_t = 10.0
  v.position = Vector2(130 + i * 240, 210)
  v.scale = Vector2.ONE * 6.0
  v._process(0.1)
  v.cast_sprite.play_sample("smoke", 0.1, [0.0, 0.22, 0.46, 0.73][i])
  v._cig.position = v.cast_sprite.grip()
  var label := Label.new()
  label.text = ["RELAX", "LIFT", "DRAW", "LOWER"][i]
  label.position = Vector2(90 + i * 240, 340)
  add_child(label)
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 if DisplayServer.get_name() != "headless":
  var texture := get_viewport().get_texture()
  var image := texture.get_image() if texture else null
  if image:
   image.save_png(OS.get_environment("CAST_PREVIEW_OUT"))
 else:
  push_warning("Smoke preview capture skipped: headless renderer has no visual texture")
 get_tree().quit()
