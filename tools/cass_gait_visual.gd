extends Node2D
var models: Array=[]
func _ready() -> void:
 RenderingServer.set_default_clear_color(Color("191622"))
 var stage:=SubViewport.new()
 stage.size=Vector2i(1720,680)
 stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 add_child(stage)
 for row in 3:
  for col in 8:
   var cell:=Node2D.new()
   cell.position=Vector2(110+col*215,190+row*220)
   cell.scale=Vector2.ONE*4.
   stage.add_child(cell)
   var model:=CastModel.create("cass")
   cell.add_child(model)
   model.moving=true
   model.move_speed=[118.,191.,65.][row]
   model.move_angle=0.
   models.append([model,["walk","run","sneak"][row],float(col)/8.])
   var label:=Label.new()
   label.text="%s %.2f" % [["Walk","Run","Crouch"][row],float(col)/8.]
   label.position=Vector2(25+col*215,210+row*220)
   stage.add_child(label)
 for frame in 20:
  for item in models:
   item[0].play_sample(item[1],1./60.,item[2])
  await get_tree().process_frame
 await RenderingServer.frame_post_draw
 stage.get_texture().get_image().save_png("res://build/cass_gait_visual.png")
 Game.request_quit()
