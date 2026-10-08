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
 for enemy in level.enemies:
  enemy.set_physics_process(false)
  enemy.state = Enemy.State.DEAD
 level.phase = Level.Phase.BOSS_DOWN
 Dialogue.start(level._boss_dialogue("down"))
 check(Dialogue.active and get_tree().paused,"boss aftermath dialogue owns paused control")
 Dialogue._end(true)
 check(level.phase == Level.Phase.PHONE and level.phone.enabled and level.phone.ringing,"actual dialogue-finished signal arms cleared-motel phone")
 for ending in ["h1","t3"]:
  level.phase = Level.Phase.PHONE
  level.exit_car.enabled = false
  level.phone.enabled = true
  level.phone.interact(level.player)
  check(Dialogue.active and Dialogue._id == "m01_phone","real telephone interaction starts authored call")
  Dialogue._goto(ending)
  check(level.phase == Level.Phase.ESCAPE and level.exit_car.enabled,"authored phone ending unlocks escape: " + ending)
  Dialogue._end(true)
  check(not get_tree().paused and not Dialogue.active and not Dialogue._line_voice.playing,"phone close restores control and stops speech: " + ending)
 SaveManager.data = saved
 print("MOTEL AFTERMATH FLOW REVIEW: ",failures," failures")
 Game.request_quit(1 if failures else 0)