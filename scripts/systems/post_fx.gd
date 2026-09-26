extends CanvasLayer
## Full-screen VHS/CRT post-processing, screen flashes, fades and the
## optional FPS counter. Reads accessibility settings.

var rect: ColorRect
var fade_rect: ColorRect
var mat: ShaderMaterial
var fps_label: Label
var _tracking := 0.0
var _flash := 0.0
var _flash_color := Color(1, 0.1, 0.3)

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/crt_vhs.gdshader")
	rect.material = mat
	add_child(rect)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.02, 0.01, 0.04, 0.0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	fps_label = Label.new()
	fps_label.position = Vector2(6, 4)
	fps_label.add_theme_color_override("font_color", Color(0.5, 1, 0.6))
	fps_label.add_theme_font_size_override("font_size", 12)
	add_child(fps_label)
	Events.settings_changed.connect(apply_settings)
	apply_settings()

func apply_settings() -> void:
	mat.set_shader_parameter("crt_enabled", SaveManager.get_setting("crt", true))
	mat.set_shader_parameter("chroma", 1.0 if SaveManager.get_setting("chromatic", true) else 0.0)
	mat.set_shader_parameter("brightness", float(SaveManager.get_setting("brightness", 1.0)))
	mat.set_shader_parameter("colorblind", int(SaveManager.get_setting("colorblind", 0)))
	mat.set_shader_parameter("bloom", 0.4 if SaveManager.get_setting("bloom", true) else 0.0)
	mat.set_shader_parameter("cel", 1.0 if SaveManager.get_setting("cel_shading", true) else 0.0)
	fps_label.visible = SaveManager.get_setting("show_fps", false)

func _process(delta: float) -> void:
	_tracking = move_toward(_tracking, 0.0, delta * 1.5)
	mat.set_shader_parameter("tracking", _tracking)
	_flash = move_toward(_flash, 0.0, delta * 3.0)
	var c := _flash_color
	c.a = _flash
	mat.set_shader_parameter("flash_color", c)
	if fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()

func vhs_glitch(amount := 0.8) -> void:
	_tracking = maxf(_tracking, amount)

func flash(color: Color, strength := 0.35) -> void:
	if SaveManager.get_setting("reduced_flashing", false):
		strength *= 0.25
	_flash_color = color
	_flash = maxf(_flash, strength)

func set_desaturate(v: float) -> void:
	mat.set_shader_parameter("desaturate", v)

func set_tint(c: Color) -> void:
	mat.set_shader_parameter("tint", c)

func fade_out(t := 0.3) -> Signal:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, t)
	return tw.finished

func fade_in(t := 0.3) -> Signal:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, t)
	return tw.finished
