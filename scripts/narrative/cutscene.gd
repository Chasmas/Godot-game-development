extends Control
## Story scenes between missions: VHS title card, animated backdrop,
## dialogue from res://data/dialogue/<id>.json, script events.

var backdrop: TitleBackdrop
var card: Label
var osd: Label
var id := ""
var _t := 0.0

func _ready() -> void:
	theme = UIStyle.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep the backdrop animating while dialogue pauses the tree
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	id = Game.current_cutscene
	var d := Dialogue.load_dialogue(id)
	backdrop = TitleBackdrop.new()
	backdrop.mode = str(d.get("bg", "black"))
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	osd = UIStyle.label("PLAY ▶", 20, UIStyle.PAPER, true)
	osd.position = Vector2(28, 20)
	add_child(osd)
	card = UIStyle.title_label(str(d.get("title", "")), 30, UIStyle.PAPER)
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.place(card, Control.PRESET_CENTER_TOP, Vector2(-480, 80), Vector2(960, 40))
	add_child(card)
	var music := str(d.get("music", ""))
	if music != "":
		Music.play(music)
	else:
		Music.stop(0.8)
	Dialogue.event.connect(_on_event)
	Dialogue.finished.connect(_on_finished)
	PostFX.vhs_glitch(1.0)
	Audio.play("vhs_static", -6.0)
	await get_tree().create_timer(1.4).timeout
	Dialogue.start(id, true)

func _process(delta: float) -> void:
	_t += delta
	osd.text = "PLAY ▶   %d:%02d" % [int(_t) / 60, int(_t) % 60]
	if _t > 4.0:
		card.modulate.a = move_toward(card.modulate.a, 0.35, delta)

func _on_event(ev: String) -> void:
	match ev:
		"fire":
			backdrop.fire = 1.0
			PostFX.flash(Color(1, 0.6, 0.2), 0.7)
			PostFX.vhs_glitch(1.0)
		"star":
			PostFX.flash(UIStyle.GOLD, 0.35)
			SaveManager.set_flag("wore_the_star", true)
		"slice_complete":
			SaveManager.set_flag("slice_complete", true)

func _on_finished(fid: String) -> void:
	if fid != id:
		return
	PostFX.vhs_glitch(0.8)
	Audio.play("vhs_static", -6.0)
	Game.story_beat_finished()

func _exit_tree() -> void:
	if Dialogue.event.is_connected(_on_event):
		Dialogue.event.disconnect(_on_event)
	if Dialogue.finished.is_connected(_on_finished):
		Dialogue.finished.disconnect(_on_finished)
