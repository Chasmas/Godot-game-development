class_name MaskSelect
extends CanvasLayer
## Before a job: which face does she wear tonight? A row of masks on a
## dressing-room shelf; the focused one lifts into the light with what it
## gives and what it costs. Locked masks are dark shapes with a hint. The
## game waits (paused) until she picks; retries keep the choice.

signal chosen(id: StringName)

var _i := 0
var _t := 0.0
var _root: Control
var _shelf: Shelf

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var cur := Game.mask if Game.mask != &"" else &"star"
	_i = maxi(0, Masks.ORDER.find(cur))
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIStyle.theme()
	add_child(_root)
	_shelf = Shelf.new()
	_shelf.sel = self
	_shelf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_shelf)
	Audio.play("tape_insert", -10.0)

func _process(delta: float) -> void:
	_t += delta
	_shelf.queue_redraw()

func _input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_left") or e.is_action_pressed("move_left"):
		_move(-1)
	elif e.is_action_pressed("ui_right") or e.is_action_pressed("move_right"):
		_move(1)
	elif e.is_action_pressed("ui_accept") or e.is_action_pressed("interact") or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		if e is InputEventMouseButton:
			var hit := _shelf.card_at(e.position)
			if hit >= 0 and hit != _i:
				_i = hit
				Audio.play("ui_move", -8.0)
				get_viewport().set_input_as_handled()
				return
		_confirm()
	elif e is InputEventMouseMotion:
		var h := _shelf.card_at(e.position)
		if h >= 0 and h != _i:
			_i = h
			Audio.play("ui_move", -12.0)
	else:
		return
	get_viewport().set_input_as_handled()

func _move(d: int) -> void:
	_i = posmod(_i + d, Masks.ORDER.size())
	Audio.play("ui_move", -8.0)
	_shelf.bump = 1.0

func _confirm() -> void:
	var id: StringName = Masks.ORDER[_i]
	if not Masks.is_unlocked(id):
		Audio.play("empty", -4.0)
		_shelf.shake = 1.0
		return
	Game.mask = id
	Game.mask_chosen = true
	Audio.play("ui_select")
	Audio.play("rank_stamp", -8.0)
	PostFX.vhs_glitch(0.5)
	get_tree().paused = false
	chosen.emit(id)
	queue_free()


class Shelf extends Control:
	var sel: MaskSelect
	var bump := 0.0
	var shake := 0.0
	var _rects: Array[Rect2] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func card_at(p: Vector2) -> int:
		for i in _rects.size():
			if _rects[i].has_point(p):
				return i
		return -1

	func _draw() -> void:
		var t := sel._t
		bump = move_toward(bump, 0.0, 0.08)
		shake = move_toward(shake, 0.0, 0.06)
		var vs := size
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.0, 0.04, 0.88))
		# the dressing-room mirror bulbs along the top
		for i in 16:
			var x := vs.x * (i + 0.5) / 16.0
			var on := 0.75 + 0.25 * sin(t * 3.0 + i * 1.7)
			draw_circle(Vector2(x, 34), 7.0, Color(1.0, 0.8, 0.45, 0.25 * on))
			draw_circle(Vector2(x, 34), 3.5, Color(1.0, 0.9, 0.7, on))
		var f := UIStyle.font_display()
		var fb := UIStyle.font_bold()
		var head := tr("WHO ARE YOU TONIGHT?")
		draw_string(f, Vector2(0, 104), head, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 42, UIStyle.PINK)
		var n := Masks.ORDER.size()
		var cw := minf(128.0, (vs.x - 80.0) / n)
		var x0 := vs.x * 0.5 - cw * n * 0.5
		var y0 := vs.y * 0.42
		_rects.clear()
		for i in n:
			var id: StringName = Masks.ORDER[i]
			var open := Masks.is_unlocked(id)
			var focus := i == sel._i
			var lift := (18.0 + 4.0 * sin(t * 2.0)) if focus else 0.0
			var sz := cw * (1.25 if focus else 0.9)
			var c := Vector2(x0 + cw * (i + 0.5), y0 - lift)
			if focus and shake > 0.0:
				c.x += sin(t * 60.0) * 6.0 * shake
			var r := Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz))
			_rects.append(Rect2(Vector2(x0 + cw * i, y0 - cw), Vector2(cw, cw * 2.0)))
			if focus:
				# a spotlight cone from above
				draw_colored_polygon(PackedVector2Array([Vector2(c.x - 18, 40), Vector2(c.x + 18, 40), Vector2(c.x + sz * 0.7, c.y + sz * 0.6), Vector2(c.x - sz * 0.7, c.y + sz * 0.6)]), Color(1, 0.85, 0.55, 0.07))
				draw_circle(c, sz * 0.62, Color(1, 0.3, 0.6, 0.12))
			var tex := Masks.icon(id)
			if tex:
				var mod := Color.WHITE if open else Color(0.16, 0.08, 0.22, 0.95)
				if open and not focus:
					mod = Color(0.6, 0.55, 0.7)
				draw_texture_rect(tex, r, false, mod)
			else:
				draw_circle(c, sz * 0.35, Color(0.9, 0.9, 0.95, 0.9) if open else Color(0.1, 0.05, 0.12))
			if not open:
				draw_string(f, c + Vector2(-sz * 0.5, 14), "?", HORIZONTAL_ALIGNMENT_CENTER, sz, 40, Color(1, 1, 1, 0.35))
			# the shelf
			draw_line(Vector2(x0 + cw * i + 4, y0 + cw * 0.62), Vector2(x0 + cw * (i + 1) - 4, y0 + cw * 0.62), Color(0.5, 0.3, 0.2, 0.8), 3.0)
		# the focused mask's card
		var id2: StringName = Masks.ORDER[sel._i]
		var p := DB.persona(id2)
		if p == null:
			return
		var yy := y0 + cw * 0.95
		var open2 := Masks.is_unlocked(id2)
		draw_string(f, Vector2(0, yy + 34), tr(p.display_name) if open2 else "? ? ?", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 38, UIStyle.GOLD)
		if open2:
			draw_string(fb, Vector2(0, yy + 66), tr(p.look), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 15, UIStyle.DIM)
			draw_string(fb, Vector2(0, yy + 104), "+  " + tr(p.pro), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 19, UIStyle.CYAN)
			draw_string(fb, Vector2(0, yy + 134), "-  " + tr(p.con), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 19, UIStyle.HOT)
		else:
			draw_string(fb, Vector2(0, yy + 80), tr("LOCKED") + "  -  " + tr(p.unlock_hint), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 18, UIStyle.DIM)
		var keys := tr("◄ ►  CHOOSE      ENTER  WEAR IT")
		draw_string(fb, Vector2(0, vs.y - 36), keys, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 14, Color(1, 1, 1, 0.5 + 0.2 * sin(t * 3.0)))
