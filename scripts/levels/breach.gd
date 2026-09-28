class_name Breach
extends Node
## A sealed room you have to blow your way into (the Sunset Palms lobby,
## where Harcourt waits). Level JSON:
##   "breach": {"doors": [[x, y], ...],   locked doors to blow
##              "sign": [x, y],           where the LOCKED neon hangs
##              "charge": [x, y],         where the explosives are
##              "plant": [x, y],          where to set them (by the doors)
##              "fuse": 4.0}
## Objectives come from "objectives": find_charge / plant / clear_out.
## Walk up to the doors: LOCKED pops up over them and Cass thinks out loud
## - these aren't opening for a shoulder, something that goes boom might.
## Then the objective: find the charges, plant them (Cass kneels and tapes
## the satchel to the doors), and a 3-2-1 over the charge. The doors go up
## in a storm of splinters, glass and fire, and the boss scene starts.

signal breached

var level: Level
var cfg: Dictionary
var doors: Array = []
var has_charge := false
var discovered := false        ## Cass has tried the doors (or found the charges)
var planting := false          ## the kneel-and-tape moment
var planted := false
var done := false
var _sign: Node2D
var _charge_it: Interactable
var _plant_it: Interactable
var _fuse_t := -1.0
var _beep_t := 0.0
var _blink: Node2D

func setup(p_level: Level, p_cfg: Dictionary, state: Dictionary) -> void:
	level = p_level
	cfg = p_cfg
	has_charge = bool(state.get("has_charge", false))
	done = bool(state.get("done", false))
	discovered = bool(state.get("discovered", false)) or has_charge
	for c in cfg.get("doors", []):
		var at := _cell(c)
		for d in get_tree().get_nodes_in_group("door"):
			if d is Door and (d as Door).global_position.distance_to(at) < 20.0 and not doors.has(d):
				doors.append(d)
	for d in doors:
		d.locked = true
		d.metal = true
	if done:
		for d in doors:
			d._break(Vector2.UP)
		return
	_plant_it = Interactable.new()
	_plant_it.setup("plant", "PLANT THE CHARGE", "breach_plant")
	_plant_it.position = _cell(cfg.plant)
	_plant_it.enabled = has_charge
	level.props_root.add_child(_plant_it)
	_plant_it.used.connect(_on_plant)
	if not has_charge:
		_charge_it = Interactable.new()
		_charge_it.setup("charge", "TAKE THE CHARGES", "breach_charge")
		_charge_it.position = _cell(cfg.charge)
		level.props_root.add_child(_charge_it)
		_charge_it.used.connect(_on_take)

func _cell(c: Array) -> Vector2:
	return Vector2(float(c[0]), float(c[1])) * 16.0 + Vector2(8, 8)

func state() -> Dictionary:
	return {"has_charge": has_charge and not done, "done": done, "discovered": discovered}

## The objective line while the room is still sealed ("" once it's open).
func objective() -> String:
	if done:
		return ""
	if not discovered:
		return level._obj("find_boss", "FIND THE NIGHT MANAGER")
	if planted or planting:
		return tr("GET CLEAR!")
	if has_charge:
		return level._obj("plant", "PLANT THE CHARGE ON THE DOORS")
	return level._obj("find_charge", "FIND SOMETHING TO BLOW THE DOORS")

## The first time Cass comes up to the doors.
func _discover() -> void:
	if discovered or done:
		return
	discovered = true
	var mid := Vector2.ZERO
	for d in doors:
		mid += (d as Node2D).global_position
	mid /= maxf(1.0, doors.size())
	var pop := LockedPopup.new()
	pop.position = mid + Vector2(0, -22)
	level.props_root.add_child(pop)
	Audio.play_at("metal_clang", mid, -4.0)
	var bl := BarkLayer.find(get_tree())
	if bl and level.player:
		bl.say(level.player, tr("Steel, bolted from the inside. Not with my shoulder... something that goes boom, maybe."), 4.0, UIStyle.PINK)
	get_tree().create_timer(2.2, false).timeout.connect(func():
		if not has_charge:
			level.hud.show_banner(tr("NEW OBJECTIVE: FIND EXPLOSIVES"), 2.2, UIStyle.GOLD)
		level._update_objective())

func _on_take(_it: Interactable, by: Node) -> void:
	has_charge = true
	discovered = true
	_plant_it.enabled = true
	Audio.play("pickup")
	Audio.play("upgrade", -6.0)
	level.hud.show_banner(tr("PYRO CHARGES"), 1.8, UIStyle.GOLD)
	var bl := BarkLayer.find(get_tree())
	if bl and by is Node2D:
		bl.say(by, tr("HOTSHOT pyro. Harcourt kept the leftovers."), 3.0, UIStyle.PINK)
	level._update_objective()

func _on_plant(_it: Interactable, by: Node) -> void:
	if planting or planted:
		return
	planting = true
	_plant_it.enabled = false
	level._update_objective()
	# Cass kneels and tapes the satchel to the doors: the charge flies from
	# her hands to the seam, strips of tape go on, the wire, the LED
	var p := by as Player
	if p:
		p.input_enabled = false
		p.velocity = Vector2.ZERO
		p.aim_dir = (_plant_it.global_position - p.global_position).normalized()
	_blink = ChargeLight.new()
	_blink.global_position = p.global_position if p else _plant_it.global_position
	level.props_root.add_child(_blink)
	# on the seam between the doors
	var to := _plant_it.position + Vector2(0, -6)
	if not doors.is_empty():
		var mid := Vector2.ZERO
		for d in doors:
			mid += (d as Node2D).global_position
		to = level.props_root.to_local(mid / doors.size()) + Vector2(0, 5)
	var tw := _blink.create_tween()
	tw.tween_property(_blink, "position", to, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): Audio.play("slide_rack", -2.0, 0.8))
	tw.tween_property(_blink, "tape", 1.0, 0.6)
	tw.parallel().tween_callback(func(): Audio.play_at("tape_slide", _blink.global_position, -6.0, 0.3)).set_delay(0.1)
	tw.tween_property(_blink, "armed", 1.0, 0.2)
	tw.tween_callback(func():
		if p and is_instance_valid(p):
			p.input_enabled = true
		planting = false
		planted = true
		_fuse_t = float(cfg.get("fuse", 3.0))
		_blink.fuse_total = _fuse_t
		Audio.play_at("rec_beep", _blink.global_position, 4.0)
		level.hud.show_hint(tr("CHARGE SET. GET CLEAR!"), 2.5)
		level._update_objective())

func _process(delta: float) -> void:
	if not discovered and not done and level and level.player and is_instance_valid(level.player):
		for d in doors:
			if (d as Node2D).global_position.distance_to(level.player.global_position) < 30.0:
				_discover()
				break
	if _fuse_t < 0.0:
		return
	if _blink:
		_blink.fuse_left = _fuse_t
	_fuse_t -= delta
	_beep_t -= delta
	# the beeps speed up as the fuse runs down
	if _beep_t <= 0.0:
		_beep_t = clampf(_fuse_t / 4.0, 0.1, 0.5)
		Audio.play_at("rec_beep", _plant_it.global_position, 2.0)
		if _blink:
			_blink.pulse()
	if _fuse_t <= 0.0:
		_fuse_t = -1.0
		detonate()

## The doors go up. Public so tests (and the debug menu) can trigger it.
func detonate() -> void:
	if done:
		return
	done = true
	planted = false
	var at: Vector2 = _plant_it.global_position if _plant_it else _cell(cfg.plant)
	var mid := Vector2.ZERO
	for d in doors:
		mid += (d as Node2D).global_position
	mid = mid / maxf(1.0, doors.size()) + Vector2(12, 0)
	# the blast itself: a fireball in layers, a shockwave, two secondary
	# pops, the doors in burning planks, glass, embers, a smoke column
	Effects.explosion(mid, 110.0)
	var fb := Fireball.new()
	fb.global_position = mid
	level.actors_root.add_child(fb)
	for k in 2:
		var at2 := mid + Vector2.from_angle(randf() * TAU) * randf_range(24, 40)
		get_tree().create_timer(0.14 + k * 0.16, false).timeout.connect(func():
			Effects.explosion(at2, 55.0)
			Audio.play_at("explosion", at2, -4.0, 0.2)
			Events.camera_shake.emit(6.0))
	for k in 14:
		var pl := Plank.new()
		pl.global_position = mid + Vector2(randf_range(-14, 14), randf_range(-6, 6))
		pl.velocity = Vector2.from_angle(-PI * 0.5 + randf_range(-1.6, 1.6)) * randf_range(150, 380)
		level.actors_root.add_child(pl)
	for i in 18:
		var dir := Vector2.from_angle(randf() * TAU)
		Effects.splinters(mid + dir * randf_range(4, 18), dir, true, 1.6)
	for i in 8:
		var dir2 := Vector2.from_angle(-PI * 0.5 + randf_range(-1.3, 1.3))
		Effects.glass(mid + dir2 * 10.0, dir2)
		Effects.debris(mid, dir2)
		Effects.dust(mid + dir2 * 20.0, dir2, 2.0)
	for i in 6:
		var fp: Vector2 = level.nearest_open_point(mid + Vector2.from_angle(randf() * TAU) * randf_range(20, 50), mid)
		FireZone.ignite(level.actors_root, fp, randf_range(8.0, 12.0), randf_range(4.0, 7.0))
	for d in doors:
		d.locked = false
		d._break(Vector2.UP)
	Audio.play("breach_boom", 2.0)
	get_tree().create_timer(0.4, false).timeout.connect(func(): Audio.play("ear_ring", -12.0))
	# a beat of slow motion to take it in
	Game.set_slowmo(0.35)
	get_tree().create_timer(0.45, true, false, true).timeout.connect(func(): Game.set_slowmo(1.0))
	PostFX.flash(Color(1.0, 0.75, 0.4), 0.45)
	PostFX.vhs_glitch(0.8)
	Events.camera_shake.emit(18.0)
	var fxn := Effects.get_fx()
	if fxn:
		fxn.decals.add_splat(mid, 80.0, Color(0.03, 0.02, 0.02, 0.9))   # scorch
	Events.camera_punch.emit(1.25, 0.6)
	Events.hit_stop.emit(0.14)
	InputSetup.vibrate(1.0, 1.0, 0.5)
	Events.noise.emit(mid, 900.0, &"explosion", level.player)
	# anyone standing too close pays for it
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and (e as Node2D).global_position.distance_to(mid) < 70.0 and not e is BossNightManager:
			var info := DamageInfo.make(DamageInfo.Type.EXPLOSIVE, level.player, mid, ((e as Node2D).global_position - mid).normalized(), &"explosion", &"explosion")
			info.lethal = (e as Node2D).global_position.distance_to(mid) < 40.0
			e.take_damage(info)
	if level.player.global_position.distance_to(mid) < 36.0:
		var pi := DamageInfo.make(DamageInfo.Type.EXPLOSIVE, null, mid, (level.player.global_position - mid).normalized(), &"explosion", &"explosion")
		pi.lethal = true
		level.player.take_damage(pi)
	if _sign:
		_sign.queue_free()
	if _blink:
		_blink.queue_free()
	if _plant_it:
		_plant_it.enabled = false
	breached.emit()


## The planted charge: a satchel of pyro sticks taped to the doors, a wire
## to a little timer with a red LED that flashes with each beep - and a big
## 3, 2, 1 over it once it's armed.
class ChargeLight extends Node2D:
	var _k := 0.0
	var tape := 0.0          ## 0..1: the strips of tape going on
	var armed := 0.0         ## 0..1: the timer switched on
	var fuse_total := 0.0
	var fuse_left := -1.0
	var _last_n := 0
	var _pop := 0.0
	func _ready() -> void:
		z_index = 30
	func pulse() -> void:
		_k = 1.0
	func _process(delta: float) -> void:
		_k = maxf(0.0, _k - delta * 5.0)
		_pop = maxf(0.0, _pop - delta * 3.0)
		if fuse_left >= 0.0:
			var n := int(ceil(fuse_left))
			if n != _last_n and n > 0:
				_last_n = n
				_pop = 1.0
		queue_redraw()
	func _draw() -> void:
		var ink := Color(0.06, 0.04, 0.05)
		# the sticks, bundled
		draw_rect(Rect2(-7, -5, 14, 10), ink)
		for i in 4:
			draw_rect(Rect2(-6 + i * 3.2, -4, 2.8, 8), Color(0.72, 0.14, 0.12))
			draw_rect(Rect2(-6 + i * 3.2, -4, 2.8, 1.5), Color(0.86, 0.3, 0.25))
		# tape strips across them
		for i in 2:
			var w := 14.0 * clampf(tape * 2.0 - i, 0.0, 1.0)
			if w > 0.0:
				draw_rect(Rect2(-7, -2.5 + i * 4.0, w, 1.6), Color(0.72, 0.72, 0.7))
		# the timer box and the wire looping to it
		if armed > 0.0:
			draw_polyline(PackedVector2Array([Vector2(6, 0), Vector2(9, 3), Vector2(10, 7)]), Color(0.9, 0.8, 0.2), 0.8)
			draw_rect(Rect2(7, 6, 7, 5), ink)
			draw_rect(Rect2(8, 7, 5, 3), Color(0.15, 0.3, 0.15))
			draw_circle(Vector2(12, 8.5), 1.2, Color(1, 0.15, 0.1, 0.4 + 0.6 * _k))
			if _k > 0.0:
				draw_circle(Vector2(12, 8.5), 7.0 * _k, Color(1, 0.1, 0.05, 0.3 * _k))
		# the countdown, big, over the charge
		if fuse_left > 0.0:
			var n := int(ceil(fuse_left))
			var f := UIStyle.font_display()
			var sz := int(22 + 10 * _pop)
			var txt := str(n)
			var w2 := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			var o := Vector2(-w2 * 0.5, -16)
			draw_string_outline(f, o, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 6, Color(0.05, 0.0, 0.02, 0.9))
			draw_string(f, o, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(1.0, 0.25 + 0.5 * (1.0 - _pop), 0.2))


## "LOCKED", stamped over the doors the first time Cass tries them: a red
## plate with a padlock that punches in, holds, and fades.
class LockedPopup extends Node2D:
	var _t := 0.0
	func _ready() -> void:
		z_index = 60
	func _process(delta: float) -> void:
		_t += delta
		if _t > 3.0:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var inn := clampf(_t / 0.18, 0.0, 1.0)
		var s := 1.6 - 0.6 * (1.0 - pow(1.0 - inn, 3.0))
		var a := clampf((3.0 - _t) / 0.5, 0.0, 1.0) * inn
		var f := UIStyle.font_display()
		var txt := tr("LOCKED")
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_set_transform(Vector2(0, -_t * 3.0), -0.06, Vector2(s, s))
		var r := Rect2(-w * 0.5 - 16, -11, w + 24, 18)
		draw_rect(r.grow(2), Color(0.05, 0.0, 0.02, 0.85 * a))
		draw_rect(r, Color(0.78, 0.08, 0.14, a))
		draw_rect(r.grow(-1.5), Color(1, 0.8, 0.8, 0.6 * a), false, 1.0)
		# the padlock
		draw_arc(Vector2(r.position.x + 8, -4), 2.6, PI, TAU, 8, Color(1, 0.95, 0.9, a), 1.3)
		draw_rect(Rect2(r.position.x + 4.5, -3.5, 7, 6), Color(1, 0.95, 0.9, a))
		draw_rect(Rect2(r.position.x + 7.5, -1.5, 1, 2), Color(0.78, 0.08, 0.14, a))
		draw_string(f, Vector2(r.position.x + 14, 3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.95, 0.9, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)



## The fireball: an orange-white core that swells and cools to red, dark
## smoke rolling out over it, a shockwave ring racing across the floor, and
## a column of smoke that keeps rising for a while. Lit by its own light.
class Fireball extends Node2D:
	var _t := 0.0
	var _light: PointLight2D
	var _puffs: Array = []
	func _ready() -> void:
		z_index = 40
		_light = PointLight2D.new()
		_light.texture = SpriteLib.light_texture(256)
		_light.texture_scale = 4.0
		_light.color = Color(1.0, 0.6, 0.25)
		_light.energy = 3.0
		add_child(_light)
		for i in 26:
			_puffs.append({"a": randf() * TAU, "d": randf_range(0.3, 1.0), "r": randf_range(10, 22), "s": randf_range(0.7, 1.3)})
	func _process(delta: float) -> void:
		_t += delta
		_light.energy = maxf(0.0, 3.0 * (1.0 - _t / 1.2))
		if _t > 1.0 and fmod(_t, 0.25) < delta and _t < 7.0:
			Effects.smoke(global_position + Vector2(randf_range(-10, 10), -_t * 4.0))
		if _t > 7.5:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		# the shockwave
		if _t < 0.5:
			var k := _t / 0.5
			draw_arc(Vector2.ZERO, 20.0 + k * 150.0, 0, TAU, 48, Color(1, 0.95, 0.8, 0.6 * (1.0 - k)), 4.0 * (1.0 - k) + 1.0)
		# smoke rolling outward, over the fire
		for p in _puffs:
			var k := clampf(_t / 1.4, 0.0, 1.0)
			var pos: Vector2 = Vector2.from_angle(float(p.a)) * float(p.d) * (20.0 + 60.0 * sqrt(k))
			var r: float = float(p.r) * float(p.s) * (0.5 + k)
			var a := clampf(1.2 - _t / 3.0, 0.0, 0.8)
			draw_circle(pos, r, Color(0.08, 0.06, 0.07, a * 0.8))
		# the fire core: white -> orange -> red, swelling then shrinking
		if _t < 0.9:
			var k2 := _t / 0.9
			var R := 26.0 + 44.0 * sin(minf(k2 * 1.8, 1.0) * PI * 0.5) - 30.0 * maxf(0.0, k2 - 0.5)
			draw_circle(Vector2.ZERO, R, Color(0.9, 0.2, 0.05, 0.8 * (1.0 - k2)))
			draw_circle(Vector2.ZERO, R * 0.7, Color(1.0, 0.55, 0.15, 0.9 * (1.0 - k2)))
			draw_circle(Vector2.ZERO, R * 0.4, Color(1.0, 0.95, 0.75, 1.0 - k2))


## A plank of the lobby door, flung out burning: it cartwheels, bounces,
## skids to a stop and smoulders a while before it's just debris.
class Plank extends Node2D:
	var velocity := Vector2.ZERO
	var _h := 0.0
	var _vh := 0.0
	var _r := 0.0
	var _w := 0.0
	var _len := 8.0
	var _burn := 0.0
	func _ready() -> void:
		z_index = 8
		_vh = randf_range(60, 160)
		_w = randf_range(-18, 18)
		_len = randf_range(6, 12)
		_burn = randf_range(2.0, 6.0)
		_r = randf() * TAU
	func _process(delta: float) -> void:
		if _h > 0.0 or _vh != 0.0:
			var space := get_world_2d().direct_space_state
			var step := velocity * delta
			var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step, Layers.WORLD | Layers.PROP)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				position += step
			else:
				global_position = hit.position + hit.normal * 2.0
				velocity = velocity.bounce(hit.normal) * 0.35
			_r += _w * delta
			_vh -= 420.0 * delta
			_h += _vh * delta
			if _h <= 0.0:
				_h = 0.0
				if _vh < -60.0:
					_vh = -_vh * 0.3
					velocity *= 0.6
					_w *= 0.5
					Audio.play_at("hit_blunt", global_position, -22.0, 0.3)
				else:
					_vh = 0.0
					velocity = Vector2.ZERO
					_w = 0.0
		_burn -= delta
		if _burn > 0.0 and randf() < delta * 6.0:
			Effects.smoke(global_position)
		queue_redraw()
	func _draw() -> void:
		var d := Vector2.from_angle(_r) * _len * 0.5
		var lift := Vector2(0, -_h * 0.2)
		if _h > 1.0:
			draw_line(-d + Vector2(3, 3), d + Vector2(3, 3), Color(0, 0, 0, 0.3), 3.0)
		draw_line(-d + lift, d + lift, Color(0.35, 0.22, 0.12), 3.0)
		draw_line(-d * 0.3 + lift, d + lift, Color(0.45, 0.3, 0.16), 1.5)
		if _burn > 0.0:
			var f := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.03 + _len)
			draw_circle(d + lift, 2.2 * f, Color(1.0, 0.5, 0.1, 0.8))
			draw_circle(d + lift, 1.0 * f, Color(1.0, 0.9, 0.5))
