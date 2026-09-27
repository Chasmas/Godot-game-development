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
## Find the charges, plant them, get clear: the doors go up in a storm of
## splinters, glass and fire, and the boss scene starts straight away.

signal breached

var level: Level
var cfg: Dictionary
var doors: Array = []
var has_charge := false
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
	_sign = Decor.NeonSign.new()
	_sign.position = _cell(cfg.get("sign", cfg.doors[0]))
	_sign.text = "LOCKED"
	_sign.color = Color("ff2a4f")
	_sign.font_size = 9
	_sign.zone = "exterior"
	level.props_root.add_child(_sign)
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
	return {"has_charge": has_charge and not done, "done": done}

## The objective line while the room is still sealed ("" once it's open).
func objective() -> String:
	if done:
		return ""
	if planted:
		return tr("GET CLEAR!")
	if has_charge:
		return level._obj("plant", "PLANT THE CHARGE ON THE DOORS")
	return level._obj("find_charge", "FIND SOMETHING TO BLOW THE DOORS")

func _on_take(_it: Interactable, by: Node) -> void:
	has_charge = true
	_plant_it.enabled = true
	Audio.play("pickup")
	Audio.play("upgrade", -6.0)
	level.hud.show_banner(tr("PYRO CHARGES"), 1.8, UIStyle.GOLD)
	var bl := BarkLayer.find(get_tree())
	if bl and by is Node2D:
		bl.say(by, tr("HOTSHOT pyro. Harcourt kept the leftovers."), 3.0, UIStyle.PINK)
	level._update_objective()

func _on_plant(_it: Interactable, _by: Node) -> void:
	planted = true
	_fuse_t = float(cfg.get("fuse", 4.0))
	_blink = ChargeLight.new()
	_blink.position = _plant_it.position + Vector2(0, -6)
	level.props_root.add_child(_blink)
	Audio.play("slide_rack", -2.0, 0.8)
	level.hud.show_hint(tr("CHARGE SET. GET CLEAR!"), 2.5)
	level._update_objective()

func _process(delta: float) -> void:
	if _fuse_t < 0.0:
		return
	_fuse_t -= delta
	_beep_t -= delta
	# the beeps speed up as the fuse runs down
	if _beep_t <= 0.0:
		_beep_t = clampf(_fuse_t / 5.0, 0.12, 0.7)
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
	# the blast itself
	Effects.explosion(mid, 90.0)
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
	Audio.play_at("explosion", mid, 6.0)
	Audio.play_at("glass", mid, 2.0)
	Audio.play_at("door_break", mid, 2.0)
	PostFX.flash(Color(1.0, 0.75, 0.4), 0.45)
	PostFX.vhs_glitch(0.8)
	Events.camera_shake.emit(14.0)
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


## The planted charge: a satchel with a red LED that flashes with each beep.
class ChargeLight extends Node2D:
	var _k := 0.0
	func _ready() -> void:
		z_index = 3
	func pulse() -> void:
		_k = 1.0
	func _process(delta: float) -> void:
		_k = maxf(0.0, _k - delta * 5.0)
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(-6, -4, 12, 8), Color(0.08, 0.05, 0.05))
		draw_rect(Rect2(-5, -3, 10, 6), Color(0.55, 0.12, 0.1))
		draw_line(Vector2(-5, 0), Vector2(5, 0), Color(0.9, 0.8, 0.3), 1.0)
		draw_circle(Vector2(3, -2), 1.5, Color(1, 0.15, 0.1, 0.4 + 0.6 * _k))
		if _k > 0.0:
			draw_circle(Vector2(3, -2), 6.0 * _k, Color(1, 0.1, 0.05, 0.3 * _k))
