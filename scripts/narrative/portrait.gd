class_name Portrait
extends Control
## Animated cel-shaded dialogue portrait inside an animated neon frame.
## Talking: mouth shapes, head bob, brow lift, glowing frame, voice meter.
## Idle: blinking, glances, breathing. Speaker changes glitch the frame.
## Real art can replace it: res://assets/characters/portraits/<id>.png

var speaker := "cass"
var talking := false
var _t := 0.0
var _glitch := 0.0
var _mouth := 0
var _mouth_t := 0.0
var _glance := 0.0
var _glance_t := 2.0
var _talk_amt := 0.0
var _last_speaker := ""

const G := 32.0   # face grid

const STYLES := {
	"cass":    {"skin": "f0b58c", "hair": "6e1f1a", "top": "d4213d", "style": "long", "mark": "star", "eyes": "3a2014", "bg": "2a0a1a", "frame": "ff3d7f"},
	"voice":   {"style": "phone", "bg": "05050a", "frame": "ffd23f"},
	"machine": {"style": "machine", "bg": "0a0a0a", "frame": "8a7fa0"},
	"harcourt":{"skin": "e8b898", "hair": "d8d0c0", "top": "e8dcc0", "style": "slick", "mark": "tie", "eyes": "2a3a50", "bg": "1a0a10", "frame": "e8dcc0"},
	"earl":    {"skin": "e8b090", "hair": "4a3020", "top": "f07ab0", "style": "balding", "mark": "stubble", "eyes": "3a2a1a", "bg": "10141a", "frame": "35e0ff"},
	"tommy":   {"skin": "e0a888", "hair": "3a1a10", "top": "2f4f8f", "style": "short", "mark": "static", "eyes": "2a1a10", "bg": "050508", "frame": "7ad0ff"},
	"anchor":  {"skin": "e6b494", "hair": "c8a060", "top": "203060", "style": "helmet_hair", "mark": "tv", "eyes": "304060", "bg": "101830", "frame": "35e0ff"},
	"guard":   {"skin": "c98f6b", "hair": "1b1410", "top": "1f9e9a", "style": "short", "mark": "", "eyes": "1a1010", "bg": "0a1414", "frame": "1f9e9a"},
	"marv":    {"skin": "e0b090", "hair": "2a2a2a", "top": "7a1030", "style": "slick", "mark": "crown", "eyes": "1a1a2a", "bg": "1a1008", "frame": "ffd23f"},
}

func _ready() -> void:
	custom_minimum_size = Vector2(110, 110)

func glitch() -> void:
	_glitch = 0.35

func _process(delta: float) -> void:
	_t += delta
	if speaker != _last_speaker:
		_last_speaker = speaker
		glitch()
	_glitch = maxf(0.0, _glitch - delta)
	_talk_amt = move_toward(_talk_amt, 1.0 if talking else 0.0, delta * 6.0)
	_mouth_t -= delta
	if _mouth_t <= 0.0:
		_mouth_t = randf_range(0.06, 0.11)
		_mouth = (randi() % 3) if talking else 0
	_glance_t -= delta
	if _glance_t <= 0.0:
		_glance_t = randf_range(1.2, 3.5)
		_glance = [0.0, 0.0, -1.0, 1.0][randi() % 4]
	queue_redraw()

func _c(hexs: String) -> Color:
	return Color.html("#" + hexs)

func _draw() -> void:
	var st: Dictionary = STYLES.get(speaker, STYLES["guard"])
	var frame_col := _c(str(st.get("frame", "ff3d7f")))
	var inset := 6.0
	var inner := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	var s := inner.size.x / G
	var jit := Vector2(randf_range(-3, 3) * _glitch * 3.0, 0) if _glitch > 0.0 else Vector2.ZERO
	var bob := sin(_t * 14.0) * 0.6 * _talk_amt + sin(_t * 1.6) * 0.3
	var o := inner.position + jit
	var px := func(x: float, y: float, w: float, h: float, col: Color) -> void:
		draw_rect(Rect2(o.x + x * s, o.y + y * s, w * s, h * s), col)
	draw_rect(inner, _c(str(st.get("bg", "101010"))))
	# background: diagonal neon stripes
	for i in 6:
		var y0 := fmod(i * 7.0 + _t * 3.0, G)
		px.call(0, y0, G, 1, Color(frame_col, 0.06))
	var style := str(st.get("style", "short"))
	if style == "phone" or style == "machine":
		_draw_device(px, style, frame_col)
	else:
		_draw_face(px, st, bob)
	# CRT scanlines + sweep
	for y in range(0, int(G), 2):
		px.call(0, y, G, 0.35, Color(0, 0, 0, 0.2))
	var sweep := fmod(_t * 12.0, G + 8.0) - 4.0
	px.call(0, sweep, G, 1.5, Color(1, 1, 1, 0.06))
	# ---- animated frame
	var glow := 0.35 + 0.65 * _talk_amt * (0.75 + 0.25 * sin(_t * 18.0))
	for g in 3:
		draw_rect(inner.grow(2.0 + g * 1.5), Color(frame_col, (0.35 - g * 0.1) * glow), false, 1.5)
	draw_rect(inner.grow(1.0), Color(frame_col, 0.9), false, 2.0)
	var br := 10.0 + 3.0 * sin(_t * 5.0) * _talk_amt
	var c1 := inner.grow(4.0 + 2.0 * _talk_amt * sin(_t * 9.0))
	for corner in [c1.position, Vector2(c1.end.x, c1.position.y), c1.end, Vector2(c1.position.x, c1.end.y)]:
		var dx := br if corner.x < inner.get_center().x else -br
		var dy := br if corner.y < inner.get_center().y else -br
		draw_line(corner, corner + Vector2(dx, 0), Color.WHITE.lerp(frame_col, 0.4), 2.0)
		draw_line(corner, corner + Vector2(0, dy), Color.WHITE.lerp(frame_col, 0.4), 2.0)
	# voice meter
	if _talk_amt > 0.05:
		var bars := 9
		var bw := inner.size.x / bars
		for i in bars:
			var hgt := (0.25 + 0.75 * absf(sin(_t * (11.0 + i * 1.7) + i))) * 8.0 * _talk_amt
			draw_rect(Rect2(inner.position.x + i * bw + 1, inner.end.y - hgt - 2, bw - 2, hgt), Color(frame_col, 0.75))
	if _glitch > 0.0:
		for i in 3:
			var gy := randf() * inner.size.y
			draw_rect(Rect2(inner.position + Vector2(0, gy), Vector2(inner.size.x, 2)), Color(frame_col, 0.5 * _glitch / 0.35))

func _draw_device(px: Callable, style: String, col: Color) -> void:
	for i in 60:
		px.call(float(randi() % 32), float(randi() % 32), 1, 1, Color(1, 1, 1, randf() * 0.2))
	if style == "phone":
		var ring := talking and fmod(_t, 0.25) < 0.12
		var lift := 1.0 if ring else 0.0
		px.call(7, 18, 18, 7, Color("b01020"))
		px.call(7, 18, 18, 1, Color("ff4050"))
		px.call(5, 11 - lift, 22, 5, Color("c81e28"))
		px.call(5, 11 - lift, 6, 7, Color("c81e28"))
		px.call(21, 11 - lift, 6, 7, Color("c81e28"))
		px.call(10, 20, 12, 3, Color("300408"))
		for k in 3:
			if talking:
				var r := 2 + k * 2 + fmod(_t * 10.0, 2.0)
				px.call(27 + k, 12 - r * 0.5, 0.8, r, Color(col, 0.8 - k * 0.2))
	else:
		px.call(4, 12, 24, 12, Color("1a1a1e"))
		px.call(4, 12, 24, 1, Color("3a3a42"))
		for k in 2:
			var cx := 10 + k * 12
			px.call(cx - 3, 15, 6, 6, Color("2a2a30"))
			var spin := fmod(_t * (4.0 if talking else 0.5), 2.0)
			px.call(cx - 1 + spin, 17, 1, 2, Color("8a8a90"))
		px.call(15, 13, 2, 1, Color(1, 0.1, 0.1) if fmod(_t, 1.0) < 0.5 else Color(0.3, 0.05, 0.05))

func _draw_face(px: Callable, st: Dictionary, bob: float) -> void:
	var skin := _c(str(st.skin))
	var hair := _c(str(st.hair))
	var top := _c(str(st.top))
	var eyes := _c(str(st.get("eyes", "201010")))
	var ink := Color("0b0710")
	var shade := skin.darkened(0.2)
	var hl := skin.lightened(0.15)
	var style := str(st.style)
	var breathe := sin(_t * 1.8) * 0.4
	var b := bob
	# shoulders / clothes (cel two-tone)
	px.call(3, 25 + breathe, 26, 7, top)
	px.call(3, 25 + breathe, 26, 1, top.lightened(0.25))
	px.call(3, 29 + breathe, 26, 3, top.darkened(0.25))
	px.call(12, 24 + breathe, 8, 3, top.darkened(0.35))
	# neck
	px.call(13, 21 + b * 0.5, 6, 5, shade)
	# head (with ink outline)
	px.call(8, 6 + b, 16, 17, ink)
	px.call(9, 7 + b, 14, 15, skin)
	px.call(9, 7 + b, 3, 15, shade)                 # cel shadow side
	px.call(19, 9 + b, 3, 6, hl)                    # cheek highlight
	px.call(10, 20 + b, 12, 2, shade)               # jaw shadow
	px.call(7, 12 + b, 2, 4, shade)                 # ears
	px.call(23, 12 + b, 2, 4, shade)
	# hair
	match style:
		"long":
			px.call(7, 4 + b, 18, 5, hair)
			px.call(6, 6 + b, 4, 20, hair)
			px.call(22, 6 + b, 4, 18, hair)
			px.call(12, 4 + b, 6, 1, hair.lightened(0.35))
			px.call(7, 8 + b, 1, 12, hair.lightened(0.2))
		"slick":
			px.call(8, 4 + b, 16, 5, hair)
			px.call(8, 5 + b, 2, 7, hair)
			px.call(11, 5 + b, 9, 1, hair.lightened(0.45))
		"balding":
			px.call(8, 8 + b, 2, 6, hair)
			px.call(22, 8 + b, 2, 6, hair)
			px.call(12, 6 + b, 7, 1, hl)
		"helmet_hair":
			px.call(7, 3 + b, 18, 6, hair)
			px.call(6, 6 + b, 3, 10, hair)
			px.call(23, 6 + b, 3, 10, hair)
			px.call(10, 4 + b, 10, 1, hair.lightened(0.4))
		_:
			px.call(8, 4 + b, 16, 5, hair)
			px.call(8, 6 + b, 2, 6, hair)
			px.call(22, 6 + b, 2, 5, hair)
	# brows (lift while talking)
	var lift := 0.8 * _talk_amt * (0.5 + 0.5 * sin(_t * 3.0))
	px.call(11, 11 + b - lift, 4, 1, hair.darkened(0.3))
	px.call(17, 11 + b - lift, 4, 1, hair.darkened(0.3))
	# eyes: whites, iris glancing, blink
	var blink := fmod(_t + 0.7, 3.4) < 0.12
	if blink:
		px.call(11, 13.5 + b, 4, 0.8, ink)
		px.call(17, 13.5 + b, 4, 0.8, ink)
	else:
		px.call(11, 13 + b, 4, 2, Color("f4f0e8"))
		px.call(17, 13 + b, 4, 2, Color("f4f0e8"))
		px.call(12.5 + _glance, 13 + b, 1.5, 2, eyes)
		px.call(18.5 + _glance, 13 + b, 1.5, 2, eyes)
		px.call(11, 12.6 + b, 4, 0.5, ink)
		px.call(17, 12.6 + b, 4, 0.5, ink)
	# nose
	px.call(15, 15 + b, 2, 3, shade)
	px.call(16, 15 + b, 1, 2, hl)
	# mouth shapes
	var mh: float = [0.8, 1.8, 2.8][_mouth]
	px.call(13, 19 + b, 6, mh, Color("3a0810"))
	if _mouth > 0:
		px.call(14, 19 + b, 4, 0.6, Color("f4f0e8"))
	px.call(13, 18.4 + b, 6, 0.5, skin.darkened(0.35))
	match str(st.get("mark", "")):
		"star":
			var g := Color("ffd23f")
			px.call(18, 10 + b, 3, 1, g)
			px.call(19, 9 + b, 1, 3, g)
			px.call(17.5, 11.2 + b, 1, 1, g)
			px.call(20.5, 11.2 + b, 1, 1, g)
		"tie":
			px.call(15, 25 + breathe, 2, 7, Color("7a1030"))
			px.call(14, 24 + breathe, 4, 2, Color("9a2040"))
		"crown":
			px.call(9, 1 + b, 14, 3, Color("ffd23f"))
			for k in 4:
				px.call(9 + k * 4, 0 + b, 2, 1, Color("ffd23f"))
		"stubble":
			for k in 10:
				px.call(10 + (k * 7) % 12, 19 + b + (k % 3), 0.6, 0.6, shade.darkened(0.3))
		"static":
			for i in 40:
				px.call(float(randi() % 32), float(randi() % 32), 1, 1, Color(1, 1, 1, randf() * 0.35))
		"tv":
			px.call(0, 0, 32, 1, Color("c81e28"))
			px.call(0, 30, 32, 2, Color("1a2a6a"))
