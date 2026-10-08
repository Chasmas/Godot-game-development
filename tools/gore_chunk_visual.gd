extends Node2D
var textures: Array[Texture2D] = []
func _ready() -> void:
 get_window().size = Vector2i(960,540)
 for i in 3:
  textures.append(ImageTexture.create_from_image(Image.load_from_file("res://build/gore_chunk_review/chunk_%d.png" % i)))
 for row in 2:
  for i in 3:
   var gib := Gore.Gib.new()
   gib.kind = "chunk"
   gib.position = Vector2(130+i*270,110+row*180)
   add_child(gib)
   gib.z_index = 1
   gib.set_process(false)
 queue_redraw()
 for i in 8: await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://build/gore_chunk_review/godot_scale.png")
 Audio.shutdown()
 get_tree().quit()
func _draw() -> void:
 for row in 2:
  var y := 50.0 + row * 180.0
  draw_rect(Rect2(30,y,850,160), Color("aaa6a1") if row == 0 else Color("29232c"))
  for i in 3:
   var center := Vector2(130+i*270,y+60)
   var size := Vector2(48,48)*0.18
   # Small sample is drawn by the actual runtime Gib node.
   var larger := size*6.0
   draw_texture_rect(textures[i],Rect2(center+Vector2(80,0)-larger*.5,larger),false)
  var arm := Gore.part_texture("guard","arm")
  if arm:
   var size := Vector2(arm.get_size())*.25
   draw_texture_rect(arm,Rect2(Vector2(300,y+115)-size*.5,size),false)
