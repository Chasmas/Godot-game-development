class_name AmbientEventDirector
extends Node
## Rare, non-interactive visual beats. Never changes actors, nav or objectives.
@export var interval_min := 8.0
@export var interval_max := 16.0
var _rng := RandomNumberGenerator.new()
var _tree_event_cooldown := 0.0
var _tree_strike_done := false

func _ready() -> void:
	_rng.randomize()
	_schedule()

func _schedule() -> void:
	var timer := get_tree().create_timer(_rng.randf_range(interval_min, interval_max), false)
	timer.timeout.connect(_beat)

func _beat() -> void:
	_try_tree_strike()
	var candidates: Array[Node] = []
	for child in get_parent().get_children():
		# NeonSign is an inner class of decor.gd, so detect its stable drawing
		# interface instead of depending on a global class name.
		if child is Node2D and child.has_method("board_size"):
			candidates.append(child)
	if not candidates.is_empty():
		var sign := candidates[_rng.randi_range(0, candidates.size() - 1)] as Node2D
		var flash := PointLight2D.new()
		flash.texture = SpriteLib.light_texture(128)
		flash.color = Color(0.45, 0.85, 1.0) if _rng.randf() > 0.5 else Color(1.0, 0.28, 0.5)
		flash.energy = 0.0
		flash.texture_scale = 0.45
		sign.add_child(flash)
		var tw := create_tween()
		tw.tween_property(flash, "energy", 0.75, 0.08)
		tw.tween_property(flash, "energy", 0.0, 0.24)
		tw.tween_callback(flash.queue_free)
	_schedule()

func _try_tree_strike() -> void:
	# The tree strike is a one-off authored surprise. Weather lightning remains
	# reusable atmosphere, but no second tree is ever ignited in this level run.
	var level := get_parent().get_parent()
	var weather := level.get("weather") as WeatherSystem
	if weather == null or not weather.thunder or weather.rain < 0.2:
		return
	if _tree_strike_done or _tree_event_cooldown > 0.0 or _rng.randf() > 0.22:
		_tree_event_cooldown = maxf(0.0, _tree_event_cooldown - _rng.randf_range(8.0, 16.0))
		return
	var trees: Array[Node] = []
	for child in get_parent().get_children():
		if child is Node2D and child.has_method("start_lightning_fire"):
			trees.append(child)
	if trees.is_empty():
		return
	var tree := trees[_rng.randi_range(0, trees.size() - 1)] as Node2D
	_tree_event_cooldown = 55.0
	_tree_strike_done = true
	var bolt := LightningStrike.new()
	# The drawn terminal point is (7,0); place it on the actual crown centre.
	bolt.position = Vector2(-7, 0)
	tree.add_child(bolt)
	bolt.strike()
	tree.call("start_lightning_fire")
	Audio.play("thunder", -4.0, _rng.randf_range(0.9, 1.08))
	Events.camera_shake.emit(1.2)

class LightningStrike extends Node2D:
	var _flash := 0.0
	var _age := 0.0
	var _points := PackedVector2Array()
	var _branches: Array[PackedVector2Array] = []
	var _light: PointLight2D
	func strike() -> void:
		_age = 0.0
		z_index = 1
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_points = _channel(Vector2(-18,-150), Vector2(7,0), 4, 17.0, rng)
		_branches.clear()
		for index in [4,7,10]:
			var origin := _points[index]
			var side := -1.0 if index % 2 == 0 else 1.0
			_branches.append(_channel(origin, origin + Vector2(side * rng.randf_range(17,31),rng.randf_range(18,34)),3,5.0,rng))
		_light = PointLight2D.new()
		_light.texture = SpriteLib.light_texture(256)
		_light.texture_scale = 0.8
		_light.color = Color(0.65,0.82,1.0)
		_light.position = Vector2(7,0)
		add_child(_light)
		_update_flash()
	func _channel(a: Vector2, b: Vector2, depth: int, spread: float, rng: RandomNumberGenerator) -> PackedVector2Array:
		if depth == 0: return PackedVector2Array([a,b])
		var middle := (a+b)*0.5 + (b-a).orthogonal().normalized()*rng.randf_range(-spread,spread)
		var left := _channel(a,middle,depth-1,spread*0.48,rng)
		var right := _channel(middle,b,depth-1,spread*0.48,rng)
		right.remove_at(0)
		left.append_array(right)
		return left
	func _process(delta: float) -> void:
		_age += delta
		_update_flash()
		if _age >= 0.4: queue_free()
	func _update_flash() -> void:
		# Main discharge, dark gap, short return stroke, then afterglow.
		if _age < 0.045: _flash = 1.0
		elif _age < 0.075: _flash = 0.08
		elif _age < 0.11: _flash = 0.75
		else: _flash = 0.32 * exp(-(_age-0.11)*24.0)
		if is_instance_valid(_light): _light.energy = _flash * 1.6
		queue_redraw()
	func _draw_channel(points: PackedVector2Array, strength: float) -> void:
		for layer in [[9.0,0.025],[5.0,0.055],[2.4,0.2]]:
			draw_polyline(points, Color(0.38,0.65,1.0,float(layer[1])*strength*_flash),float(layer[0]),true)
		draw_polyline(points,Color(0.87,0.95,1.0,strength*_flash),0.65,true)
	func _draw() -> void:
		if _flash < 0.005 or _points.is_empty(): return
		_draw_channel(_points,1.0)
		for branch in _branches: _draw_channel(branch,0.48)
