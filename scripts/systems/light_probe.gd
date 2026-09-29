class_name LightProbe
extends RefCounted
## Which lights fall on a point, for the silhouette shadows: lamps and tubes
## (group "lights", LightFixture), flares and fires. Returns up to `count`
## entries, strongest first: {"dir": unit vector from the light to the
## point (the way the shadow falls), "k": 0..1 how strongly it's lit,
## "far": 0..1 how far inside the light's reach}. With nothing near, a faint
## moonlight entry so everything still sits on the floor.

const MOON := Vector2(0.45, 0.9)

static func sample(tree: SceneTree, p: Vector2, count := 2) -> Array:
	var out: Array = []
	for l in tree.get_nodes_in_group("lights"):
		if not l.on:
			continue
		var d: Vector2 = p - (l as Node2D).global_position
		var dist := d.length()
		if dist > l.radius_px or dist < 0.5:
			continue
		var k: float = l.level_at(p)
		if k > 0.04:
			# steady brightness (energy, not the flicker), so a buzzing tube
			# doesn't make the shadow jitter
			var ks: float = clampf(1.0 - dist / l.radius_px, 0.0, 1.0) * l.energy
			out.append({"id": l.get_instance_id(), "dir": d / dist, "k": clampf(ks, 0.0, 1.0), "far": dist / l.radius_px})
	for f in tree.get_nodes_in_group("flares"):
		var d2: Vector2 = p - (f as Node2D).global_position
		var k2: float = f.light_level_at(p) if f.has_method("light_level_at") else 0.0
		if k2 > 0.04 and d2.length() > 0.5:
			out.append({"id": f.get_instance_id(), "dir": d2.normalized(), "k": clampf(k2, 0.0, 1.0), "far": clampf(d2.length() / 120.0, 0.0, 1.0)})
	for z in tree.get_nodes_in_group("fires"):
		var d3: Vector2 = p - (z as Node2D).global_position
		var dist3 := d3.length()
		if dist3 < 90.0 and dist3 > 0.5:
			out.append({"id": z.get_instance_id(), "dir": d3 / dist3, "k": (1.0 - dist3 / 90.0) * 0.8, "far": dist3 / 90.0})
	out.sort_custom(func(a, b): return a.k > b.k)
	if out.size() > count:
		out.resize(count)
	if out.is_empty():
		out.append({"id": 0, "dir": MOON.normalized(), "k": 0.25, "far": 0.6})
	return out

## A transform that stretches along `dir` by `k` (a shadow laid on the floor).
static func stretch(dir: Vector2, k: float) -> Transform2D:
	var a := dir.angle()
	return Transform2D(a, Vector2.ZERO) * Transform2D(0.0, Vector2(k, 1.0), 0.0, Vector2.ZERO) * Transform2D(-a, Vector2.ZERO)


## Smoothed shadows for something that moves: each light's shadow eases in
## and out and turns smoothly, so walking past lamps (or a lamp flickering)
## never makes the shadow jump.
class Smoother extends RefCounted:
	var cur: Dictionary = {}     ## id -> {dir, k, far}
	var _tgt: Dictionary = {}
	var _t := randf() * 0.15    ## staggered: not every shadow samples on the same frame

	## Straight to the current lights (coming back on screen).
	func snap(tree: SceneTree, p: Vector2) -> void:
		cur.clear()
		for e in LightProbe.sample(tree, p, 3):
			cur[e.id] = e.duplicate()
		_tgt = cur.duplicate(true)
		_t = 0.15

	func update(tree: SceneTree, p: Vector2, delta: float) -> void:
		_t -= delta
		if _t <= 0.0:
			_t = 0.15
			_tgt.clear()
			for e in LightProbe.sample(tree, p, 3):
				_tgt[e.id] = e
		var rate := 1.0 - exp(-delta * 7.0)
		for id in _tgt:
			var t: Dictionary = _tgt[id]
			if not cur.has(id):
				cur[id] = {"dir": t.dir, "k": 0.0, "far": t.far}
			var c: Dictionary = cur[id]
			c.dir = (c.dir as Vector2).slerp(t.dir, rate).normalized()
			c.k = lerpf(c.k, t.k, rate)
			c.far = lerpf(c.far, t.far, rate)
		for id in cur.keys():
			if not _tgt.has(id):
				cur[id].k = lerpf(cur[id].k, 0.0, rate)
				if cur[id].k < 0.01:
					cur.erase(id)

	## the (up to) two strongest right now
	func top(n := 2) -> Array:
		var out: Array = cur.values()
		out.sort_custom(func(a, b): return a.k > b.k)
		if out.size() > n:
			out.resize(n)
		return out
