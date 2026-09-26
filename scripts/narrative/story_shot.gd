class_name StoryShot
extends Control
## Plays the illustrated story shots (assets/art/shots/<id>/<layer>.png,
## painted by tools/art/gen_shots.py): parallax layers under a slow camera
## move, per-layer animation (blinking LEDs, police lights, the clapper
## snapping shut, breathing, flicker) and drawn effects (rain, embers, smoke,
## dust, tape static). Changing shot cuts with a VHS glitch and a short
## cross-fade. Used by cutscenes, the intro and the chapter covers.

const ART := "res://assets/art/shots/%s/%s.png"
const FRAME := Vector2(480, 270)     ## the visible frame inside each 544x306 layer

## Per shot: layers back to front [name, depth]; camera from/to (zoom, pan
## in frame pixels); anims per layer; fx drawn over it.
const SHOTS := {
	"desert_road":  {"layers": [["bg", 0.2], ["mid", 0.6], ["fg", 1.0]], "cam": [1.0, Vector2(-14, 0), 1.08, Vector2(10, -4)], "fx": ["dust"]},
	"cass_close":   {"layers": [["bg", 0.25], ["fg", 1.0]], "cam": [1.04, Vector2(-8, 4), 1.1, Vector2(6, -2)], "anim": {"fg": "breathe"}, "fx": ["dust"]},
	"tommy_car":    {"layers": [["bg", 0.3], ["mid", 0.7], ["fg", 1.0]], "cam": [1.02, Vector2(8, 0), 1.06, Vector2(-6, 2)], "anim": {"mid": "breathe", "fg": "rumble"}, "fx": []},
	"clapper":      {"layers": [["bg", 0.3], ["fg", 1.0], ["arm", 1.0]], "cam": [1.0, Vector2.ZERO, 1.05, Vector2(0, 4)], "anim": {"arm": "snap"}, "fx": []},
	"explosion":    {"layers": [["bg", 0.2], ["mid", 0.6], ["fg", 1.0]], "cam": [1.12, Vector2(0, -6), 1.02, Vector2.ZERO], "anim": {"mid": "flicker_fire"}, "fx": ["shake", "embers", "flash"]},
	"wreck":        {"layers": [["bg", 0.3], ["mid", 1.0]], "cam": [1.0, Vector2(-10, 0), 1.06, Vector2(6, 0)], "anim": {"mid": "flicker_fire"}, "fx": ["embers", "smoke"]},
	"apartment":    {"layers": [["bg", 0.4], ["mid", 1.0], ["led", 1.0]], "cam": [1.0, Vector2(-10, 0), 1.06, Vector2(10, -2)], "anim": {"led": "blink", "bg": "neon"}, "fx": ["rain_window", "dust"]},
	"machine":      {"layers": [["bg", 0.3], ["mid", 1.0], ["reels", 1.0], ["led", 1.0]], "cam": [1.06, Vector2(0, 2), 1.14, Vector2(-8, 0)], "anim": {"led": "blink", "reels": "wobble"}, "fx": ["dust"]},
	"package":      {"layers": [["bg", 0.5], ["mid", 1.0]], "cam": [1.0, Vector2(-16, 6), 1.12, Vector2(12, -4)], "fx": ["dust"]},
	"mirror":       {"layers": [["bg", 0.4], ["mid", 0.9], ["fg", 1.0]], "cam": [1.02, Vector2(0, -6), 1.12, Vector2(0, 4)], "anim": {"mid": "breathe"}, "fx": ["glint"]},
	"tv_news":      {"layers": [["bg", 0.3], ["mid", 1.0]], "cam": [1.0, Vector2.ZERO, 1.07, Vector2(-6, 0)], "anim": {"mid": "tv"}, "fx": ["scan"]},
	"motel_night":  {"layers": [["bg", 0.2], ["mid", 0.6], ["sign", 0.6], ["fg", 1.0]], "cam": [1.0, Vector2(-12, 0), 1.06, Vector2(10, -2)], "anim": {"sign": "flicker"}, "fx": ["rain"]},
	"motel_crime":  {"layers": [["bg", 0.2], ["mid", 1.0], ["red", 1.0], ["blue", 1.0]], "cam": [1.0, Vector2(10, 0), 1.06, Vector2(-8, 0)], "anim": {"red": "siren_a", "blue": "siren_b"}, "fx": []},
	"marv":         {"layers": [["bg", 0.3], ["mid", 1.0]], "cam": [1.06, Vector2(0, 4), 1.0, Vector2.ZERO], "anim": {"mid": "breathe", "bg": "neon"}, "fx": ["scan"]},
	"polaroid":     {"layers": [["bg", 0.4], ["mid", 1.0]], "cam": [1.0, Vector2(0, 10), 1.14, Vector2(10, -6)], "fx": ["dust"]},
	"salvage_yard": {"layers": [["bg", 0.2], ["mid", 0.6], ["fg", 1.0], ["eyes", 1.0]], "cam": [1.0, Vector2(-10, 0), 1.08, Vector2(8, 0)], "anim": {"eyes": "eyes"}, "fx": ["dust"]},
	"galaxy_palace": {"layers": [["bg", 0.3], ["mid", 1.0]], "cam": [1.0, Vector2(0, 6), 1.08, Vector2(0, -2)], "anim": {"bg": "neon"}, "fx": []},
	"barstow_pd":   {"layers": [["bg", 0.2], ["mid", 1.0], ["red", 1.0]], "cam": [1.0, Vector2(-8, 0), 1.06, Vector2(8, 0)], "anim": {"red": "siren_a"}, "fx": ["rain"]},
	"hills_fire":   {"layers": [["bg", 0.2], ["mid", 0.6], ["fg", 1.0]], "cam": [1.0, Vector2(0, 0), 1.08, Vector2(-8, -4)], "anim": {"mid": "flicker_fire"}, "fx": ["embers", "smoke"]},
	"static":       {"layers": [], "cam": [1.0, Vector2.ZERO, 1.0, Vector2.ZERO], "fx": ["static"]},
}

var shot_id := ""
var shot_time := 9.0         ## seconds the camera takes over its move
var letterbox := true
var _t := 0.0
var _tex: Array = []         ## [[texture, depth, layer name], ...] of the current shot
var _prev: Array = []
var _prev_def: Dictionary = {}
var _prev_t := 0.0
var _fade := 1.0             ## 0..1 cross-fade from the previous shot
var _def: Dictionary = {}
var _bars := 0.0
var _glitch := 0.0
var _flash := 0.0
var _shake := 0.0
var _rng := RandomNumberGenerator.new()
var _embers: Array = []
var _rain: Array = []

static var _cache: Dictionary = {}

static func has_shot(id: String) -> bool:
	return SHOTS.has(id)

static func tex(id: String, layer: String) -> Texture2D:
	var key := id + "/" + layer
	if not _cache.has(key):
		var p := ART % [id, layer]
		_cache[key] = load(p) if ResourceLoader.exists(p) else null
	return _cache[key]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	_rng.seed = 1988
	for i in 90:
		_rain.append(Vector3(_rng.randf(), _rng.randf(), _rng.randf_range(0.6, 1.0)))

## Cut to a shot. `hard` skips the cross-fade (first shot of a scene).
func show_shot(id: String, hard := false) -> void:
	if id == shot_id or not SHOTS.has(id):
		return
	if not hard and shot_id != "":
		_prev = _tex
		_prev_def = _def
		_prev_t = _t
		_fade = 0.0
		_glitch = 1.0
		if is_inside_tree():
			PostFX.vhs_glitch(0.35)
	shot_id = id
	_def = SHOTS[id]
	_t = 0.0
	_tex = []
	for l in _def.get("layers", []):
		var t := tex(id, l[0])
		if t:
			_tex.append([t, float(l[1]), String(l[0])])
	if "shake" in _def.get("fx", []):
		_shake = 1.0
	if "flash" in _def.get("fx", []):
		_flash = 1.0
	_embers.clear()

func _process(delta: float) -> void:
	_t += delta
	_prev_t += delta
	_fade = move_toward(_fade, 1.0, delta / 0.45)
	_bars = move_toward(_bars, 1.0 if letterbox else 0.0, delta * 2.0)
	_glitch = move_toward(_glitch, 0.0, delta * 3.0)
	_flash = move_toward(_flash, 0.0, delta * 1.4)
	_shake = move_toward(_shake, 0.0, delta * 0.7)
	var fx: Array = _def.get("fx", [])
	if "embers" in fx and _embers.size() < 60 and _rng.randf() < 0.6:
		_embers.append({"p": Vector2(_rng.randf_range(0.2, 0.8), _rng.randf_range(0.6, 0.9)), "v": Vector2(_rng.randf_range(-0.02, 0.02), _rng.randf_range(-0.12, -0.05)), "life": _rng.randf_range(1.5, 3.5), "t": 0.0})
	for e in _embers.duplicate():
		e.t += delta
		e.p += e.v * delta
		e.v.x += sin(_t * 3.0 + e.life * 10.0) * 0.004 * delta * 60.0
		if e.t > e.life:
			_embers.erase(e)
	queue_redraw()

## Scale (screen px per art px) so the frame fills the control.
func _base_scale() -> float:
	return maxf(size.x / FRAME.x, size.y / FRAME.y)

func _cam(def: Dictionary, t: float) -> Array:
	var c: Array = def.get("cam", [1.0, Vector2.ZERO, 1.0, Vector2.ZERO])
	var k := clampf(t / shot_time, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	return [lerpf(float(c[0]), float(c[2]), k), (c[1] as Vector2).lerp(c[3] as Vector2, k)]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.0, 0.02))
	if _fade < 1.0 and not _prev.is_empty():
		_draw_layers(_prev, _prev_def, _prev_t, 1.0)
	_draw_layers(_tex, _def, _t, _fade if not _prev.is_empty() else 1.0)
	_draw_fx()
	# letterbox bars (drawn last, over everything but the dialogue)
	var bh := size.y * 0.1 * _bars
	if bh > 0.5:
		draw_rect(Rect2(0, 0, size.x, bh), Color.BLACK)
		draw_rect(Rect2(0, size.y - bh, size.x, bh), Color.BLACK)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.8, 0.5, _flash * 0.6))

func _draw_layers(list: Array, def: Dictionary, t: float, alpha: float) -> void:
	var cam := _cam(def, t)
	var zoom: float = cam[0]
	var pan: Vector2 = cam[1]
	var base := _base_scale()
	var shake := Vector2.ZERO
	if _shake > 0.0 and def == _def:
		shake = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 6.0 * _shake * _shake
	var anims: Dictionary = def.get("anim", {})
	for entry in list:
		var tx: Texture2D = entry[0]
		var depth: float = entry[1]
		var lname: String = entry[2]
		var z := 1.0 + (zoom - 1.0) * (0.4 + 0.6 * depth)
		var sc := base * z
		var tsz := Vector2(tx.get_width(), tx.get_height()) * sc
		var centre := size * 0.5 + (pan * depth) * base + shake * depth
		var pos := centre - tsz * 0.5
		var mod := Color(1, 1, 1, alpha)
		var xform_scale := 1.0
		var rot := 0.0
		var pivot := Vector2.ZERO
		match str(anims.get(lname, "")):
			"blink":
				mod.a *= 1.0 if fmod(t, 1.2) < 0.6 else 0.08
			"flicker":
				mod.a *= 0.25 if (fmod(t, 3.7) < 0.12 or fmod(t, 1.9) < 0.05) else 1.0
			"neon":
				mod = mod * Color(1, 1, 1).lerp(Color(1.08, 0.95, 1.08), 0.5 + 0.5 * sin(t * 7.0) * sin(t * 2.3))
			"flicker_fire":
				var f := 0.9 + 0.1 * sin(t * 17.0) * sin(t * 5.3)
				mod = Color(f, f * 0.97, f * 0.94, mod.a)
			"siren_a":
				mod.a *= clampf(sin(t * 9.0) * 1.5, 0.0, 1.0)
			"siren_b":
				mod.a *= clampf(-sin(t * 9.0) * 1.5, 0.0, 1.0)
			"eyes":
				# red eyes: steady glow, a slow blink now and then
				mod.a *= 0.0 if fmod(t + 0.4, 4.3) < 0.12 else (0.75 + 0.25 * sin(t * 2.0))
			"breathe":
				xform_scale = 1.0 + sin(t * 1.6) * 0.006
				pivot = Vector2(tsz.x * 0.5, tsz.y)
			"rumble":
				pos += Vector2(0, sin(t * 40.0) * 0.6 + sin(t * 13.0) * 0.4)
			"wobble":
				pos += Vector2(0, sin(t * 3.0) * 0.4)
			"tv":
				var fl := 0.94 + 0.06 * sin(t * 50.0)
				mod = Color(fl, fl, fl, mod.a)
			"snap":
				# the clapper stick hangs open, then snaps shut at 0.9s
				var k := clampf((t - 0.9) / 0.08, 0.0, 1.0)
				rot = lerpf(-0.32, 0.0, k)
				if k >= 1.0 and t < 1.05 and is_inside_tree():
					_on_snap()
				pivot = Vector2(tsz.x * 0.3 / 1.0, tsz.y * 0.31)
		if rot != 0.0 or xform_scale != 1.0:
			var xf := Transform2D(rot, pos + pivot) * Transform2D(0.0, Vector2(xform_scale, xform_scale), 0.0, -pivot)
			draw_set_transform_matrix(xf)
			draw_texture_rect(tx, Rect2(Vector2.ZERO, tsz), false, mod)
			draw_set_transform_matrix(Transform2D.IDENTITY)
		else:
			draw_texture_rect(tx, Rect2(pos, tsz), false, mod)

var _snapped_at := -1.0
func _on_snap() -> void:
	if _snapped_at >= 0.0 and _t - _snapped_at < 1.0:
		return
	_snapped_at = _t
	Audio.play("door_slam", -6.0, 1.6)
	_shake = maxf(_shake, 0.35)

func _draw_fx() -> void:
	var fx: Array = _def.get("fx", [])
	var t := _t
	if "rain" in fx or "rain_window" in fx:
		var a := 0.22 if "rain" in fx else 0.1
		for r in _rain:
			var x := fmod(r.x * size.x + t * 50.0, size.x)
			var y := fmod(r.y * size.y + t * 620.0 * r.z, size.y)
			draw_line(Vector2(x, y), Vector2(x - 4, y + 16), Color(0.75, 0.8, 1.0, a), 1.0)
	if "embers" in fx:
		for e in _embers:
			var k: float = 1.0 - e.t / e.life
			var p: Vector2 = e.p * size
			draw_rect(Rect2(p, Vector2(2, 2)), Color(1.0, 0.6 + 0.3 * k, 0.2, k))
	if "smoke" in fx:
		for i in 6:
			var k := fmod(t * 0.05 + i / 6.0, 1.0)
			var c := Vector2(size.x * (0.35 + 0.3 * sin(i * 1.7)), size.y * (0.8 - k * 0.8))
			draw_circle(c, 40.0 + k * 120.0, Color(0.08, 0.04, 0.05, 0.12 * sin(k * PI)))
	if "dust" in fx:
		for i in 26:
			var x := fmod(i * 97.0 + t * (6.0 + i % 5), size.x)
			var y := fmod(i * 53.0 + sin(t * 0.4 + i) * 20.0 + t * 3.0, size.y)
			draw_rect(Rect2(x, y, 2, 2), Color(1, 0.9, 0.8, 0.12 + 0.08 * sin(t * 2.0 + i)))
	if "glint" in fx:
		var g := fmod(t, 3.2)
		if g < 0.5:
			var c := size * Vector2(0.43, 0.42)
			var k := sin(g / 0.5 * PI)
			draw_line(c - Vector2(14, 0) * k, c + Vector2(14, 0) * k, Color(1, 0.95, 0.7, k), 2.0)
			draw_line(c - Vector2(0, 14) * k, c + Vector2(0, 14) * k, Color(1, 0.95, 0.7, k), 2.0)
	if "scan" in fx:
		for i in 12:
			var y := fmod(i * 47.0 + t * 60.0, size.y)
			draw_rect(Rect2(0, y, size.x, 2), Color(1, 1, 1, 0.025))
	if "static" in fx:
		for i in 700:
			var p := Vector2(_rng.randf() * size.x, _rng.randf() * size.y)
			var v := _rng.randf()
			draw_rect(Rect2(p, Vector2(3, 2)), Color(v, v, v, 0.5))
		var ty := fmod(t * 120.0, size.y)
		draw_rect(Rect2(0, ty, size.x, 18), Color(1, 1, 1, 0.08))
	if _glitch > 0.0:
		for i in 6:
			var y := _rng.randf() * size.y
			draw_rect(Rect2(0, y, size.x, _rng.randf_range(2, 10)), Color(1, 1, 1, 0.08 * _glitch))
