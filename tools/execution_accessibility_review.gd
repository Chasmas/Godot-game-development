extends Node2D
var failures := 0
func check(ok:bool,label:String)->void:
 if not ok: failures += 1
 print("PASS " if ok else "FAIL ",label)
func _ready()->void:
 Engine.set_meta("skip_tasks",true)
 await get_tree().process_frame
 var player := Player.new()
 add_child(player)
 player.setup(CharacterData.new())
 player.position = Vector2(100,100)
 player.set_physics_process(false)
 player.visual.set_process(false)
 player.input_enabled = true
 var enemy := Enemy.new()
 enemy.idle_action = "watch"
 add_child(enemy)
 enemy.setup(DB.enemy(&"guard"),self,Vector2.RIGHT)
 enemy.position = Vector2(120,100)
 enemy.state = Enemy.State.DOWNED
 enemy.set_physics_process(false)
 enemy.visual.set_process(false)
 var wall := StaticBody2D.new()
 wall.position = Vector2(110,100)
 wall.collision_layer = Layers.WORLD
 var collider := CollisionShape2D.new()
 var shape := RectangleShape2D.new()
 shape.size = Vector2(2,30)
 collider.shape = shape
 wall.add_child(collider)
 add_child(wall)
 for frame in 2: await get_tree().physics_frame
 check(player._find_downed() == null,"wall blocks close downed execution selection")
 player._update_prompt()
 check(player.prompt_target != enemy,"wall blocks execution HUD target")
 wall.collision_layer = Layers.DOOR
 for frame in 2: await get_tree().physics_frame
 check(player._find_downed() == null,"closed door blocks downed execution selection")
 wall.collision_layer = 0
 for frame in 2: await get_tree().physics_frame
 check(player._find_downed() == enemy,"clear close downed enemy remains selectable")
 player._update_prompt()
 check(player.prompt_target == enemy and player.prompt.contains("EXECUTE"),"clear target shows execution prompt")
 player._stagger = .3
 player._update_prompt()
 check(player.prompt_target != enemy,"stagger hides unavailable execution prompt")
 player._stagger = 0
 player.input_enabled = false
 player._update_prompt()
 check(player.prompt.is_empty() and player.prompt_target == null,"disabled control clears old interaction prompt")
 player.input_enabled = true
 player._locked_t = .3
 player._update_prompt()
 check(player.prompt.is_empty(),"paired animation hides interaction prompt")
 enemy.state = Enemy.State.IDLE
 enemy.facing = Vector2.RIGHT
 player._locked_t = 0
 wall.collision_layer = Layers.DOOR
 for frame in 2: await get_tree().physics_frame
 check(player._find_takedown() == null,"closed door blocks standing takedown selection")
 wall.collision_layer = 0
 for frame in 2: await get_tree().physics_frame
 check(player._find_takedown() == enemy,"clear unaware guard can still be grabbed from behind")
 print("EXECUTION ACCESSIBILITY REVIEW: ",failures," failures")
 Game.request_quit(1 if failures else 0)