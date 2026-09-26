class_name DamageInfo
extends RefCounted
## Universal damage packet. Anything with take_damage(info: DamageInfo) can be hurt.

enum Type { BALLISTIC, MELEE, EXPLOSIVE, FIRE, ELECTRIC, ENVIRONMENT, DOOR, THROWN, PUNCH }

var type: Type = Type.BALLISTIC
var amount := 1.0
var lethal := true          ## false -> knock down / stun instead of kill
var heavy := false          ## heavy melee / big explosion: beats armor & immunities
var source: Node = null
var dir := Vector2.RIGHT
var pos := Vector2.ZERO
var weapon_id: StringName = &""
var method: StringName = &"gun"   ## scoring category
var knockback := 120.0
var from_player := false

static func make(p_type: Type, p_source: Node, p_pos: Vector2, p_dir: Vector2, p_weapon: StringName = &"", p_method: StringName = &"gun") -> DamageInfo:
	var d := DamageInfo.new()
	d.type = p_type
	d.source = p_source
	d.pos = p_pos
	d.dir = p_dir.normalized() if p_dir.length() > 0.001 else Vector2.RIGHT
	d.weapon_id = p_weapon
	d.method = p_method
	d.from_player = p_source != null and is_instance_valid(p_source) and p_source.is_in_group("player")
	return d
