class_name Difficulty
extends RefCounted
## Difficulty lookup. The chosen level is a setting ("difficulty": 0 easy,
## 1 normal, 2 hard); every modifier comes from Tuning's per-difficulty
## arrays so no gameplay script branches on the difficulty itself.

enum Level { EASY, NORMAL, HARD }

const NAMES := ["EASY", "NORMAL", "HARD"]
const DESCRIPTIONS := [
	"Enemies react slower and miss more. You can shrug off one hit, and it comes back if you stay out of trouble.",
	"The intended experience. One hit kills, both ways.",
	"Enemies react faster, aim better, hear more and coordinate their attacks. Less ammo.",
]

static var _cache: Dictionary = {}   ## "id:level" -> scaled EnemyData

static func current() -> int:
	return clampi(int(SaveManager.get_setting("difficulty", Level.NORMAL)), 0, 2)

## Per-difficulty value from one of Tuning's arrays.
static func value(key: String) -> Variant:
	var arr: Variant = Tuning.get_t().get(key)
	if arr is Array and not (arr as Array).is_empty():
		return arr[clampi(current(), 0, arr.size() - 1)]
	return 1.0

static func mult(key: String) -> float:
	return float(value(key))

## A copy of an enemy archetype with the difficulty applied. Cached so every
## guard shares one resource per difficulty. The source is never modified.
static func scaled_enemy(src: EnemyData) -> EnemyData:
	if src == null:
		return null
	var lv := current()
	if lv == Level.NORMAL:
		return src
	var key := "%s:%d:%d" % [src.id, lv, src.get_instance_id()]
	if _cache.has(key):
		return _cache[key]
	var d := src.duplicate() as EnemyData
	d.reaction_time *= mult("reaction_mult")
	d.aim_error_deg *= mult("aim_error_mult")
	d.view_distance *= mult("view_distance_mult")
	d.hearing_mult *= mult("hearing_mult")
	d.melee_windup *= mult("melee_windup_mult")
	d.flank_chance = clampf(d.flank_chance * mult("flank_mult"), 0.0, 0.9)
	_cache[key] = d
	return d
