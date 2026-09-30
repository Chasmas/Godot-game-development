class_name WeatherSystem
extends Node2D
## Dynamic weather. Each level picks a preset (a schedule of states that come
## and go) or its own schedule; arcade runs can override it or roll one at
## random. States mix rain, snow, wind, fog, blowing dust and falling ash, and
## storms add lightning (a DirectionalLight2D pulse that throws shadows
## through every doorway) with delayed thunder. Wind carries debris (leaves,
## newspaper, palm fronds, embers) across outdoor floors in gusts; snow
## settles on them. Presets also set the light: a sunny afternoon, a snowy
## blue night, the orange glow of a Santa Ana night.
## Level JSON: "weather": {"preset": "santa_ana"}
##          or "weather": {"schedule": [["clear", 30], ["storm", 45], ...]}

## rain/snow/fog/dust/ash 0..1, wind 0..1, debris = leaves per second at
## full wind, kinds = what the wind carries.
const STATES := {
	"clear":     {"wind": 0.15},
	"sunny":     {"wind": 0.2, "debris": 0.6, "kinds": ["leaf", "paper"], "clouds": 0.5},
	"windy":     {"wind": 0.75, "debris": 3.0, "kinds": ["leaf", "paper", "frond", "leaf"], "clouds": 0.6},
	"gale":      {"wind": 1.0, "debris": 5.0, "dust": 0.35, "kinds": ["leaf", "paper", "frond", "ember"]},
	"drizzle":   {"rain": 0.35, "wind": 0.3},
	"rain":      {"rain": 0.75, "wind": 0.5, "debris": 0.8, "kinds": ["leaf"]},
	"storm":     {"rain": 1.0, "wind": 0.9, "thunder": true, "debris": 2.0, "kinds": ["leaf", "paper", "frond"]},
	"dust":      {"wind": 0.85, "dust": 0.8, "debris": 2.5, "kinds": ["paper", "frond", "tumble"]},
	"dry_storm": {"wind": 0.9, "dust": 0.45, "thunder": true, "debris": 2.5, "kinds": ["paper", "frond", "tumble"]},
	"santa_ana": {"wind": 0.85, "ash": 0.6, "dust": 0.2, "debris": 3.5, "kinds": ["leaf", "frond", "ember", "paper", "ember"]},
	"fog":       {"fog": 0.85, "wind": 0.1},
	"snow":      {"snow": 0.7, "wind": 0.3, "fog": 0.2},
	"blizzard":  {"snow": 1.0, "wind": 0.95, "fog": 0.35},
	"nightmare": {"rain": 0.32, "fog": 0.38, "wind": 0.3, "thunder": true, "debris": 0.6, "kinds": ["leaf", "ember"], "bolt": [1.0, 0.3, 0.25], "rain_color": [0.72, 0.04, 0.07]},
}

## Named schedules. "light" tints the level's ambient (multiplied) or sets it.
const PRESETS := {
	"night_rain":  {"schedule": [["drizzle", 25], ["rain", 40], ["storm", 50], ["rain", 30], ["clear", 20]]},
	"desert_wind": {"schedule": [["windy", 35], ["dust", 40], ["dry_storm", 45], ["windy", 30]], "light": [1.0, 0.95, 0.88]},
	"santa_ana":   {"schedule": [["santa_ana", 60], ["gale", 30], ["santa_ana", 45]], "light": [1.15, 0.85, 0.72]},
	"snowfall":    {"schedule": [["snow", 60], ["blizzard", 35], ["snow", 45]], "light": [0.85, 0.95, 1.3]},
	"sunny":       {"schedule": [["sunny", 90], ["windy", 30]], "set_ambient": [0.98, 0.9, 0.82], "boost": 1.05},
	"foggy":       {"schedule": [["fog", 70], ["drizzle", 25]], "light": [0.9, 0.92, 1.05]},
	"clear_night": {"schedule": [["clear", 60], ["windy", 25]]},
	"nightmare":   {"schedule": [["nightmare", 999]], "light": [1.05, 0.6, 0.72]},
}
const RANDOM_POOL := ["night_rain", "desert_wind", "santa_ana", "snowfall", "sunny", "foggy", "clear_night"]

const OUTDOOR := ":=\"~;"
const MAX_DROPS := 420
const MAX_FLAKES := 360
const MAX_DEBRIS := 110
const DEBRIS_TEX := {"leaf": "leaf", "paper": "paper", "frond": "frond"}

var level: Node
var builder: LevelBuilder
var preset := ""
var schedule: Array = PRESETS.night_rain.schedule
var rain := 0.0
var snow := 0.0
var fog := 0.0
var dust := 0.0
var ash := 0.0
var clouds := 0.0
var wind := 0.2
var wind_dir := Vector2(1.0, 0.18).normalized()
var thunder := false
var snow_cover := 0.0          ## 0..1 how much snow has settled on the ground
var _target := {}
var _si := -1
var _state_t := 0.0
var _gust := 0.0
var _gust_t := 0.0
var _flash_t := -1.0
var _next_bolt := 10.0
var _drops: Array = []      # [pos(view 0..1), speed, length]
var _flakes: Array = []     # [pos(view 0..1), speed, size, phase]
var _splashes: Array = []   # [world pos, t]
var _debris: Array = []     # {p, v, rot, spin, kind, t, life, s, flip}
var _bits: Array = []       # pieces of debris that broke on a wall
var _t := 0.0
var _debris_acc := 0.0
var bolt: DirectionalLight2D
var rain_player: AudioStreamPlayer
var wind_player: AudioStreamPlayer
var state_name := "clear"
var rain_color := Color(0.7, 0.8, 1.0)   ## blood, in the dream
var _tex: Dictionary = {}
var _soft: Texture2D

func setup(p_level: Node, p_builder: LevelBuilder, cfg: Dictionary) -> void:
	level = p_level
	builder = p_builder
	var over := str(Game.modifiers.get("weather", "")) if Game else ""
	if over == "random":
		over = RANDOM_POOL[randi() % RANDOM_POOL.size()]
	if over != "" and PRESETS.has(over):
		cfg = {"preset": over}
	if cfg.has("preset") and PRESETS.has(str(cfg.preset)):
		preset = str(cfg.preset)
		var p: Dictionary = PRESETS[preset]
		schedule = p.schedule
		if builder:
			if p.has("set_ambient"):
				var a: Array = p.set_ambient
				builder.ambient = Color(a[0], a[1], a[2])
				builder.boost = float(p.get("boost", builder.boost))
			elif p.has("light"):
				var l: Array = p.light
				builder.ambient = Color(builder.ambient.r * l[0], builder.ambient.g * l[1], builder.ambient.b * l[2])
	elif cfg.has("schedule"):
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
	rain_player = _loop_player("rain_loop")
	wind_player = _loop_player("wind_loop")
	for i in MAX_DROPS:
		_drops.append([Vector2(randf(), randf()), randf_range(0.8, 1.2), randf_range(0.7, 1.3)])
	for i in MAX_FLAKES:
		_flakes.append([Vector2(randf(), randf()), randf_range(0.6, 1.4), randf_range(0.8, 2.2), randf() * TAU])
	for k in DEBRIS_TEX:
		var p := "res://assets/art/sprites/%s.png" % DEBRIS_TEX[k]
		var pixel_path := "res://assets/art/pixellab_world/sprites/%s.png" % DEBRIS_TEX[k]
		if ResourceLoader.exists(pixel_path):
			_tex[k] = load(pixel_path)
		elif ResourceLoader.exists(p):
			_tex[k] = load(p)
	_soft = SpriteLib.light_texture(128, 1.2)
	_advance_state()
	# start already in the weather instead of fading in from nothing
	rain = _target.get("rain", 0.0)
	snow = _target.get("snow", 0.0)
	fog = _target.get("fog", 0.0)
	dust = _target.get("dust", 0.0)
	ash = _target.get("ash", 0.0)
	clouds = _target.get("clouds", 0.0)
	wind = _target.get("wind", 0.2)
	if snow > 0.0:
		snow_cover = 0.55

func _loop_player(sound: String) -> AudioStreamPlayer:
	var pl := AudioStreamPlayer.new()
	pl.bus = "SFX"
	var s: AudioStream = Audio.get_stream(sound)
	if s is AudioStreamWAV:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = s.data.size() / 2
	pl.stream = s
	pl.volume_db = -80.0
	add_child(pl)
	if s:
		pl.play()
	return pl

func _advance_state() -> void:
	_si = (_si + 1) % schedule.size()
	if not SaveManager.get_setting("weather", true):
		state_name = "clear"
		_state_t = 5.0
		_target = STATES["clear"]
		thunder = false
		return
	var entry: Array = schedule[_si]
	state_name = str(entry[0])
	_state_t = float(entry[1])
	_target = STATES.get(state_name, STATES["clear"])
	thunder = bool(_target.get("thunder", false))
	var rc: Array = _target.get("rain_color", [0.7, 0.8, 1.0])
	rain_color = Color(rc[0], rc[1], rc[2])
	var bc: Array = _target.get("bolt", [0.75, 0.82, 1.0])
	bolt.color = Color(bc[0], bc[1], bc[2])
	if thunder:
		_next_bolt = randf_range(3.0, 7.0)
	# the wind swings round a little with each change
	wind_dir = Vector2(1.0, randf_range(-0.3, 0.35)).normalized()

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
	rain = move_toward(rain, _target.get("rain", 0.0), rd * 0.12)
	snow = move_toward(snow, _target.get("snow", 0.0), rd * 0.1)
	fog = move_toward(fog, _target.get("fog", 0.0), rd * 0.08)
	dust = move_toward(dust, _target.get("dust", 0.0), rd * 0.12)
	ash = move_toward(ash, _target.get("ash", 0.0), rd * 0.1)
	clouds = move_toward(clouds, _target.get("clouds", 0.0), rd * 0.05)
	snow_cover = clampf(snow_cover + (snow * 0.02 - (0.01 if snow < 0.05 else 0.0)) * rd, 0.0, 1.0)
	var tw: float = _target.get("wind", 0.2)
	_gust_t -= rd
	if _gust_t <= 0.0:
		_gust_t = randf_range(1.5, 5.0)
		_gust = randf_range(-0.3, 0.7) * tw
	wind = lerpf(wind, tw + _gust, 1.0 - exp(-rd * 1.5))
	# lightning
	if thunder and (rain > 0.5 or dust > 0.3 or fog > 0.3):
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
	var wv := clampf((wind - 0.25) * 1.2 + dust * 0.4 + snow * wind * 0.5, 0.0, 1.0) * (1.0 if outside else 0.3)
	wind_player.volume_db = linear_to_db(maxf(wv * 0.5, 0.0001))
	wind_player.pitch_scale = 0.85 + wind * 0.3
	# rain splashes
	if rain > 0.02:
		for i in int(rain * 6.0 * rd * 60.0):
			var sp := _random_view_point()
			if is_outdoor_at(sp):
				# a ring and a few droplets thrown up and out
				var drops: Array = []
				for k in randi_range(2, 4):
					drops.append(Vector3(randf_range(-1.0, 1.0), randf_range(0.6, 1.0), randf_range(0.7, 1.3)))
				_splashes.append([sp, 0.0, drops])
	var i2 := _splashes.size() - 1
	while i2 >= 0:
		_splashes[i2][1] += rd
		if _splashes[i2][1] > 0.3:
			_splashes.remove_at(i2)
		i2 -= 1
	_update_debris(rd)
	queue_redraw()

## Wind-blown debris: spawned upwind of the view, carried by the wind with
## gusts; paper tumbles and flips, leaves flutter, fronds skid, tumbleweeds
## roll and bounce, embers glow and fade.
func _update_debris(rd: float) -> void:
	var rate: float = float(_target.get("debris", 0.0)) * clampf(wind * 1.3, 0.0, 1.4)
	if ash > 0.05:
		rate += ash * 3.0
	_debris_acc += rate * rd
	var kinds: Array = _target.get("kinds", ["leaf"])
	if ash > 0.05:
		kinds = kinds + ["ash", "ash"]
	var r := _view_rect()
	while _debris_acc >= 1.0 and _debris.size() < MAX_DEBRIS:
		_debris_acc -= 1.0
		var kind: String = kinds[randi() % kinds.size()]
		var start := r.position + Vector2(randf() * r.size.x, randf() * r.size.y)
		# enter from the upwind edge most of the time
		if randf() < 0.7:
			start = r.position + Vector2(-20.0 if wind_dir.x > 0.0 else r.size.x + 20.0, randf() * r.size.y)
		_debris.append({"p": start, "v": wind_dir * randf_range(40.0, 90.0), "rot": randf() * TAU, "spin": randf_range(-6.0, 6.0),
			"kind": kind, "t": 0.0, "life": randf_range(5.0, 9.0), "s": randf_range(0.7, 1.3), "flip": randf() * TAU, "z": 0.0})
	_debris_acc = minf(_debris_acc, 3.0)
	var j := _debris.size() - 1
	while j >= 0:
		var d: Dictionary = _debris[j]
		d.t += rd
		var speed := 60.0 + wind * 230.0
		var drag := 0.9
		match d.kind:
			"paper":
				speed *= 1.1
				d.flip += rd * (3.0 + wind * 6.0)
			"frond":
				speed *= 0.65
				drag = 0.6
			"tumble":
				speed *= 0.8
				d.z = absf(sin(d.t * 3.0 + d.flip)) * 6.0
			"ember":
				speed *= 1.25
			"ash":
				speed *= 0.5
			_:
				d.flip += rd * 5.0
		var want: Vector2 = wind_dir * speed + Vector2(sin(_t * 2.3 + d.rot) * 25.0, cos(_t * 1.7 + d.flip) * 18.0)
		d.v = (d.v as Vector2).lerp(want, 1.0 - exp(-rd * drag * 2.0))
		d.p += d.v * rd
		d.rot += d.spin * rd * (0.4 + wind)
		if d.t > d.life or not r.grow(80.0).has_point(d.p):
			_debris.remove_at(j)
		elif d.t > 0.2 and r.has_point(d.p) and not is_outdoor_at(d.p):
			# it hit a wall / roofline: it breaks up instead of vanishing
			_shatter(d)
			_debris.remove_at(j)
		j -= 1
	# the pieces: flung out off the wall, tumbling, settling and fading
	var i := _bits.size() - 1
	while i >= 0:
		var b: Dictionary = _bits[i]
		b.t += rd
		b.v = (b.v as Vector2) * (1.0 - rd * 3.0) + wind_dir * wind * 40.0 * rd
		b.p += b.v * rd
		b.h = maxf(0.0, b.h + b.vh * rd)
		b.vh -= 60.0 * rd
		b.rot += b.spin * rd
		if b.t > b.life:
			_bits.remove_at(i)
		i -= 1

## Debris meeting a wall: a leaf tears into flecks, paper into scraps, a
## frond or a tumbleweed snaps into twigs, an ember bursts into sparks.
func _shatter(d: Dictionary) -> void:
	var col := Color(0.35, 0.55, 0.2)
	var n := 6
	match str(d.kind):
		"paper":
			col = Color(0.86, 0.84, 0.76)
			n = 7
		"frond":
			col = Color(0.55, 0.42, 0.22)
			n = 8
		"tumble":
			col = Color(0.55, 0.42, 0.25)
			n = 12
		"ember":
			col = Color(1.0, 0.6, 0.2)
			n = 5
		"ash":
			col = Color(0.75, 0.72, 0.7)
			n = 3
	var back := -(d.v as Vector2).normalized()
	for k in n:
		if _bits.size() >= 160:
			return
		var dir := back.rotated(randf_range(-1.3, 1.3))
		_bits.append({"p": d.p + dir * 2.0, "v": dir * randf_range(30.0, 90.0), "h": randf_range(2.0, 6.0), "vh": randf_range(10.0, 40.0),
			"rot": randf() * TAU, "spin": randf_range(-12.0, 12.0), "t": 0.0, "life": randf_range(0.5, 1.1) * (0.5 if d.kind == "ember" else 1.0),
			"c": col.lerp(col.darkened(0.3), randf()), "s": randf_range(0.8, 1.6) * float(d.s), "kind": str(d.kind)})

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

func _cell_hash(x: int, y: int) -> int:
	var v := (x * 73856093) ^ (y * 19349663)
	return absi(v ^ (v >> 13))

func _draw() -> void:
	var r := _view_rect()
	# settled snow: a soft white blanket over outdoor floors, patchy per cell
	if snow_cover > 0.02 and builder:
		var x0 := maxi(0, int(r.position.x / 16.0))
		var y0 := maxi(0, int(r.position.y / 16.0))
		var x1 := mini(builder.w - 1, int(r.end.x / 16.0) + 1)
		var y1 := mini(builder.h - 1, int(r.end.y / 16.0) + 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var f: String = builder.floor_grid[y][x]
				if f == "" or f == "~" or not OUTDOOR.contains(f):
					continue
				var hh := _cell_hash(x, y)
				var a := snow_cover * (0.5 + 0.25 * float(hh % 7) / 6.0)
				draw_rect(Rect2(x * 16, y * 16, 16, 16), Color(0.92, 0.95, 1.0, a))
				if hh % 5 == 0:
					draw_circle(Vector2(x * 16 + hh % 13 + 2, y * 16 + (hh >> 4) % 13 + 2), 2.5, Color(1, 1, 1, snow_cover * 0.5))
	# cloud shadows sliding across sunny/windy ground
	if clouds > 0.02:
		for i in 5:
			var cx := fposmod(i * 347.0 + _t * (12.0 + wind * 30.0), r.size.x + 600.0) - 300.0
			var cy := fposmod(i * 211.0 + _t * 3.0, r.size.y + 300.0) - 150.0
			draw_texture_rect(_soft, Rect2(r.position + Vector2(cx, cy) - Vector2(260, 180), Vector2(520, 360)), false, Color(0.05, 0.02, 0.1, 0.16 * clouds))
	# rain
	if rain > 0.01:
		var n := int(MAX_DROPS * rain)
		var slant := Vector2(wind * 0.55 * signf(wind_dir.x), 1.0).normalized()
		var fall := _t * 1.6
		for i in n:
			var d: Array = _drops[i]
			var u: Vector2 = d[0]
			var yy := fposmod(u.y + fall * float(d[1]), 1.0)
			var xx := fposmod(u.x + yy * wind * 0.25 * signf(wind_dir.x) + _t * wind * 0.05, 1.0)
			var wp := r.position + Vector2(xx * r.size.x, yy * r.size.y)
			if not is_outdoor_at(wp):
				continue
			var L := 7.0 * float(d[2]) * (0.6 + rain * 0.6)
			draw_line(wp, wp + slant * L, Color(rain_color, 0.3 + 0.25 * rain), 1.0)
		for s in _splashes:
			var k: float = s[1] / 0.3
			draw_set_transform(s[0], 0.0, Vector2(1.0, 0.55))
			draw_arc(Vector2.ZERO, 1.0 + k * 4.0, 0, TAU, 8, Color(rain_color.lightened(0.1), 0.5 * (1.0 - k)), 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# droplets: a little hop up and out, falling back as they fade
			if s.size() > 2:
				for dv in s[2]:
					var v: Vector3 = dv
					var hop := Vector2(v.x * 5.0 * k * v.z, -sin(k * PI) * 5.0 * v.y)
					draw_rect(Rect2(s[0] + hop, Vector2(1, 1)), Color(rain_color.lightened(0.25), 0.8 * (1.0 - k)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# wet-road glints: sparse highlights sell rain without a reflection pass
		if rain > 0.45:
			for g in int(18.0 * rain):
				var gp := _random_view_point()
				if not is_outdoor_at(gp):
					continue
				var gl := 0.35 + 0.65 * sin(_t * 4.0 + float(g) * 1.7)
				draw_line(gp, gp + Vector2(10.0 + gl * 12.0, 0.0), Color(0.55, 0.7, 0.9, 0.08 + 0.08 * gl), 1.0)
	# snowfall: slow flakes that sway and ride the wind
	if snow > 0.01:
		var n2 := int(MAX_FLAKES * snow)
		for i in n2:
			var f: Array = _flakes[i]
			var u: Vector2 = f[0]
			var yy := fposmod(u.y + _t * 0.08 * float(f[1]), 1.0)
			var xx := fposmod(u.x + _t * wind * 0.09 * signf(wind_dir.x) + sin(_t * 1.3 + float(f[3])) * 0.01, 1.0)
			var wp := r.position + Vector2(xx * r.size.x, yy * r.size.y)
			if not is_outdoor_at(wp):
				continue
			var sz: float = f[2]
			draw_rect(Rect2(wp, Vector2(sz, sz)), Color(1, 1, 1, 0.55 + 0.35 * snow))
			if wind > 0.7:
				draw_line(wp, wp - wind_dir * sz * 3.0, Color(1, 1, 1, 0.25), 1.0)
	# blowing dust: a brown haze and fast streaks along the wind
	if dust > 0.02:
		draw_rect(r, Color(0.55, 0.38, 0.22, 0.12 * dust))
		for i in int(40 * dust):
			var sx := fposmod(i * 97.0 + _t * (300.0 + i * 7.0) * wind, r.size.x + 100.0) - 50.0
			var sy := fposmod(i * 53.0 + sin(_t * 0.7 + i) * 30.0, r.size.y)
			var sp := r.position + Vector2(sx if wind_dir.x > 0.0 else r.size.x - sx, sy)
			if is_outdoor_at(sp):
				draw_line(sp, sp + wind_dir * (18.0 + i % 5 * 6.0), Color(0.8, 0.62, 0.42, 0.18 * dust), 1.0)
	# debris
	for d in _debris:
		var lp: Vector2 = d.p
		if not is_outdoor_at(lp):
			continue
		var s: float = d.s
		match d.kind:
			"ember":
				var k: float = 1.0 - d.t / d.life
				var flick := 0.6 + 0.4 * sin(_t * 20.0 + d.flip)
				draw_rect(Rect2(lp, Vector2(2, 2)), Color(1.0, 0.55 + 0.3 * flick, 0.15, k * flick))
				draw_circle(lp + Vector2(1, 1), 3.0, Color(1.0, 0.4, 0.1, 0.12 * k))
			"ash":
				draw_rect(Rect2(lp, Vector2(2, 1)), Color(0.75, 0.72, 0.7, 0.55))
			"tumble":
				var c := lp - Vector2(0, d.z)
				draw_circle(lp + Vector2(2, 3), 5.0 * s, Color(0, 0, 0, 0.25))
				for k in 6:
					var a: float = d.rot + k * 1.05
					draw_line(c + Vector2.from_angle(a) * 5.0 * s, c - Vector2.from_angle(a + 0.6) * 5.0 * s, Color(0.55, 0.42, 0.25, 0.9), 1.0)
				draw_arc(c, 5.0 * s, 0.0, TAU, 10, Color(0.45, 0.33, 0.2, 0.9), 1.0)
			_:
				var tex: Texture2D = _tex.get(d.kind)
				var sq := 1.0
				if d.kind == "paper" or d.kind == "leaf":
					sq = 0.35 + 0.65 * absf(cos(d.flip))
				if tex:
					var base := 7.0 if d.kind == "leaf" else (10.0 if d.kind == "paper" else 14.0)
					var sz := Vector2(base, base) * s
					draw_set_transform(lp, d.rot, Vector2(1.0, sq))
					draw_texture_rect(tex, Rect2(-sz * 0.5 + Vector2(1.5, 2.5), sz), false, Color(0, 0, 0, 0.3))
					draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					var dir := Vector2.from_angle(d.rot)
					var col := Color(0.35, 0.55, 0.2, 0.9)
					if d.kind == "paper":
						col = Color(0.85, 0.83, 0.75, 0.9)
					elif d.kind == "frond":
						col = Color(0.55, 0.42, 0.22, 0.9)
					draw_line(lp - dir * 2.5 * s, lp + dir * 2.5 * s, col, 2.0 * sq)
	for b in _bits:
		var k2: float = 1.0 - b.t / b.life
		var bp: Vector2 = b.p - Vector2(0, b.h)
		if b.kind == "ember":
			draw_rect(Rect2(bp, Vector2(1.5, 1.5)), Color(b.c, k2))
			continue
		var dir2 := Vector2.from_angle(b.rot)
		if b.kind == "frond" or b.kind == "tumble":
			draw_line(bp - dir2 * 1.8 * b.s, bp + dir2 * 1.8 * b.s, Color(b.c, k2), 0.8)
		else:
			draw_colored_polygon(PackedVector2Array([bp + dir2 * 1.4 * b.s, bp + dir2.orthogonal() * 0.9 * b.s, bp - dir2 * 1.1 * b.s]), Color(b.c, k2))
	# fog: big soft banks drifting with the wind
	if fog > 0.02:
		draw_rect(r, Color(0.6, 0.62, 0.72, 0.1 * fog))
		for i in 9:
			var fx := fposmod(i * 283.0 + _t * (8.0 + wind * 40.0) * signf(wind_dir.x), r.size.x + 700.0) - 350.0
			var fy := fposmod(i * 157.0, r.size.y + 300.0) - 150.0
			var fs := 380.0 + (i % 3) * 120.0
			draw_texture_rect(_soft, Rect2(r.position + Vector2(fx, fy) - Vector2(fs, fs * 0.6) * 0.5, Vector2(fs, fs * 0.6)), false, Color(0.75, 0.78, 0.88, 0.22 * fog))
