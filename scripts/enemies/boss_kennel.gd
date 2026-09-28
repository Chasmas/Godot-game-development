class_name BossKennel
extends BossNightManager
## BUCK HALVERSON, KENNEL MASTER of Yermo Salvage & K-9 - and the animal
## wrangler on HOTSHOT in 1987, whose dogs kept the fire lane clear.
## Phase 1: shotgun from behind the pens; every piece of his bar she takes,
##   he opens a cage and another dog comes for her.
## Phase 2 "OPEN ALL THE PENS": two more at once, and he gets reckless.
## The room's trick: the DINNER BELL on the yard wall. Ring it and every dog
##   in the place goes for the troughs - and Buck, suddenly alone, freezes.

const BARKS_BUCK := ["Go on, girls!", "Sic her! SIC HER!", "Fresh meat, ladies!"]
const BARKS_BUCK_P2 := ["Everybody out! Dinner's HER!"]
var cages: PackedVector2Array = []   ## where the dogs come out of
var _cage_i := 0

func _hit_barks() -> Array:
	return BARKS_BUCK

func _on_armor_hit(info: DamageInfo) -> void:
	_hit_n += 1
	_say(BARKS_BUCK[_hit_n % BARKS_BUCK.size()])
	_cover_i += 1
	_relocating = true
	_release_dog()
	Events.boss_phase.emit(1)

func _start_phase_two() -> void:
	phase = 2
	data = data.duplicate()
	data.reaction_time = 0.4
	data.run_speed *= 1.15
	_say(BARKS_BUCK_P2[0])
	visual.flash(0.22)
	Events.camera_shake.emit(6.0)
	Audio.play_at("bark", global_position, 4.0)
	Events.boss_phase.emit(2)
	_release_dog()
	_release_dog()

## A cage bangs open and a dog comes out already running.
func _release_dog() -> void:
	if level == null:
		return
	var at: Vector2 = global_position + Vector2(20, 0)
	if not cages.is_empty():
		at = cages[_cage_i % cages.size()]
		_cage_i += 1
	var d := Dog.new()
	d.enemy_id = "buck_dog_%d_%d" % [Time.get_ticks_msec(), _cage_i]
	d.required = false
	d.position = at
	level.actors_root.add_child(d)
	d.setup(DB.enemy(&"dog_rott"), level, Vector2.DOWN)
	d.sleeping = false
	d.died.connect(level._on_enemy_died)
	Audio.play_at("metal_clang", at, -4.0, 0.1)
	d._enter_combat()
