extends Node
func _ready()->void:
 var level := Level.new()
 level.nav = AStarGrid2D.new()
 level.nav.region = Rect2i(0,0,8,8)
 level.nav.cell_size = Vector2(16,16)
 level.nav.offset = Vector2(8,8)
 level.nav.update()
 level.nav.set_point_solid(Vector2i(4,4),true)
 var failures := 0
 var blocked := level.get_nav_path(Vector2(24,24),Vector2(73,74))
 var blocked_ok := not blocked.is_empty()
 if blocked_ok:
  var endpoint := blocked[blocked.size()-1]
  blocked_ok = not level.nav.is_point_solid(Vector2i(endpoint/16.0)) and endpoint.distance_to(Vector2(73,74)) > 1
 if not blocked_ok: failures += 1
 print("PASS " if blocked_ok else "FAIL "," blocked furniture target ends on open floor: ",blocked)
 var exact := level.get_nav_path(Vector2(24,24),Vector2(89,90))
 var exact_ok := not exact.is_empty() and exact[exact.size()-1].distance_to(Vector2(89,90)) < .01
 if not exact_ok: failures += 1
 print("PASS " if exact_ok else "FAIL "," open destination keeps exact position")
 var enemy := Enemy.new()
 enemy.level = level
 enemy.position = Vector2(56,56)
 enemy._path = PackedVector2Array([enemy.position])
 enemy._path_target = Vector2(89,90)
 enemy._repath_t = 10.0
 var stopped_ok := enemy._go_to(Vector2(89,90),100.0) == Vector2.ZERO and enemy._repath_t > 1.0
 if not stopped_ok: failures += 1
 print("PASS " if stopped_ok else "FAIL "," NPC stops at projected endpoint without repeatedly replanning unchanged request")
 enemy.free()
 for outside in [Vector2(-1,24),Vector2(24,-1),Vector2(128,24),Vector2(24,128)]:
  var outside_ok := level.get_nav_path(Vector2(24,24),outside).is_empty() and level.get_nav_path(outside,Vector2(24,24)).is_empty()
  if not outside_ok: failures += 1
  print("PASS " if outside_ok else "FAIL "," outside start/destination rejected: ",outside)
 var fallback_ok := level.nearest_open_point(Vector2(-1,24),Vector2(24,24)) == Vector2(24,24)
 if not fallback_ok: failures += 1
 print("PASS " if fallback_ok else "FAIL "," negative fractional cell uses safe fallback")
 for x in 8:
  for y in 8: level.nav.set_point_solid(Vector2i(x,y),true)
 var trapped_ok := level.get_nav_path(Vector2(24,24),Vector2(73,74)).is_empty()
 if not trapped_ok: failures += 1
 print("PASS " if trapped_ok else "FAIL "," no nearby open floor returns no route")
 level.free()
 print("NAVIGATION ENDPOINT REVIEW: ",failures," failures")
 Audio.shutdown()
 get_tree().quit(1 if failures else 0)
