extends RefCounted
## Candidate texture-only fitting; no runtime integration yet.
static func fit(source: Array, target: Array) -> Transform2D:
	if source.size() != target.size() or source.size() < 3:
		return Transform2D.IDENTITY
	var xx := 0.0
	var xy := 0.0
	var yy := 0.0
	var bx := Vector2.ZERO
	var by := Vector2.ZERO
	for i in source.size():
		var x: Vector2 = source[i]
		var y: Vector2 = target[i]
		xx += x.x * x.x
		xy += x.x * x.y
		yy += x.y * x.y
		bx += y * x.x
		by += y * x.y
	var determinant := xx * yy - xy * xy
	if determinant <= maxf(0.000001, xx * yy * 0.000001):
		return Transform2D.IDENTITY
	var axis_x := (bx * yy - by * xy) / determinant
	var axis_y := (by * xx - bx * xy) / determinant
	var trace := axis_x.length_squared() + axis_y.length_squared()
	var det := axis_x.cross(axis_y)
	var discriminant := sqrt(maxf(0.0, trace * trace - 4.0 * det * det))
	var low := sqrt(maxf(0.0, (trace - discriminant) * 0.5))
	var high := sqrt(maxf(0.0, (trace + discriminant) * 0.5))
	# Reject reflections, collapsed ribbons and unstable stretches.
	if not is_finite(high) or not is_finite(low) or det <= 0.0 or low < 0.45 or high > 1.8:
		return Transform2D.IDENTITY
	return Transform2D(axis_x, axis_y, Vector2.ZERO)
