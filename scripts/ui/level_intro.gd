class_name LevelIntro
extends CanvasLayer
## The chapter's spotlight as a job begins: a slanted panel slides in from
## the left with the painted VHS box art drifting inside it, the chapter
## number, the title typing itself out in the display face, the place, date
## and time, and a line of what this job is about. The right of the screen
## stays clear so the car can be seen arriving. Holds a few seconds, then
## wipes out; any key sends it on its way sooner.

const INFO := {
	"m01_checkout": ["I", "cover_m01", "Room 204 is waiting. So is the night manager who stood fire watch in 1987 - with an empty extinguisher."],
	"m02_dog_days": ["I-B", "cover_m02", "Forty dogs, an old man with six TVs, and a tape somebody would kill to get back."],
	"m03_prime_time": ["I-C", "cover_m03", "Tonight HOTSHOT CALIFORNIA goes out live. The Fireman is the special guest, and you're the show."],
	"m04_sweet_dreams": ["I-D", "cover_m04", "She counts them before she sleeps. Tonight they're all at the party - and Tommy is the host."],
}
const HOLD := 4.2

var mission: MissionData
var time_text := ""
var _t := 0.0
var _out := -1.0
var _panel: Panel
var _tex: Texture2D

func _ready() -> void:
	add_to_group("level_intro")
	layer = 40
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var info: Array = INFO.get(String(mission.id), ["", "", ""])
	var pixel_path := "res://assets/art/pixellab_ui_v3_approved/covers/%s.png" % info[1]
	var p := pixel_path if ResourceLoader.exists(pixel_path) else "res://assets/art/covers/%s.webp" % info[1]
	_tex = load(p) if ResourceLoader.exists(p) else null
	_panel = Panel.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_panel.draw.connect(_draw_card)
	add_child(_panel)
	Audio.play("tape_insert", -8.0)
	Audio.play("slate_clap", -10.0)

func _input(e: InputEvent) -> void:
	if _out < 0.0 and _t > 0.8 and UIStyle.is_any_press(e) and not (e is InputEventMouseMotion):
		_out = 0.0

func _process(delta: float) -> void:
	_t += delta
	if _out < 0.0 and _t > HOLD:
		_out = 0.0
	if _out >= 0.0:
		_out += delta
		if _out > 0.5:
			queue_free()
	_panel.queue_redraw()

func _draw_card() -> void:
	# a compact lower-third, bottom centre: it never covers the car, the
	# HUD corners or the caller's panel
	var c := _panel
	var vs := c.size
	var info: Array = INFO.get(String(mission.id), ["", "", ""])
	var inn := clampf(_t / 0.4, 0.0, 1.0)
	inn = 1.0 - pow(1.0 - inn, 3.0)
	var outk := clampf(_out / 0.45, 0.0, 1.0) if _out >= 0.0 else 0.0
	var a := inn * (1.0 - outk)
	var w := minf(760.0, vs.x * 0.6)
	var h := 150.0
	var pos := Vector2(vs.x * 0.5 - w * 0.5, vs.y - h - 118.0 + (1.0 - inn) * 30.0 + outk * 30.0)
	var box := Rect2(pos, Vector2(w, h))
	c.draw_rect(box, Color(0.03, 0.0, 0.05, 0.72 * a))
	c.draw_rect(Rect2(box.position, Vector2(w, 3)), Color(UIStyle.PINK, a))
	c.draw_rect(Rect2(Vector2(box.position.x, box.end.y - 2), Vector2(w * (1.0 - clampf(_t / HOLD, 0.0, 1.0)), 2)), Color(UIStyle.CYAN, 0.7 * a))
	# the box art, small, drifting
	var art := Rect2(box.position + Vector2(12, 12), Vector2(84, 126))
	if _tex:
		var tw := float(_tex.get_width())
		var th := float(_tex.get_height())
		var sh := tw * art.size.y / art.size.x
		var drift := (th - sh) * clampf(_t / (HOLD + 0.5), 0.0, 1.0)
		c.draw_texture_rect_region(_tex, art, Rect2(0, drift, tw, sh), Color(1, 1, 1, a))
	c.draw_rect(art, Color(UIStyle.GOLD, 0.9 * a), false, 1.5)
	var fd := UIStyle.font_display()
	var fb := UIStyle.font_bold()
	var fm := UIStyle.font_mono()
	var tx := art.end.x + 18.0
	c.draw_string(fm, Vector2(tx, box.position.y + 30), tr("CHAPTER") + " " + str(info[0]) + "   ·   " + tr(mission.location).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w - 130, 13, Color(UIStyle.CYAN, a))
	var title := tr(mission.title).to_upper()
	var n := clampi(int((_t - 0.25) * 28.0), 0, title.length())
	c.draw_string(fd, Vector2(tx, box.position.y + 68), title.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, w - 130, 36, Color(UIStyle.PINK, a))
	c.draw_string(fm, Vector2(tx, box.position.y + 90), "%s  ·  %s" % [tr(mission.date_text), time_text], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UIStyle.GOLD, 0.9 * a))
	var blurb := tr(str(info[2]))
	var bn := clampi(int((_t - 0.8) * 45.0), 0, blurb.length())
	c.draw_multiline_string(fb, Vector2(tx, box.position.y + 114), blurb.substr(0, bn), HORIZONTAL_ALIGNMENT_LEFT, w - 130, 13, 2, Color(UIStyle.PAPER, 0.9 * a))
