extends Node
const Fit = preload("res://tools/melee_texture_fit.gd")
func _ready() -> void:
	var points := [Vector2(1,0),Vector2(0,1),Vector2(-1,1),Vector2(2,3)]
	var reference := Transform2D(Vector2(0.9,0.2),Vector2(-0.3,1.1),Vector2.ZERO)
	var targets := []
	for point in points:
		targets.append(reference.basis_xform(point))
	var result: Transform2D = Fit.fit(points,targets)
	var failures := 0
	for point in points:
		if result.basis_xform(point).distance_to(reference.basis_xform(point)) > 0.00001:
			failures += 1
	for scale in [0.01,225.0,-1.0]:
		targets.clear()
		for point in points:
			targets.append(Vector2(point.x * scale,point.y))
		if Fit.fit(points,targets) != Transform2D.IDENTITY:
			failures += 1
	if Fit.fit([Vector2.ZERO,Vector2.ONE,Vector2.ONE*2],[Vector2.ZERO,Vector2.ONE,Vector2.ONE*2]) != Transform2D.IDENTITY:
		failures += 1
	print("TEXTURE FIT REGRESSION: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
