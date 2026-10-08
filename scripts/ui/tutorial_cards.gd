class_name TutorialCards
extends Control
## Teaching cards on the right-hand side: a title, a plain-words line on
## what the thing does and why you'd use it, the real keys (keyboard or pad,
## whichever is in use) as chips, and a bar that drains while it's up.
## They queue - two at most on screen, never over each other - and each is
## shown once per save (story flag "tut_<id>").

## id -> [title, body, [actions]]
const DEFS := {
	"move": ["MOVE & AIM", "Walk with the movement keys, aim with the mouse or right stick. You're faster than anyone here - use it.", ["move_up", "fire"]],
	"sneak": ["SNEAK UP", "He hasn't seen you. Hold SNEAK to move silently, get behind him and press EXECUTE for a takedown. Or punch him down first, then EXECUTE.", ["sneak", "execute"]],
	"lock": ["LOCK-ON", "Lock onto the nearest enemy so every swing and shot goes to them. Tap again to release. Flick the right stick to switch target.", ["lock_on"]],
	"switch": ["LIGHT SWITCHES", "Kill the lights: guards who haven't spotted you are blind in the dark. Somebody may walk over to turn them back on - be waiting.", ["interact"]],
	"dog": ["DOGS", "Dogs smell you if you run past. Sneak, take them from behind, or throw a MEAT BONE to keep them eating for a minute. They don't count toward clearing a floor.", ["sneak", "equipment"]],
	"upgrade": ["BRIEFCASES", "Briefcases hold a random upgrade that lasts the whole job. Smash or open them.", ["interact"]],
	"window": ["DODGE ROLL", "A quick roll: through windows, over tables, out of the line of fire. It costs stamina - watch the ring at your feet.", ["dash"]],
	"doors": ["DOORS", "Walk into a door to push it open. KICK it and it slams into whoever's behind, knocking them down.", ["execute"]],
	"brick": ["PICK UP & THROW", "Pick up anything lying around. Anything you throw knocks a person down - then finish them.", ["interact", "secondary"]],
	"m01_locked": ["LOCKED OUT", "The lobby doors are chained from inside. Harcourt kept pyro charges from the shoot - try the boiler room.", []],
	"spotlight": ["SPOTLIGHT READY", "Your SPOTLIGHT is full. Trigger it and the world slows while you don't: six seconds of slow motion, and every kill in the light adds a little more. Fill it again by scoring points.", ["ability"]],
	"stamina": ["STAMINA", "Rolling and sprinting burn stamina (the ring at your feet). Let it come back before you need to roll - a roll costs about a third.", ["dash", "sprint"]],
	"bone": ["MEAT BONE", "Throw it near dogs: every dog close enough to smell it goes to eat it for a minute and ignores you. Hurt one and the meal's over.", ["equipment"]],
	"tape": ["VHS TAPE FOUND", "Tapes and evidence you find go into the VCR on the main menu: PLAY VIDEOTAPE to watch what they show.", []],
	"mask": ["MASKS", "Each mask gives you an edge and costs you something. You'll choose one before every job; find or earn the rest.", []],
	"tasks": ["SIDE JOBS", "Killing isn't all of it: the job lists what else needs doing. The way out stays shut until it's done.", ["map"]],
	"weapon": ["WEAPONS", "Guns have limited rounds - throw an empty one, it still knocks people down. Melee weapons break after a few hits.", ["fire", "secondary", "swap"]],
	"reload": ["RELOAD", "Out of rounds in the magazine: reload, or swap to your other weapon - swapping is faster.", ["reload", "swap"]],
}
const MAX_ON := 1
var hud: Node

func showing() -> bool:
	return not _cards.is_empty()

var _queue: Array = []
var _cards: Array = []     ## {id, t, dur, y, a}
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Queue a card by id (DEFS), or a free one with `text` (for level JSON
## hints that don't have a definition). Returns false if already seen.
func show_card(id: String, text := "") -> bool:
	if not bool(SaveManager.get_setting("tips", true)):
		return false
	if bool(SaveManager.get_flag("tut_" + id, false)):
		return false
	for c in _cards:
		if c.id == id:
			return false
	if id in _queue:
		return false
	SaveManager.data.story.flags["tut_" + id] = true
	if not DEFS.has(id) and text != "":
		_extra[id] = text
	_queue.append(id)
	return true

var _extra: Dictionary = {}

func _body(id: String) -> String:
	return tr(str(DEFS[id][1])) if DEFS.has(id) else tr(str(_extra.get(id, "")))

func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.03)
	_t += rd
	while _cards.size() < MAX_ON and not _queue.is_empty() and (hud == null or hud.may_show(self)):
		var id: String = _queue.pop_front()
		var words := _body(id).split(" ").size()
		_cards.append({"id": id, "t": 0.0, "dur": clampf(3.5 + words * 0.28, 5.0, 11.0), "y": -1.0, "a": 0.0})
		Audio.play("blip", -10.0, 0.8)
	var y := 0.0
	for c in _cards:
		c.t = float(c.t) + rd
		var h := _height(c)
		c.y = y if float(c.y) < 0.0 else lerpf(float(c.y), y, minf(1.0, rd * 10.0))
		var out := float(c.t) > float(c.dur)
		c.a = move_toward(float(c.a), 0.0 if out else 1.0, rd * 4.0)
		y += h + 10.0
	_cards = _cards.filter(func(c): return not (float(c.t) > float(c.dur) and float(c.a) <= 0.0))
	queue_redraw()

const W := 380.0

func _lines(id: String) -> PackedStringArray:
	var f := UIStyle.font_bold()
	var out := PackedStringArray()
	var line := ""
	for word in _body(id).split(" "):
		var trial := word if line == "" else line + " " + word
		if f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x > W - 28.0 and line != "":
			out.append(line)
			line = word
		else:
			line = trial
	out.append(line)
	return out

func _key_label(act: String) -> String:
	if act == "move_up":
		return "WASD" if not InputSetup.using_gamepad else "L-STICK"
	return InputSetup.binding_text(act, InputSetup.using_gamepad)

## Chip widths -> which row each key lands on (rows wrap inside the card).
func _key_rows(id: String) -> Array:
	var fm := UIStyle.font_mono()
	var fb := UIStyle.font_bold()
	var keys: Array = DEFS[id][2] if DEFS.has(id) else []
	var out: Array = []
	var row := 0
	var kx := 16.0
	for act in keys:
		var kw := fm.get_string_size(_key_label(str(act)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0
		var nm := tr(str(InputSetup.ACTIONS.get(str(act), [str(act)])[0])).to_upper()
		var nw := fb.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		if kx + kw + 6.0 + nw > W - 12.0 and kx > 16.0:
			row += 1
			kx = 16.0
		out.append({"row": row, "x": kx, "w": kw, "nw": nw, "name": nm, "label": _key_label(str(act))})
		kx += kw + nw + 18.0
	return out

func _height(c: Dictionary) -> float:
	var id: String = c.id
	var rows := _key_rows(id)
	var nrows: int = (int(rows[-1].row) + 1) if not rows.is_empty() else 0
	return 40.0 + _lines(id).size() * 18.0 + nrows * 28.0 + 12.0

func _draw() -> void:
	var fd := UIStyle.font_display()
	var fb := UIStyle.font_bold()
	var fm := UIStyle.font_mono()
	for c in _cards:
		var a: float = c.a
		if a <= 0.0:
			continue
		var id: String = c.id
		var h := _height(c)
		var slide := (1.0 - a) * 60.0
		var r := Rect2(Vector2(size.x - W + slide, float(c.y)), Vector2(W, h))
		draw_rect(r, Color(0.03, 0.01, 0.06, 0.86 * a))
		draw_rect(Rect2(r.position, Vector2(4, h)), Color(UIStyle.GOLD, a))
		draw_rect(r, Color(UIStyle.PINK, 0.5 * a), false, 1.0)
		var title := tr(str(DEFS[id][0])) if DEFS.has(id) else tr("TIP")
		draw_string(fd, r.position + Vector2(16, 26), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(UIStyle.GOLD, a))
		var ly := r.position.y + 48.0
		for l in _lines(id):
			draw_string(fb, Vector2(r.position.x + 16, ly), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UIStyle.PAPER, 0.92 * a))
			ly += 18.0
		# the keys, as chips
		for kr in _key_rows(id):
			var cy: float = ly - 2 + float(kr.row) * 28.0
			var chip := Rect2(Vector2(r.position.x + float(kr.x), cy), Vector2(float(kr.w), 20))
			draw_rect(chip, Color(UIStyle.CYAN, 0.18 * a))
			draw_rect(chip, Color(UIStyle.CYAN, 0.8 * a), false, 1.0)
			draw_string(fm, chip.position + Vector2(7, 15), str(kr.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UIStyle.CYAN, a))
			draw_string(fb, Vector2(chip.end.x + 6, cy + 14), str(kr.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UIStyle.DIM, a))
		# the time left, draining
		var k := clampf(1.0 - float(c.t) / float(c.dur), 0.0, 1.0)
		draw_rect(Rect2(r.position.x, r.end.y - 3, W * k, 3), Color(UIStyle.PINK, 0.9 * a))
