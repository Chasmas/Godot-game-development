extends Node
var failures := 0
func check(ok:bool,label:String)->void:
 if not ok: failures += 1
 print("PASS " if ok else "FAIL ",label)
func _ready()->void:
 Engine.set_meta("skip_tasks",true)
 Engine.set_meta("autoplay",true)
 process_mode = Node.PROCESS_MODE_ALWAYS
 await get_tree().process_frame
 var saved := SaveManager.data.duplicate(true)
 var placeholder := Node.new()
 get_tree().root.add_child(placeholder)
 get_tree().current_scene = placeholder
 Game.campaign_mode = false
 Game.replay_mission("m01_checkout")
 Game.attempts = 2
 for frame in 90: await get_tree().physics_frame
 var level := get_tree().get_first_node_in_group("level") as Level
 level.set_process(false)
 level.player.set_physics_process(false)
 for enemy in level.enemies: enemy.set_physics_process(false)
 Dialogue._end(false)
 level._on_boss_defeated(null)
 level.player.alive = false
 await get_tree().create_timer(1.05,true,false,true).timeout
 check(not Dialogue.active and not get_tree().paused,"dead player receives no delayed boss dialogue")
 level.player.alive = true
 level._on_boss_defeated(null)
 level.phase = Level.Phase.ESCAPE
 await get_tree().create_timer(1.05,true,false,true).timeout
 check(not Dialogue.active and level.phase == Level.Phase.ESCAPE,"superseded boss phase cannot open stale dialogue")
 level._on_boss_defeated(null)
 await get_tree().create_timer(1.05,true,false,true).timeout
 check(Dialogue.active and Dialogue._id == level._boss_dialogue("down"),"valid living aftermath still starts authored dialogue")
 Dialogue._end(false)
 var original_save_path := SaveManager.save_path
 SaveManager.save_path = "user://delayed_dialogue_lifecycle_review_save.json"
 var evidence := Interactable.new()
 evidence.setup("tape","TAKE TAPE","lifecycle_review_only")
 evidence.set_meta("title","Lifecycle review")
 evidence.set_meta("text","Review evidence")
 level.props_root.add_child(evidence)
 level.player.alive = true
 level._on_collectible(evidence,level.player)
 level.player.alive = false
 await get_tree().create_timer(.55,true,false,true).timeout
 check(not Dialogue.active and not get_tree().paused,"death after collection prevents delayed evidence dialogue")
 SaveManager.save_path = original_save_path
 level.player.alive = true
 SaveManager.data = saved
 print("DELAYED DIALOGUE LIFECYCLE REVIEW: ",failures," failures")
 Game.request_quit(1 if failures else 0)