extends Node
## Game flow: campaign progression, scene transitions, mission/character
## selection, time-scale management (slow-mo + hit-stop), pause.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const LEVEL_SCENE := "res://scenes/levels/level.tscn"
const CUTSCENE_SCENE := "res://scenes/game/cutscene.tscn"
const RESULTS_SCENE := "res://scenes/ui/results.tscn"
const HUB_SCENE := "res://scenes/ui/hub.tscn"

var campaign: Array = []
var missions: Dictionary = {}       # id -> MissionData
var characters: Dictionary = {}     # id -> CharacterData
var current_mission: MissionData
var current_character: CharacterData
var current_cutscene := ""
var campaign_mode := true           # false = arcade / level select replay
var mask: StringName = &""
var mask_chosen := false
var highlights: Array = []           # [{img, combo, t, weapon}] the job's best kills, for the results reel             # picked for this job already (retries keep it)         # the mask for this job (see Masks); "" = the star
var modifiers: Dictionary = {}      # challenge/arcade modifiers e.g. {"melee_only": true}
var last_result: Dictionary = {}

# checkpoint state for instant restarts
var checkpoint_index := -1
var checkpoint_state: Dictionary = {}
var attempts := 1

# time scale layers
var _slowmo_scale := 1.0
var _hitstop_until := 0
var transitioning := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_data()
	Events.hit_stop.connect(hit_stop)

func _load_data() -> void:
	for id in ["m01_checkout", "m02_dog_days", "m03_prime_time", "m04_sweet_dreams"]:
		var path := "res://data/missions/%s.tres" % id
		if ResourceLoader.exists(path):
			missions[id] = load(path)
	var cdir := DirAccess.open("res://data/characters")
	if cdir:
		for f in cdir.get_files():
			var fname := f.trim_suffix(".remap")
			if fname.ends_with(".tres"):
				var c: CharacterData = load("res://data/characters/" + fname)
				if c:
					characters[c.id] = c
	var f := FileAccess.open("res://data/missions/campaign.json", FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Array:
			campaign = parsed

# ------------------------------------------------------------ campaign flow
func new_game() -> void:
	SaveManager.data.story.chapter = 0
	SaveManager.data.story.flags = {}
	SaveManager.save_game()
	campaign_mode = true
	modifiers = {}
	advance_to(0)

func continue_game() -> void:
	campaign_mode = true
	modifiers = {}
	advance_to(int(SaveManager.data.story.chapter))

func advance_to(step: int) -> void:
	if step >= campaign.size():
		goto_title()
		return
	SaveManager.data.story.chapter = step
	SaveManager.save_game()
	var beat: Dictionary = campaign[step]
	match str(beat.type):
		"cutscene":
			current_cutscene = beat.id
			change_scene(CUTSCENE_SCENE)
		"mission":
			start_mission(str(beat.id), str(beat.get("character", "")))
		"hub":
			change_scene(HUB_SCENE)
		_:
			goto_title()

func story_beat_finished() -> void:
	if campaign_mode:
		advance_to(int(SaveManager.data.story.chapter) + 1)
	else:
		goto_title()

func start_mission(mission_id: String, character_id := "", mods := {}) -> void:
	current_mission = missions.get(mission_id)
	if current_mission == null:
		push_error("Mission %s missing" % mission_id)
		goto_title()
		return
	var cid := character_id if character_id != "" else current_mission.default_character
	current_character = characters.get(cid, characters.get("cass"))
	if not mods.is_empty():
		modifiers = mods
	checkpoint_index = -1
	checkpoint_state = {}
	attempts = 1
	mask_chosen = false
	highlights = []
	if modifiers.get("arcade", false) or modifiers.has("mode"):
		SaveManager.add_stat("arcade_runs")
	Score.reset()
	_apply_time_scale()
	change_scene(LEVEL_SCENE)

func replay_mission(mission_id: String, character_id := "", mods := {}) -> void:
	campaign_mode = false
	modifiers = mods
	start_mission(mission_id, character_id, mods)

func mission_complete(result: Dictionary) -> void:
	last_result = result
	result["masks_unlocked"] = Masks.check_all()
	set_slowmo(1.0)
	change_scene(RESULTS_SCENE)

func goto_title() -> void:
	modifiers = {}
	set_slowmo(1.0)
	get_tree().paused = false
	change_scene(TITLE_SCENE)

## Instant restart: reload the level scene; the level reads checkpoint_state.
func restart_level() -> void:
	attempts += 1
	SaveManager.add_stat("deaths")
	set_slowmo(1.0)
	get_tree().paused = false
	get_tree().reload_current_scene()

# ------------------------------------------------------------ transitions
var _queued_scene := ""
var _queued_fade := true

func change_scene(path: String, fade := true) -> void:
	if _timed_slowmo_until > 0:
		_timed_slowmo_until = 0
		set_slowmo(1.0)
	if transitioning:
		# a request mid-fade (e.g. a cutscene ending as a mission starts) is
		# queued, not dropped: the newest one wins once this fade finishes
		_queued_scene = path
		_queued_fade = fade
		return
	transitioning = true
	get_tree().paused = false
	if fade and is_inside_tree():
		await PostFX.fade_out(0.25)
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Scene change failed %s: %s" % [path, err])
	await get_tree().process_frame
	await get_tree().process_frame
	transitioning = false
	if _queued_scene != "":
		var q := _queued_scene
		_queued_scene = ""
		change_scene(q, _queued_fade)
		return
	if fade:
		PostFX.fade_in(0.35)

# ------------------------------------------------------------ time
func set_slowmo(scale: float) -> void:
	_slowmo_scale = scale
	_apply_time_scale()

func get_slowmo() -> float:
	return _slowmo_scale

## Slow motion for a fixed stretch of real time (the FINAL TAKE). Owned
## here, not by the level, so a level torn down mid-effect can't leave a
## dangling timer behind; any scene change also ends it.
var _timed_slowmo_until := 0
func timed_slowmo(scale: float, seconds: float) -> void:
	if _slowmo_scale < 0.99:
		return   # the player's own slow-mo is running: leave it alone
	set_slowmo(scale)
	_timed_slowmo_until = Time.get_ticks_msec() + int(seconds * 1000.0)

func hit_stop(duration: float) -> void:
	_hitstop_until = maxi(_hitstop_until, Time.get_ticks_msec() + int(duration * 1000.0))
	_apply_time_scale()

func _process(_delta: float) -> void:
	if _timed_slowmo_until > 0 and Time.get_ticks_msec() >= _timed_slowmo_until:
		_timed_slowmo_until = 0
		set_slowmo(1.0)
	if _hitstop_until > 0 and Time.get_ticks_msec() >= _hitstop_until:
		_hitstop_until = 0
		_apply_time_scale()

## Mission-start calls: off in headless test runs (they'd hold the dialogue
## box while a test drives it) unless a test asks for them.
var force_intro_calls := false
func intro_calls_enabled() -> bool:
	if Engine.has_meta("trailer"):
		return false
	return force_intro_calls or DisplayServer.get_name() != "headless"

## Arcade TURBO runs the whole world a notch faster.
func _base_speed() -> float:
	return 1.2 if modifiers.get("turbo", false) and not campaign_mode else 1.0

func _apply_time_scale() -> void:
	Engine.time_scale = 0.03 if _hitstop_until > 0 else _slowmo_scale * _base_speed()
