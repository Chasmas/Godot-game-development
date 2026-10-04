extends Control
## Story scenes between missions: VHS title card, animated backdrop,
## dialogue from res://data/dialogue/<id>.json, script events.

var backdrop: TitleBackdrop
var shot: StoryShot
var _lines := 0
var _slam: Label               ## the big ACTION! card          ## illustrated shots, when the dialogue names them
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
		# Treat single-frame key art like a held film shot: a slow breathing
		# push-in plus a barely perceptible handheld drift keeps it alive without
		# making text or character silhouettes wobble.
		var k := 1.012 + sin(_t * 0.12) * 0.003
		art.scale = Vector2.ONE * k
		art.position = Vector2(sin(_t * 0.10) * 2.5, cos(_t * 0.08) * 1.5)
		if art_shade:
			var pulse := 0.10 + sin(_t * 0.55) * 0.018
			art_shade.color = Color(0.01, 0.0, 0.025, pulse)

## Each line can cut to a new shot ("shot" on the dialogue node).
func _on_line(_speaker: String, _text: String) -> void:
	var sid := str(Dialogue._node.get("shot", ""))
	if shot == null:
		return
	if sid != "" and StoryShot.resolve(sid) != shot.shot_id:
		shot.show_shot(sid)
	elif _lines > 0:
		# the same painting again: cut to another angle on it
		shot.reframe()
	_lines += 1

func _on_event(ev: String) -> void:
	match ev:
		"action":
			# the director's call: the slate cracks, the room goes dead quiet,
			# the word slams onto the screen - and hangs there a beat too long
			Audio.play("slate_clap", 2.0)
			PostFX.vhs_glitch(0.5)
			if shot:
				shot._shake = 0.35
			_slam = UIStyle.title_label(tr("ACTION!"), 118, UIStyle.GOLD)
			_slam.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_slam.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_slam.add_theme_color_override("font_outline_color", UIStyle.PINK)
			_slam.add_theme_constant_override("outline_size", 14)
			_slam.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_slam.offset_bottom = -140
			add_child(_slam)
			_slam.pivot_offset = get_viewport_rect().size * 0.5 - Vector2(0, 70)
			_slam.scale = Vector2.ONE * 2.6
			_slam.modulate.a = 0.0
			var tw := create_tween().set_parallel()
			tw.tween_property(_slam, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
			tw.tween_property(_slam, "modulate:a", 1.0, 0.08)
			# a slow creep closer while nothing happens
			tw.chain().tween_property(_slam, "scale", Vector2.ONE * 1.08, 0.7)
		"fire":
			if backdrop:
				backdrop.fire = 1.0
			# the word is blown off the screen with the car
			if _slam and is_instance_valid(_slam):
				var sl := _slam
				_slam = null
				var tw := create_tween().set_parallel()
				tw.tween_property(sl, "scale", Vector2.ONE * 4.0, 0.35).set_ease(Tween.EASE_OUT)
				tw.tween_property(sl, "modulate", Color(1.6, 0.6, 0.2, 0.0), 0.35)
				tw.chain().tween_callback(sl.queue_free)
			PostFX.flash(Color(1, 1, 0.9), 1.0)
			PostFX.vhs_glitch(1.0)
			Events.camera_shake.emit(14.0)
			InputSetup.vibrate(0.9, 1.0, 0.6)
			if shot:
				shot._shake = 1.0
				shot._flash = 1.0
			# ears ringing under whatever comes next
			get_tree().create_timer(0.35).timeout.connect(func(): Audio.play("ear_ring", -10.0))
			get_tree().create_timer(0.25).timeout.connect(func(): PostFX.flash(Color(1, 0.5, 0.15), 0.8))
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
