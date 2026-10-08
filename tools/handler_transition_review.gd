extends Node
var failures: Array=[]
func check(ok: bool, message: String) -> void:
 if not ok: failures.append(message)
 print("PASS " if ok else "FAIL ",message)
func _ready() -> void:
 var effects:=Effects.new()
 add_child(effects)
 var h:=Handler.new()
 h.enemy_id="handler_transition"
 add_child(h)
 h.set_physics_process(false)
 h.setup(DB.enemy(&"handler"),null,Vector2.RIGHT)
 if h.idle_activity:
  h.idle_activity.drop()
  h.idle_activity=null
 await get_tree().process_frame
 var activity:=IdleActivity.new()
 h.visual.rig.add_child(activity)
 activity.setup(h.visual,IdleActivity.Kind.SMOKE,"handler_transition")
 h.idle_activity=activity
 h.visual._process_cast(0)
 check(h.visual.idle_activity_pose=="smoke","Handler uses authored smoke")
 check(not h.dog.is_physics_processing(),"Dog waits at heel")
 for angle in [0.,PI*.25,PI*.5,PI]:
  h.visual.set_aim(angle)
  h.visual._process_cast(0)
  var actual:=h.to_local(h.visual.rig.to_global(h.visual.cast_sprite.grip(true)))
  check(h._leash_hand_point().distance_to(actual)<.001,"Leash starts on real left hand")
 if DisplayServer.get_name()!="headless":
  h.position=Vector2(350,260)
  h.scale=Vector2.ONE*4
  h.dog.position=h.position+Vector2(20,55)
  h.dog.scale=Vector2.ONE*4
  h.visual.set_aim(0.)
  h.visual._process_cast(0)
  for frame in 5: await get_tree().process_frame
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://build/handler_leash_review.png")
 h.set_process(false)
 h.position=Vector2.ZERO
 h.scale=Vector2.ONE
 h.dog.position=Vector2(0,11)
 for frame in 240: h._simulate_leash(1.0/120.0)
 check(h._leash_points.size()==9,"Leash has simulated particles")
 check(h._leash_points[0].distance_to(h.to_global(h._leash_hand_point()))<.001,"Physics pins hand anchor")
 check(h._leash_points[8].distance_to(h.dog.global_position+h.dog.facing*3.5)<.001,"Physics pins collar anchor")
 var settled: Array[Vector2]=[]
 for rate in [30,60,120,240]:
  h._leash_points.clear()
  h._leash_previous.clear()
  for frame in rate*4: h._simulate_leash(1.0/rate)
  settled.append(h._leash_points[4])
  var segment:=maxf(14.,h._leash_points[0].distance_to(h._leash_points[8])*1.01)/8.
  var bounded:=true
  for i in 8: bounded=bounded and h._leash_points[i].distance_to(h._leash_points[i+1])<segment*1.1
  check(bounded,"Leash stretch bounded at %s FPS" % rate)
 for point in settled: check(point.distance_to(settled[2])<.5,"Resting shape agrees across frame rates")
 var moving_shapes: Array[Vector2]=[]
 for rate in [30,60,120,240]:
  h._leash_points.clear()
  h._leash_previous.clear()
  var stable:=true
  for frame in rate*3:
   var time: float=float(frame+1)/rate
   h.dog.position=Vector2(sin(time*4.)*7.,11.+cos(time*3.)*2.)
   h._simulate_leash(1./rate)
   for point in h._leash_points:
    stable=stable and point.is_finite() and point.distance_to(h.global_position)<35.
  check(stable,"Turns remain stable at %s FPS" % rate)
  moving_shapes.append(h._leash_points[4])
 for point in moving_shapes:
  check(point.distance_to(moving_shapes[2])<1.,"Moving shape agrees across frame rates")
 var frozen:=h._leash_points.duplicate()
 h._simulate_leash(0.)
 check(h._leash_points==frozen,"Zero delta does not advance rope")
 var before:=h._leash_points[4]
 h.dog.position+=Vector2(8,0)
 h._simulate_leash(1.0/120.0)
 check(h._leash_points[4].distance_to(before)>0.01,"Moving dog pulls physical leash")
 h.position+=Vector2(1000,1000)
 h.dog.position+=Vector2(1000,1000)
 h._simulate_leash(.5)
 var finite:=true
 for point in h._leash_points: finite=finite and point.is_finite() and point.distance_to(h.global_position)<50
 check(finite,"Teleport and long frame keep leash stable")
 h._held=true
 h._enter_combat()
 check(not h._released and not h.dog.is_physics_processing(),"Held handler cannot release dog")
 h._held=false
 h._enter_combat()
 check(h._released,"Alert releases dog")
 check(h._leash_points.is_empty(),"Release clears leash physics")
 check(h.idle_activity==null and h.visual.idle_activity_pose=="","Alert clears smoking")
 check(h.visual.weapon_sprite.visible,"Alert restores handler weapon")
 check(h.dog.is_physics_processing() and h.dog.is_aware(),"Dog enters active combat")
 h.dog.set_physics_process(false)
 h._enter_combat()
 check(not h.dog.is_physics_processing(),"Repeated alert does not repeat release")
 h.dog.queue_free()
 h.queue_free()
 await get_tree().process_frame
 print("HANDLER TRANSITION REVIEW: ",failures.size()," failures ",failures)
 Game.request_quit(1 if not failures.is_empty() else 0)
