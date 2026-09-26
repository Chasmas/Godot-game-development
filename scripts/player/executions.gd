class_name Executions
extends RefCounted
## Execution / takedown moves. Picked at random from what fits the weapon in
## hand and the situation (target downed on the floor, grabbed from behind,
## or a dog). Each move: name, number of blows, total time, per-blow
## animation, how bloody each blow is, the finisher (what happens to the
## body) and how much noise it makes.
##
## anim: swing | stab | punch | stomp | shot | grab
## finisher: decap | skull | throat | gut | limb | teeth | neck | ""

const MOVES := {
	"fists_down": [
		{"name": "CURB STOMP", "hits": 3, "time": 0.62, "anim": "stomp", "blood": 1.2, "finisher": "skull", "noise": 60.0},
		{"name": "GROUND & POUND", "hits": 4, "time": 0.6, "anim": "punch", "blood": 0.9, "finisher": "teeth", "noise": 50.0},
		{"name": "SKULL SLAM", "hits": 2, "time": 0.5, "anim": "punch", "blood": 1.4, "finisher": "skull", "noise": 70.0},
	],
	"fists_stand": [
		{"name": "NECK SNAP", "hits": 1, "time": 0.38, "anim": "grab", "blood": 0.0, "finisher": "neck", "noise": 0.0},
		{"name": "CHOKEHOLD", "hits": 2, "time": 0.55, "anim": "grab", "blood": 0.0, "finisher": "neck", "noise": 0.0},
	],
	"blade_down": [
		{"name": "THROAT SLIT", "hits": 1, "time": 0.3, "anim": "stab", "blood": 1.6, "finisher": "throat", "noise": 0.0},
		{"name": "FRENZY", "hits": 5, "time": 0.55, "anim": "stab", "blood": 1.0, "finisher": "gut", "noise": 30.0},
		{"name": "EYE SOCKET", "hits": 2, "time": 0.36, "anim": "stab", "blood": 1.3, "finisher": "", "noise": 0.0},
	],
	"blade_stand": [
		{"name": "THROAT SLIT", "hits": 1, "time": 0.28, "anim": "stab", "blood": 1.8, "finisher": "throat", "noise": 0.0},
		{"name": "BACKSTAB", "hits": 2, "time": 0.32, "anim": "stab", "blood": 1.3, "finisher": "gut", "noise": 0.0},
	],
	"machete_down": [
		{"name": "DECAPITATION", "hits": 1, "time": 0.3, "anim": "swing", "blood": 2.0, "finisher": "decap", "noise": 20.0},
		{"name": "DISMEMBER", "hits": 2, "time": 0.4, "anim": "swing", "blood": 1.6, "finisher": "limb", "noise": 20.0},
		{"name": "BUTCHER", "hits": 3, "time": 0.48, "anim": "swing", "blood": 1.3, "finisher": "decap", "noise": 30.0},
	],
	"machete_stand": [
		{"name": "DECAPITATION", "hits": 1, "time": 0.28, "anim": "swing", "blood": 2.0, "finisher": "decap", "noise": 0.0},
		{"name": "SPINE SPLITTER", "hits": 1, "time": 0.3, "anim": "swing", "blood": 1.6, "finisher": "gut", "noise": 0.0},
	],
	"blunt_down": [
		{"name": "HOME RUN", "hits": 1, "time": 0.36, "anim": "swing", "blood": 2.0, "finisher": "skull", "noise": 60.0},
		{"name": "BATTERED", "hits": 3, "time": 0.52, "anim": "swing", "blood": 1.2, "finisher": "skull", "noise": 70.0},
		{"name": "DENTAL WORK", "hits": 2, "time": 0.42, "anim": "swing", "blood": 1.0, "finisher": "teeth", "noise": 50.0},
	],
	"blunt_stand": [
		{"name": "LIGHTS OUT", "hits": 1, "time": 0.3, "anim": "swing", "blood": 1.4, "finisher": "skull", "noise": 20.0},
		{"name": "SKULL CRACK", "hits": 2, "time": 0.4, "anim": "swing", "blood": 1.2, "finisher": "skull", "noise": 30.0},
	],
	"gun_down": [
		{"name": "POINT BLANK", "hits": 1, "time": 0.3, "anim": "shot", "blood": 2.0, "finisher": "skull", "noise": -1.0},
		{"name": "DOUBLE TAP", "hits": 2, "time": 0.4, "anim": "shot", "blood": 1.5, "finisher": "skull", "noise": -1.0},
	],
	"gun_stand": [
		{"name": "BACK OF THE HEAD", "hits": 1, "time": 0.28, "anim": "shot", "blood": 2.0, "finisher": "skull", "noise": -1.0},
	],
	"gun_empty": [
		{"name": "PISTOL WHIP", "hits": 3, "time": 0.5, "anim": "swing", "blood": 1.1, "finisher": "teeth", "noise": 50.0},
	],
	"dog": [
		{"name": "PUT DOWN", "hits": 1, "time": 0.3, "anim": "stab", "blood": 1.2, "finisher": "", "noise": 0.0},
		{"name": "STOMPED", "hits": 2, "time": 0.4, "anim": "stomp", "blood": 1.2, "finisher": "", "noise": 30.0},
	],
	"dog_blade": [
		{"name": "SILENCED", "hits": 1, "time": 0.26, "anim": "stab", "blood": 1.4, "finisher": "throat", "noise": 0.0},
		{"name": "OFF WITH ITS HEAD", "hits": 1, "time": 0.3, "anim": "swing", "blood": 1.8, "finisher": "decap", "noise": 0.0},
	],
}

static func category(w: WeaponData, standing: bool, dog: bool) -> String:
	if dog:
		if w and w.is_melee() and w.id in [&"knife", &"broken_bottle", &"machete"]:
			return "dog_blade"
		return "dog"
	var suffix := "_stand" if standing else "_down"
	if w == null:
		return "fists" + suffix
	if w.is_firearm():
		return "gun" + suffix
	match w.id:
		&"knife", &"broken_bottle":
			return "blade" + suffix
		&"machete":
			return "machete" + suffix
	return "blunt" + suffix

static func pick(w: WeaponData, ammo: int, standing: bool, dog: bool) -> Dictionary:
	var cat := category(w, standing, dog)
	if cat.begins_with("gun") and ammo <= 0:
		cat = "gun_empty"
	var list: Array = MOVES.get(cat, MOVES["fists_down"])
	var m: Dictionary = list[randi() % list.size()].duplicate()
	if cat == "dog_blade" and w and w.id != &"machete" and m.finisher == "decap":
		m = list[0].duplicate()
	m["category"] = cat
	return m
