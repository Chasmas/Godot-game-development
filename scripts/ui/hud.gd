class_name HUD
extends CanvasLayer
## In-game HUD: score/combo, weapon + ammo, ability meter, prompts, hints,
## objectives, enemy tracker, boss pips, title card, death screen, crosshair.

const DEATH_LINES := [
	"THAT'S A WRAP", "CUT!", "RESHOOT", "TAKE TWO", "BAD TAKE", "STUNT DOUBLE NEEDED",
	"ROLL IT AGAIN", "FROM THE TOP", "YOU MISSED YOUR MARK", "DEAD ON ARRIVAL",
]

var level: Node
var player: Player
var root: Control
var score_label: Label
var combo_label: Label
var combo_bar: ColorRect
var weapon_label: Label
var ammo_label: Label
var holster_label: Label
var ability_label: Label
var ability_bar: ColorRect
var ability_bg: ColorRect
var equip_label: Label
var prompt_label: Label
var hint_label: Label
var objective_label: Label
var banner: Label
var card_sub: Label
var _card_t := 0.0
var death_panel: Control
var death_title: Label
var death_sub: Label
var boss_label: Label
var map_panel: PanelContainer
var map_text: Label
var cross: Crosshair
var tracker: Tracker
var status: StatusPanel
var _hint_t := 0.0
var _banner_t := 0.0
var _combo_pulse := 0.0
var _last_combo := 0

func _ready() -> void:
	layer = 50
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)
	# --- score / combo (top left)
	score_label = _lbl(Vector2(22, 14), 30, UIStyle.PAPER, UIStyle.font_display())
	combo_label = _lbl(Vector2(24, 52), 24, UIStyle.GOLD, UIStyle.font_display())
	combo_bar = ColorRect.new()
	combo_bar.position = Vector2(26, 86)
	combo_bar.size = Vector2(120, 4)
	combo_bar.color = UIStyle.GOLD
	root.add_child(combo_bar)
	# --- weapon (top right)
	weapon_label = _lbl(Vector2(0, 14), 20, UIStyle.PAPER, UIStyle.font_bold())
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIStyle.place(weapon_label, Control.PRESET_TOP_RIGHT, Vector2(-420, 14), Vector2(400, 24))
	ammo_label = _lbl(Vector2(-420, 38), 28, UIStyle.PINK, UIStyle.font_display())
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIStyle.place(ammo_label, Control.PRESET_TOP_RIGHT, Vector2(-420, 38), Vector2(400, 36))
	holster_label = _lbl(Vector2(-420, 76), 13, UIStyle.DIM, UIStyle.font_mono())
	holster_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIStyle.place(holster_label, Control.PRESET_TOP_RIGHT, Vector2(-420, 76), Vector2(400, 18))
	# --- ability (bottom left)
	ability_label = _lbl(Vector2(22, 0), 14, UIStyle.GOLD, UIStyle.font_bold())
	UIStyle.place(ability_label, Control.PRESET_BOTTOM_LEFT, Vector2(22, -58))
	ability_bg = ColorRect.new()
	ability_bg.color = Color(1, 1, 1, 0.15)
	UIStyle.place(ability_bg, Control.PRESET_BOTTOM_LEFT, Vector2(22, -36), Vector2(160, 6))
	root.add_child(ability_bg)
	ability_bar = ColorRect.new()
	ability_bar.color = UIStyle.GOLD
	UIStyle.place(ability_bar, Control.PRESET_BOTTOM_LEFT, Vector2(22, -36), Vector2(160, 6))
	root.add_child(ability_bar)
	equip_label = _lbl(Vector2(22, 0), 13, UIStyle.DIM, UIStyle.font_mono())
	UIStyle.place(equip_label, Control.PRESET_BOTTOM_LEFT, Vector2(22, -26))
	# --- prompt (bottom centre)
	prompt_label = _lbl(Vector2.ZERO, 16, UIStyle.PAPER, UIStyle.font_bold())
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_constant_override("outline_size", 6)
	UIStyle.place(prompt_label, Control.PRESET_CENTER_BOTTOM, Vector2(-300, -64), Vector2(600, 24))
	# --- hint / objective (top centre)
	objective_label = _lbl(Vector2.ZERO, 14, UIStyle.CYAN, UIStyle.font_bold())
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.add_theme_constant_override("outline_size", 5)
	UIStyle.place(objective_label, Control.PRESET_CENTER_TOP, Vector2(-300, 12), Vector2(600, 20))
	hint_label = _lbl(Vector2.ZERO, 15, UIStyle.PAPER, UIStyle.font_bold())
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_constant_override("outline_size", 6)
	UIStyle.place(hint_label, Control.PRESET_CENTER_TOP, Vector2(-340, 104), Vector2(680, 48))
	boss_label = _lbl(Vector2.ZERO, 16, UIStyle.HOT, UIStyle.font_display())
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.visible = false
	UIStyle.place(boss_label, Control.PRESET_CENTER_TOP, Vector2(-300, 36), Vector2(600, 24))
	banner = _lbl(Vector2.ZERO, 40, UIStyle.PAPER, UIStyle.font_display())
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_theme_constant_override("outline_size", 10)
	banner.add_theme_color_override("font_outline_color", UIStyle.INK)
	UIStyle.place(banner, Control.PRESET_CENTER, Vector2(-480, -120), Vector2(960, 240))
	banner.modulate.a = 0.0
	card_sub = _lbl(Vector2.ZERO, 18, UIStyle.CYAN, UIStyle.font_bold())
	UIStyle.place(card_sub, Control.PRESET_CENTER, Vector2(-480, 30), Vector2(960, 60))
	card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_sub.modulate.a = 0.0
	_build_death()
	_build_map()
	tracker = Tracker.new()
	tracker.hud = self
	tracker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tracker)
	status = StatusPanel.new()
	status.hud = self
	status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(status)
	cross = Crosshair.new()
	cross.hud = self
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)
	# signals
	Score.score_changed.connect(_on_score)
	Score.combo_changed.connect(_on_combo)
	Score.combo_ended.connect(_on_combo_end)
	Score.points_popup.connect(_on_points)
	Events.weapon_changed.connect(_on_weapon)
	Events.ability_changed.connect(_on_ability)
	Events.hint.connect(show_hint)
	Events.objective_changed.connect(_on_objective)
	Events.player_died.connect(_on_player_died)
	_on_score(Score.score)
	_on_combo(0, 0.0, 1.0)

func _lbl(pos: Vector2, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", UIStyle.INK)
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l

func _build_death() -> void:
	death_panel = Control.new()
	death_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_panel.visible = false
	root.add_child(death_panel)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.3, 0.0, 0.08, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_panel.add_child(shade)
	death_title = UIStyle.title_label("CUT!", 72, UIStyle.HOT)
	death_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_title.add_theme_color_override("font_outline_color", UIStyle.INK)
	death_title.add_theme_constant_override("outline_size", 12)
	UIStyle.place(death_title, Control.PRESET_CENTER, Vector2(-480, -80), Vector2(960, 90))
	death_panel.add_child(death_title)
	death_sub = UIStyle.label("[R] RESTART", 20, UIStyle.PAPER, true)
	death_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_sub.add_theme_color_override("font_outline_color", UIStyle.INK)
	death_sub.add_theme_constant_override("outline_size", 6)
	UIStyle.place(death_sub, Control.PRESET_CENTER, Vector2(-480, 20), Vector2(960, 30))
	death_panel.add_child(death_sub)

func _build_map() -> void:
	map_panel = PanelContainer.new()
	map_panel.visible = false
	UIStyle.place(map_panel, Control.PRESET_CENTER, Vector2(-260, -150), Vector2(520, 300))
	root.add_child(map_panel)
	map_text = UIStyle.label("", 15)
	map_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_panel.add_child(map_text)

# ------------------------------------------------------------ updates
func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.03)
	if player and is_instance_valid(player):
		prompt_label.text = player.prompt if player.alive else ""
		if player.is_reloading():
			prompt_label.text = "RELOADING..."
		equip_label.text = "FLARES %d   [%s]" % [player.equipment_left, InputSetup.binding_text("equipment", InputSetup.using_gamepad)]
	if _hint_t > 0.0:
		_hint_t -= rd
		hint_label.modulate.a = clampf(_hint_t * 2.0, 0.0, 1.0)
	if _banner_t > 0.0:
		_banner_t -= rd
		banner.modulate.a = clampf(_banner_t * 1.5, 0.0, 1.0)
	if _card_t > 0.0:
		_card_t -= rd
		card_sub.modulate.a = clampf(_card_t * 1.5, 0.0, 1.0)
	_combo_pulse = move_toward(_combo_pulse, 0.0, rd * 4.0)
	combo_label.scale = Vector2.ONE * (1.0 + _combo_pulse * 0.35)
	var show_map := Input.is_action_pressed("map")
	map_panel.visible = show_map
	if show_map and level:
		map_text.text = level.objectives_text()
	if level and level.boss and is_instance_valid(level.boss) and level.boss.active and level.boss.is_alive():
		boss_label.visible = true
		var b: BossNightManager = level.boss
		var pips := "◆".repeat(b.armor_left) + "◇".repeat(maxi(0, b.data.armor - b.armor_left))
		boss_label.text = "LYLE HARCOURT — NIGHT MANAGER   %s" % (pips if b.phase == 1 else "LIGHTS OUT")
	else:
		boss_label.visible = false

func _on_objective(t: String) -> void:
	objective_label.text = t

func show_hint(text: String, duration := 3.0) -> void:
	hint_label.text = text
	_hint_t = duration
	hint_label.modulate.a = 1.0

func show_banner(text: String, duration := 2.5, color := UIStyle.PAPER) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	_banner_t = duration
	banner.modulate.a = 1.0

## Mission title card: big pink title, VHS-style details beneath.
func show_title_card(title: String, sub: String, duration := 3.6) -> void:
	show_banner(title, duration, UIStyle.PINK)
	banner.add_theme_font_size_override("font_size", 56)
	card_sub.text = sub
	_card_t = duration
	card_sub.modulate.a = 1.0
	await get_tree().create_timer(duration).timeout
	banner.add_theme_font_size_override("font_size", 40)

func _on_score(s: int) -> void:
	score_label.text = "%d PTS" % s

func _on_combo(count: int, t: float, window: float) -> void:
	combo_label.visible = count >= 2
	combo_bar.visible = count >= 2
	if count >= 2:
		combo_label.text = "%dx COMBO" % count
		combo_bar.size.x = 120.0 * clampf(t / window, 0.0, 1.0)
		if count != _last_combo:
			_combo_pulse = 1.0
	_last_combo = count

func _on_combo_end(count: int, bonus: int) -> void:
	if count >= 3:
		show_banner("%dx COMBO\n+%d" % [count, bonus], 1.2, UIStyle.GOLD)

func _on_points(text: String, pts: int, pos: Vector2) -> void:
	Effects.popup("%s +%d" % [text, pts] if pts >= 0 else "%s %d" % [text, pts], pos, UIStyle.GOLD if pts >= 0 else UIStyle.HOT)

func _on_weapon(id: StringName, ammo: int, reserve: int) -> void:
	if player == null:
		return
	var w := player.current()
	if w == null:
		weapon_label.text = "FISTS"
		ammo_label.text = ""
	elif w.data.is_firearm():
		weapon_label.text = w.data.display_name.to_upper()
		ammo_label.text = "%d / %d" % [w.ammo, w.reserve]
		ammo_label.add_theme_color_override("font_color", UIStyle.HOT if w.ammo == 0 else UIStyle.PINK)
	else:
		weapon_label.text = w.data.display_name.to_upper()
		ammo_label.text = "∞" if w.durability < 0 else "%d HITS" % w.durability
		ammo_label.add_theme_color_override("font_color", UIStyle.PINK)
	var other = player.slots[1 - player.slot]
	holster_label.text = ("[%s] %s" % [InputSetup.binding_text("swap", InputSetup.using_gamepad), (other as WeaponInstance).data.display_name]) if other else ""

func _on_ability(charge: float, active: bool) -> void:
	ability_bar.size.x = 160.0 * clampf(charge, 0.0, 1.0)
	ability_bar.color = Color.WHITE if active else (UIStyle.GOLD if charge >= 0.999 else Color(UIStyle.GOLD, 0.5))
	var nm := player.ability.display_name() if player else "ABILITY"
	ability_label.text = "%s  [%s]%s" % [nm, InputSetup.binding_text("ability", InputSetup.using_gamepad), "  READY" if charge >= 0.999 and not active else ""]

func _on_player_died(_info: Dictionary) -> void:
	death_panel.visible = true
	death_title.text = DEATH_LINES[randi() % DEATH_LINES.size()]
	death_sub.text = "[%s] RESTART" % InputSetup.binding_text("restart", InputSetup.using_gamepad)
	death_title.scale = Vector2(1.4, 1.4)
	death_title.pivot_offset = death_title.size * 0.5
	var tw := create_tween()
	tw.tween_property(death_title, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Mouse / aim reticle.
class Crosshair extends Control:
	var hud: HUD
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		if hud == null or hud.player == null or not is_instance_valid(hud.player) or not hud.player.alive:
			return
		if get_tree().paused:
			return
		var lt: Node2D = hud.player.lock_target
		if lt and is_instance_valid(lt):
			var tp := hud.player.get_viewport().get_canvas_transform() * lt.global_position
			var rr := 14.0 + sin(_t * 8.0) * 1.5
			var rot := _t * 2.0
			for i in 4:
				var a0 := rot + i * PI * 0.5
				var c0 := tp + Vector2.from_angle(a0) * rr
				var arm1 := Vector2.from_angle(a0 + 2.4) * 6.0
				var arm2 := Vector2.from_angle(a0 - 2.4) * 6.0
				draw_polyline(PackedVector2Array([c0 + arm1, c0, c0 + arm2]), UIStyle.INK, 4.0)
				draw_polyline(PackedVector2Array([c0 + arm1, c0, c0 + arm2]), UIStyle.HOT, 2.0)
			draw_circle(tp, 2.0, UIStyle.HOT)
			var pp := hud.player.get_viewport().get_canvas_transform() * hud.player.global_position
			draw_dashed_line(pp + (tp - pp).normalized() * 16.0, tp - (tp - pp).normalized() * 18.0, Color(UIStyle.HOT, 0.35), 1.0, 4.0)
			return
		var p: Vector2
		if InputSetup.using_gamepad:
			p = hud.player.get_viewport().get_canvas_transform() * hud.player.aim_point
		else:
			p = get_local_mouse_position()
		var spread := 4.0 + hud.player._bloom * 0.6
		var c := UIStyle.PINK
		var w := hud.player.current()
		if w and w.data.is_firearm() and w.ammo == 0:
			c = Color(0.6, 0.6, 0.6)
		for a in 4:
			var d := Vector2.from_angle(a * PI * 0.5 + PI * 0.25)
			draw_line(p + d * spread, p + d * (spread + 5.0), UIStyle.INK, 4.0)
			draw_line(p + d * spread, p + d * (spread + 5.0), c, 2.0)
		draw_circle(p, 1.5, UIStyle.PAPER)


## Arrow to the nearest remaining enemy when only a few are left.
class Tracker extends Control:
	var hud: HUD
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if hud == null or hud.level == null or hud.player == null or not is_instance_valid(hud.player) or not hud.player.alive:
			return
		var remaining: Array = hud.level.remaining_enemies()
		if remaining.is_empty() or remaining.size() > 3:
			return
		var ct := hud.player.get_viewport().get_canvas_transform()
		var pp := ct * hud.player.global_position
		for e in remaining:
			var ep: Vector2 = ct * (e as Node2D).global_position
			var d := ep - pp
			if d.length() < 140.0:
				continue
			var dir := d.normalized()
			var tip := pp + dir * 70.0
			var pts := PackedVector2Array([tip, tip - dir * 10.0 + dir.orthogonal() * 5.0, tip - dir * 10.0 - dir.orthogonal() * 5.0])
			draw_colored_polygon(pts, Color(UIStyle.HOT, 0.8))


## Bottom-left status: stealth state + collected upgrades.
class StatusPanel extends Control:
	var hud: HUD
	var _t := 0.0
	var _state := ""
	func _process(delta: float) -> void:
		_t += delta
		if Engine.get_process_frames() % 3 == 0:
			_state = _compute()
		queue_redraw()
	func _compute() -> String:
		var p := hud.player
		if p == null or not is_instance_valid(p) or not p.alive:
			return ""
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.is_alive() and e.is_aware() and e._sees_player:
				return "SPOTTED"
		if hud.level:
			var dk: int = hud.level.darkness_at(p.global_position)
			if dk == 2:
				return "HIDDEN"
			if dk == 1 and p.is_quiet():
				return "SHADOW"
		if p.velocity.length() > 8.0 and p.is_quiet():
			return "SNEAKING"
		return ""
	func _draw() -> void:
		if hud == null or hud.player == null or not is_instance_valid(hud.player):
			return
		var base := Vector2(22, size.y - 92)
		# stealth eye
		if _state != "":
			var col: Color = {"SPOTTED": UIStyle.HOT, "HIDDEN": UIStyle.CYAN, "SNEAKING": Color("b18cff"), "SHADOW": Color("7a8fb0")}[_state]
			var c := base + Vector2(10, 0)
			var open := 1.0 if _state == "SPOTTED" else (0.25 if _state == "HIDDEN" else (0.4 if _state == "SHADOW" else 0.6))
			var pts := PackedVector2Array()
			for i in 17:
				var a := PI * i / 16.0
				pts.append(c + Vector2(-cos(a) * 10.0, -sin(a) * 6.0 * open))
			for i in 17:
				var a := PI * i / 16.0
				pts.append(c + Vector2(cos(a) * 10.0, sin(a) * 6.0 * open))
			draw_colored_polygon(pts, UIStyle.INK)
			draw_polyline(pts, col, 2.0, true)
			if open > 0.3:
				draw_circle(c, 3.0 * open, col)
			var label: String = {"SPOTTED": "SPOTTED", "HIDDEN": "HIDDEN IN THE DARK", "SNEAKING": "SNEAKING", "SHADOW": "IN SHADOW"}[_state]
			var f := UIStyle.font_bold()
			draw_string_outline(f, base + Vector2(26, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 5, UIStyle.INK)
			draw_string(f, base + Vector2(26, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
		# upgrades row
		var x := 22.0
		var y := size.y - 118.0
		for id in hud.player.upgrades.keys():
			var d := Upgrades.def(id)
			var col2: Color = d.color
			if id == &"armor" and hud.player.armor_hits <= 0:
				col2 = Color(0.4, 0.4, 0.45)
			draw_rect(Rect2(x - 1, y - 1, 26, 16), UIStyle.INK)
			draw_rect(Rect2(x, y, 24, 14), Color(col2, 0.25))
			draw_rect(Rect2(x, y, 24, 14), col2, false, 1.0)
			draw_string(UIStyle.font_bold(), Vector2(x + 3, y + 11), str(d.icon), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col2)
			x += 30.0
