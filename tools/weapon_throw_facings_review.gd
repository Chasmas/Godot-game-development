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
 for weapon_name in ["pistol","knife","machete","bat"]:
  print("WEAPON ",weapon_name)
  for heading in 8:
   print("HEADING ",heading)
   var player:=Player.new()
   add_child(player)
   player.setup(CharacterData.new())
   player.set_physics_process(false)
   var saw:=WeaponInstance.create(DB.weapon(StringName(weapon_name)))
   player.slots=[saw,null]
   player.slot=0
   player._refresh_weapon()
   player.aim_dir=Vector2.from_angle(heading*PI*.25)
   player.visual.set_aim(heading*PI*.25)
   player.visual._face_angle=heading*PI*.25
   player.visual.cast_sprite._body_init=false
   player.visual._process_cast(0)
   var enemy:=Enemy.new()
   enemy.idle_action="watch"
   add_child(enemy)
   enemy.setup(DB.enemy(&"guard"),self,Vector2.LEFT)
   enemy.armor_left=0
   enemy.position=player.aim_dir*60
   enemy.set_physics_process(false)
   await get_tree().physics_frame
   await get_tree().physics_frame
   var held_width:=player.visual.weapon_sprite.texture.get_width()*player.visual.weapon_sprite.scale.x
   var drawn_hand:=player.visual.hand_global()
   player._throw_current()
   var pickup:WeaponPickup
   for child in get_children():
    if child is WeaponPickup and child.weapon==saw:pickup=child
   print("THROW geometry start=",pickup.global_position," velocity=",pickup.velocity," target=",enemy.global_position)
   if weapon_name=="chainsaw":check(absf(pickup.sprite.texture.get_width()*pickup.sprite.scale.x-held_width)<.1,"saw retains held size when thrown")
   check(pickup.sprite.global_position.distance_to(drawn_hand)<.01,"drawn throw starts at hand")
   check(pickup!=null,"throw creates recoverable same weapon")
   for frame in 180:await get_tree().physics_frame
   check(pickup._hit_this_throw.size()==1,"physical flight hits guard exactly once")
   check((not is_instance_valid(enemy) or not enemy.is_alive()) if saw.data.throw_lethal else (is_instance_valid(enemy) and enemy.state==Enemy.State.DOWNED),"impact respects weapon lethality")
   check(pickup.sprite.position.length()<.01,"drawn throw settles on floor")
   check(pickup.can_pick_up(),"weapon settles and becomes collectible")
   check(WeaponPickup.nearest(pickup.global_position,get_tree())==pickup,"settled saw is discoverable by pickup system")
   player._pick_up(pickup)
   check(player.current()==saw,"pickup restores same saw instance")
   check(player.visual._powered_weapon==(weapon_name=="chainsaw") and not player.visual.powered_cutting,"pickup restores ready powered hold")
   await get_tree().process_frame
   check(not is_instance_valid(pickup),"pickup removes floor instance")
   if is_instance_valid(enemy):enemy.queue_free()
   player.queue_free()
   for child in get_children():
    if child is WeaponPickup:child.queue_free()
   await get_tree().process_frame
 SaveManager.data=saved
 print("WEAPON THROW FACINGS: ",failures," failures")
 Game.request_quit(1 if failures else 0)
