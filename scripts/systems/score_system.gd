extends Node
## Score + combo + run statistics for the current mission attempt.
##
## Combo: every kill inside the combo window adds +1 to the chain and refreshes
## the window. Missed shots and hesitation drain the window. When it runs out,
## the chain is banked as a bonus. Variety, method and stealth multiply points.

signal score_changed(score: int)
signal combo_changed(count: int, time_left: float, window: float)
signal combo_ended(count: int, bonus: int)
signal points_popup(text: String, points: int, pos: Vector2)
## Combo 8+ and a melee kill: the one-per-combo finisher ("FINAL TAKE").
signal finisher(pos: Vector2)

const FINISHER_COMBO := 8
var _finisher_used := false

const COMBO_WINDOW := 3.2
const MISS_PENALTY := 0.45
const RANKS := ["C", "B", "A", "A+", "S", "S+", "SS", "SSS"]

const METHOD_POINTS := {
	&"gun": 300, &"melee": 500, &"thrown": 650, &"door": 700, &"execution": 900,
	&"environment": 1000, &"counter": 750, &"explosion": 800, &"punch": 400,
}

var score := 0
var combo := 0
var combo_time := 0.0
var combo_points := 0
var max_combo := 0
var stats := {}
var _last_method: StringName = &""
var _last_weapon: StringName = &""
var _methods_used := {}
var _weapons_used := {}
var running := false
var elapsed := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_fired.connect(_on_player_fired)
	Events.execution_performed.connect(func(_e): stats.executions += 1)
	reset()

func reset(keep_score := 0) -> void:
	score = keep_score
	combo = 0
	combo_time = 0.0
	combo_points = 0
	max_combo = 0
	_last_method = &""
	_last_weapon = &""
	_methods_used = {}
	_weapons_used = {}
	elapsed = 0.0
	stats = {"kills": 0, "shots": 0, "hits": 0, "executions": 0, "melee_kills": 0, "silent_kills": 0,
		"environment_kills": 0, "door_kills": 0, "thrown_kills": 0, "attempts": 1, "collectibles": 0}
	score_changed.emit(score)
	combo_changed.emit(0, 0.0, COMBO_WINDOW)

## Keep stats across a checkpoint restart but roll score back.
func snapshot() -> Dictionary:
	return {"score": score, "stats": stats.duplicate(), "max_combo": max_combo, "elapsed": elapsed,
		"methods": _methods_used.duplicate(), "weapons": _weapons_used.duplicate()}

func restore(snap: Dictionary, attempts: int) -> void:
	score = snap.get("score", 0)
	stats = snap.get("stats", stats).duplicate()
	stats.attempts = attempts
	max_combo = snap.get("max_combo", 0)
	elapsed = snap.get("elapsed", elapsed)
	_methods_used = snap.get("methods", {}).duplicate()
	_weapons_used = snap.get("weapons", {}).duplicate()
	combo = 0
	combo_time = 0.0
	combo_points = 0
	score_changed.emit(score)
	combo_changed.emit(0, 0.0, COMBO_WINDOW)

func _process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	if combo > 0:
		combo_time -= delta
		combo_changed.emit(combo, combo_time, COMBO_WINDOW)
		if combo_time <= 0.0:
			_bank_combo()

func _on_enemy_killed(_enemy: Node, info: Dictionary) -> void:
	var method: StringName = info.get("method", &"gun")
	var weapon: StringName = info.get("weapon_id", &"fists")
	var base: int = METHOD_POINTS.get(method, 300)
	var mult := 1.0
	var tags: Array[String] = []
	if weapon != _last_weapon and _last_weapon != &"":
		mult += 0.25
		tags.append("VARIETY")
	if method != _last_method and _last_method != &"":
		mult += 0.15
	if info.get("silent", false):
		mult += 0.5
		tags.append("SILENT")
		stats.silent_kills += 1
	if info.get("while_dashing", false):
		mult += 0.3
		tags.append("MOMENTUM")
	if info.get("slowmo", false):
		mult -= 0.2
	combo += 1
	max_combo = maxi(max_combo, combo)
	combo_time = COMBO_WINDOW
	var pts := int(round(base * mult * (1.0 + 0.5 * (combo - 1)) / 10.0)) * 10
	score += pts
	combo_points += pts
	_last_method = method
	_last_weapon = weapon
	_methods_used[method] = true
	_weapons_used[weapon] = true
	stats.kills += 1
	match method:
		&"melee", &"counter", &"punch": stats.melee_kills += 1
		&"environment", &"explosion": stats.environment_kills += 1
		&"door": stats.door_kills += 1
		&"thrown": stats.thrown_kills += 1
	var label := String(method).to_upper()
	if not tags.is_empty():
		label += " · " + " · ".join(tags)
	points_popup.emit(label, pts, info.get("pos", Vector2.ZERO))
	score_changed.emit(score)
	combo_changed.emit(combo, combo_time, COMBO_WINDOW)
	if combo >= 2:
		Audio.play("combo", -6.0, 1.0 + minf(combo, 12) * 0.05)
	if combo >= FINISHER_COMBO and not _finisher_used and method in [&"melee", &"punch", &"counter", &"execution"]:
		_finisher_used = true
		var fb := 2000 + combo * 150
		score += fb
		points_popup.emit("FINAL TAKE", fb, info.get("pos", Vector2.ZERO))
		score_changed.emit(score)
		finisher.emit(info.get("pos", Vector2.ZERO))

func _on_player_fired(_weapon_id: StringName, hit: bool) -> void:
	stats.shots += 1
	if hit:
		stats.hits += 1
	elif combo > 0:
		combo_time -= MISS_PENALTY

func on_player_hurt() -> void:
	if combo > 0:
		combo_time = minf(combo_time, 0.4)

func add_bonus(text: String, pts: int, pos := Vector2.ZERO) -> void:
	score += pts
	points_popup.emit(text, pts, pos)
	score_changed.emit(score)

func _bank_combo() -> void:
	var bonus := 0
	if combo >= 2:
		bonus = int(combo_points * 0.25 * (combo - 1)) / 10 * 10
		score += bonus
		score_changed.emit(score)
	combo_ended.emit(combo, bonus)
	_finisher_used = false
	combo = 0
	combo_points = 0
	combo_time = 0.0
	combo_changed.emit(0, 0.0, COMBO_WINDOW)

func finish() -> Dictionary:
	if combo > 0:
		_bank_combo()
	running = false
	return {"score": score, "time": elapsed, "max_combo": max_combo, "stats": stats.duplicate(),
		"variety": _weapons_used.size(), "methods": _methods_used.size()}

## Rank from a result + mission par values. Rewards speed, flow and expression.
func compute_rank(result: Dictionary, par_score: int, par_time: float) -> Dictionary:
	var st: Dictionary = result.stats
	var acc := float(st.hits) / maxf(1.0, float(st.shots)) if st.shots > 0 else 1.0
	var time_bonus := int(clampf((par_time - result.time) / par_time, -0.5, 1.0) * 8000.0)
	var flow_bonus := int(result.max_combo) * 600
	var variety_bonus := int(result.variety) * 400 + int(result.methods) * 500
	var acc_bonus := int(acc * 3000.0)
	var total := int(result.score) + maxi(time_bonus, 0) + flow_bonus + variety_bonus + acc_bonus
	var ratio := float(total) / maxf(1.0, float(par_score))
	var thresholds := [0.0, 0.45, 0.65, 0.8, 0.95, 1.1, 1.3, 1.55]
	var idx := 0
	for i in thresholds.size():
		if ratio >= thresholds[i]:
			idx = i
	return {"rank": RANKS[idx], "total": total, "time_bonus": maxi(time_bonus, 0), "flow_bonus": flow_bonus,
		"variety_bonus": variety_bonus, "accuracy": acc, "accuracy_bonus": acc_bonus, "ratio": ratio}
