class_name Interactable
extends Node2D
## Generic [E]-interactable: phones, collectibles (VHS tapes, photos,
## clippings), terminals, switches. Emits `used`; the level wires behaviour.

signal used(it: Interactable, by: Node)

var kind := "phone"          # phone, tape, photo, clipping, terminal, switch, car
var prompt := "USE"
var enabled := true
var one_shot := true
var item_id := ""
var ringing := false
var _t := 0.0

func setup(p_kind: String, p_prompt: String, p_id := "") -> void:
	kind = p_kind
	prompt = p_prompt
	item_id = p_id

func _ready() -> void:
	add_to_group("interactable")
	z_index = 2
	if kind in ["tape", "photo", "clipping"]:
		# a real glow, so a tape in a dark room still catches the eye
		var l := PointLight2D.new()
		l.texture = SpriteLib.light_texture(128)
		l.texture_scale = 0.45
		l.color = UIStyle.GOLD if kind == "tape" else UIStyle.CYAN
		l.energy = 0.8
		add_child(l)
		_glow = l

var _glow: PointLight2D

func can_interact(_p: Node) -> bool:
	return enabled

func get_prompt() -> String:
	return prompt

func interact(by: Node) -> void:
	if not enabled:
		return
	if one_shot:
		enabled = false
		if _glow:
			create_tween().tween_property(_glow, "energy", 0.0, 0.3)
	ringing = false
	used.emit(self, by)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	if ringing and fmod(_t, 2.0) < delta:
		Audio.play_at("phone_ring", global_position, -2.0, 0.0)
	if Engine.get_process_frames() % 5 == 0:
		queue_redraw()

## A find worth crossing the room for: a soft shaft of light it sits in,
## rings pulsing out along the floor, and a glint that runs over it.
func _draw_treasure(col: Color, bob: float) -> void:
	draw_circle(Vector2.ZERO, 16.0, Color(col, 0.07))
	draw_circle(Vector2.ZERO, 10.0, Color(col, 0.1))
	for k in 2:
		var ph := fmod(_t * 0.8 + k * 0.5, 1.0)
		draw_arc(Vector2.ZERO, 8.0 + ph * 16.0, 0, TAU, 24, Color(col, 0.45 * (1.0 - ph)), 1.2)
	var g := fmod(_t, 2.2)
	if g < 0.3:
		var k2 := g / 0.3
		var c := Vector2(-6 + 12 * k2, -6 + bob)
		draw_line(c - Vector2(3, 0), c + Vector2(3, 0), Color(1, 1, 1, 1.0 - k2), 1.0)
		draw_line(c - Vector2(0, 3), c + Vector2(0, 3), Color(1, 1, 1, 1.0 - k2), 1.0)

func _draw() -> void:
	var ink := Color(0.06, 0.03, 0.08)
	var bob := sin(_t * 4.0) * 0.8
	match kind:
		"phone":
			draw_rect(Rect2(-5, -3, 10, 7), ink)
			draw_rect(Rect2(-4, -2, 8, 5), Color(0.8, 0.1, 0.15))
			draw_rect(Rect2(-5, -4 - (1.5 if ringing and fmod(_t, 0.2) < 0.1 else 0.0), 10, 2), Color(0.9, 0.15, 0.2))
			if ringing:
				draw_arc(Vector2.ZERO, 8.0 + fmod(_t * 12.0, 4.0), -0.6, 0.6, 6, UIStyle.GOLD, 1.0)
				draw_arc(Vector2.ZERO, 8.0 + fmod(_t * 12.0, 4.0), PI - 0.6, PI + 0.6, 6, UIStyle.GOLD, 1.0)
		"tape":
			if not enabled:
				return
			_draw_treasure(UIStyle.GOLD, bob)
			draw_set_transform(Vector2(0, bob), sin(_t * 1.4) * 0.35, Vector2.ONE * 1.35)
			draw_rect(Rect2(-6, -4, 12, 8), ink)
			draw_rect(Rect2(-5, -3, 10, 6), Color(0.12, 0.1, 0.12))
			draw_rect(Rect2(-4, -2, 8, 2), UIStyle.GOLD)
			draw_circle(Vector2(-2, 1.5), 1.2, Color(0.9, 0.9, 0.9))
			draw_circle(Vector2(2, 1.5), 1.2, Color(0.9, 0.9, 0.9))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"photo", "clipping":
			if not enabled:
				return
			_draw_treasure(UIStyle.CYAN, bob)
			draw_set_transform(Vector2(0, bob), sin(_t * 1.2) * 0.3, Vector2.ONE * 1.3)
			draw_rect(Rect2(-5, -4, 10, 8), Color(0.95, 0.93, 0.85))
			draw_rect(Rect2(-4, -3, 8, 5), Color(0.3, 0.25, 0.35) if kind == "photo" else Color(0.6, 0.6, 0.6))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"breaker":
			draw_rect(Rect2(-6, -8, 12, 16), ink)
			draw_rect(Rect2(-5, -7, 10, 14), Color(0.35, 0.36, 0.4))
			draw_rect(Rect2(-2, -4 if not enabled else 1, 4, 5), Color(0.9, 0.2, 0.15))
			if enabled:
				draw_arc(Vector2.ZERO, 12.0, 0, TAU, 20, Color(UIStyle.GOLD, 0.4 + 0.3 * sin(_t * 6.0)), 1.5)
		"valve":
			draw_circle(Vector2.ZERO, 7.0, ink)
			draw_circle(Vector2.ZERO, 6.0, Color(0.75, 0.1, 0.12))
			for k in 4:
				draw_line(Vector2.ZERO, Vector2.from_angle(k * PI * 0.5 + (_t * 2.0 if not enabled else 0.0)) * 6.0, ink, 1.5)
			if enabled:
				draw_arc(Vector2.ZERO, 12.0, 0, TAU, 20, Color(UIStyle.CYAN, 0.4 + 0.3 * sin(_t * 6.0)), 1.5)
		"extinguisher":
			if not enabled and _t > 0.0 and kind == "extinguisher":
				draw_rect(Rect2(-3, -6, 6, 12), Color(0.3, 0.3, 0.32))   # the empty bracket
				return
			draw_rect(Rect2(-3, -7, 6, 13), ink)
			draw_rect(Rect2(-2, -6, 4, 11), Color(0.85, 0.08, 0.1))
			draw_rect(Rect2(-2, -8, 4, 2), Color(0.2, 0.2, 0.2))
			if enabled:
				draw_arc(Vector2.ZERO, 12.0, 0, TAU, 20, Color(1, 1, 1, 0.35 + 0.3 * sin(_t * 6.0)), 1.5)
		"terminal":
			draw_rect(Rect2(-6, -5, 12, 10), ink)
			draw_rect(Rect2(-5, -4, 10, 7), Color(0.05, 0.25, 0.1))
			if fmod(_t, 1.0) < 0.5:
				draw_rect(Rect2(-4, 1, 3, 1), Color(0.3, 1.0, 0.4))
		"car":
			if enabled:
				draw_arc(Vector2.ZERO, 10.0 + sin(_t * 3.0) * 1.5, 0, TAU, 20, Color(UIStyle.PINK, 0.8), 1.5)
		"charge":
			if not enabled:
				return
			# a satchel of pyro charges, bobbing, ringed in gold
			draw_rect(Rect2(-6, -4 + bob, 12, 8), ink)
			draw_rect(Rect2(-5, -3 + bob, 10, 6), Color(0.6, 0.14, 0.1))
			for i in 3:
				draw_rect(Rect2(-4 + i * 3, -3 + bob, 2, 6), Color(0.85, 0.2, 0.14))
			draw_line(Vector2(-5, bob), Vector2(5, bob), Color(0.95, 0.85, 0.3), 1.0)
			draw_circle(Vector2(3, -2 + bob), 1.0, Color(1, 0.2, 0.1, 0.5 + 0.5 * sin(_t * 8.0)))
			draw_arc(Vector2(0, bob), 10.0, 0, TAU, 16, Color(UIStyle.GOLD, 0.35 + 0.25 * sin(_t * 5.0)), 1.0)
		"plant":
			if not enabled:
				return
			# where the charge goes: a pulsing target on the doors
			var r := 9.0 + sin(_t * 5.0) * 1.5
			draw_arc(Vector2.ZERO, r, 0, TAU, 20, Color(1.0, 0.3, 0.2, 0.9), 1.5)
			for k in 4:
				var d := Vector2.from_angle(k * PI * 0.5)
				draw_line(d * (r - 3.0), d * (r + 3.0), Color(1.0, 0.3, 0.2, 0.9), 1.5)
		"switch":
			draw_rect(Rect2(-3, -4, 6, 8), ink)
			draw_rect(Rect2(-2, -3 if enabled else 0, 4, 3), UIStyle.GOLD)
