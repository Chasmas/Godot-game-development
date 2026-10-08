class_name BossBurningMan
extends BossFireman
## "TOMMY?" - the burning man at the end of the dream. Everything the
## Fireman does (the spray, the ring of fire, fireproof), plus:
## Phase 1: every hit sends him back into the crowd and the dead climb out
##   of the ballroom floor to cover him.
## Phase 2: the house burns. He summons a ring of the dead every few
##   seconds and his spray is wider. He always leaves a trail of fire.

const BARKS_TOMMY := ["Is this still the take, Cassie?", "Tell Mom I got top billing!", "Keep rolling! KEEP ROLLING!"]
const BARKS_TOMMY_P2 := ["It's getting hot, Cassie. I can't get the door open."]

var _summon_t := 8.0
var _trail_t := 0.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not active or _defeated:
		return
	_trail_t -= delta
	if _trail_t <= 0.0 and velocity.length() > 10.0:
		_trail_t = 0.35
		FireZone.ignite(get_parent(), global_position - velocity.normalized() * 8.0, 8.0, 3.0)
	if phase == 2:
		_summon_t -= delta
		if _summon_t <= 0.0:
			_summon_t = randf_range(7.0, 10.0)
			_summon(3)

func _summon(n: int) -> void:
	var dir := get_tree().get_first_node_in_group("nightmare") as NightmareDirector
	if dir == null:
		return
	Audio.play_at("growl", global_position, 3.0)
	_say("Everybody, places!")
	for i in n:
		var at := global_position + Vector2.from_angle(randf() * TAU) * randf_range(60.0, 110.0)
		dir.rise(at, &"zombie" if randf() < 0.7 else &"ghoul")

func _hit_barks() -> Array:
	return BARKS_TOMMY

func _phase_two_bark() -> String:
	return BARKS_TOMMY_P2[0]

## Bullets and blades barely scorch him (the fire keeps him standing);
## the extinguishers on the ballroom walls take the bar down in big pieces.
const FOAM := 3.0

func _chip(info: DamageInfo) -> float:
	# half of what the others take, per weapon (pellets split, as everywhere)
	return super._chip(info) * 0.5 if info.type != DamageInfo.Type.EXPLOSIVE else 1.5

func take_damage(info: DamageInfo) -> String:
	if _defeated:
		return "pass"
	if bool(info.get_meta("foam", false)):
		Effects.smoke(global_position)
		Effects.smoke(global_position + info.dir * 6.0)
		var r := _hurt(FOAM, info)
		if r != "killed":
			blind(2.5, ["It's cold... it's cold, Cassie.", "Again. Do it again.", "Almost out..."][randi() % 3])
		return r
	if info.type == DamageInfo.Type.FIRE:
		return "pass"
	if info.from_player and randf() < 0.3:
		_say(["Bullets don't put a fire out, Cassie.", "You can't shoot a fire.", "The extinguishers, Cassie. Remember?"][randi() % 3])
	return super.take_damage(info)

func _on_armor_hit(info: DamageInfo) -> void:
	super._on_armor_hit(info)
	if phase == 1:
		_summon(2)

func _start_phase_two() -> void:
	super._start_phase_two()
	_summon_t = 3.0

func resolve(executed: bool, by: Node) -> void:
	if executed:
		var info := DamageInfo.make(DamageInfo.Type.MELEE, by, global_position, Vector2.RIGHT, &"fists", &"execution")
		info.lethal = true
		info.from_player = true
		Score.add_bonus("CUT!", 5000, global_position)
		state = State.COMBAT
		_die(info)
	else:
		Score.add_bonus("FORGIVEN", 4000, global_position)
		state = State.EXECUTED
		remove_from_group("enemies")
		remove_from_group("damageable")
	# the dream lets go of its dead
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e.is_alive():
			var d := DamageInfo.make(DamageInfo.Type.FIRE, by, (e as Node2D).global_position, Vector2.UP, &"dream", &"environment")
			d.lethal = true
			e.take_damage(d)
