extends Node
var failures: Array=[]
func check(ok: bool, message: String) -> void:
 if not ok: failures.append(message)
func _ready() -> void:
 var seed_str:=""
 for i in 100:
  var candidate:="creature_idle_"+str(i)
  if absi(hash(candidate+"busy"))%100<65:
   seed_str=candidate
   break
 for id in [&"zombie",&"ghoul",&"demon",&"guard"]:
  var e:=Enemy.new()
  e.enemy_id=seed_str
  add_child(e)
  e.set_physics_process(false)
  e.setup(DB.enemy(id),self,Vector2.RIGHT)
  if id in [&"zombie",&"ghoul",&"demon"]:
   check(e.idle_activity==null,str(id)+" spawns without human idle props")
   check(not e.is_snoozing(),str(id)+" never sleeps in a chair")
   check(e.visual.idle_activity_pose=="",str(id)+" keeps creature idle")
  else:
   check(e.idle_activity!=null,"Human guards retain ambient activity")
  e.queue_free()
  await get_tree().process_frame
 print("CREATURE IDLE REVIEW: ",failures.size()," failures ",failures)
 Game.request_quit(1 if not failures.is_empty() else 0)
