class_name AbilitySystem
extends Node
## Signature abilities. Charge is earned through play (kills, executions,
## stylish moves) rather than a cooldown, so using it is a reward for flow.
##
## Implemented:  spotlight (Cass - slow motion burst with near-normal player speed)
## Stubbed with the same interface for the wider cast: blackout, dead_eye,
## frenzy, shadow_dash, double_or_nothing, laying_on_hands, long_shadow, continue.

signal activated(id: StringName)
signal ended(id: StringName)

const DEFS := {
	&"spotlight": {"name": "SPOTLIGHT", "duration": 3.0, "cost": 1.0, "desc": "The world slows. You don't."},
	&"blackout": {"name": "BLACKOUT", "duration": 4.0, "cost": 1.0, "desc": "Invisible while in darkness."},
	&"dead_eye": {"name": "DEAD EYE", "duration": 3.0, "cost": 1.0, "desc": "Mark every visible enemy; each shot snaps to a mark."},
	&"frenzy": {"name": "FRENZY", "duration": 5.0, "cost": 1.0, "desc": "Melee kills heal the combo. Can't stop."},
	&"shadow_dash": {"name": "SHADOW DASH", "duration": 0.0, "cost": 0.34, "desc": "Dash through enemies, killing them."},
}

var id: StringName = &"spotlight"
var charge := 1.0            # 0..1, starts full so the first level teaches it
var active := false
var time_left := 0.0
var charge_mult := 1.0
var owner_player: Node

func setup(ability_id: StringName, p_owner: Node, p_charge_mult := 1.0) -> void:
	id = ability_id if DEFS.has(ability_id) else &"spotlight"
	owner_player = p_owner
	charge_mult = p_charge_mult
	Events.enemy_killed.connect(_on_kill)
	Events.execution_performed.connect(_on_execution)
	_emit()

func _exit_tree() -> void:
	if active:
		_end()

func add_charge(v: float) -> void:
	if active:
		return
	charge = clampf(charge + v * charge_mult, 0.0, 1.0)
	_emit()

func _on_execution(_e: Node) -> void:
	add_charge(0.15)

func _on_kill(_e: Node, info: Dictionary) -> void:
	add_charge(0.12 if info.get("method", &"gun") == &"gun" else 0.2)

func can_activate() -> bool:
	if Game.modifiers.get("no_ability", false):
		return false
	return not active and charge >= float(DEFS[id].cost) - 0.001

func activate() -> bool:
	if not can_activate():
		Audio.play("empty", -6.0)
		return false
	charge -= float(DEFS[id].cost)
	active = true
	time_left = float(DEFS[id].duration)
	match id:
		&"spotlight":
			Game.set_slowmo(0.35)
			Audio.play("slowmo_in")
			Music.set_pitch(0.8)
			PostFX.set_tint(Color(1.0, 0.85, 0.55, 0.25))
			Events.camera_punch.emit(1.08, 0.3)
	activated.emit(id)
	_emit()
	if time_left <= 0.0:
		_end()
	return true

func _process(delta: float) -> void:
	if not active:
		return
	# measure in real time so slow-mo doesn't extend itself
	var real := delta / maxf(Engine.time_scale, 0.01)
	time_left -= real
	_emit()
	if time_left <= 0.0:
		_end()

func _end() -> void:
	active = false
	match id:
		&"spotlight":
			Game.set_slowmo(1.0)
			Audio.play("slowmo_out")
			Music.set_pitch(1.0)
			PostFX.set_tint(Color(1, 1, 1, 0))
	ended.emit(id)
	_emit()

func force_end() -> void:
	if active:
		_end()

## Player movement multiplier while ability runs (spotlight: move near real-time).
func player_time_mult() -> float:
	if active and id == &"spotlight":
		return 1.0 / maxf(Game.get_slowmo(), 0.05) * 0.7
	return 1.0

func _emit() -> void:
	var shown := charge
	if active and float(DEFS[id].duration) > 0.0:
		shown = time_left / float(DEFS[id].duration)
	Events.ability_changed.emit(shown, active)

func display_name() -> String:
	return str(DEFS[id].name)
