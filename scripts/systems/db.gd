class_name DB
extends RefCounted
## Static registry for data resources (weapons, enemies, personas).
## Scans the data folders once; lookups are dictionary reads.

static var _weapons: Dictionary = {}
static var _enemies: Dictionary = {}
static var _personas: Dictionary = {}
static var _loaded := false

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_weapons = _scan("res://data/weapons")
	_enemies = _scan("res://data/enemies")
	_personas = _scan("res://data/personas")

static func _scan(dir_path: String) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		var fname := f.trim_suffix(".remap")
		if not fname.ends_with(".tres"):
			continue
		var r: Resource = load(dir_path + "/" + fname)
		if r and "id" in r:
			out[StringName(r.id)] = r
	return out

static func weapon(id: StringName) -> WeaponData:
	_ensure()
	return _weapons.get(id)

static func enemy(id: StringName) -> EnemyData:
	_ensure()
	return _enemies.get(id)

static func persona(id: StringName) -> PersonaData:
	_ensure()
	return _personas.get(id)

static func all_weapons() -> Array:
	_ensure()
	return _weapons.values()

static func all_enemies() -> Array:
	_ensure()
	return _enemies.values()
