class_name UIStyle
extends RefCounted
## Shared look: fonts, colours and a generated Theme for the VHS/neon UI.

const PINK := Color("ff3d7f")
const HOT := Color("ff2a4f")
const GOLD := Color("ffd23f")
const CYAN := Color("35e0ff")
const VIOLET := Color("7a2cff")
const INK := Color("0b0614")
const PAPER := Color("f4f0e8")
const DIM := Color("8a7fa0")

static var _theme: Theme
static var _fonts: Dictionary = {}

static func _font(path: String) -> Font:
	if _fonts.has(path):
		return _fonts[path]
	var f: Font = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	_fonts[path] = f
	return f

static func font_mono() -> Font:
	return _font("res://assets/fonts/DejaVuSansMono.ttf")

static func font_bold() -> Font:
	return _font("res://assets/fonts/DejaVuSansMono-Bold.ttf")

static func font_display() -> Font:
	return _font("res://assets/fonts/Poppins-BoldItalic.ttf")

static func font_script() -> Font:
	return _font("res://assets/fonts/Lora-Italic-Variable.ttf")

static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font_mono()
	t.default_font_size = 16
	var clear := StyleBoxEmpty.new()
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0, 0, 0, 0)
	btn_normal.content_margin_left = 10
	btn_normal.content_margin_right = 10
	btn_normal.content_margin_top = 3
	btn_normal.content_margin_bottom = 3
	var btn_focus := btn_normal.duplicate() as StyleBoxFlat
	btn_focus.bg_color = Color(PINK, 0.9)
	btn_focus.skew = Vector2(-0.25, 0)
	var btn_hover := btn_focus.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(PINK, 0.55)
	for s in ["normal", "disabled"]:
		t.set_stylebox(s, "Button", btn_normal)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_focus)
	t.set_stylebox("focus", "Button", btn_focus)
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(DIM, 0.6))
	t.set_font("font", "Button", font_bold())
	t.set_font_size("font_size", "Button", 18)
	t.set_color("font_color", "Label", PAPER)
	t.set_color("font_outline_color", "Label", INK)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.04, 0.02, 0.08, 0.92)
	panel.border_color = Color(PINK, 0.8)
	panel.set_border_width_all(2)
	panel.set_content_margin_all(14)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	# sliders
	var grab := StyleBoxFlat.new()
	grab.bg_color = GOLD
	var track := StyleBoxFlat.new()
	track.bg_color = Color(DIM, 0.4)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = PINK
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var gimg := Image.create(10, 16, false, Image.FORMAT_RGBA8)
	gimg.fill(GOLD)
	t.set_icon("grabber", "HSlider", ImageTexture.create_from_image(gimg))
	var gimg2 := Image.create(10, 16, false, Image.FORMAT_RGBA8)
	gimg2.fill(Color.WHITE)
	t.set_icon("grabber_highlight", "HSlider", ImageTexture.create_from_image(gimg2))
	t.set_stylebox("focus", "HSlider", btn_hover)
	t.set_stylebox("focus", "CheckButton", btn_hover)
	t.set_stylebox("focus", "OptionButton", btn_hover)
	t.set_stylebox("normal", "OptionButton", btn_normal)
	t.set_stylebox("hover", "OptionButton", btn_hover)
	t.set_stylebox("pressed", "OptionButton", btn_hover)
	t.set_color("font_color", "CheckButton", PAPER)
	t.set_color("font_color", "OptionButton", PAPER)
	t.set_stylebox("normal", "CheckButton", btn_normal)
	t.set_stylebox("hover", "CheckButton", btn_hover)
	t.set_stylebox("pressed", "CheckButton", btn_normal)
	t.set_stylebox("hover_pressed", "CheckButton", btn_hover)
	t.set_stylebox("panel", "TabContainer", clear)
	var tab_sel := StyleBoxFlat.new()
	tab_sel.bg_color = PINK
	tab_sel.set_content_margin_all(6)
	var tab_un := StyleBoxFlat.new()
	tab_un.bg_color = Color(0.1, 0.05, 0.16)
	tab_un.set_content_margin_all(6)
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", tab_un)
	t.set_stylebox("tab_hovered", "TabContainer", tab_un)
	t.set_stylebox("tab_focus", "TabContainer", btn_hover)
	t.set_color("font_selected_color", "TabContainer", INK)
	t.set_color("font_unselected_color", "TabContainer", PAPER)
	t.set_font("font", "TabContainer", font_bold())
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PINK, 0.6)
	t.set_stylebox("grabber", "VScrollBar", sb)
	t.set_stylebox("grabber_highlight", "VScrollBar", sb)
	t.set_stylebox("grabber_pressed", "VScrollBar", sb)
	var sbt := StyleBoxFlat.new()
	sbt.bg_color = Color(0.1, 0.05, 0.16, 0.6)
	sbt.content_margin_left = 4
	t.set_stylebox("scroll", "VScrollBar", sbt)
	_theme = t
	return t

static func label(text: String, size := 16, color := PAPER, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_bold() if bold else font_mono())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func title_label(text: String, size := 48, color := PINK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_display())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(VIOLET, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l

## Anchor a control to a preset and place it with offsets relative to that
## anchor (unlike `position`, this stays correct when the screen resizes).
## Menu button feedback: the focused button grows a little from its left
## edge and flashes; quick in both directions so menus stay snappy.
static func menu_fx(b: Button) -> void:
	b.pivot_offset = Vector2(0, 14)
	b.focus_entered.connect(func():
		b.pivot_offset = Vector2(0, b.size.y * 0.5)
		var tw := b.create_tween().set_parallel(true)
		tw.tween_property(b, "scale", Vector2(1.06, 1.06), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		b.modulate = Color(1.6, 1.6, 1.6)
		tw.tween_property(b, "modulate", Color.WHITE, 0.18))
	b.focus_exited.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.08))
	b.mouse_entered.connect(func():
		if not b.disabled:
			b.grab_focus())

## Staggered reveal for a freshly built menu: each item fades in a beat
## after the previous one (total well under a quarter second).
static func reveal(container: Control, step := 0.03) -> void:
	var i := 0
	for c in container.get_children():
		if c is CanvasItem:
			(c as CanvasItem).modulate.a = 0.0
			var tw := (c as Node).create_tween()
			tw.tween_interval(i * step)
			tw.tween_property(c, "modulate:a", 1.0, 0.12)
			i += 1

static func place(c: Control, preset: Control.LayoutPreset, pos: Vector2, sz := Vector2(-1, -1)) -> void:
	if sz.x < 0.0:
		sz = c.size if c.size != Vector2.ZERO else c.get_combined_minimum_size()
	c.set_anchors_preset(preset)
	c.offset_left = pos.x
	c.offset_top = pos.y
	c.offset_right = pos.x + sz.x
	c.offset_bottom = pos.y + sz.y

## Any key, any mouse button, any pad button, a pulled trigger or a pushed
## stick, or a tap. Key repeats don't count (a held key from the splash
## shouldn't fall straight through the title).
static func is_any_press(e: InputEvent) -> bool:
	if e is InputEventKey:
		return e.pressed and not e.echo
	if e is InputEventMouseButton or e is InputEventJoypadButton or e is InputEventScreenTouch:
		return e.is_pressed()
	if e is InputEventJoypadMotion:
		return absf(e.axis_value) > 0.6
	return false
