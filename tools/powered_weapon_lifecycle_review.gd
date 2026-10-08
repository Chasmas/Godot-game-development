extends Node2D
var failures := 0
func check(ok: bool,label: String) -> void:
 if not ok: failures+=1
 print("PASS " if ok else "FAIL ",label)
func _ready() -> void:
 Engine.set_meta("skip_tasks",true)
 await get_tree().process_frame
 var saved:=SaveManager.data.duplicate(true)
 add_child(Effects.new())
 for action in ["swap","throw"]:
  var player:=Player.new()
  add_child(player)
  player.setup(CharacterData.new())
  player.set_physics_process(false)
  var saw:=WeaponInstance.create(DB.weapon(&"chainsaw"))
  player.slots=[saw,WeaponInstance.create(DB.weapon(&"pistol"))]
  player.slot=0
  player._refresh_weapon()
  player.aim_dir=Vector2.RIGHT
  var enemy:=Enemy.new()
  enemy.idle_action="watch"
  add_child(enemy)
  enemy.setup(DB.enemy(&"guard"),self,Vector2.LEFT)
  enemy.armor_left=0
  enemy.position=Vector2(20,0)
  enemy.set_physics_process(false)
  await get_tree().physics_frame
  await get_tree().physics_frame
  Input.action_press("fire")
  player._chainsaw_attack(saw)
  player.visual.set_powered_cutting(true)
  player._tick_timers(saw.data.melee_windup*.5)
  if action=="swap":player._swap()
  else:player._throw_current()
  # Freeze the physical thrown weapon: this check isolates pending melee damage.
  var dropped:=0
  for child in get_children():
   if child is WeaponPickup:
    child.set_physics_process(false)
    if child.weapon==saw:dropped+=1
  check(player._pending_melee<0 and player._pending_weapon==null,action+" cancels pending contact")
  check(not player.visual._powered_weapon and not player.visual.powered_cutting,action+" clears cutting visual")
  check(player.current().data.id==&"pistol",action+" selects pistol")
  check(dropped==(1 if action=="throw" else 0),action+" drops correct count")
  player._tick_timers(.2)
  check(enemy.is_alive(),action+" has no delayed saw damage")
  Input.action_release("fire")
  enemy.queue_free()
  player.queue_free()
  for child in get_children():
   if child is WeaponPickup:child.queue_free()
  await get_tree().process_frame
 SaveManager.data=saved
 print("POWERED WEAPON LIFECYCLE: ",failures," failures")
 Game.request_quit(1 if failures else 0)
