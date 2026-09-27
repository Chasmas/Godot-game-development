extends Control
## Story scenes between missions: VHS title card, animated backdrop,
## dialogue from res://data/dialogue/<id>.json, script events.

var backdrop: TitleBackdrop
var shot: StoryShot          ## illustrated shots, when the dialogue names them
var art: TextureRect         ## authored full-frame art (CinematicArt), when present
var art_shade: ColorRect
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
	# authored key art wins when its PNG is in the project; otherwise the
	# illustrated StoryShot sequence; otherwise the procedural backdrop
	var art_tex := CinematicArt.cutscene_texture(id)
	if StoryShot.has_shot(str(d.get("shot", ""))):
		shot = StoryShot.new()
		shot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(shot)
		shot.show_shot(str(d.shot), true)
		Dialogue.line_shown.connect(_on_line)
	elif art_tex:
		backdrop = TitleBackdrop.new()
		backdrop.mode = str(d.get("bg", "black"))
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(backdrop)
		art = CinematicArt.make_fullscreen(art_tex)
		add_child(art)
		art_shade = ColorRect.new()
		art_shade.color = Color(0.01, 0.0, 0.025, 0.12)
		art_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art_shade)
	else:
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
		card.modulate.a = move_toward(card.modulate.a, 0.0 if shot else 0.35, delta)
	if art:
		art.pivot_offset = art.size * 0.5
		var k := 1.012 + sin(_t * 0.12) * 0.003
		art.scale = Vector2.ONE * k
		art.position = Vector2(sin(_t * 0.10) * 2.5, cos(_t * 0.08) * 1.5)

## Each line can cut to a new shot ("shot" on the dialogue node).
func _on_line(_speaker: String, _text: String) -> void:
	var sid := str(Dialogue._node.get("shot", ""))
	if shot and sid != "":
		shot.show_shot(sid)

func _on_event(ev: String) -> void:
	match ev:
		"fire":
			if backdrop:
				backdrop.fire = 1.0
			PostFX.flash(Color(1, 0.6, 0.2), 0.7)
			PostFX.vhs_glitch(1.0)
		"gunshot":
			PostFX.flash(Color(1, 1, 1), 0.5)
			PostFX.vhs_glitch(1.0)
			Events.camera_shake.emit(8.0)
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
	if Dialogue.line_shown.is_connected(_on_line):
		Dialogue.line_shown.disconnect(_on_line)
	if Dialogue.finished.is_connected(_on_finished):
		Dialogue.finished.disconnect(_on_finished)
