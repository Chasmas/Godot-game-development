extends Node2D
func _ready()->void:
 Engine.set_meta("skip_tasks",true)
 var stage:=SubViewport.new()
 stage.size=Vector2i(1600,800)
 stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 add_child(stage)
 var camera:=Camera2D.new()
 stage.add_child(camera)
 camera.position=Vector2(200,100)
 camera.zoom=Vector2.ONE*4
 var players:Array=[]
 for heading in 8:
  var player:=Player.new()
  stage.add_child(player)
  player.setup(CharacterData.new())
  player.position=Vector2(50+(heading%4)*100,50+(heading/4)*100)
  player.set_physics_process(false)
  player.slots=[WeaponInstance.create(DB.weapon(&"chainsaw")),null]
  player.slot=0
  player._refresh_weapon()
  player.aim_dir=Vector2.from_angle(heading*PI*.25)
  player.visual.set_aim(heading*PI*.25)
  player.visual._face_angle=heading*PI*.25
  player.visual.cast_sprite._body_init=false
  player.visual._process_cast(0)
  players.append(player)
 for frame in 3:await get_tree().physics_frame
 await RenderingServer.frame_post_draw
 stage.get_texture().get_image().save_png("res://build/chainsaw_throw_held.png")
 for player in players:player._throw_current()
 for frame in 29:
  await get_tree().physics_frame
  if frame in [0,4,12,28]:
   await RenderingServer.frame_post_draw
   stage.get_texture().get_image().save_png("res://build/chainsaw_throw_frame%02d.png"%frame)
 print("THROW VISUAL CAPTURE COMPLETE")
 Game.request_quit()
