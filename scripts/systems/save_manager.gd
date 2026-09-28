extends Node
## Robust save architecture.
## - Two files: settings.json (options) and save.json (progress).
## - Writes go to a .tmp file first, the previous good file is kept as .bak,
##   then the tmp is renamed into place. A crash mid-write never corrupts saves.
## - Loads validate JSON and fall back to the backup, then to defaults.

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const SAVE_VERSION := 1
const WINDOW_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]

const DEFAULT_SETTINGS := {
	"master_volume": 0.9, "music_volume": 0.8, "sfx_volume": 0.9, "dialogue_volume": 0.9,
	"screen_shake": 1.0, "crt": true, "chromatic": true, "gore": 2, "reduced_flashing": false,
	"brightness": 1.0, "fullscreen": false, "vsync": true, "vibration": true,
	"aim_assist": 0.5, "language": "en", "subtitles": true, "ui_scale": 1.0,
	"colorblind": 0, "show_fps": false, "bindings": {}, "window_size": 1, "bloom": true, "cel_shading": true, "weather": true,
	"lock_auto_next": true, "laser_always": false, "difficulty": 1,
	"subtitle_size": 1, "text_speed": 1, "set_dressing": true, "painted_props": true,
}

const DEFAULT_SAVE := {
	"version": SAVE_VERSION,
	"story": {"chapter": 0, "flags": {}},
	"missions": {},          # id -> {completed, best_score, best_rank, best_time}
	"leaderboards": {},      # id -> [{score, rank, time, character, date}]
	"unlocked_characters": ["cass"],
	"unlocked_weapons": [],
	"collectibles": [],
	"secrets": [],
	"stats": {"kills": 0, "deaths": 0, "executions": 0, "shots": 0, "hits": 0, "play_time": 0.0},
	"gallery": [],
	"masks": ["star"],
}

var settings: Dictionary = {}
var data: Dictionary = {}

func _ready() -> void:
	settings = _merge(DEFAULT_SETTINGS.duplicate(true), _load_json(SETTINGS_PATH))
	data = _merge(DEFAULT_SAVE.duplicate(true), _load_json(SAVE_PATH))
	apply_video_settings()

func has_progress() -> bool:
	return not data.missions.is_empty() or int(data.story.chapter) > 0 or not data.story.flags.is_empty()

# ------------------------------------------------------------ settings
func get_setting(key: String, fallback: Variant = null) -> Variant:
	return settings.get(key, DEFAULT_SETTINGS.get(key, fallback))

func set_setting(key: String, value: Variant, save_now := true) -> void:
	settings[key] = value
	if key in ["fullscreen", "vsync", "ui_scale", "window_size"]:
		apply_video_settings()
	if save_now:
		save_settings()
	Events.settings_changed.emit()

func apply_video_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var fs: bool = settings.get("fullscreen", false)
	var cur := DisplayServer.window_get_mode()
	if fs and cur != DisplayServer.WINDOW_MODE_FULLSCREEN and cur != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fs:
		if cur == DisplayServer.WINDOW_MODE_FULLSCREEN or cur == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var idx := clampi(int(settings.get("window_size", 1)), 0, WINDOW_SIZES.size() - 1)
		var want: Vector2i = WINDOW_SIZES[idx]
		var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		want = Vector2i(mini(want.x, screen.size.x), mini(want.y, screen.size.y))
		if DisplayServer.window_get_size() != want:
			DisplayServer.window_set_size(want)
			DisplayServer.window_set_position(screen.position + (screen.size - want) / 2)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.get("vsync", true) else DisplayServer.VSYNC_DISABLED)
	get_tree().root.content_scale_factor = clampf(float(settings.get("ui_scale", 1.0)), 0.75, 1.5)

func save_settings() -> void:
	_write_json(SETTINGS_PATH, settings)

# ------------------------------------------------------------ progress
func save_game() -> void:
	data.version = SAVE_VERSION
	_write_json(SAVE_PATH, data)

func set_flag(flag: String, value: Variant = true) -> void:
	data.story.flags[flag] = value
	save_game()

func get_flag(flag: String, fallback: Variant = false) -> Variant:
	return data.story.flags.get(flag, fallback)

func add_collectible(id: String) -> bool:
	if id in data.collectibles:
		return false
	data.collectibles.append(id)
	if not id in data.gallery:
		data.gallery.append(id)
	save_game()
	return true

func record_mission(mission_id: String, result: Dictionary) -> Dictionary:
	## Stores best results + a local leaderboard entry. Returns {new_best: bool, place: int}.
	var m: Dictionary = data.missions.get(mission_id, {"completed": false, "best_score": 0, "best_rank": "", "best_time": 0.0})
	var new_best: bool = int(result.score) > int(m.best_score)
	m.completed = true
	if new_best:
		m.best_score = int(result.score)
		m.best_rank = result.rank
		m.best_time = float(result.time)
	data.missions[mission_id] = m
	var board: Array = data.leaderboards.get(mission_id, [])
	var entry := {"score": int(result.score), "rank": result.rank, "time": float(result.time),
		"character": result.get("character", "cass"), "date": Time.get_date_string_from_system()}
	board.append(entry)
	board.sort_custom(func(a, b): return int(a.score) > int(b.score))
	if board.size() > 10:
		board.resize(10)
	data.leaderboards[mission_id] = board
	save_game()
	return {"new_best": new_best, "place": board.find(entry) + 1}

func add_stat(key: String, amount: float = 1.0) -> void:
	data.stats[key] = float(data.stats.get(key, 0.0)) + amount

func reset_progress() -> void:
	data = DEFAULT_SAVE.duplicate(true)
	save_game()

# ------------------------------------------------------------ io
func _write_json(path: String, dict: Dictionary) -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: cannot open %s (%s)" % [tmp, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(dict, "\t"))
	f.flush()
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var fname := path.get_file()
	if dir.file_exists(fname):
		if dir.file_exists(fname + ".bak"):
			dir.remove(fname + ".bak")
		dir.rename(fname, fname + ".bak")
	var err := dir.rename(tmp.get_file(), fname)
	if err != OK:
		push_warning("Save rename failed: %s" % err)

func _load_json(path: String) -> Dictionary:
	for p in [path, path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			return parsed
		push_warning("Corrupt save %s, trying backup" % p)
	return {}

func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	## Deep merge so that new keys added in updates always exist.
	for k in over.keys():
		if base.has(k) and base[k] is Dictionary and over[k] is Dictionary and k != "bindings" and k != "flags" and k != "missions" and k != "leaderboards":
			base[k] = _merge(base[k], over[k])
		elif not base.has(k) or typeof(base[k]) == typeof(over[k]) or base[k] == null:
			base[k] = over[k]
		elif (typeof(base[k]) == TYPE_INT or typeof(base[k]) == TYPE_FLOAT) and (typeof(over[k]) == TYPE_INT or typeof(over[k]) == TYPE_FLOAT):
			base[k] = over[k]
	return base
