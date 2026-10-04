class_name IntroCall
extends CanvasLayer
## The call at the start of a mission: somebody who matters rings Cass as
## she arrives (the Voice at the motel, Mom before Yermo, Rudy on a walkie
## on the lot, Tommy in the dream). A panel slides in with the caller's
## portrait and a handset that shakes on every ring; she picks up, the line
## plays through the dialogue box without pausing the game (the caller's
## portrait talks and blinks), and the panel hangs up and slides away.
## Only on a mission's first load: never after a death or a checkpoint.

const RINGS := 2
const RING_GAP := 1.1

var dialogue_id := ""
var caller := "voice"          ## speaker id: portrait + name
var device := "phone"          ## phone | walkie
var _panel: Control
var _t := 0.0
var _state := "ring"           ## ring -> talk -> hangup
var _rings := 0
var _ring_t := 0.2
var _shake := 0.0
var _portrait: TextureRect
var _portrait_home := Vector2(12, 12)

func _ready() -> void:
	add_to_group("intro_call")
	layer = 55
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_panel = CallPanel.new()
	_panel.line = self
	_panel.position = Vector2(-420, 150)
	_panel.size = Vector2(380, 96)
	add_child(_panel)
	var pixel_path := "res://assets/art/pixellab_ui_v3_approved/portraits/%s.png" % caller
	var tex_path := pixel_path if ResourceLoader.exists(pixel_path) else "res://assets/characters/portraits/%s.png" % caller
	_portrait = TextureRect.new()
	if ResourceLoader.exists(tex_path):
		_portrait.texture = load(tex_path)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.position = _portrait_home
	_portrait.size = Vector2(72, 72)
	_panel.add_child(_portrait)
	var tw := create_tween()
	tw.tween_property(_panel, "position:x", 24.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Dialogue.finished.connect(_on_finished)

func _process(delta: float) -> void:
	# the phone waits for the chapter card to leave: one thing at a time
	if _state == "ring" and _rings == 0 and not get_tree().get_nodes_in_group("level_intro").is_empty():
		_panel.visible = false
		return
	_panel.visible = true
	_t += delta
	# A live caller should never read as a pasted card: the portrait breathes
	# while the line is open and reacts sharply to each ring.
	if _portrait:
		var talking := _state == "talk" and Dialogue.active and Dialogue.is_typing()
		var breath := sin(_t * (8.0 if talking else 2.0))
		_portrait.position = _portrait_home + Vector2(0, breath * (1.4 if talking else 0.45))
		_portrait.rotation = breath * (0.012 if talking else 0.004) + sin(_t * 45.0) * 0.025 * _shake
		_portrait.scale = Vector2.ONE * (1.0 + (0.018 if talking else 0.006) * maxf(0.0, breath))
	_shake = maxf(0.0, _shake - delta * 3.0)
	match _state:
		"ring":
			_ring_t -= delta
			if _ring_t <= 0.0:
				if _rings >= RINGS:
					_pick_up()
				else:
					_rings += 1
					_ring_t = RING_GAP
					_shake = 1.0
					Audio.play("phone_ring" if device == "phone" else "rec_beep", -4.0)
					InputSetup.vibrate(0.15, 0.25, 0.12)
		"talk":
			# the call ends if a scene takes over the box (a boss, a pickup)
			if not Dialogue.active or Dialogue._id != dialogue_id:
				_hang_up()
	_panel.queue_redraw()

func _pick_up() -> void:
	_state = "talk"
	Audio.play("phone_pickup" if device == "phone" else "blip", -2.0)
	if Dialogue.active:
		_hang_up()   # something else is already talking: take a message
		return
	Dialogue.start(dialogue_id, false)

func _on_finished(id: String) -> void:
	if id == dialogue_id and _state == "talk":
		_hang_up()

func _hang_up() -> void:
	if _state == "hangup":
		return
	_state = "hangup"
	Audio.play("blip", -8.0, 0.7)
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(_panel, "position:x", -420.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _exit_tree() -> void:
	if Dialogue.finished.is_connected(_on_finished):
		Dialogue.finished.disconnect(_on_finished)


## The call panel: VHS-styled card with the caller, a handset or walkie
## that jitters on each ring, signal waves while the line is open.
class CallPanel extends Control:
	var line: IntroCall
	var _icon: Texture2D

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.04, 0.02, 0.07, 0.88))
		draw_rect(r, UIStyle.PINK, false, 2.0)
		draw_rect(Rect2(Vector2(10, 10), Vector2(76, 76)), UIStyle.INK)
		var sd: Dictionary = Dialogue.speakers.get(line.caller, {})
		var who := tr(str(sd.get("name", line.caller.to_upper())))
		var head := tr("INCOMING CALL") if line._state == "ring" else (tr("ON THE LINE") if line._state == "talk" else tr("CALL ENDED"))
		var blink := line._state != "ring" or fmod(line._t, 0.6) < 0.4
		if blink:
			draw_string(UIStyle.font_bold(), Vector2(98, 30), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.GOLD)
		var name_fs := 20
		var name_room := size.x - 98.0 - 84.0   # keep clear of the handset
		while name_fs > 11 and UIStyle.font_display().get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, name_fs).x > name_room:
			name_fs -= 1
		draw_string(UIStyle.font_display(), Vector2(98, 58), who, HORIZONTAL_ALIGNMENT_LEFT, name_room, name_fs, Color.html("#" + str(sd.get("color", "f4f0e8"))))
		# the handset: a neon line drawing (walkie or phone), shaking per ring
		var c := Vector2(size.x - 46, 46) + Vector2(sin(line._t * 70.0), cos(line._t * 55.0)) * 3.0 * line._shake
		var rot := -0.5 + sin(line._t * 40.0) * 0.25 * line._shake
		var neon := UIStyle.PINK if line._state == "ring" else UIStyle.CYAN
		var glow_a := 0.55 + 0.45 * sin(line._t * (9.0 if line._state == "ring" else 3.0))
		var ipath := "res://assets/art/ui/icon_%s_neon.png" % ("walkie" if line.device == "walkie" else "phone")
		# held on the panel: a texture loaded into a local here is freed
		# before the frame is drawn and shows as a blank white square
		if _icon == null and ResourceLoader.exists(ipath):
			_icon = load(ipath)
		var icon: Texture2D = _icon
		if icon:
			# the neon handset / walkie: jumps on each ring, glow breathing,
			# dim while the line is quiet, bright while someone's talking
			var talking := line._state == "talk" and Dialogue.active and Dialogue.is_typing()
			var lit := 1.0 if line._state == "ring" or talking else 0.7
			var isz := Vector2(64, 64)
			draw_set_transform(c, sin(line._t * 40.0) * 0.15 * line._shake, Vector2.ONE * (1.0 + 0.08 * line._shake))
			draw_texture_rect(icon, Rect2(-isz * 0.5 * 1.25, isz * 1.25), false, Color(1, 1, 1, 0.25 * glow_a * lit))
			draw_texture_rect(icon, Rect2(-isz * 0.5, isz), false, Color(lit, lit, lit, 1.0))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_set_transform(c, rot, Vector2.ONE)
		var strokes: Array = []
		if icon:
			pass
		elif line.device == "walkie":
			strokes = [
				PackedVector2Array([Vector2(-7, -12), Vector2(7, -12), Vector2(8, 14), Vector2(-8, 14), Vector2(-7, -12)]),
				PackedVector2Array([Vector2(-4, -8), Vector2(4, -8), Vector2(4, -2), Vector2(-4, -2), Vector2(-4, -8)]),
				PackedVector2Array([Vector2(4, -12), Vector2(5, -24)]),
			]
			for k in 3:
				strokes.append(PackedVector2Array([Vector2(-4, 3 + k * 3), Vector2(4, 3 + k * 3)]))
		else:
			# a classic handset: curved grip, ear cup and mouthpiece as rounded
			# pads at the ends, turned along the curve
			var grip := PackedVector2Array()
			for k in 13:
				var ga: float = PI * 1.2 + k / 12.0 * PI * 0.6
				grip.append(Vector2.from_angle(ga) * 15.0 + Vector2(0, 13))
			strokes.append(grip)
			for end in [PI * 1.2, PI * 1.8]:
				var ep: Vector2 = Vector2.from_angle(end) * 15.0 + Vector2(0, 13)
				var tang: Vector2 = Vector2.from_angle(end).orthogonal()
				var nrm: Vector2 = Vector2.from_angle(end)
				var pad := PackedVector2Array()
				for k in 11:
					var pa: float = k / 10.0 * TAU
					pad.append(ep + nrm * 1.5 + tang * cos(pa) * 6.5 + nrm * sin(pa) * 3.5)
				strokes.append(pad)
			# the coiled cord trailing off
			var cord := PackedVector2Array()
			for k in 16:
				var t := k / 15.0
				cord.append(Vector2(10 + t * 10.0, 6 + t * 12.0) + Vector2.from_angle(t * TAU * 3.0) * 2.0)
			strokes.append(cord)
		for st in strokes:
			draw_polyline(st, Color(neon, 0.15 * glow_a), 6.0, true)
			draw_polyline(st, Color(neon, 0.35 * glow_a), 3.5, true)
			draw_polyline(st, neon.lightened(0.45), 1.5, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# signal: rings pulse outward while ringing, bars bounce while talking
		if line._state == "ring":
			var k := fmod(line._t, 1.1) / 1.1
			draw_arc(c, 16.0 + k * 18.0, -0.9, 0.9, 12, Color(UIStyle.PINK, 1.0 - k), 2.0)
			draw_arc(c, 16.0 + k * 18.0, PI - 0.9, PI + 0.9, 12, Color(UIStyle.PINK, 1.0 - k), 2.0)
		elif line._state == "talk":
			var talking := Dialogue.active and Dialogue.is_typing()
			for i in 5:
				var hgt := 4.0 + (10.0 * absf(sin(line._t * 9.0 + i * 1.3)) if talking else 2.0)
				draw_rect(Rect2(98 + i * 7, 84 - hgt, 4, hgt), UIStyle.CYAN)
		# scanlines
		for y in range(0, int(size.y), 3):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.12), 1.0)
