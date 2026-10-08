extends Node2D
var failures:=0
func check(ok:bool,label:String)->void:
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label)
func _ready()->void:
 Engine.set_meta("skip_tasks",true)
 await get_tree().process_frame
 var saved:=SaveManager.data.duplicate(true)
 add_child(Effects.new())
 var player:=Player.new()
 add_child(player)
 player.setup(CharacterData.new())
 player.set_physics_process(false)
 var saw:=WeaponInstance.create(DB.weapon(&"chainsaw"))
 player.slots=[saw,null]
 player.slot=0
 player._refresh_weapon()
 player.aim_dir=Vector2.RIGHT
 player.visual.set_aim(0)
 var enemy:=Enemy.new()
 enemy.idle_action="watch"
 add_child(enemy)
 enemy.setup(DB.enemy(&"guard"),self,Vector2.LEFT)
 enemy.armor_left=0
 enemy.position=Vector2(60,0)
 enemy.set_physics_process(false)
 await get_tree().physics_frame
 await get_tree().physics_frame
 player._throw_current()
 var pickup:WeaponPickup
 for child in get_children():
  if child is WeaponPickup and child.weapon==saw:pickup=child
 print("THROW geometry start=",pickup.global_position," velocity=",pickup.velocity," target=",enemy.global_position)
 check(pickup!=null,"throw creates recoverable same weapon")
 for frame in 180:await get_tree().physics_frame
 check(pickup._hit_this_throw.size()==1,"physical flight hits guard exactly once")
 check(not enemy.is_alive() if saw.data.throw_lethal else enemy.state==Enemy.State.DOWNED,"impact respects weapon lethality")
 check(pickup.can_pick_up(),"weapon settles and becomes collectible")
 check(WeaponPickup.nearest(pickup.global_position,get_tree())==pickup,"settled saw is discoverable by pickup system")
 SaveManager.data=saved
 print("CHAINSAW THROW PHYSICS: ",failures," failures")
 Game.request_quit(1 if failures else 0)
