extends Node2D
var models: Array=[]
func _ready() -> void:
 RenderingServer.set_default_clear_color(Color("191622"))
 var stage:=SubViewport.new()
 stage.size=Vector2i(1100,260)
 stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 add_child(stage)
 for row in 1:
  for col in 5:
   var cell:=Node2D.new()
   cell.position=Vector2(110+col*215,190+row*220)
   cell.scale=Vector2.ONE*4.
   stage.add_child(cell)
   var model:=CastModel.create(OS.get_environment("SEVER_REVIEW_LOOK") if OS.get_environment("SEVER_REVIEW_LOOK") != "" else "guard")
   cell.add_child(model)
   if col>0: model.sever_part(["","head","arm","leg","legs"][col])
   model.moving=false
   model.move_speed=[118.,191.,65.][row]
   model.move_angle=0.
   models.append([model,"death_back",.995])
   var label:=Label.new()
   label.text=["Intact","Head removed","Arm removed","Leg removed","Legs removed"][col]
   label.position=Vector2(25+col*215,210+row*220)
   stage.add_child(label)
 for frame in 20:
  for item in models:
   item[0].play_sample(item[1],1./60.,item[2])
  await get_tree().process_frame
 await RenderingServer.frame_post_draw
 stage.get_texture().get_image().save_png("res://build/%s_sever_mesh_visual.png" % (OS.get_environment("SEVER_REVIEW_LOOK") if OS.get_environment("SEVER_REVIEW_LOOK") != "" else "guard"))
 Game.request_quit()
