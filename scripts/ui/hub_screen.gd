extends Control
## Between jobs: Cass's room. The painted apartment, lived-in and quiet,
## with the things in it that matter lit up when you point at them:
##   the ANSWERING MACHINE - the calls so far, played back
##   the VCR              - the tapes and photos found (VcrScreen)
##   the MIRROR           - the masks (MaskSelect, picks for the next job)
##   the CORKBOARD        - the story so far, and what she chose
##   the DOOR             - the next job
## Keyboard/pad: up/down through them, confirm to use. Mouse: point and click.

const SPOTS := [
	["DOOR", "NEXT JOB", "Grab the keys. Somebody else on the call sheet is waiting.", Vector2(0.07, 0.78)],
	["MACHINE", "ANSWERING MACHINE", "Every call so far. Play them back.", Vector2(0.5, 0.33)],
	["VCR", "VCR", "The tapes and photos you've found.", Vector2(0.2, 0.6)],
	["MIRROR", "MIRROR", "Choose the face for the next job.", Vector2(0.78, 0.1)],
	["BOARD", "CORKBOARD", "The story so far, pinned up with red string.", Vector2(0.48, 0.1)],
]
const CALLS := [["m01_checkout", "call_m01"], ["m02_dog_days", "call_m02"], ["m03_prime_time", "call_m03"], ["m04_sweet_dreams", "call_m04"]]

var _shot: StoryShot
var _sel := 0
var _t := 0.0
var _busy := false
var _over: Control
var _board: Control

func _ready() -> void:
	theme = UIStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_shot = StoryShot.new()
	_shot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shot.letterbox = false
	_shot.shot_time = 40.0
	add_child(_shot)
	_shot.show_shot("apartment", true)
	_over = Control.new()
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_over)
	add_child(_over)
	Music.play("apartment")
	PostFX.vhs_glitch(0.6)
	Audio.play("tape_insert", -8.0)
	Dialogue.finished.connect(func(_id): _busy = false)
	if Engine.has_meta("autoplay") and not OS.get_environment("SHOT_MODE") == "hub":
		Game.story_beat_finished.call_deferred()   # the bot goes straight out the door

func _process(delta: float) -> void:
	_t += delta
	_over.queue_redraw()

func _spot_pos(i: int) -> Vector2:
	var p: Vector2 = SPOTS[i][3]
	return Vector2(p.x * size.x, p.y * size.y)

func _input(e: InputEvent) -> void:
	if _busy or Dialogue.active:
		return
	if _board and is_instance_valid(_board):
		if UIStyle.is_any_press(e) and not (e is InputEventMouseMotion):
			_board.queue_free()
			_board = null
			Audio.play("ui_back")
			get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("ui_down") or e.is_action_pressed("ui_right"):
		_sel = (_sel + 1) % SPOTS.size()
		Audio.play("ui_move", -8.0)
	elif e.is_action_pressed("ui_up") or e.is_action_pressed("ui_left"):
		_sel = posmod(_sel - 1, SPOTS.size())
		Audio.play("ui_move", -8.0)
	elif e is InputEventMouseMotion:
		for i in SPOTS.size():
			if _spot_pos(i).distance_to(e.position) < 60.0 and i != _sel:
				_sel = i
				Audio.play("ui_move", -12.0)
		return
	elif e.is_action_pressed("ui_accept") or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		_use(str(SPOTS[_sel][0]))
	else:
		return
	get_viewport().set_input_as_handled()

func _use(id: String) -> void:
	Audio.play("ui_select")
	match id:
		"DOOR":
			_busy = true
			Audio.play("door_open", -2.0)
			PostFX.vhs_glitch(0.8)
			Game.story_beat_finished()
		"MACHINE":
			# the latest call she's had, then the ones before, one tap each
			var ids: Array = []
			for c in CALLS:
				if SaveManager.data.missions.has(c[0]):
					ids.append(c[1])
			if ids.is_empty():
				Audio.play("rec_beep", -4.0)
				return
			_busy = true
			Audio.play("rec_beep", -4.0)
			Dialogue.start(str(ids[-1]), true)
		"VCR":
			var v := VcrScreen.new()
			add_child(v)
			_busy = true
			v.closed.connect(func(): _busy = false)
		"MIRROR":
			var ms := MaskSelect.new()
			ms.gallery = true
			add_child(ms)
			_busy = true
			ms.closed.connect(func(): _busy = false)
		"BOARD":
			_board = StoryBoard.new()
			_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(_board)

func _draw_over() -> void:
	var c := _over
	var fd := UIStyle.font_display()
	var fb := UIStyle.font_bold()
	c.draw_rect(Rect2(0, size.y - 90, size.x, 90), Color(0.02, 0.0, 0.04, 0.7))
	c.draw_string(fd, Vector2(40, 54), tr("BETWEEN JOBS"), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UIStyle.PINK)
	for i in SPOTS.size():
		var p := _spot_pos(i)
		var on := i == _sel
		var pulse := 0.5 + 0.5 * sin(_t * 4.0 + i)
		c.draw_arc(p, 16.0 + (4.0 * pulse if on else 0.0), 0, TAU, 32, Color(UIStyle.GOLD if on else UIStyle.CYAN, 0.9 if on else 0.45), 2.0 if on else 1.2)
		c.draw_circle(p, 3.0, Color(UIStyle.GOLD if on else UIStyle.CYAN, 0.9))
		if on:
			c.draw_string(fb, p + Vector2(24, 6), tr(str(SPOTS[i][1])), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIStyle.GOLD)
	var s: Array = SPOTS[_sel]
	c.draw_string(fd, Vector2(40, size.y - 52), tr(str(s[1])), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UIStyle.GOLD)
	c.draw_string(fb, Vector2(40, size.y - 26), tr(str(s[2])), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIStyle.PAPER)


## The corkboard: the story so far, one card per job she's finished, with
## what she chose there, and the evidence count.
class StoryBoard extends Control:
	const NOTES := {
		"m01_checkout": ["CHECKOUT TIME", "The Sunset Palms. Harcourt stood fire watch in 1987 with an empty extinguisher.", "harcourt_spared", "Harcourt: walked away", "Harcourt: finished"],
		"m02_dog_days": ["DOG DAYS", "Yermo. Buck's dogs kept the fire lane clear that night. Arlo was watching it all on six TVs.", "buck_spared", "Buck: left to his dogs", "Buck: finished"],
		"m03_prime_time": ["PRIME TIME", "Stage Nine, live. Dutch doubled the fire bars. The change order was signed T. MORENO.", "dutch_spared", "Dutch: feed cut", "Dutch: for the viewers"],
		"m04_sweet_dreams": ["SWEET DREAMS", "The dream. Everyone she put down, at the party. Tommy, still burning.", "held_tommy_dream", "Held him", "Let him burn out"],
	}
	func _draw() -> void:
		var vs := size
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.01, 0.04, 0.9))
		var fd := UIStyle.font_display()
		var fb := UIStyle.font_bold()
		draw_rect(Rect2(60, 60, vs.x - 120, vs.y - 120), Color(0.42, 0.3, 0.2))
		draw_string(fd, Vector2(80, 100), tr("THE STORY SO FAR"), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.1, 0.05, 0.05))
		var x := 90.0
		var prev := Vector2.ZERO
		var i := 0
		for mid in NOTES.keys():
			var done: bool = SaveManager.data.missions.has(mid)
			var n: Array = NOTES[mid]
			var card := Rect2(Vector2(x, 130 + (i % 2) * 40), Vector2((vs.x - 220) / 4.0 - 14, 230))
			draw_rect(card.grow(2), Color(0, 0, 0, 0.3))
			draw_rect(card, Color(0.95, 0.92, 0.84) if done else Color(0.6, 0.55, 0.5))
			draw_circle(card.position + Vector2(card.size.x * 0.5, 8), 5.0, Color(0.8, 0.1, 0.1))
			if prev != Vector2.ZERO and done:
				draw_line(prev, card.position + Vector2(card.size.x * 0.5, 8), Color(0.8, 0.05, 0.05), 2.0)
			prev = card.position + Vector2(card.size.x * 0.5, 8)
			draw_string(fb, card.position + Vector2(10, 34), tr(str(n[0])) if done else "???", HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 20, 15, Color(0.15, 0.05, 0.05))
			if done:
				draw_multiline_string(fb, card.position + Vector2(10, 58), tr(str(n[1])), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 20, 12, 8, Color(0.2, 0.15, 0.12))
				var chose := tr(str(n[3])) if bool(SaveManager.get_flag(str(n[2]), false)) else tr(str(n[4]))
				draw_string(fb, card.position + Vector2(10, card.size.y - 14), chose, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 20, 12, Color(0.6, 0.05, 0.05))
			x += card.size.x + 14.0
			i += 1
		var found: int = SaveManager.data.get("collectibles", []).size()
		draw_string(fb, Vector2(80, vs.y - 80), tr("EVIDENCE FOUND: %d") % found, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.1, 0.05, 0.05))
		draw_string(fb, Vector2(0, vs.y - 30), tr("ANY KEY  BACK"), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 13, Color(1, 1, 1, 0.6))
