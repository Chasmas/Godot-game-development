extends Control
## Cold open between the studio splash and the title: a tape starts, the
## story flashes past in illustrated shots with typed captions, and the logo
## slams in. Any key, button or click skips to the title.

## A trailer, cut to its own track (music/intro_teaser.ogg, 128 bpm - see
## TEASER_CUTS in tools/gen_music_hm.py): every cut lands on the beat. The
## story in a breath, then a taste of every job ahead, then the logo.
const BPM := 128.0
const BEATS := [
	# [shot, beats, caption]
	["static", 2, ""],
	["t_tape", 4, "1988. SOMEBODY MAILED HER A TAPE."],
	["t_drive", 2, "NO RETURN ADDRESS."],
	["t_star", 4, "SHE KNOWS WHAT IT MEANS."],
	["t_arsenal", 4, "EVERY NAME ON THE CALL SHEET."],
	["t_corridor", 2, "THE MOTEL."],
	["t_dogs", 2, "THE YARD."],
	["t_studio", 2, "THE STUDIO."],
	["t_fire", 2, "THE FIREMAN."],
	["t_mansion", 2, "THE DREAM."],
	["t_monitors", 2, "AND SOMEONE"],
	["t_marv", 2, "IS WATCHING."],
	["t_phone", 2, "NOBODY YELLS CUT."],
	["t_fire", 1, ""],
	["t_marv", 1, ""],
	["t_dogs", 1, ""],
	["t_star", 1, ""],
	["t_walk", 4, "SHE'S THE LEAD."],
]
const LOGO_TIME := 3.2

var shot: StoryShot
var caption: Label
var osd: Label
var logo_top: Label
var logo_bottom: Label
var _beat := -1
var _beat_t := 0.0
var _t := 0.0
var _caption_full := ""
var _typed := 0
var _logo_t := -1.0
var _leaving := false

func _ready() -> void:
	theme = UIStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	shot = StoryShot.new()
	shot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shot.shot_time = 3.0
	add_child(shot)
	caption = UIStyle.label("", 22, UIStyle.PAPER, true)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	caption.add_theme_constant_override("outline_size", 6)
	UIStyle.place(caption, Control.PRESET_CENTER_BOTTOM, Vector2(-480, -62), Vector2(960, 40))
	add_child(caption)
	osd = UIStyle.label("PLAY ▶", 20, UIStyle.PAPER, true)
	osd.position = Vector2(28, 20)
	add_child(osd)
	logo_top = Label.new()
	logo_top.text = "HOTSHOT"
	logo_top.add_theme_font_override("font", UIStyle.font_display())
	logo_top.add_theme_font_size_override("font_size", 128)
	logo_top.add_theme_color_override("font_shadow_color", Color(0.05, 0.0, 0.12, 0.9))
	logo_top.add_theme_constant_override("shadow_offset_x", 6)
	logo_top.add_theme_constant_override("shadow_offset_y", 6)
	logo_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.place(logo_top, Control.PRESET_CENTER, Vector2(-460, -120), Vector2(920, 150))
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/logo_gradient.gdshader")
	m.set_shader_parameter("height", 150.0)
	logo_top.material = m
	logo_top.visible = false
	add_child(logo_top)
	logo_bottom = Label.new()
	logo_bottom.text = "California"
	logo_bottom.add_theme_font_override("font", UIStyle.font_script())
	logo_bottom.add_theme_font_size_override("font_size", 64)
	logo_bottom.add_theme_color_override("font_color", Color(1, 0.35, 0.75))
	logo_bottom.add_theme_color_override("font_outline_color", Color(1, 0.2, 0.6, 0.35))
	logo_bottom.add_theme_constant_override("outline_size", 14)
	logo_bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_bottom.rotation = -0.06
	UIStyle.place(logo_bottom, Control.PRESET_CENTER, Vector2(-250, 22), Vector2(700, 90))
	logo_bottom.visible = false
	add_child(logo_bottom)
	Music.play("teaser", true)
	PostFX.set_desaturate(0.0)
	PostFX.set_tint(Color(1, 1, 1, 0))
	Audio.play("vhs_static", -6.0)
	_next_beat()

func _next_beat() -> void:
	_beat += 1
	_beat_t = 0.0
	if _beat >= BEATS.size():
		_start_logo()
		return
	var b: Array = BEATS[_beat]
	shot.show_shot(str(b[0]), _beat == 0)
	var cap := tr(str(b[2]))
	if cap != _caption_full:
		_caption_full = cap
		_typed = 0
		caption.text = ""
	if _beat == 3:   # the drop: lands on the star
		PostFX.flash(Color(1, 0.8, 0.5), 0.8)
		PostFX.vhs_glitch(1.0)
		Events.camera_shake.emit(10.0)
	elif _beat > 0:
		# a tape-splice glitch on every cut, harder as the cuts get faster
		PostFX.vhs_glitch(0.25 if float(b[1]) >= 2.0 else 0.5)

func _start_logo() -> void:
	_logo_t = 0.0
	shot.show_shot("static")
	shot.letterbox = false
	caption.text = ""
	logo_top.visible = true
	logo_bottom.visible = true
	Audio.play("rank_stamp", -2.0)
	PostFX.vhs_glitch(1.0)
	PostFX.flash(UIStyle.PINK, 0.25)

func _process(delta: float) -> void:
	_t += delta
	var secs := int(_t * 30.0)
	osd.text = "PLAY ▶   SP   0:00:%02d:%02d" % [secs / 30, secs % 30]
	if _logo_t >= 0.0:
		_logo_t += delta
		var k := clampf(_logo_t / 0.18, 0.0, 1.0)
		logo_top.pivot_offset = logo_top.size * 0.5
		logo_top.scale = Vector2.ONE * lerpf(1.6, 1.0, k)
		logo_top.modulate.a = k
		var k2 := clampf((_logo_t - 0.35) / 0.3, 0.0, 1.0)
		logo_bottom.modulate.a = k2 * (0.35 if fmod(_logo_t, 1.7) < 0.06 else 1.0)
		shot.modulate.a = clampf(1.0 - _logo_t / 0.6, 0.12, 1.0)
		if _logo_t > LOGO_TIME:
			_leave()
		return
	_beat_t += delta
	# caption typewriter
	if _typed < _caption_full.length():
		var want := int(_beat_t * 32.0) if _beat_t > 0.15 else 0
		while _typed < mini(want, _caption_full.length()):
			_typed += 1
			if _caption_full[_typed - 1] != " ":
				Audio.play("type_clack", -12.0, randf_range(0.9, 1.1))
		caption.text = _caption_full.substr(0, _typed)
	if _beat < BEATS.size() and _beat_t >= float(BEATS[_beat][1]) * 60.0 / BPM:
		_next_beat()

func _input(e: InputEvent) -> void:
	if UIStyle.is_any_press(e):
		get_viewport().set_input_as_handled()
		_leave()

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	Game.change_scene(Game.TITLE_SCENE)
