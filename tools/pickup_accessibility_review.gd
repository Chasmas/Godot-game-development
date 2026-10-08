extends Node2D
var failures := 0
func check(ok:bool,label:String)->void:
 if not ok: failures += 1
 print("PASS " if ok else "FAIL ",label)
func _ready()->void:
 await get_tree().process_frame
 var origin := Vector2(100,100)
 var blocked := WeaponPickup.spawn(self,WeaponInstance.create(DB.weapon(&"knife")),origin+Vector2(10,0))
 var reachable := WeaponPickup.spawn(self,WeaponInstance.create(DB.weapon(&"pistol")),origin+Vector2(0,14))
 var wall := StaticBody2D.new()
 wall.position = origin+Vector2(5,0)
 wall.collision_layer = Layers.WORLD
 var collider := CollisionShape2D.new()
 var shape := RectangleShape2D.new()
 shape.size = Vector2(2,8)
 collider.shape = shape
 wall.add_child(collider)
 add_child(wall)
 for frame in 2: await get_tree().physics_frame
 check(WeaponPickup.nearest(origin,get_tree()) == reachable,"blocked nearest weapon does not hide reachable alternative")
 reachable.thrown = true
 reachable.set_physics_process(false)
 check(WeaponPickup.nearest(origin,get_tree()) == null,"wall prevents pickup when no alternative is settled")
 wall.collision_layer = Layers.DOOR
 for frame in 2: await get_tree().physics_frame
 check(WeaponPickup.nearest(origin,get_tree()) == null,"closed door prevents weapon pickup")
 wall.collision_layer = 0
 for frame in 2: await get_tree().physics_frame
 check(WeaponPickup.nearest(origin,get_tree()) == blocked,"opening the route restores nearest weapon")
 blocked.queue_free()
 check(WeaponPickup.nearest(origin,get_tree()) == null,"queued pickup cannot be selected twice")
 print("PICKUP ACCESSIBILITY REVIEW: ",failures," failures")
 Game.request_quit(1 if failures else 0)