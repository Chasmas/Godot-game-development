class_name NightmareDirector
extends Node
## The dream at Villa Estrella. Scripted surprises from the level's
## "scares" list, each fired once when the player walks into its rect:
##   spawn       the dead climb out at the listed cells (graves, coffins)
##   lights      a zone blacks out for a few seconds; something laughs
##   apparition  a face from the past flashes over the screen
##   whisper     one of the dead says something she said, or they did
##   slam        every door in the rect slams and holds while the dead come
##   chandelier  the chandelier comes down (fire, and a crash)
## And the dead don't stay down: a zombie that wasn't executed may get back
## up a few seconds later, unless it burned.

const RISE_CHANCE := 0.3
const FACE_TIME := 4.5            ## seconds an apparition takes to rise and fade
const CHANDELIER_WARN := 2.2      ## creaking and swaying before it comes down
const APPARITIONS := {"cass": "cass", "tommy": "tommy_burnt", "harcourt": "harcourt", "earl": "earl", "guard": "dead", "arlo": "arlo", "dutch": "dutch"}

var level: Level
var _fired: Dictionary = {}
var _layer: CanvasLayer
var _face: TextureRect
var _face_t := 0.0
var _amb_t := 9.0              ## until the next far-off cry or scream
var _voice_t := 2.0            ## until the next creature sound nearby
const FAR_SOUNDS := ["cry", "scream_f", "cry", "scream_m", "laugh_track"]
const VOICES := {&"zombie": "moan", &"ghoul": "shriek", &"demon": "roar", &"hellhound": "growl", &"cultist": "moan"}
var _chandelier_t := 0.0
var _chandelier_at := Vector2.ZERO
var _warn: Node2D

func setup(p_level: Level) -> void:
	level = p_level
	for e in level.enemies:
		_watch(e)
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)
	_face = TextureRect.new()
	_face.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_face.custom_minimum_size = Vector2(420, 420)
	_face.size = Vector2(420, 420)
	_face.position = -_face.size * 0.5
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.modulate = Color(1, 1, 1, 0)
	_layer.add_child(_face)

func _watch(e: Node) -> void:
	if e is Enemy and not (e as Enemy).died.is_connected(_on_died):
		(e as Enemy).died.connect(_on_died)

func _process(delta: float) -> void:
	if level == null or level.player == null or not level.player.alive:
		return
	if _face_t > 0.0:
		# a face that surfaces slowly out of the dark and sinks back: no sting
		_face_t -= delta
		var k := sin(clampf(1.0 - _face_t / FACE_TIME, 0.0, 1.0) * PI)
		_face.modulate = Color(0.9, 0.7, 0.72, k * 0.22)
		_face.scale = Vector2.ONE * (1.0 + (1.0 - _face_t / FACE_TIME) * 0.08)
		_face.pivot_offset = _face.size * 0.5
	_ambience(delta)
	if _chandelier_t > 0.0:
		_chandelier_t -= delta
		if _chandelier_t <= 0.0:
			_drop_chandelier()
	var cell := Vector2i(level.player.global_position / 16.0)
	var scares: Array = level.data.get("scares", [])
	for i in scares.size():
		if _fired.has(i):
			continue
		var s: Dictionary = scares[i]
		var r: Array = s.rect
		if Rect2i(r[0], r[1], r[2], r[3]).has_point(cell):
			_fired[i] = true
			_scare(s)

func _scare(s: Dictionary) -> void:
	match str(s.type):
		"spawn":
			var kinds: Array = s.get("kinds", ["zombie"])
			var i := 0
			for c in s.get("at", []):
				var kind := StringName(kinds[i % kinds.size()])
				i += 1
				get_tree().create_timer(0.15 * i, false).timeout.connect(func():
					if is_inside_tree():
						rise(Vector2(float(c[0]), float(c[1])) * 16.0 + Vector2(8, 8), kind))
			Audio.play("growl", -10.0, 0.7)
		"lights":
			var zone := str(s.get("zone", level.zone_at(level.player.global_position)))
			# the lights brown out and die slowly; somewhere a TV audience chuckles
			level.set_zone_lights(zone, false, "boss")
			Audio.play("laugh_track", -16.0, 0.75)
			get_tree().create_timer(float(s.get("time", 3.5)), false).timeout.connect(func():
				if is_inside_tree():
					level.set_zone_lights(zone, true, "boss"))
		"apparition":
			var who := str(s.get("who", "tommy"))
			var portrait_id := str(APPARITIONS.get(who, who))
			var pixel_path := "res://assets/art/pixellab_ui_v3_approved/portraits/%s.png" % portrait_id
			var source_path := "res://assets/characters/portraits/%s.png" % portrait_id
			var tex: Texture2D = load(pixel_path if ResourceLoader.exists(pixel_path) else source_path)
			if tex:
				_face.texture = tex
				_face_t = FACE_TIME
			Audio.play("vhs_static", -18.0, 0.6)
		"whisper":
			var bl := BarkLayer.find(get_tree())
			if bl:
				bl.say(level.player, tr(str(s.text)), 3.5, Color(0.75, 0.8, 0.7))
			Audio.play("growl", -18.0, 0.5)
		"slam":
			var r: Array = s.rect
			var rect := Rect2(Vector2(r[0], r[1]) * 16.0, Vector2(r[2], r[3]) * 16.0)
			for d in get_tree().get_nodes_in_group("door"):
				if d is Door and rect.grow(16.0).has_point((d as Node2D).global_position):
					d.slam_shut()
			Audio.play("door_open", -6.0, 0.55)
		"chandelier":
			# telegraphed: it creaks and a shadow grows on the floor first
			_chandelier_at = Vector2(float(s.at[0]), float(s.at[1])) * 16.0 + Vector2(8, 8)
			_chandelier_t = CHANDELIER_WARN
			_warn = ChandelierShadow.new()
			_warn.position = _chandelier_at
			_warn.director = self
			level.actors_root.add_child(_warn)
			Audio.play_at("metal_clang", _chandelier_at, -10.0)

func _drop_chandelier() -> void:
	var at := _chandelier_at
	if _warn and is_instance_valid(_warn):
		_warn.queue_free()
	Audio.play_at("glass", at, 4.0)
	Effects.shards(at, Vector2.DOWN, Color(0.9, 0.95, 1.0), 24, true)
	for k in 6:
		FireZone.ignite(level.actors_root, level.nearest_open_point(at + Vector2.from_angle(k * TAU / 6.0) * 18.0, at), 11.0, 7.0)
	Events.camera_shake.emit(7.0)
	Events.hit_stop.emit(0.08)
	# anyone under it
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and (e as Node2D).global_position.distance_to(at) < 30.0:
			var info := DamageInfo.make(DamageInfo.Type.ENVIRONMENT, self, at, Vector2.DOWN, &"chandelier", &"environment")
			info.lethal = true
			e.take_damage(info)
	var p := level.player
	if p.global_position.distance_to(at) < 22.0:
		var pi := DamageInfo.make(DamageInfo.Type.EXPLOSIVE, self, at, Vector2.DOWN, &"chandelier", &"environment")
		pi.lethal = true
		p.take_damage(pi)

## The house is never quiet: now and then someone cries or screams in
## another room (positional, far away, never twice in a row), and the dead
## near you moan, shriek, roar or snarl.
var _last_far := ""
func _ambience(delta: float) -> void:
	var p := level.player
	_amb_t -= delta
	if _amb_t <= 0.0:
		_amb_t = randf_range(14.0, 32.0)
		var pick := _last_far
		while pick == _last_far:
			pick = FAR_SOUNDS[randi() % FAR_SOUNDS.size()]
		_last_far = pick
		var at := p.global_position + Vector2.from_angle(randf() * TAU) * randf_range(300.0, 480.0)
		Audio.play_at(pick, at, -6.0 if pick != "laugh_track" else -14.0)
	_voice_t -= delta
	if _voice_t <= 0.0:
		_voice_t = randf_range(1.4, 3.6)
		var near: Array = []
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.is_alive() and e.data and VOICES.has(e.data.id) and (e as Node2D).global_position.distance_to(p.global_position) < 420.0:
				near.append(e)
		if not near.is_empty():
			var e: Enemy = near[randi() % near.size()]
			var v: String = VOICES[e.data.id]
			Audio.play_at(v, e.global_position, -4.0 if e.is_aware() else -10.0)

## Something climbs out of the floor at `at`.
func rise(at: Vector2, kind: StringName) -> Enemy:
	var data := DB.enemy(kind)
	if data == null:
		return null
	var e: Enemy = Dog.new() if kind == &"hellhound" else Enemy.new()
	e.enemy_id = "rise_%d_%d" % [Time.get_ticks_usec(), randi() % 1000]
	e.required = false
	e.position = level.nearest_open_point(at, at)
	level.actors_root.add_child(e)
	e.setup(data, level, Vector2.from_angle(randf() * TAU))
	if e is Dog:
		(e as Dog).sleeping = false
	e.died.connect(level._on_enemy_died)
	_watch(e)
	e._last_known = level.player.global_position
	e._enter_combat()
	Effects.dust(e.global_position, Vector2.UP, 2.0)
	Effects.debris(e.global_position, Vector2.UP)
	if VOICES.has(kind):
		Audio.play_at(VOICES[kind], e.global_position, -6.0)
	return e

func _on_died(e: Enemy, info: DamageInfo) -> void:
	if e == null or not is_instance_valid(e) or e.data == null or e.data.id != &"zombie":
		return
	if info and (info.type == DamageInfo.Type.FIRE or info.method == &"execution" or info.type == DamageInfo.Type.EXPLOSIVE):
		return
	if randf() > RISE_CHANCE:
		return
	var at := e.global_position
	get_tree().create_timer(randf_range(3.0, 5.0), false).timeout.connect(func():
		if not is_inside_tree() or level.player == null or level.phase >= Level.Phase.ESCAPE:
			return
		if level.player.global_position.distance_to(at) < 60.0:
			return
		var z := rise(at, &"zombie")
		if z:
			Audio.play_at("growl", at, 0.0)
			var bl := BarkLayer.find(get_tree())
			if bl:
				bl.say(z, tr("...not yet..."), 2.0, Color(0.7, 0.8, 0.65)))


## The chandelier's shadow on the floor, growing and swaying before it falls.
class ChandelierShadow extends Node2D:
	var director: NightmareDirector
	var _t := 0.0

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / CHANDELIER_WARN, 0.0, 1.0)
		var sway := Vector2(sin(_t * 6.0) * 4.0 * (1.0 - k * 0.5), 0)
		draw_circle(sway, 10.0 + 14.0 * k, Color(0, 0, 0, 0.15 + 0.35 * k))
		draw_arc(sway, 24.0, 0.0, TAU, 32, Color(1.0, 0.5, 0.3, 0.2 + 0.5 * k), 1.5)
