extends Node
class Target:
 extends Node2D
 var alive := true
 func is_alive() -> bool: return alive
class LockPlayer:
 extends Player
 var candidates: Array = []
 func _ready() -> void: pass
 func _physics_process(_delta: float) -> void: pass
 func _process(_delta: float) -> void: pass
 func _lock_candidates() -> Array:
  return candidates.filter(func(t): return is_instance_valid(t) and t.is_alive())
var failures: Array = []
func check(ok: bool, message: String) -> void:
 if not ok: failures.append(message)
func _ready() -> void:
 var p := LockPlayer.new()
 add_child(p)
 var target := Target.new()
 add_child(target)
 p.candidates=[target]
 var changes: Array=[]
 Events.lock_changed.connect(func(t): changes.append(t))
 await get_tree().process_frame
 Input.action_press("lock_on")
 p._update_lock(.016)
 check(p.lock_target==target,"First tap acquires target")
 await get_tree().process_frame
 p._update_lock(.016)
 check(p.lock_target==target,"Held button does not toggle repeatedly")
 Input.action_release("lock_on")
 await get_tree().process_frame
 Input.action_press("lock_on")
 p._update_lock(.016)
 check(p.lock_target==null,"Second tap releases sole target")
 check(changes.size()==2,"One signal per manual transition")
 await get_tree().process_frame
 p._update_lock(.016)
 check(p.lock_target==null,"Manual release remains released despite auto-next")
 Input.action_release("lock_on")
 await get_tree().process_frame
 Input.action_press("lock_on")
 p._update_lock(.016)
 Input.action_release("lock_on")
 await get_tree().process_frame
 target.alive=false
 p._update_lock(.016)
 check(p.lock_target==null,"Dead last target releases lock")
 check(changes.back()==null,"Target loss notifies HUD")
 var second := Target.new()
 add_child(second)
 target.alive=true
 p.candidates=[target,second]
 p.set_lock(target)
 await get_tree().process_frame
 Input.action_press("lock_on")
 p._update_lock(.016)
 check(p.lock_target==null,"Tap releases even when multiple targets exist")
 Input.action_release("lock_on")
 await get_tree().process_frame
 p.set_lock(target)
 target.alive=false
 p._update_lock(.016)
 check(p.lock_target==second,"Auto-next still selects living candidate")
 target.alive=true
 p.candidates=[target]
 second.position=Vector2(1000,0)
 p._update_lock(.016)
 check(p.lock_target==null,"Out-of-range target releases without grabbing another candidate")
 second.queue_free()
 print("LOCK TOGGLE REVIEW: ",failures.size()," failures ",failures)
 p.queue_free()
 target.queue_free()
 Game.request_quit(1 if not failures.is_empty() else 0)
