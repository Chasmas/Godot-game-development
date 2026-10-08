extends Node2D
var failures := 0
class InteractionProbe extends Node2D:
 var uses := 0
 func interact(_player:Player)->void: uses += 1
 func get_prompt()->String: return "USE SWITCH"
func check(ok:bool,label:String)->void:
 if not ok: failures += 1
 print("PASS " if ok else "FAIL ",label)
func _ready()->void:
 await get_tree().process_frame
 var player := Player.new()
 add_child(player)
 player.setup(CharacterData.new())
 player.position = Vector2(100,100)
 player.set_physics_process(false)
 player.visual.set_process(false)
 player.input_enabled = true
 var object := InteractionProbe.new()
 add_child(object)
 object.add_to_group("interactable")
 object.position = player.position+Vector2(20,0)
 var pickup := WeaponPickup.spawn(self,WeaponInstance.create(DB.weapon(&"knife")),player.position+Vector2(0,8))
 for frame in 2: await get_tree().physics_frame
 player._update_prompt()
 check(player.prompt_target == pickup,"HUD selects clearly closer weapon rather than distant switch")
 player._interact()
 check(player.current()!=null and player.current().data.id == &"knife" and object.uses == 0,"button performs displayed weapon pickup")
 pickup = WeaponPickup.spawn(self,WeaponInstance.create(DB.weapon(&"pistol")),player.position+Vector2(0,10))
 object.position = player.position+Vector2(12,0)
 for frame in 2: await get_tree().physics_frame
 player._update_prompt()
 check(player.prompt_target == object and player.prompt.contains("USE SWITCH"),"HUD honors nearby interactable priority within four pixels")
 player._interact()
 check(object.uses == 1 and not pickup.is_queued_for_deletion(),"button uses displayed switch and leaves weapon")
 object.position = player.position+Vector2(50,0)
 player._update_prompt()
 check(player.prompt_target == pickup,"HUD falls back to weapon when switch leaves reach")
 object.position = player.position+Vector2(12,0)
 var wall := StaticBody2D.new()
 wall.position = player.position+Vector2(6,0)
 wall.collision_layer = Layers.WORLD
 var collider := CollisionShape2D.new()
 var shape := RectangleShape2D.new()
 shape.size = Vector2(2,8)
 collider.shape = shape
 wall.add_child(collider)
 add_child(wall)
 for frame in 2: await get_tree().physics_frame
 player._update_prompt()
 check(player.prompt_target == pickup,"wall-blocked switch yields accessible weapon prompt")
 check(player._nearest_interactable() == null,"wall blocks interactable selection")
 wall.collision_layer = Layers.DOOR
 for frame in 2: await get_tree().physics_frame
 check(player._nearest_interactable() == null,"closed door blocks interactable selection")
 wall.collision_layer = 0
 for frame in 2: await get_tree().physics_frame
 check(player._nearest_interactable() == object,"opening route restores interactive object")
 object.queue_free()
 check(player._nearest_interactable() == null,"queued interactive object cannot be selected again")
 print("INTERACTION PROMPT REVIEW: ",failures," failures")
 Game.request_quit(1 if failures else 0)