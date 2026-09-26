extends Control
## Launch splash: INVERTED INDEX STUDIO logo, then the "A GAME CREATED BY" card.
## Any key / button / click skips to the title.

const STUDIO_TIME := 3.6
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
var _played_name := false

func _ready() -> void:
	theme = UIStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.0, 0.02)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
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
			if _t > 1.05 and not _played_stamp:
				_played_stamp = true
				Audio.play("rank_stamp", -6.0, 0.8)
				PostFX.vhs_glitch(0.6)
			if _t > STUDIO_TIME - 0.5:
				_studio.modulate.a = clampf((STUDIO_TIME - _t) / 0.5, 0.0, 1.0)
			if _t >= STUDIO_TIME:
				_phase = 1
				_t = 0.0
				PostFX.vhs_glitch(1.0)
				Audio.play("vhs_static", -8.0)
		1:
			_credit.modulate.a = clampf(_t / 0.25, 0.0, 1.0)
			var secs := int(_t * 30.0)
			_osd.text = "PLAY ▶   SP   0:00:%02d:%02d" % [secs / 30, secs % 30]
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
	Game.change_scene(Game.TITLE_SCENE)


## The INVERTED INDEX mark: an inverted triangle built from index bars,
## crowned by an upside-down "i" (¡) - the index turned on its head.
class StudioLogo extends Control:
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5 + Vector2(0, -50)
		var reveal := clampf((t - 0.15) / 0.9, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - reveal, 3.0)
		var r := 92.0
		# outer inverted triangle, drawn stroke by stroke
		var a := c + Vector2(-r, -r * 0.62)
		var b := c + Vector2(r, -r * 0.62)
		var d := c + Vector2(0, r * 0.95)
		var cols := [UIStyle.GOLD, UIStyle.PINK, UIStyle.VIOLET]
		var edges := [[a, b], [b, d], [d, a]]
		for i in 3:
			var k := clampf(e * 3.0 - i, 0.0, 1.0)
			if k <= 0.0:
				continue
			var p0: Vector2 = edges[i][0]
			var p1: Vector2 = p0.lerp(edges[i][1], k)
			# chromatic split while drawing in
			var split := (1.0 - e) * 6.0 + (4.0 if t > 1.0 and t < 1.12 else 0.0)
			draw_line(p0 + Vector2(split, 0), p1 + Vector2(split, 0), Color(1, 0.1, 0.3, 0.5), 5.0)
			draw_line(p0 - Vector2(split, 0), p1 - Vector2(split, 0), Color(0.2, 0.9, 1.0, 0.5), 5.0)
			draw_line(p0, p1, cols[i], 4.0)
		# index bars: descending widths inside the triangle (a sorted index, inverted)
		var bars_k := clampf((t - 0.6) / 0.6, 0.0, 1.0)
		for i in 5:
			var bk := clampf(bars_k * 5.0 - i, 0.0, 1.0)
			if bk <= 0.0:
				continue
			var y := c.y - r * 0.4 + i * 17.0
			var half := (r * 0.78 - i * 15.0) * bk
			var col: Color = UIStyle.PINK.lerp(UIStyle.GOLD, i / 4.0)
			draw_rect(Rect2(c.x - half, y, half * 2.0, 7.0), Color(col, 0.9))
		# the inverted "i": stem above the triangle, dot below the tip
		var ik := clampf((t - 1.0) / 0.25, 0.0, 1.0)
		if ik > 0.0:
			draw_rect(Rect2(c.x - 6, c.y - r * 0.62 - 58.0 * ik, 12, 46.0 * ik), UIStyle.PAPER)
			draw_circle(c + Vector2(0, r * 0.95 + 22.0), 8.0 * ik, UIStyle.PAPER)
		# glow ring pulse
		if t > 1.0:
			var gk := clampf((t - 1.0) / 0.6, 0.0, 1.0)
			draw_arc(c + Vector2(0, 10), 60.0 + gk * 140.0, 0, TAU, 64, Color(UIStyle.PINK, (1.0 - gk) * 0.5), 3.0)
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
