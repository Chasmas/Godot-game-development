class_name FireZone
extends Node2D
## A patch of burning floor (the Fireman's spray, a set going up). Kills
## anyone who stands in it once it has caught (a dodge's i-frames get you
## through), lights the room, crackles, throws embers and burns out.
## The Fireman's suit shrugs it off.

var radius := 12.0
var life := 6.0
var catch_time := 0.22        ## seconds before a fresh patch can burn you
var harmless := false         ## set dressing only (a burning backdrop behind glass)
var friendly := false         ## the player's own flames: burn enemies, never the player
var _t := 0.0
var _seed := 0.0
var _light: PointLight2D
var _sound: AudioStreamPlayer2D
var _ember_t := 0.0
static var _sounding := 0

static func ignite(parent: Node, pos: Vector2, r := 12.0, p_life := 6.0) -> FireZone:
	var f := FireZone.new()
	f.position = pos
	f.radius = r
	f.life = p_life
	parent.add_child(f)
	return f

func _ready() -> void:
	add_to_group("fires")
	z_index = -1
	_seed = randf() * 100.0
	_light = PointLight2D.new()
	_light.texture = SpriteLib.light_texture(128)
	_light.texture_scale = 0.35 + radius / 40.0
	_light.color = Color(1.0, 0.55, 0.2)
	_light.energy = 0.0
	_light.range_item_cull_mask = 1 | 2
	add_child(_light)
	if _sounding < 5:
		_sounding += 1
		_sound = AudioStreamPlayer2D.new()
		var s: AudioStream = Audio.get_stream("fire_loop")
		if s is AudioStreamWAV:
			s = s.duplicate()
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = s.data.size() / 2
		_sound.stream = s
		_sound.bus = "SFX"
		_sound.volume_db = -14.0
		_sound.max_distance = 420.0
		add_child(_sound)
		if s:
			_sound.play(randf() * 3.0)

func _exit_tree() -> void:
	if _sound:
		_sounding -= 1

func _physics_process(delta: float) -> void:
	_t += delta
	var k := _strength()
	_light.energy = k * (1.1 + 0.25 * sin(_t * 23.0 + _seed) * sin(_t * 7.0))
	if _sound:
		_sound.volume_db = linear_to_db(maxf(k, 0.001)) - 14.0
	if _t >= life:
		queue_free()
		return
	_ember_t -= delta
	if _ember_t <= 0.0 and k > 0.4:
		_ember_t = randf_range(0.25, 0.6)
		Effects.dust(global_position + Vector2(randf_range(-radius, radius), randf_range(-radius, radius) * 0.6), Vector2.UP * 0.3, 0.3)
	if harmless or _t < catch_time or k < 0.35:
		queue_redraw()
		return
	var r2 := radius * 0.85
	for p in get_tree().get_nodes_in_group("player"):
		if friendly:
			break
		if p.alive and (p as Node2D).global_position.distance_to(global_position) < r2:
			var info := DamageInfo.make(DamageInfo.Type.FIRE, self, global_position, ((p as Node2D).global_position - global_position).normalized(), &"fire", &"fire")
			info.lethal = true
			p.take_damage(info)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is BossFireman or not e.is_alive():
			continue
		if (e as Node2D).global_position.distance_to(global_position) < r2:
			var info := DamageInfo.make(DamageInfo.Type.FIRE, self, global_position, Vector2.UP, &"flamethrower" if friendly else &"fire", &"fire")
			info.lethal = true
			if friendly:
				info.from_player = true
				info.source = get_tree().get_first_node_in_group("player")
			e.take_damage(info)
	queue_redraw()

## 0..1: flares up, holds, gutters out over the last second and a half.
func _strength() -> float:
	return clampf(_t / 0.15, 0.0, 1.0) * clampf((life - _t) / 1.5, 0.0, 1.0)

func _draw() -> void:
	var k := _strength()
	if k <= 0.01:
		return
	# scorch under it, darkening as it burns
	draw_circle(Vector2(0, 2), radius * 1.05, Color(0.05, 0.02, 0.02, 0.35 * minf(1.0, _t / 2.0)))
	# tongues: back to front, hot core last
	var n := 5 + int(radius / 5.0)
	for i in n:
		var a := float(i) / n * TAU + _seed
		var off := Vector2(cos(a), sin(a) * 0.6) * radius * 0.5 * (0.6 + 0.4 * sin(_t * 3.0 + i))
		var hgt := radius * (0.9 + 0.5 * sin(_t * (9.0 + i) + _seed + i)) * k
		var wdt := radius * 0.42 * k
		var base := off + Vector2(0, radius * 0.25)
		var tip := base + Vector2(sin(_t * 6.0 + i) * wdt * 0.6, -hgt)
		var col := Color(1.0, 0.32 + 0.1 * (i % 3), 0.08, 0.75)
		draw_colored_polygon(PackedVector2Array([base - Vector2(wdt, 0), tip, base + Vector2(wdt, 0)]), col)
	for i in 3:
		var hgt := radius * (0.5 + 0.3 * sin(_t * 14.0 + i * 2.0)) * k
		var base := Vector2((i - 1) * radius * 0.3, radius * 0.2)
		draw_colored_polygon(PackedVector2Array([base - Vector2(radius * 0.22, 0), base + Vector2(sin(_t * 11.0 + i) * 2.0, -hgt), base + Vector2(radius * 0.22, 0)]), Color(1.0, 0.85, 0.35, 0.85))
	draw_circle(Vector2(0, radius * 0.15), radius * 0.3 * k, Color(1.0, 0.95, 0.7, 0.55))
