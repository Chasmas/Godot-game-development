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
## Expression for the current line: "", "angry", "shock", "sad", "smirk",
## "smile", "scared". Set per dialogue node ("mood") by the dialogue manager.
var mood := ""
var _mood_k := 0.0              ## eases expressions in instead of snapping
var _shown_mood := ""
var _blink_t := 2.0
var _blinking := 0.0
var _jit := Vector2.ZERO
var _sweat := 0.0

## Temperament per character: how they blink, look around, move while
## talking. Cass is calm and restrained, Earl can't sit still, the anchor
## never takes his eyes off the camera, Harcourt performs.
const TEMPER := {
	"cass":     {"blink": 4.6, "glance": 4.0, "glance_amp": 0.6, "jitter": 0.0, "bob": 0.45, "tilt": 0.02, "lid": 0.15, "smile": 0.0},
	"harcourt": {"blink": 3.2, "glance": 2.2, "glance_amp": 1.0, "jitter": 0.0, "bob": 1.1, "tilt": 0.07, "lid": 0.3, "smile": 0.4},
	"earl":     {"blink": 1.4, "glance": 0.7, "glance_amp": 1.2, "jitter": 0.35, "bob": 0.9, "tilt": 0.04, "lid": 0.0, "smile": -0.3, "sweat": true},
	"anchor":   {"blink": 5.5, "glance": 99.0, "glance_amp": 0.0, "jitter": 0.0, "bob": 0.3, "tilt": 0.0, "lid": 0.0, "smile": 0.8},
	"guard":    {"blink": 3.8, "glance": 3.0, "glance_amp": 0.8, "jitter": 0.0, "bob": 0.5, "tilt": 0.02, "lid": 0.45, "smile": 0.0},
	"tommy":    {"blink": 7.0, "glance": 6.0, "glance_amp": 0.3, "jitter": 0.15, "bob": 0.2, "tilt": 0.03, "lid": 0.3, "smile": 0.0},
	"marv":     {"blink": 3.0, "glance": 1.8, "glance_amp": 1.0, "jitter": 0.0, "bob": 1.3, "tilt": 0.08, "lid": 0.0, "smile": 0.9},
}
const DEFAULT_TEMPER := {"blink": 3.4, "glance": 2.4, "glance_amp": 1.0, "jitter": 0.0, "bob": 0.6, "tilt": 0.03, "lid": 0.1, "smile": 0.0}

func _temper() -> Dictionary:
	return TEMPER.get(speaker, DEFAULT_TEMPER)

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
	var tp := _temper()
	if speaker != _last_speaker:
		_last_speaker = speaker
		glitch()
	_glitch = maxf(0.0, _glitch - delta)
	_talk_amt = move_toward(_talk_amt, 1.0 if talking else 0.0, delta * 6.0)
	# expressions ease in; a new mood briefly passes through neutral
	if mood != _shown_mood:
		_mood_k = move_toward(_mood_k, 0.0, delta * 8.0)
		if _mood_k <= 0.0:
			_shown_mood = mood
	else:
		_mood_k = move_toward(_mood_k, 1.0 if mood != "" else 0.0, delta * 5.0)
	_mouth_t -= delta
	if _mouth_t <= 0.0:
		_mouth_t = randf_range(0.06, 0.11)
		_mouth = (randi() % 3) if talking else 0
	_glance_t -= delta
	if _glance_t <= 0.0:
		var g: float = tp.glance
		_glance_t = randf_range(g * 0.5, g * 1.4)
		var amp: float = tp.glance_amp
		_glance = [0.0, 0.0, -amp, amp][randi() % 4]
	# blinks: per-character rhythm, occasionally a double blink
	_blink_t -= delta
	if _blink_t <= 0.0:
		var b: float = tp.blink
		_blink_t = randf_range(b * 0.6, b * 1.3)
		_blinking = 0.12
		if randf() < 0.15:
			_blink_t = 0.25
	_blinking = maxf(0.0, _blinking - delta)
	var jit: float = tp.jitter
	if jit > 0.0 and randf() < 0.3:
		_jit = Vector2(randf_range(-jit, jit), randf_range(-jit, jit))
	if tp.get("sweat", false) or _shown_mood == "scared":
		_sweat = fmod(_sweat + delta * 0.25, 1.0)
	queue_redraw()

static var _art_cache: Dictionary = {}

func _art(id: String) -> Texture2D:
	if not _art_cache.has(id):
		var pixel_path := "res://assets/art/pixellab_ui_v3_approved/portraits/%s.png" % id
		var path := pixel_path if ResourceLoader.exists(pixel_path) else "res://assets/characters/portraits/%s.png" % id
		_art_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return _art_cache[id]

func _on_a_job() -> bool:
	return is_inside_tree() and get_tree().get_first_node_in_group("level") != null

## The painted frame for this moment, if the speaker has painted art. Cass
## wears the gold star once she's painted it on.
func _art_frame() -> Texture2D:
	var id := speaker
	# she paints it on in the apartment and wears it on every job after -
	# also when a chapter is started straight from the shelf
	if id == "cass" and (bool(SaveManager.get_flag("wore_the_star", false)) or _on_a_job()):
		id = "cass_star"
	var base := _art(id)
	if base == null:
		return null
	if _blinking > 0.0:
		var b := _art(id + "_blink")
		if b:
			return b
	if talking and _mouth > 0:
		var t := _art(id + "_talk")
		if t:
			return t
	return base

func _c(hexs: String) -> Color:
	return Color.html("#" + hexs)

func _draw() -> void:
	var st: Dictionary = STYLES.get(speaker, STYLES["guard"])
	var frame_col := _c(str(st.get("frame", "ff3d7f")))
	var inset := 6.0
	var inner := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	var s := inner.size.x / G
	var jit := Vector2(randf_range(-3, 3) * _glitch * 3.0, 0) if _glitch > 0.0 else Vector2.ZERO
	var tp := _temper()
	var bob := sin(_t * 14.0) * float(tp.bob) * _talk_amt + sin(_t * 1.6) * 0.3
	var o := inner.position + jit
	var px := func(x: float, y: float, w: float, h: float, col: Color) -> void:
		draw_rect(Rect2(o.x + x * s, o.y + y * s, w * s, h * s), col)
	draw_rect(inner, _c(str(st.get("bg", "101010"))))
	# background: diagonal neon stripes
	for i in 6:
		var y0 := fmod(i * 7.0 + _t * 3.0, G)
		px.call(0, y0, G, 1, Color(frame_col, 0.06))
	var style := str(st.get("style", "short"))
	var art := _art_frame()
	if art:
		# painted portrait: rest / talk / blink frames, head bob and tilt
		# while talking, a jolt for shock, a tremor for fear or anger
		var tilt2 := sin(_t * 2.3) * float(tp.tilt) * (0.4 + _talk_amt)
		var sc := 1.0 + (0.04 if _shown_mood == "shock" else 0.0) * _mood_k
		var shake := Vector2.ZERO
		if _shown_mood in ["angry", "scared"]:
			shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 1.2 * _mood_k
		var ctr := inner.get_center() + jit + shake + Vector2(0, -bob * s * 0.6) + _jit * s
		draw_set_transform(ctr, tilt2, Vector2.ONE * sc)
		draw_texture_rect(art, Rect2(-inner.size * 0.5 - Vector2(2, 2), inner.size + Vector2(4, 4)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif style == "phone" or style == "machine":
		_draw_device(px, style, frame_col)
	else:
		# the head tilts a little while talking (more for expressive people),
		# around the neck
		var tilt := sin(_t * 2.3) * float(tp.tilt) * (0.4 + _talk_amt)
		var pivot := o + Vector2(G * 0.5, G * 0.75) * s
		draw_set_transform(pivot + _jit * s, tilt, Vector2.ONE)
		var rel := o - pivot
		var pxr := func(x: float, y: float, w: float, h: float, col: Color) -> void:
			draw_rect(Rect2(rel.x + x * s, rel.y + y * s, w * s, h * s), col)
		_draw_face(pxr, st, bob)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
	var tp := _temper()
	var mk := _mood_k
	var md := _shown_mood
	# brows: lift while talking; moods angle them (inner end is x=14/18)
	var lift := 0.8 * _talk_amt * (0.5 + 0.5 * sin(_t * 3.0))
	if speaker == "harcourt":
		lift += 0.6   # one eyebrow permanently up (see below)
	var brow := hair.darkened(0.3)
	var in_dy := 0.0     # inner ends
	var out_dy := 0.0    # outer ends
	match md:
		"angry":
			in_dy = 1.2 * mk
			out_dy = -0.4 * mk
		"sad", "scared":
			in_dy = -1.0 * mk
			out_dy = 0.6 * mk
		"shock":
			in_dy = -1.2 * mk
			out_dy = -1.2 * mk
	px.call(11, 11 + b - lift + out_dy, 2, 1, brow)
	px.call(13, 11 + b - lift + in_dy, 2, 1, brow)
	var right_lift := 0.8 if speaker == "harcourt" else 0.0
	px.call(17, 11 + b - lift + in_dy - right_lift * 0.5, 2, 1, brow)
	px.call(19, 11 + b - lift + out_dy - right_lift, 2, 1, brow)
	# eyes: whites, iris glancing, blink, lids (bored / sleepy / smug)
	var eye_h := 2.0 + (0.8 * mk if md in ["shock", "scared"] else 0.0)
	var lid := float(tp.lid) * (1.0 - (mk if md in ["shock", "scared"] else 0.0))
	if md == "angry":
		lid = maxf(lid, 0.35 * mk)
	if _blinking > 0.0:
		px.call(11, 13.5 + b, 4, 0.8, ink)
		px.call(17, 13.5 + b, 4, 0.8, ink)
	else:
		var ey := 13.0 + b - (eye_h - 2.0) * 0.5
		px.call(11, ey, 4, eye_h, Color("f4f0e8"))
		px.call(17, ey, 4, eye_h, Color("f4f0e8"))
		var iris := 1.2 if md in ["shock", "scared"] else 1.5
		px.call(12.5 + _glance, ey + (eye_h - 2.0) * 0.5, iris, 2, eyes)
		px.call(18.5 + _glance, ey + (eye_h - 2.0) * 0.5, iris, 2, eyes)
		# glint
		px.call(12.6 + _glance, ey + 0.2, 0.5, 0.5, Color(1, 1, 1, 0.9))
		px.call(18.6 + _glance, ey + 0.2, 0.5, 0.5, Color(1, 1, 1, 0.9))
		px.call(11, ey - 0.4, 4, 0.5 + lid * 1.2, ink if lid < 0.05 else skin.darkened(0.25))
		px.call(17, ey - 0.4, 4, 0.5 + lid * 1.2, ink if lid < 0.05 else skin.darkened(0.25))
		px.call(11, ey - 0.4, 4, 0.4, ink)
		px.call(17, ey - 0.4, 4, 0.4, ink)
	# nose
	px.call(15, 15 + b, 2, 3, shade)
	px.call(16, 15 + b, 1, 2, hl)
	# mouth shapes (+ resting curve from temperament / mood)
	var mh: float = [0.8, 1.8, 2.8][_mouth]
	var smile := float(tp.smile)
	match md:
		"smile": smile = lerpf(smile, 1.0, mk)
		"smirk": smile = lerpf(smile, 0.6, mk)
		"angry", "sad": smile = lerpf(smile, -0.9, mk)
		"scared": smile = lerpf(smile, -0.5, mk)
	if md == "shock" and mk > 0.5 and _mouth == 0:
		mh = 2.4   # jaw drops
	px.call(13, 19 + b, 6, mh, Color("3a0810"))
	if _mouth > 0:
		px.call(14, 19 + b, 4, 0.6, Color("f4f0e8"))
	px.call(13, 18.4 + b, 6, 0.5, skin.darkened(0.35))
	# mouth corners: up for a smile, down for a frown; a smirk only lifts one
	if absf(smile) > 0.15:
		var cy := 19.0 + b - signf(smile) * 0.8 * absf(smile)
		var corner := Color("3a0810") if _mouth == 0 else skin.darkened(0.35)
		if md != "smirk":
			px.call(12.2, cy, 1, 0.7, corner)
		px.call(18.8, cy - (0.4 if md == "smirk" else 0.0), 1, 0.7, corner)
	# nervous sweat bead running down the temple
	if _sweat > 0.0 and (tp.get("sweat", false) or md == "scared"):
		px.call(22.5, 9 + b + _sweat * 8.0, 1, 1.4, Color(0.75, 0.9, 1.0, 0.85 * (1.0 - _sweat)))
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
