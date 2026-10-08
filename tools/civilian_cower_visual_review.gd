extends Node
func _ready()->void:
 var stage := SubViewport.new()
 stage.size = Vector2i(640,220)
 stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 add_child(stage)
 var bg := ColorRect.new()
 bg.color = Color("292430")
 bg.size = Vector2(640,220)
 bg.z_index = -10
 stage.add_child(bg)
 var bodies: Array[CastModel] = []
 for i in 4:
  var cast := CastModel.new()
  if not cast.configure("civilian","res://build/civilian_cower_review/civilian_cower.glb"):
   Game.request_quit(1)
   return
  var rig := Node2D.new()
  rig.position = Vector2(80+i*160,175)
  rig.rotation = i*PI*.5
  stage.add_child(rig)
  rig.add_child(cast)
  cast.scale = Vector2.ONE*3
  cast.rotation = 0
  bodies.append(cast)
 for frame in 20:
  for cast in bodies: cast.play_sample("cower",1.0/60.0,float(OS.get_environment("COWER_PROGRESS")) if not OS.get_environment("COWER_PROGRESS").is_empty() else .5)
  await get_tree().process_frame
  await RenderingServer.frame_post_draw
 stage.get_texture().get_image().save_png("res://build/civilian_cower_review/transition_%s.png" % OS.get_environment("COWER_PROGRESS") + "")
 print("CIVILIAN COWER: four directions captured")
 Game.request_quit(0)