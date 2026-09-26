class_name WeaponInstance
extends RefCounted
## A specific gun/knife in the world: data + its own ammo and wear.

var data: WeaponData
var ammo := 0
var reserve := 0
var durability := -1

static func create(d: WeaponData, full := true) -> WeaponInstance:
	var w := WeaponInstance.new()
	w.data = d
	if d:
		w.ammo = d.magazine if full else 0
		w.reserve = d.reserve_on_pickup() if full else 0
		w.durability = d.durability
	return w

func can_reload() -> bool:
	return data and data.is_firearm() and reserve > 0 and ammo < data.magazine

func is_empty_gun() -> bool:
	return data and data.is_firearm() and ammo <= 0 and reserve <= 0
