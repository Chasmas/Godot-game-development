class_name WeatherSystem
extends Node2D
## Dynamic weather: rain that comes and goes, gusting wind, and storms with
## lightning (a DirectionalLight2D pulse that throws shadows through every
## doorway) and delayed thunder. Rain only falls on outdoor floors.
## Level JSON: "weather": {"schedule": [["clear", 30], ["drizzle", 20], ["storm", 45], ...]}

const STATES := {
	"clear":   {"rain": 0.0, "wind": 0.15, "thunder": false},
	"drizzle": {"rain": 0.35, "wind": 0.3, "thunder": false},
	"rain":    {"rain": 0.75, "wind": 0.5, "thunder": false},
	"storm":   {"rain": 1.0, "wind": 0.9, "thunder": true},
}
const OUTDOOR := ":=\"~;"
const MAX_DROPS := 420

var level: Node
var builder: LevelBuilder
var schedule: Array = [["drizzle", 25], ["storm", 50], ["rain", 30], ["clear", 25]]
var rain := 0.0
var wind := 0.2
var thunder := false
var _target_rain := 0.0
var _target_wind := 0.2
var _si := -1
var _state_t := 0.0
var _gust := 0.0
var _gust_t := 0.0
var _flash_t := -1.0
var _next_bolt := 10.0
var _drops: Array = []      # [pos(view-local 0..1), speed, length]
var _splashes: Array = []   # [world pos, t]
var _leaves: Array = []     # [world pos, spin, t]
var _t := 0.0
var bolt: DirectionalLight2D
var rain_player: AudioStreamPlayer
var state_name := "clear"

func setup(p_level: Node, p_builder: LevelBuilder, cfg: Dictionary) -> void:
	level = p_level
	builder = p_builder
	if cfg.has("schedule"):
		schedule = cfg.schedule

func _ready() -> void:
	z_index = 40
	add_to_group("weather")
	bolt = DirectionalLight2D.new()
	bolt.energy = 0.0
	bolt.color = Color(0.75, 0.82, 1.0)
	bolt.rotation = 0.7
	bolt.shadow_enabled = true
	bolt.shadow_color = Color(0, 0, 0, 0.65)
	bolt.range_item_cull_mask = 1 | 2
	bolt.max_distance = 3000.0
	add_child(bolt)
	rain_player = AudioStreamPlayer.new()
	rain_player.bus = "SFX"
	var s: AudioStream = Audio.get_stream("rain_loop")
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = s.data.size() / 2
	rain_player.stream = s
	rain_player.volume_db = -80.0
	add_child(rain_player)
	if s:
		rain_player.play()
	for i in MAX_DROPS:
		_drops.append([Vector2(randf(), randf()), randf_range(0.8, 1.2), randf_range(0.7, 1.3)])
	_advance_state()

func _advance_state() -> void:
	_si = (_si + 1) % schedule.size()
	if not SaveManager.get_setting("weather", true):
		state_name = "clear"
		_state_t = 5.0
		_target_rain = 0.0
		_target_wind = 0.15
		thunder = false
		return
	var entry: Array = schedule[_si]
	state_name = str(entry[0])
	_state_t = float(entry[1])
	var st: Dictionary = STATES.get(state_name, STATES["clear"])
	_target_rain = st.rain
	_target_wind = st.wind
	thunder = st.thunder
	if thunder:
		_next_bolt = randf_range(3.0, 7.0)

func is_outdoor_at(p: Vector2) -> bool:
	if builder == null:
		return false
	var x := int(p.x / 16.0)
	var y := int(p.y / 16.0)
	if y < 0 or y >= builder.h or x < 0 or x >= builder.w:
		return true
	var f: String = builder.floor_grid[y][x]
	return f != "" and OUTDOOR.contains(f)

func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.05)
	rd = minf(rd, 0.1)
	_t += rd
	_state_t -= rd
	if _state_t <= 0.0:
		_advance_state()
	rain = move_toward(rain, _target_rain, rd * 0.12)
	_gust_t -= rd
	if _gust_t <= 0.0:
		_gust_t = randf_range(2.0, 6.0)
		_gust = randf_range(-0.3, 0.6) * _target_wind
	wind = lerpf(wind, _target_wind + _gust, 1.0 - exp(-rd * 1.5))
	# lightning
	if thunder and rain > 0.5:
		_next_bolt -= rd
		if _next_bolt <= 0.0:
			_next_bolt = randf_range(9.0, 22.0)
			_strike()
	if _flash_t >= 0.0:
		_flash_t += rd
		var e := 0.0
		for pulse in [[0.0, 0.06, 1.5], [0.11, 0.16, 0.9], [0.22, 0.42, 1.2]]:
			if _flash_t >= pulse[0] and _flash_t <= pulse[1]:
				e = pulse[2] * (1.0 - (_flash_t - pulse[0]) / (pulse[1] - pulse[0]) * 0.6)
		if SaveManager.get_setting("reduced_flashing", false):
			e *= 0.3
		bolt.energy = e
		if _flash_t > 0.5:
			_flash_t = -1.0
			bolt.energy = 0.0
	# audio: louder outside
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var outside := p != null and is_outdoor_at(p.global_position)
	var vol := rain * (1.0 if outside else 0.35)
	rain_player.volume_db = linear_to_db(maxf(vol * 0.55, 0.0001))
	# particles
	if rain > 0.02:
		for i in int(rain * 6.0 * rd * 60.0):
			var sp := _random_view_point()
			if is_outdoor_at(sp):
				_splashes.append([sp, 0.0])
	var i2 := _splashes.size() - 1
	while i2 >= 0:
		_splashes[i2][1] += rd
		if _splashes[i2][1] > 0.3:
			_splashes.remove_at(i2)
		i2 -= 1
	if wind > 0.45 and randf() < rd * wind * 2.5:
		_leaves.append([_random_view_point() - Vector2(260, 0), randf() * TAU, 0.0])
	var j := _leaves.size() - 1
	while j >= 0:
		var L: Array = _leaves[j]
		L[0] += Vector2(90.0 + wind * 160.0, sin(_t * 3.0 + L[1]) * 20.0) * rd
		L[1] += rd * 6.0
		L[2] += rd
		if L[2] > 4.0:
			_leaves.remove_at(j)
		j -= 1
	queue_redraw()

func _strike() -> void:
	_flash_t = 0.0
	bolt.rotation = randf_range(0.3, 1.2)
	PostFX.flash(Color(0.85, 0.9, 1.0), 0.12)
	var delay := randf_range(0.3, 1.4)
	get_tree().create_timer(delay, false).timeout.connect(func():
		if is_instance_valid(self):
			Audio.play("thunder", -2.0 if delay < 0.7 else -7.0, randf_range(0.85, 1.05))
			Events.camera_shake.emit(2.0 if delay < 0.7 else 0.8)
			InputSetup.vibrate(0.2, 0.5, 0.25))

func _view_rect() -> Rect2:
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var vs := get_viewport_rect().size
	var a := inv * Vector2.ZERO
	var b := inv * vs
	return Rect2(a, b - a).abs()

func _random_view_point() -> Vector2:
	var r := _view_rect()
	return r.position + Vector2(randf() * r.size.x, randf() * r.size.y)

func _draw() -> void:
	if rain <= 0.01 and _leaves.is_empty():
		return
	var r := _view_rect()
	var n := int(MAX_DROPS * rain)
	var slant := Vector2(wind * 0.55, 1.0).normalized()
	var fall := _t * 1.6
	for i in n:
		var d: Array = _drops[i]
		var u: Vector2 = d[0]
		var yy := fposmod(u.y + fall * float(d[1]), 1.0)
		var xx := fposmod(u.x + yy * wind * 0.25 + _t * wind * 0.05, 1.0)
		var wp := r.position + Vector2(xx * r.size.x, yy * r.size.y)
		if not is_outdoor_at(wp):
			continue
		var L := 7.0 * float(d[2]) * (0.6 + rain * 0.6)
		draw_line(wp, wp + slant * L, Color(0.7, 0.8, 1.0, 0.22 + 0.2 * rain), 1.0)
	for s in _splashes:
		var k: float = s[1] / 0.3
		draw_set_transform(s[0], 0.0, Vector2(1.0, 0.55))
		draw_arc(Vector2.ZERO, 1.0 + k * 4.0, 0, TAU, 8, Color(0.75, 0.85, 1.0, 0.5 * (1.0 - k)), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for L in _leaves:
		var lp: Vector2 = L[0]
		if not is_outdoor_at(lp):
			continue
		var dir := Vector2.from_angle(L[1])
		draw_line(lp - dir * 2.0, lp + dir * 2.0, Color(0.35, 0.55, 0.2, 0.9), 2.0)
