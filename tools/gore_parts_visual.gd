extends Node2D
func _ready() -> void:
 var effects:=Effects.new()
 add_child(effects)
 var stage:=SubViewport.new()
 stage.size=Vector2i(900,380)
 stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 add_child(stage)
 var background:=ColorRect.new()
 background.size=Vector2(stage.size)
 background.color=Color("191622")
 stage.add_child(background)
 for row in 2:
  for col in 3:
   var gib:=Gore.Gib.new()
   gib.kind=["head","arm","leg"][col]
   gib.palette=["guard","stagehand"][row]
   gib.position=Vector2(120+col*300,80+row*190)
   gib.scale=Vector2.ONE*8.
   gib.z_index=1
   stage.add_child(gib)
   gib.z_index=1
   gib.set_process(false)
   var label:=Label.new()
   label.text=gib.palette+" "+gib.kind
   label.position=Vector2(30+col*300,155+row*190)
   stage.add_child(label)
 for frame in 4: await get_tree().process_frame
 await RenderingServer.frame_post_draw
 stage.get_texture().get_image().save_png("res://build/gore_parts_integrated_visual.png")
 Game.request_quit()
