class_name Sniper
extends Enemy
## Long-sightline shooter with a tell: before every shot a laser finds you
## and settles (about a second, rising whine, the beam thickening). The shot
## goes where the laser was a beat before it fires, so moving or breaking line
## of sight makes it miss. Deadly if you stand still in the open.

const CHARGE := 1.05          ## seconds from laser-on to shot
const LAG := 0.14             ## the aim trails the target by this much
var _charge_t := -1.0
var _aim_point := Vector2.ZERO
var _laser: SniperLaser

func _ready() -> void:
	super._ready()
	_laser = SniperLaser.new()
	_laser.sniper = self
	add_child(_laser)

func _shoot(p: Player) -> void:
	if _charge_t < 0.0:
		_charge_t = 0.0
		_aim_point = p.global_position
		Audio.play_at("sniper_charge", global_position, -2.0, 0.0)
		_fire_cd = CHARGE + 0.1
		return

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _charge_t < 0.0:
		return
	var p := _player()
	if not is_alive() or state in [State.DOWNED, State.STUNNED] or p == null or not p.alive or not _sees_player:
		_charge_t = -1.0   # lost the shot
		return
	_charge_t += delta
	# the laser trails you: it slides toward where you are, a beat behind
	_aim_point = _aim_point.lerp(p.global_position, clampf(delta / LAG, 0.0, 1.0))
	visual.set_aim((_aim_point - global_position).angle())
	if _charge_t >= CHARGE:
		_charge_t = -1.0
		_fire_at(_aim_point)

func _fire_at(point: Vector2) -> void:
	if weapon == null:
		return
	var aim := (point - global_position).normalized()
	var origin := visual.muzzle_global()
	var bs := BulletSystem.get_system()
	if bs:
		bs.fire(origin, aim, weapon.data, self, 0.3)
	visual.kick_recoil(3.0)
	Effects.muzzle(origin + visual.muzzle_lift(), aim, weapon.data.muzzle_color, false, 1.4)
	Effects.gun_smoke(origin, aim, 1.2)
	Audio.play_at("rifle", global_position, 2.0, 0.02)
	Events.noise.emit(global_position, weapon.data.noise_radius, &"gunshot", self)
	Events.camera_shake.emit(2.0)
	_fire_cd = 1.4 + randf_range(0.0, 0.6)

func charge_k() -> float:
	return clampf(_charge_t / CHARGE, 0.0, 1.0) if _charge_t >= 0.0 else -1.0


## The laser: faint while searching, bright and thick as the shot settles.
class SniperLaser extends Node2D:
	var sniper: Sniper
	func _ready() -> void:
		top_level = true
		z_index = 30
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if sniper == null or not is_instance_valid(sniper) or not sniper.is_alive():
			return
		var k := sniper.charge_k()
		if k < 0.0:
			return
		var from := sniper.visual.muzzle_global()
		var dir := (sniper._aim_point - from).normalized()
		var space := get_world_2d().direct_space_state
		var q := PhysicsRayQueryParameters2D.create(from, from + dir * 700.0, Layers.WORLD | Layers.DOOR | Layers.PROP | Layers.PLAYER, [sniper.get_rid()])
		var hit := space.intersect_ray(q)
		var to: Vector2 = hit.position if not hit.is_empty() else from + dir * 700.0
		var lift: Vector2 = sniper.visual.muzzle_lift()   # drawn at the rifle's height
		from += lift
		to += lift
		var flick := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.06)
		var w := 0.8 + k * 2.2
		draw_line(from, to, Color(1.0, 0.05, 0.1, (0.12 + 0.3 * k) * flick), w * 3.0)
		draw_line(from, to, Color(1.0, 0.3, 0.3, (0.4 + 0.6 * k) * flick), w)
		draw_circle(to, 2.0 + k * 3.0, Color(1, 0.1, 0.15, 0.4 + 0.5 * k))
		if k > 0.8 and fmod(Time.get_ticks_msec() * 0.001, 0.12) < 0.06:
			draw_arc(to, 8.0 - k * 4.0, 0, TAU, 16, Color(1, 0.8, 0.8, 0.9), 1.0)
