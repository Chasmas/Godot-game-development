class_name VcrScreen
extends Control
## PLAY VIDEOTAPE: the tapes and photos Cass has found, on a shelf by
## chapter, next to an old CRT and a top-loading VCR. Pick a tape: it
## slides off the shelf into the deck (clunk), the TV warms up out of a
## white line into snow, and the footage plays - painted, animated frames
## with the deck's on-screen display, tracking noise on every cut and the
## tape's words typed along the bottom. Photos come up on the screen as
## stills. Tapes you haven't found are blank spines.
## Second shelf (left / right): the POSTER COLLECTION - every movie poster
## you've stopped to read on a wall, hung big in a lit frame.

signal closed

## id -> chapter, label, spine colour, frames, lines (one per frame, in order)
const TAPES := [
	{"id": "tape_roll7", "ch": "I", "label": "HOTSHOT - CAM B / ROLL 7", "col": Color("d8342f"),
		"frames": ["vhs_roll7_a", "vhs_roll7_b", "vhs_roll7_c"],
		"lines": ["Unedited stunt footage, 1987. The Cadillac goes up on the desert road. Nobody runs for an extinguisher.",
			"Cass walks out of frame, coughing, reaching back. Tommy is still inside the car.",
			"A hand comes up in front of the lens. A voice behind the camera: \"Don't cut. Aurelio wants the whole take.\""]},
	{"id": "tape_vance", "ch": "I-B", "label": "HOTSHOT - STUNT REHEARSAL", "col": Color("e0a020"),
		"frames": ["vhs_vance_a", "vhs_vance_b", "vhs_vance_c"],
		"lines": ["Arlo Vance walks a young man to the edge of a rooftop. \"Don't think about the ground, Tommy.\" Tommy laughs.",
			"The camera leans over the edge. Where the crash pad should be, there's concrete.",
			"Off camera, a voice you know: \"Keep rolling. He doesn't need to know the pad's not there.\""]},
	{"id": "tape_pilot", "ch": "I-C", "label": "HOTSHOT CALIFORNIA - PILOT", "col": Color("ff3d9a"),
		"frames": ["vhs_pilot_a", "vhs_pilot_b", "vhs_pilot_c"],
		"lines": ["The Sunset Palms from four angles, cut together. A laugh track where the gunshots are.",
			"Your face in a doorway, looking straight up at a camera you never saw.",
			"A title card: NEXT WEEK - THE DOGS. It's dated a week before you ever went to Yermo."]},
	{"id": "tape_dream", "ch": "I-D", "label": "WRAP PARTY - 1987", "col": Color("7a5cff"),
		"frames": ["vhs_dream_a", "vhs_dream_b", "vhs_dream_c"],
		"lines": ["The crew party the night after the fire. Everyone's drinking. On the TV in the corner, the stunt footage.",
			"When the car goes up, the room cheers. One woman doesn't. She has her hand over her mouth.",
			"The camera finds the Director for half a second. He's clapping with his whole body. This tape was never made. You're dreaming it."]},
]
const PHOTOS := [
	{"id": "photo_harcourt", "ch": "I", "label": "WRAP PARTY POLAROID", "shot": "ev_photo_harcourt"},
	{"id": "photo_kennel", "ch": "I-B", "label": "EMPLOYEE OF THE MONTH", "shot": "ev_photo_kennel"},
	{"id": "photo_casting", "ch": "I-C", "label": "CASTING - 1990 / 91", "shot": "ev_photo_casting"},
	{"id": "photo_nursery", "ch": "I-D", "label": "TWO KIDS ON A CAR HOOD", "shot": "ev_photo_nursery"},
]
const CHAPTERS := [["I", "CHECKOUT TIME"], ["I-B", "DOG DAYS"], ["I-C", "PRIME TIME"], ["I-D", "SWEET DREAMS"]]

var _items: Array = []        ## flattened shelf: {kind, def, found, rect}
var _sel := 0
var _t := 0.0
var _state := "idle"          ## idle | insert | warm | play | stop
var _st := 0.0                ## time in state
var _frame := 0
var _typed := 0.0
var _playing: Dictionary = {}
var _fly_from := Rect2()
var _shot: StoryShot
var _tv := Rect2()
var _deck := Rect2()
var _glitch := 0.0
var _hiss: AudioStreamPlayer
var _over: Control
var _tab := "tapes"           ## tapes | posters
var _psel := 0
var _prects: Array = []

func _poster_ids() -> Array:
	return WallArt.POSTER_DEFS.keys()

func _poster_found(id: String) -> bool:
	return id in SaveManager.data.get("posters", [])

func _switch_tab(t: String) -> void:
	if t == _tab or _state != "idle":
		return
	_tab = t
	Audio.play("tape_slide", -8.0, 1.2)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var found: Array = SaveManager.data.get("collectibles", [])
	for ch in CHAPTERS:
		for t in TAPES:
			if t.ch == ch[0]:
				_items.append({"kind": "tape", "def": t, "found": t.id in found})
		for p in PHOTOS:
			if p.ch == ch[0]:
				_items.append({"kind": "photo", "def": p, "found": p.id in found})
	_shot = StoryShot.new()
	_shot.letterbox = false
	_shot.visible = false
	_shot.clip_contents = true
	add_child(_shot)
	# what the deck prints over the picture (OSD, noise, the words, glass)
	# has to draw above the StoryShot, so it's its own layer on top
	_over = Control.new()
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_over)
	add_child(_over)
	_layout()
	resized.connect(_layout)
	Audio.play("tape_slide", -6.0)

func _layout() -> void:
	var vs := size
	_tv = Rect2(vs.x * 0.44, vs.y * 0.12, vs.x * 0.5, vs.x * 0.5 * 0.62)
	_deck = Rect2(_tv.position.x + _tv.size.x * 0.12, _tv.end.y + 34.0, _tv.size.x * 0.76, 54.0)
	var scr := _tv.grow(-18.0)
	_shot.position = scr.position
	_shot.size = scr.size

func _input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var handled := true
	if e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause"):
		if _state in ["play", "warm", "insert"]:
			_eject()
		else:
			_close()
	elif _state == "idle" and (e.is_action_pressed("ui_left") or e.is_action_pressed("move_left")):
		_switch_tab("tapes")
	elif _state == "idle" and (e.is_action_pressed("ui_right") or e.is_action_pressed("move_right")):
		_switch_tab("posters")
	elif _tab == "posters" and _state == "idle" and (e.is_action_pressed("ui_down") or e.is_action_pressed("move_down")):
		_psel = posmod(_psel + 1, _poster_ids().size())
		Audio.play("ui_move", -10.0)
	elif _tab == "posters" and _state == "idle" and (e.is_action_pressed("ui_up") or e.is_action_pressed("move_up")):
		_psel = posmod(_psel - 1, _poster_ids().size())
		Audio.play("ui_move", -10.0)
	elif _tab == "posters" and e.is_action_pressed("ui_accept"):
		pass
	elif _tab == "posters" and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i in _prects.size():
			if (_prects[i] as Rect2).has_point(e.position):
				_psel = i
				Audio.play("ui_move", -10.0)
		_click_tabs(e.position)
	elif _tab == "posters" and e is InputEventMouseMotion:
		for i in _prects.size():
			if (_prects[i] as Rect2).has_point(e.position) and i != _psel:
				_psel = i
				Audio.play("ui_move", -12.0)
		handled = false
	elif _state == "idle" and (e.is_action_pressed("ui_down") or e.is_action_pressed("move_down")):
		_move(1)
	elif _state == "idle" and (e.is_action_pressed("ui_up") or e.is_action_pressed("move_up")):
		_move(-1)
	elif e.is_action_pressed("ui_accept"):
		if _state == "idle":
			_play_selected()
		elif _state == "play":
			_next_frame()
	elif e is InputEventMouseMotion and _state == "idle":
		for i in _items.size():
			var r: Rect2 = _items[i].get("rect", Rect2())
			if r.has_point(e.position) and i != _sel:
				_sel = i
				Audio.play("ui_move", -12.0)
		handled = false
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if _state == "idle":
			_click_tabs(e.position)
			for i in _items.size():
				var r: Rect2 = _items[i].get("rect", Rect2())
				if r.has_point(e.position):
					_sel = i
					_play_selected()
		elif _state == "play":
			_next_frame()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()

var _tab_rects := {}
func _click_tabs(p: Vector2) -> void:
	for t in _tab_rects.keys():
		if (_tab_rects[t] as Rect2).has_point(p):
			_switch_tab(t)

func _move(d: int) -> void:
	_sel = posmod(_sel + d, _items.size())
	Audio.play("tape_slide", -10.0, randf_range(0.95, 1.1))

func _play_selected() -> void:
	var it: Dictionary = _items[_sel]
	if not it.found:
		Audio.play("empty", -4.0)
		return
	_playing = it
	_fly_from = it.get("rect", Rect2())
	_frame = 0
	_typed = 0.0
	_state = "insert"
	_st = 0.0
	Audio.play("ui_select", -6.0)

func _eject() -> void:
	_state = "stop"
	_st = 0.0
	_shot.visible = false
	Audio.play("tape_rewind", -8.0)
	if _hiss:
		_hiss.queue_free()
		_hiss = null

func _close() -> void:
	Audio.play("ui_back")
	closed.emit()
	queue_free()

func _lines() -> Array:
	if _playing.is_empty():
		return []
	return _playing.def.lines if _playing.kind == "tape" else [tr(_photo_text(_playing.def.id))]

func _photo_text(id: String) -> String:
	for f in ["m01_sunset_palms", "m02_yermo_salvage", "m03_khsc_studios", "m04_villa_estrella"]:
		var fa := FileAccess.open("res://levels/%s.json" % f, FileAccess.READ)
		if fa == null:
			continue
		var d = JSON.parse_string(fa.get_as_text())
		if d is Dictionary:
			for c in d.get("collectibles", {}).values():
				if str(c.get("id", "")) == id:
					return str(c.get("text", ""))
	return ""

func _frames() -> Array:
	if _playing.is_empty():
		return []
	return _playing.def.frames if _playing.kind == "tape" else [_playing.def.shot]

func _next_frame() -> void:
	var lines := _lines()
	var line := tr(str(lines[mini(_frame, lines.size() - 1)]))
	if _typed < line.length():
		_typed = line.length()
		return
	_frame += 1
	_typed = 0.0
	if _frame >= _frames().size():
		_eject()
		return
	_glitch = 1.0
	_shot.show_shot(str(_frames()[_frame]))
	Audio.play("vhs_static", -16.0, 1.3)

func _process(delta: float) -> void:
	_t += delta
	_st += delta
	_glitch = maxf(0.0, _glitch - delta * 2.5)
	match _state:
		"insert":
			if _st > 0.55:
				_state = "warm"
				_st = 0.0
				Audio.play("tape_insert", -2.0)
		"warm":
			if _st > 0.9:
				_state = "play"
				_st = 0.0
				_shot.visible = true
				_shot.show_shot(str(_frames()[0]), true)
				_glitch = 1.0
				var src := Audio.get_stream("tv_hum") as AudioStreamWAV
				if src:
					var s2 := src.duplicate() as AudioStreamWAV
					s2.loop_mode = AudioStreamWAV.LOOP_FORWARD
					s2.loop_end = s2.data.size() / 2
					_hiss = AudioStreamPlayer.new()
					_hiss.stream = s2
					_hiss.volume_db = -18.0
					add_child(_hiss)
					_hiss.play()
		"play":
			var lines := _lines()
			var line := tr(str(lines[mini(_frame, lines.size() - 1)]))
			var before := int(_typed)
			_typed = minf(_typed + delta * 34.0, line.length())
			if int(_typed) > before and int(_typed) % 3 == 0:
				Audio.play("type_clack", -22.0, randf_range(0.9, 1.1))
			# hold each frame a while after its line is out, then cut
			if _typed >= line.length() and _st > line.length() / 34.0 + 3.2:
				_st = 0.0
				_next_frame()
		"stop":
			if _st > 0.6:
				_state = "idle"
				_playing = {}
	queue_redraw()
	if _over:
		_over.queue_redraw()

func _draw_over() -> void:
	var fb := UIStyle.font_bold()
	var fm := UIStyle.font_mono()
	var scr := _tv.grow(-18.0)
	var on := _state in ["warm", "play"]
	var c := _over
	if _tab == "posters":
		return
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if on and _state == "play":
		# the deck's on-screen display, the tracking noise, the words
		var secs := int(_st)
		c.draw_string(fm, scr.position + Vector2(18, 30), "PLAY ▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.9))
		c.draw_string(fm, scr.position + Vector2(scr.size.x - 150, 30), "SP  0:%02d:%02d" % [_frame, secs], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.8))
		if _glitch > 0.0:
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = int(_t * 50.0)
			for i3 in 10:
				c.draw_rect(Rect2(scr.position.x, scr.position.y + rng2.randf() * scr.size.y, scr.size.x, rng2.randf_range(2, 10)), Color(1, 1, 1, 0.25 * _glitch))
		var lines := _lines()
		var line := tr(str(lines[mini(_frame, lines.size() - 1)]))
		var shown := line.substr(0, int(_typed))
		var box := Rect2(scr.position + Vector2(12, scr.size.y - 74), Vector2(scr.size.x - 24, 62))
		c.draw_rect(box, Color(0, 0, 0, 0.6))
		c.draw_multiline_string(fb, box.position + Vector2(10, 22), shown, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 20, 15, 3, Color(1, 0.95, 0.85))
	# scanlines and glass
	for yy in range(int(scr.position.y), int(scr.end.y), 3):
		c.draw_line(Vector2(scr.position.x, yy), Vector2(scr.end.x, yy), Color(0, 0, 0, 0.18), 1.0)
	c.draw_rect(scr, Color(0.3, 0.5, 0.6, 0.05), false, 6.0)

func _draw() -> void:
	var vs := size
	var fd := UIStyle.font_display()
	var fb := UIStyle.font_bold()
	var fm := UIStyle.font_mono()
	# the room: dark wallpaper, a neon strip bleeding in from the window
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.04, 0.02, 0.06))
	for i in 12:
		draw_rect(Rect2(0, vs.y * i / 12.0, vs.x, 2), Color(1, 0.3, 0.6, 0.015))
	draw_rect(Rect2(vs.x * 0.36, 0, 6, vs.y), Color(1.0, 0.25, 0.6, 0.06 + 0.02 * sin(_t * 2.0)))
	draw_string(fd, Vector2(40, 60), tr("PLAY VIDEOTAPE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 38, UIStyle.PINK)
	# the two shelves, as tabs
	var tx := 42.0
	for t in [["tapes", tr("TAPES & PHOTOS")], ["posters", tr("POSTER COLLECTION")]]:
		var tw := fb.get_string_size(t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var tr2 := Rect2(tx - 6, 70, tw + 12, 22)
		_tab_rects[t[0]] = tr2
		var act: bool = _tab == t[0]
		if act:
			draw_rect(tr2, Color(UIStyle.PINK, 0.18))
			draw_rect(Rect2(tr2.position.x, tr2.end.y - 2, tr2.size.x, 2), UIStyle.PINK)
		draw_string(fb, Vector2(tx, 86), t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.PAPER if act else UIStyle.DIM)
		tx += tw + 28.0
	draw_string(fm, Vector2(tx + 6, 86), "◀ ▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.DIM)
	if _tab == "posters":
		_draw_posters()
		return
	var got := _items.filter(func(it): return it.found).size()
	draw_string(fm, Vector2(42, 112), tr("%d OF %d FOUND") % [got, _items.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.DIM)
	# the shelf, by chapter: tapes as spines, photos as little polaroids
	var y := 132.0
	var x0 := 40.0
	var w := vs.x * 0.34
	var last_ch := ""
	for i in _items.size():
		var it: Dictionary = _items[i]
		var def: Dictionary = it.def
		if def.ch != last_ch:
			last_ch = def.ch
			var title := ""
			for c in CHAPTERS:
				if c[0] == def.ch:
					title = c[1]
			y += 8.0
			draw_string(fb, Vector2(x0, y + 12), tr("CH.") + " %s  -  %s" % [def.ch, tr(title)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.GOLD)
			draw_line(Vector2(x0, y + 18), Vector2(x0 + w, y + 18), Color(0.5, 0.3, 0.2, 0.8), 2.0)
			y += 24.0
		var focus := i == _sel and _state == "idle"
		var off := 14.0 if focus else 0.0
		var r := Rect2(Vector2(x0 + off, y), Vector2(w - 20.0, 30.0))
		it.rect = r
		var flying: bool = _state == "insert" and it == _playing
		if flying:
			# the tape leaves the shelf and flies to the slot
			var k := clampf(_st / 0.55, 0.0, 1.0)
			var slot := Rect2(_deck.get_center() - Vector2(60, 8), Vector2(120, 16))
			var e := k * k * (3.0 - 2.0 * k)
			r = Rect2(r.position.lerp(slot.position, e), r.size.lerp(slot.size, e))
		if it.kind == "tape":
			var col: Color = def.col if it.found else Color(0.18, 0.16, 0.2)
			draw_rect(r, Color(0.06, 0.05, 0.07))
			draw_rect(Rect2(r.position + Vector2(8, 5), Vector2(r.size.x - 16, r.size.y - 10)), col.darkened(0.2) if it.found else col)
			if it.found:
				draw_string(fb, r.position + Vector2(14, 20), tr(str(def.label)), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28, 12, Color(0.05, 0.03, 0.05))
			else:
				draw_string(fb, r.position + Vector2(14, 20), "? ? ?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.DIM)
		else:
			draw_rect(Rect2(r.position + Vector2(10, 2), Vector2(26, 26)), Color(0.92, 0.9, 0.84) if it.found else Color(0.2, 0.18, 0.22))
			draw_rect(Rect2(r.position + Vector2(13, 5), Vector2(20, 16)), Color(0.35, 0.25, 0.3) if it.found else Color(0.1, 0.08, 0.12))
			draw_string(fb, r.position + Vector2(46, 20), tr(str(def.label)) if it.found else tr("MISSING PHOTO"), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 56, 12, UIStyle.PAPER if it.found else UIStyle.DIM)
		if focus:
			draw_rect(r.grow(3), Color(UIStyle.PINK, 0.7 + 0.3 * sin(_t * 5.0)), false, 2.0)
		y += 36.0
	# the TV
	draw_rect(_tv.grow(10), Color(0.09, 0.07, 0.08))
	draw_rect(_tv, Color(0.14, 0.12, 0.13))
	var scr := _tv.grow(-18.0)
	var on := _state in ["warm", "play"]
	if not on:
		draw_rect(scr, Color(0.03, 0.04, 0.05))
		draw_line(scr.position + Vector2(scr.size.x * 0.1, 10), scr.position + Vector2(scr.size.x * 0.4, 30), Color(1, 1, 1, 0.05), 8.0)
	elif _state == "warm":
		# a white line opens out into snow
		var k := clampf(_st / 0.3, 0.0, 1.0)
		draw_rect(scr, Color(0.02, 0.02, 0.03))
		var hh := scr.size.y * k
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_t * 30.0)
		var band := Rect2(scr.position.x, scr.get_center().y - hh * 0.5, scr.size.x, maxf(hh, 2.0))
		if k < 1.0:
			draw_rect(band, Color(1, 1, 1, 0.9))
		else:
			for i2 in 180:
				draw_rect(Rect2(band.position + Vector2(rng.randf() * band.size.x, rng.randf() * band.size.y), Vector2(rng.randf_range(2, 8), 2)), Color(1, 1, 1, rng.randf_range(0.2, 0.8)))
	# the VCR
	draw_rect(_deck, Color(0.12, 0.11, 0.13))
	draw_rect(_deck, Color(0.3, 0.28, 0.32), false, 1.0)
	var slot := Rect2(_deck.get_center() - Vector2(66, 12), Vector2(132, 10))
	draw_rect(slot, Color(0.02, 0.02, 0.03))
	var led := "12:00"
	if _state == "play" or _state == "warm":
		led = "PLAY"
	elif _state == "insert":
		led = "LOAD"
	elif _state == "stop":
		led = "EJECT"
	var blink := led != "12:00" or fmod(_t, 1.0) < 0.6
	if blink:
		draw_string(fm, Vector2(_deck.end.x - 86, _deck.position.y + 38), led, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.3, 1.0, 0.5))
	draw_circle(Vector2(_deck.position.x + 22, _deck.position.y + 32), 4.0, Color(1.0, 0.2, 0.15) if _state == "play" else Color(0.3, 0.1, 0.1))
	# how to use it
	var hint := tr("ENTER  PLAY     ESC  BACK") if _state == "idle" else tr("ENTER  NEXT     ESC  EJECT")
	draw_string(fb, Vector2(0, vs.y - 30), hint, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 14, Color(1, 1, 1, 0.55))
	if got == 0:
		draw_string(fb, Vector2(_tv.position.x, _deck.end.y + 40), tr("Tapes and photos are hidden in every job. Find them and they'll be waiting here."), HORIZONTAL_ALIGNMENT_LEFT, _tv.size.x, 14, UIStyle.DIM)


## The poster collection: the list on the left (a thumbnail and a title per
## poster, blanks for the ones still out on some wall), and the focused one
## hung big on the right in a lit frame, with its tagline.
func _draw_posters() -> void:
	var vs := size
	var fd := UIStyle.font_display()
	var fb := UIStyle.font_bold()
	var fm := UIStyle.font_mono()
	var ids := _poster_ids()
	var got := ids.filter(func(i): return _poster_found(i)).size()
	draw_string(fm, Vector2(42, 112), tr("%d OF %d FOUND") % [got, ids.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.DIM)
	_prects.clear()
	var x0 := 40.0
	var w := vs.x * 0.34
	var rowh := minf(46.0, (vs.y - 190.0) / ids.size())
	var y := 128.0
	for i in ids.size():
		var id: String = ids[i]
		var found := _poster_found(id)
		var d: Array = WallArt.POSTER_DEFS[id]
		var focus := i == _psel
		var r := Rect2(Vector2(x0 + (12.0 if focus else 0.0), y), Vector2(w - 20.0, rowh - 6.0))
		_prects.append(r)
		draw_rect(r, Color(0.08, 0.06, 0.1) if found else Color(0.05, 0.04, 0.06))
		var th := Rect2(r.position + Vector2(4, 3), Vector2((r.size.y - 6.0) * 0.72, r.size.y - 6.0))
		var tex := StoryShot.painted_tex("poster_" + id) if found else null
		if tex:
			var pw := float(tex.get_width())
			var ph := float(tex.get_height())
			var sw := ph * th.size.x / th.size.y
			draw_texture_rect_region(tex, th, Rect2((pw - sw) * 0.5, 0, sw, ph))
		else:
			draw_rect(th, Color(0.14, 0.12, 0.16))
			draw_string(fb, th.position + Vector2(0, th.size.y * 0.66), "?", HORIZONTAL_ALIGNMENT_CENTER, th.size.x, 14, UIStyle.DIM)
		draw_string(fb, Vector2(th.end.x + 10, r.position.y + r.size.y * 0.62), str(d[0]) if found else "? ? ?", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - th.size.x - 20, 13, UIStyle.PAPER if found else UIStyle.DIM)
		if focus:
			draw_rect(r.grow(3), Color(UIStyle.PINK, 0.7 + 0.3 * sin(_t * 5.0)), false, 2.0)
		y += rowh
	# the big frame on the right
	var id2: String = ids[_psel]
	var d2: Array = WallArt.POSTER_DEFS[id2]
	var found2 := _poster_found(id2)
	var fh := vs.y * 0.66
	var fr := Rect2(Vector2(vs.x * 0.69 - fh * 0.36, vs.y * 0.12), Vector2(fh * 0.72, fh))
	# a picture light over it and its glow on the wallpaper
	draw_circle(fr.get_center(), fr.size.y * 0.62, Color(1.0, 0.85, 0.6, 0.035))
	draw_rect(Rect2(fr.get_center().x - 40, fr.position.y - 22, 80, 8), Color(0.55, 0.45, 0.25))
	draw_rect(fr.grow(14), Color(0.03, 0.02, 0.03))
	draw_rect(fr.grow(10), Color(0.12, 0.1, 0.12))
	draw_rect(fr.grow(10), Color(0.4, 0.34, 0.3), false, 1.5)
	var tex2 := StoryShot.painted_tex("poster_" + id2) if found2 else null
	if tex2:
		var pw2 := float(tex2.get_width())
		var ph2 := float(tex2.get_height())
		var sw2 := ph2 * fr.size.x / fr.size.y
		draw_texture_rect_region(tex2, fr, Rect2((pw2 - sw2) * 0.5, 0, sw2, ph2))
		# glass glare
		draw_colored_polygon(PackedVector2Array([fr.position + Vector2(fr.size.x * 0.1, 0), fr.position + Vector2(fr.size.x * 0.3, 0), fr.position + Vector2(fr.size.x * 0.05, fr.size.y * 0.4), fr.position + Vector2(0, fr.size.y * 0.4), fr.position + Vector2(0, fr.size.y * 0.25)]), Color(1, 1, 1, 0.05))
	else:
		draw_rect(fr, Color(0.06, 0.05, 0.07))
		draw_string(fd, Vector2(fr.position.x, fr.get_center().y), "?", HORIZONTAL_ALIGNMENT_CENTER, fr.size.x, 90, Color(1, 1, 1, 0.08))
	var cy := fr.end.y + 44.0
	draw_string(fd, Vector2(fr.position.x - 80, cy), str(d2[0]) if found2 else tr("NOT FOUND YET"), HORIZONTAL_ALIGNMENT_CENTER, fr.size.x + 160, 28, UIStyle.GOLD if found2 else UIStyle.DIM)
	var sub := "\"" + tr(str(d2[1])) + "\"" if found2 else tr("It's up on a wall somewhere. Stop and read it.")
	draw_string(fb, Vector2(fr.position.x - 120, cy + 28), sub, HORIZONTAL_ALIGNMENT_CENTER, fr.size.x + 240, 14, UIStyle.PAPER if found2 else UIStyle.DIM)
	draw_string(fb, Vector2(0, vs.y - 30), tr("UP / DOWN  BROWSE     LEFT  TAPES     ESC  BACK"), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 14, Color(1, 1, 1, 0.55))
