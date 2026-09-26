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

func can_interact(_p: Node) -> bool:
	return enabled

func get_prompt() -> String:
	return prompt

func interact(by: Node) -> void:
	if not enabled:
		return
	if one_shot:
		enabled = false
	ringing = false
	used.emit(self, by)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	if ringing and fmod(_t, 2.0) < delta:
		Audio.play_at("phone_ring", global_position, -2.0, 0.0)
	if Engine.get_process_frames() % 5 == 0:
		queue_redraw()

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
			draw_rect(Rect2(-6, -4 + bob, 12, 8), ink)
			draw_rect(Rect2(-5, -3 + bob, 10, 6), Color(0.12, 0.1, 0.12))
			draw_rect(Rect2(-4, -2 + bob, 8, 2), UIStyle.GOLD)
			draw_circle(Vector2(-2, 1.5 + bob), 1.2, Color(0.9, 0.9, 0.9))
			draw_circle(Vector2(2, 1.5 + bob), 1.2, Color(0.9, 0.9, 0.9))
			draw_arc(Vector2(0, bob), 9.0, 0, TAU, 16, Color(UIStyle.GOLD, 0.35 + 0.25 * sin(_t * 5.0)), 1.0)
		"photo", "clipping":
			if not enabled:
				return
			draw_rect(Rect2(-5, -4 + bob, 10, 8), Color(0.95, 0.93, 0.85))
			draw_rect(Rect2(-4, -3 + bob, 8, 5), Color(0.3, 0.25, 0.35) if kind == "photo" else Color(0.6, 0.6, 0.6))
			draw_arc(Vector2(0, bob), 9.0, 0, TAU, 16, Color(UIStyle.CYAN, 0.35 + 0.25 * sin(_t * 5.0)), 1.0)
		"terminal":
			draw_rect(Rect2(-6, -5, 12, 10), ink)
			draw_rect(Rect2(-5, -4, 10, 7), Color(0.05, 0.25, 0.1))
			if fmod(_t, 1.0) < 0.5:
				draw_rect(Rect2(-4, 1, 3, 1), Color(0.3, 1.0, 0.4))
		"car":
			if enabled:
				draw_arc(Vector2.ZERO, 10.0 + sin(_t * 3.0) * 1.5, 0, TAU, 20, Color(UIStyle.PINK, 0.8), 1.5)
		"switch":
			draw_rect(Rect2(-3, -4, 6, 8), ink)
			draw_rect(Rect2(-2, -3 if enabled else 0, 4, 3), UIStyle.GOLD)
