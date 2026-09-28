class_name Masks
extends RefCounted
## The masks Cass can wear on a job (PersonaData). Each one gives something
## and takes something. She starts with THE STAR; the rest are earned by
## finishing chapters, by how well she plays them, by habits (bare-handed
## kills, arcade runs) or by finding them hidden in a level. Unlocks live in
## the save ("masks"); the one she's wearing is Game.mask.

const ORDER := [&"star", &"soldier", &"dog", &"cowboy", &"angel", &"saint", &"ghost", &"fool", &"king", &"devil", &"king_hidden"]
const RANKS := ["C", "B", "A", "A+", "S", "S+", "SS", "SSS"]

static func unlocked_list() -> Array:
	var l: Array = SaveManager.data.get("masks", [])
	if not "star" in l:
		l.append("star")
		SaveManager.data["masks"] = l
	return l

static func is_unlocked(id: StringName) -> bool:
	return String(id) in unlocked_list()

## The mask for this job: the chosen one if it's unlocked, else the star.
static func current() -> PersonaData:
	var id: StringName = Game.mask if Game.mask != &"" and is_unlocked(Game.mask) else &"star"
	return DB.persona(id)

static func unlock(id: StringName) -> bool:
	if is_unlocked(id):
		return false
	var l := unlocked_list()
	l.append(String(id))
	SaveManager.data["masks"] = l
	SaveManager.save_game()
	var p := DB.persona(id)
	Events.mask_unlocked.emit(id)
	if p:
		Events.hint.emit(TranslationServer.translate("MASK UNLOCKED: %s") % TranslationServer.translate(p.display_name), 3.5)
	return true

static func _rank_at_least(r: String, want: String) -> bool:
	return RANKS.find(r) >= RANKS.find(want) and RANKS.find(r) >= 0

## Called after every finished mission (and when stats change): hands out
## everything whose condition is now met. Returns the ids unlocked.
static func check_all() -> Array:
	var got: Array = []
	for id in ORDER:
		if is_unlocked(id):
			continue
		var p := DB.persona(id)
		if p == null or p.unlock == "" or p.unlock.begins_with("secret:"):
			continue
		var parts := p.unlock.split(":")
		var ok := false
		match parts[0]:
			"start":
				ok = true
			"mission":
				ok = bool(SaveManager.data.missions.get(parts[1], {}).get("completed", false))
			"rank":
				ok = _rank_at_least(str(SaveManager.data.missions.get(parts[1], {}).get("best_rank", "")), parts[2])
			"rank_any":
				for m in SaveManager.data.missions.values():
					if _rank_at_least(str(m.get("best_rank", "")), parts[1]):
						ok = true
			"stat":
				ok = float(SaveManager.data.stats.get(parts[1], 0.0)) >= float(parts[2])
		if ok and unlock(id):
			got.append(id)
	return got

## The hidden mask for a mission, if it's still waiting to be found.
static func secret_for(mission_id: String) -> StringName:
	for id in ORDER:
		var p := DB.persona(id)
		if p and p.unlock == "secret:" + mission_id and not is_unlocked(id):
			return id
	return &""

static var _icons: Dictionary = {}

## Held in a static cache: a texture that only lives in a local while a
## _draw() runs is freed before the frame renders (a blank white square).
static func icon(id: StringName) -> Texture2D:
	if not _icons.has(id):
		var p := "res://assets/art/masks/%s.png" % id
		_icons[id] = load(p) if ResourceLoader.exists(p) else null
	return _icons[id]
