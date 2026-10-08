extends Control
## Launch splash: INVERTED INDEX STUDIO logo, then the "A GAME CREATED BY" card.
## Any key / button / click skips to the title.

const INTRO_SCENE := "res://scenes/ui/intro.tscn"
const STUDIO_TIME := 5.0
const CREDIT_TIME := 3.8

var _t := 0.0
var _phase := 0            # 0 studio, 1 credit, 2 leaving
var _leaving := false
var _studio: StudioLogo
var _credit: Control
var _by_label: Label
var _name_label: Label
var _osd: Label
var _played_stamp := false
var _played_chime := false
var _played_name := false

func _ready() -> void:
	theme = UIStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/pixellab_ui_v3_approved/splash_background_openai.png") as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.78, 0.82, 0.95, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var vignette := ColorRect.new()
	vignette.color = Color(0.005, 0.0, 0.025, 0.28)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	_studio = StudioLogo.new()
	_studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_studio)
	# --- credit card
	_credit = Control.new()
	_credit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_credit.modulate.a = 0.0
	add_child(_credit)
	_osd = UIStyle.label("PLAY ▶", 22, UIStyle.PAPER, true)
	_osd.position = Vector2(28, 20)
	_credit.add_child(_osd)
	_by_label = UIStyle.label("", 20, UIStyle.CYAN, true)
	_by_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.place(_by_label, Control.PRESET_CENTER, Vector2(-480, -70), Vector2(960, 30))
	_credit.add_child(_by_label)
	_name_label = Label.new()
	_name_label.text = "GILBERTO LOPES"
	_name_label.add_theme_font_override("font", UIStyle.font_display())
	_name_label.add_theme_font_size_override("font_size", 72)
	_name_label.add_theme_color_override("font_shadow_color", Color(0.05, 0.0, 0.12, 0.9))
	_name_label.add_theme_constant_override("shadow_offset_x", 5)
	_name_label.add_theme_constant_override("shadow_offset_y", 5)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.place(_name_label, Control.PRESET_CENTER, Vector2(-480, -38), Vector2(960, 100))
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/logo_gradient.gdshader")
	m.set_shader_parameter("height", 100.0)
	_name_label.material = m
	_name_label.modulate.a = 0.0
	_credit.add_child(_name_label)
	var underline := NeonLine.new()
	UIStyle.place(underline, Control.PRESET_CENTER, Vector2(-300, 66), Vector2(600, 10))
	underline.name = "Underline"
	_credit.add_child(underline)
	Music.stop(0.0)
	PostFX.set_desaturate(0.0)
	PostFX.set_tint(Color(1, 1, 1, 0))
	Audio.play("vhs_static", -14.0)

func _process(delta: float) -> void:
	_t += delta
	match _phase:
		0:
			_studio.t = _t
			# the studio's chime: a bell per side of the triangle as it draws,
			# the motif turned upside down as the logo lands
			if _t > 0.15 and not _played_chime:
				_played_chime = true
				Audio.play("studio_chime", -2.0)
			if _t > 1.05 and not _played_stamp:
				_played_stamp = true
				PostFX.vhs_glitch(0.35)
				PostFX.flash(UIStyle.GOLD, 0.12)
			if _t > STUDIO_TIME - 0.5:
				_studio.modulate.a = clampf((STUDIO_TIME - _t) / 0.5, 0.0, 1.0)
			if _t >= STUDIO_TIME:
				_phase = 1
				_t = 0.0
				PostFX.vhs_glitch(1.0)
				Audio.play("vhs_static", -8.0)
		1:
			_credit.modulate.a = clampf(_t / 0.25, 0.0, 1.0)
			var now := Time.get_time_dict_from_system()
			_osd.text = "PLAY ▶   SP   %02d:%02d:%02d" % [int(now.hour), int(now.minute), int(now.second)]
			# typewriter for the small line
			var full := tr("A  GAME  CREATED  BY")
			var n := clampi(int((_t - 0.3) * 28.0), 0, full.length())
			if n != _by_label.text.length():
				_by_label.text = full.substr(0, n)
				if n > 0 and full[n - 1] != " ":
					Audio.play("blip", -12.0, 1.2)
			if _t > 1.15:
				if not _played_name:
					_played_name = true
					Audio.play("rank_stamp", -2.0)
					PostFX.vhs_glitch(0.9)
					PostFX.flash(UIStyle.PINK, 0.18)
				var k := clampf((_t - 1.15) / 0.18, 0.0, 1.0)
				_name_label.modulate.a = k
				_name_label.pivot_offset = _name_label.size * 0.5
				_name_label.scale = Vector2.ONE * lerpf(1.25, 1.0, k)
				# brief horizontal glitch jitter on arrival
				_name_label.position.x = _name_label.get_parent_area_size().x * 0.5 - 480 + (randf_range(-8, 8) if _t < 1.5 else 0.0)
				(_credit.get_node("Underline") as NeonLine).grow = clampf((_t - 1.3) / 0.5, 0.0, 1.0)
			if _t > CREDIT_TIME - 0.5:
				_credit.modulate.a = clampf((CREDIT_TIME - _t) / 0.5, 0.0, 1.0)
			if _t >= CREDIT_TIME:
				_leave()

func _input(e: InputEvent) -> void:
	if _leaving:
		return
	var pressed := UIStyle.is_any_press(e)
	if pressed:
		get_viewport().set_input_as_handled()
		if _phase == 0:
			_phase = 1
			_t = 0.0
			_studio.visible = false
			PostFX.vhs_glitch(0.8)
		else:
			_leave()

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	_phase = 2
	Game.change_scene(INTRO_SCENE)


## The INVERTED INDEX mark: an inverted triangle built from index bars,
## crowned by an upside-down "i" (¡) - the index turned on its head.
class StudioLogo extends Control:
	var t := 0.0
	var logo_art: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo_art = load("res://assets/art/pixellab_ui_v3_approved/studio_logo_openai.png") as Texture2D

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5 + Vector2(0, -50)
		var reveal := clampf((t - 0.15) / 0.9, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - reveal, 3.0)
		var r := 92.0
		if logo_art and e > 0.0:
			var art_size := minf(size.x, size.y) * 0.32
			var art_rect := Rect2(c - Vector2(art_size, art_size) * 0.5, Vector2(art_size, art_size))
			# Separate the mark from the dark key art with a soft cyan/pink halo and
			# a small chromatic offset. This gives the bitmap physical depth on entry.
			var halo := art_rect.grow(8.0 + 3.0 * sin(t * 2.4))
			draw_style_box(_logo_glow(Color(0.02, 0.7, 1.0, 0.10 * e), Color(UIStyle.CYAN, 0.34 * e)), halo)
			draw_texture_rect(logo_art, Rect2(art_rect.position + Vector2(3, 2), art_rect.size), false, Color(UIStyle.PINK, 0.16 * e))
			draw_texture_rect(logo_art, art_rect, false, Color(1, 1, 1, e * 0.92))
			# One restrained neon tracer travels around the approved mark's three corners.
			var q0 := art_rect.position + Vector2(art_size * 0.18, art_size * 0.24)
			var q1 := art_rect.position + Vector2(art_size * 0.82, art_size * 0.24)
			var q2 := art_rect.position + Vector2(art_size * 0.50, art_size * 0.86)
			var u := fmod(t * 0.18, 3.0)
			var qa := q0 if u < 1.0 else (q1 if u < 2.0 else q2)
			var qb := q1 if u < 1.0 else (q2 if u < 2.0 else q0)
			var tracer := qa.lerp(qb, fmod(u, 1.0))
			var td := (qb - qa).normalized()
			var trail := tracer - td * 22.0
			# A moving dash, rather than a round marker: the highlight hugs each
			# corner and reads as reflected neon travelling over chrome.
			var loop := PackedVector2Array([q0, q1, q2, q0])
			draw_polyline(loop, Color(UIStyle.CYAN, 0.14 * e), 9.0, true)
			draw_polyline(loop, Color(UIStyle.PINK, 0.24 * e), 3.0, true)
			draw_line(trail, tracer, Color(UIStyle.CYAN, 0.16 * e), 10.0)
			draw_line(trail, tracer, Color(UIStyle.PINK, 0.42 * e), 5.0)
			draw_line(trail, tracer, Color.WHITE, 1.8)
		# The bitmap carries the approved mark; code below is limited to motion/glitch treatment.
		# glow ring pulse
		if t > 1.0:
			var gk := clampf((t - 1.0) / 0.6, 0.0, 1.0)
			draw_arc(c + Vector2(0, 10), 60.0 + gk * 140.0, 0, TAU, 64, Color(UIStyle.PINK, (1.0 - gk) * 0.5), 3.0)
		# holographic index ring and calibration ticks: a studio mark with
		# physical presence, rather than a flat triangle on black.
		if e > 0.35:
			var ring_alpha := 0.28 + 0.18 * sin(t * 5.0)
			draw_arc(c, r * 1.18, -PI * 0.82, PI * 0.12, 48, Color(UIStyle.CYAN, ring_alpha), 2.0)
			draw_arc(c, r * 1.18, PI * 0.22, PI * 1.16, 48, Color(UIStyle.PINK, ring_alpha), 2.0)
			for tick in 12:
				var ang := TAU * float(tick) / 12.0 + t * 0.18
				var inner := c + Vector2(cos(ang), sin(ang)) * (r * 1.10)
				var outer := c + Vector2(cos(ang), sin(ang)) * (r * 1.16)
				draw_line(inner, outer, Color(UIStyle.GOLD, 0.55), 1.5)
		# wordmark
		var tk := clampf((t - 1.2) / 0.5, 0.0, 1.0)
		if tk > 0.0:
			var f := UIStyle.font_display()
			var word := "INVERTED  INDEX"
			var fs := 44
			var w := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := Vector2(c.x - w * 0.5, c.y + r + 92.0)
			draw_string(f, pos + Vector2(3, 3), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UIStyle.VIOLET, 0.8 * tk))
			draw_string(f, pos, word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UIStyle.PAPER, tk))
			var f2 := UIStyle.font_bold()
			var sub := "S   T   U   D   I   O"
			var w2 := f2.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string(f2, Vector2(c.x - w2 * 0.5, pos.y + 34), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UIStyle.GOLD, tk))
		# scanlines over the mark
		for y in range(int(c.y - 200), int(c.y + 260), 3):
			draw_line(Vector2(c.x - 320, y), Vector2(c.x + 320, y), Color(0, 0, 0, 0.18), 1.0)

	func _logo_glow(bg: Color, border: Color) -> StyleBoxFlat:
		var b := StyleBoxFlat.new()
		b.bg_color = bg
		b.border_color = border
		b.set_border_width_all(2)
		b.set_corner_radius_all(18)
		return b


## Neon underline that grows out from the centre.
class NeonLine extends Control:
	var grow := 0.0
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if grow <= 0.0:
			return
		var mid := size.x * 0.5
		var half := mid * grow
		draw_rect(Rect2(mid - half, 2, half * 2.0, 6), Color(UIStyle.PINK, 0.25))
		draw_rect(Rect2(mid - half, 4, half * 2.0, 2), UIStyle.PINK)
