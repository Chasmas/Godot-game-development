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
		equip_label.text = tr("FLARES %d   [%s]") % [player.equipment_left, InputSetup.binding_text("equipment", InputSetup.using_gamepad)]
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
	# the ammo counter jolts on each shot
	_ammo_pulse = move_toward(_ammo_pulse, 0.0, rd * 10.0)
	ammo_label.pivot_offset = Vector2(400, 18)
	ammo_label.scale = Vector2.ONE * (1.0 + _ammo_pulse * 0.08)
	combo_label.scale = Vector2.ONE * (1.0 + _combo_pulse * 0.35)
	var show_map := Input.is_action_pressed("map")
	map_panel.visible = show_map
	if show_map and level:
		map_text.text = level.objectives_text()
	if level and level.boss and is_instance_valid(level.boss) and level.boss.active and level.boss.is_alive():
		boss_label.visible = true
		var b: BossNightManager = level.boss
		var pips := "◆".repeat(b.armor_left) + "◇".repeat(maxi(0, b.data.armor - b.armor_left))
		boss_label.text = tr("LYLE HARCOURT — NIGHT MANAGER   %s") % (pips if b.phase == 1 else tr("LIGHTS OUT"))
	else:
		boss_label.visible = false

func _on_objective(t: String) -> void:
	objective_label.text = t

## Upgrade pickup: an animated card (icon, name, what it does) instead of a
## line of text. The HUD badge for it pulses in at the same time.
var upgrade_times: Dictionary = {}
func show_upgrade(id: StringName) -> void:
	upgrade_times[id] = status.now() if status else 0.0
	var card := UpgradeCard.new()
	card.upgrade_id = id
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in root.get_children():
		if c is UpgradeCard:
			c.queue_free()
	root.add_child(card)

func show_hint(text: String, duration := 3.0) -> void:
	hint_label.text = tr(text)
	_hint_t = duration
	hint_label.modulate.a = 1.0

func show_banner(text: String, duration := 2.5, color := UIStyle.PAPER) -> void:
	banner.text = tr(text)
	banner.add_theme_color_override("font_color", color)
	_banner_t = duration
	banner.modulate.a = 1.0

## Mission title card: big pink title, VHS-style details beneath.
func show_title_card(title: String, sub: String, duration := 3.6) -> void:
	show_banner(tr(title), duration, UIStyle.PINK)
	banner.add_theme_font_size_override("font_size", 56)
	card_sub.text = sub
	_card_t = duration
	card_sub.modulate.a = 1.0
	await get_tree().create_timer(duration).timeout
	banner.add_theme_font_size_override("font_size", 40)

func _on_score(s: int) -> void:
	score_label.text = tr("%d PTS") % s

func _on_combo(count: int, t: float, window: float) -> void:
	combo_label.visible = count >= 2
	combo_bar.visible = count >= 2
	if count >= 2:
		combo_label.text = tr("%dx COMBO") % count
		combo_bar.size.x = 120.0 * clampf(t / window, 0.0, 1.0)
		if count != _last_combo:
			_combo_pulse = 1.0
	_last_combo = count

func _on_combo_end(count: int, bonus: int) -> void:
	if count >= 3:
		show_banner(tr("%dx COMBO\n+%d") % [count, bonus], 1.2, UIStyle.GOLD)

func _on_points(text: String, pts: int, pos: Vector2) -> void:
	Effects.popup("%s +%d" % [tr(text), pts] if pts >= 0 else "%s %d" % [tr(text), pts], pos, UIStyle.GOLD if pts >= 0 else UIStyle.HOT)

var _ammo_pulse := 0.0
var _last_ammo_shown := 0
var _last_weapon_shown: StringName = &""

func _on_weapon(id: StringName, ammo: int, reserve: int) -> void:
	if player == null:
		return
	_on_weapon_inner(id, ammo, reserve)
	_last_ammo_shown = ammo
	_last_weapon_shown = id

func _on_weapon_inner(id: StringName, ammo: int, reserve: int) -> void:
	var w := player.current()
	if w == null:
		weapon_label.text = "FISTS"
		ammo_label.text = ""
	elif w.data.is_firearm():
		weapon_label.text = ("2× " if w.dual else "") + tr(w.data.display_name).to_upper()
		if w.dual:
			ammo_label.text = "%d | %d / %d" % [w.ammo2, w.ammo, w.reserve]
		else:
			ammo_label.text = "%d / %d" % [w.ammo, w.reserve]
		ammo_label.add_theme_color_override("font_color", UIStyle.HOT if w.loaded() == 0 else UIStyle.PINK)
		if ammo > _last_ammo_shown or id != _last_weapon_shown:
			_ammo_pulse = 0.0
		elif ammo < _last_ammo_shown:
			_ammo_pulse = 1.0
	else:
		weapon_label.text = tr(w.data.display_name).to_upper()
		ammo_label.text = "∞" if w.durability < 0 else tr("%d HITS") % w.durability
		ammo_label.add_theme_color_override("font_color", UIStyle.PINK)
	var other = player.slots[1 - player.slot]
	holster_label.text = ("[%s] %s" % [InputSetup.binding_text("swap", InputSetup.using_gamepad), tr((other as WeaponInstance).data.display_name)]) if other else ""

func _on_ability(charge: float, active: bool) -> void:
	ability_bar.size.x = 160.0 * clampf(charge, 0.0, 1.0)
	ability_bar.color = Color.WHITE if active else (UIStyle.GOLD if charge >= 0.999 else Color(UIStyle.GOLD, 0.5))
	var nm := player.ability.display_name() if player else "ABILITY"
	ability_label.text = "%s  [%s]%s" % [tr(nm), InputSetup.binding_text("ability", InputSetup.using_gamepad), tr("  READY") if charge >= 0.999 and not active else ""]

func _on_player_died(_info: Dictionary) -> void:
	death_panel.visible = true
	death_title.text = DEATH_LINES[randi() % DEATH_LINES.size()]
	death_sub.text = tr("[%s] RESTART") % InputSetup.binding_text("restart", InputSetup.using_gamepad)
	death_title.scale = Vector2(1.4, 1.4)
	death_title.pivot_offset = death_title.size * 0.5
	var tw := create_tween()
	tw.tween_property(death_title, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Mouse / aim reticle.
class Crosshair extends Control:
	var hud: HUD
	var _t := 0.0
	var _hit := 0.0      ## white X: a shot connected
	var _kill := 0.0     ## red X: it was a kill
	var _kick := 0.0     ## reticle opens on each shot
	func _ready() -> void:
		Events.player_fired.connect(func(_w, hit): 
			_kick = 1.0
			if hit:
				_hit = 1.0)
		Events.enemy_killed.connect(func(_e, _i): _kill = 1.0)
	func _process(delta: float) -> void:
		var rd := delta / maxf(Engine.time_scale, 0.03)
		_t += delta
		_hit = move_toward(_hit, 0.0, rd * 5.0)
		_kill = move_toward(_kill, 0.0, rd * 2.8)
		_kick = move_toward(_kick, 0.0, rd * 12.0)
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
		var spread := 4.0 + hud.player._bloom * 0.6 + _kick * 3.0
		var c := UIStyle.PINK
		var w := hud.player.current()
		if w and w.data.is_firearm() and w.loaded() == 0:
			c = Color(0.6, 0.6, 0.6)
		if hud.player.is_reloading():
			# reload progress ring
			var k := 1.0 - hud.player._reload_t / maxf(0.01, w.data.reload_time * hud.player.data.reload_mult * (Player.DUAL_RELOAD if w.dual else 1.0)) if w else 0.0
			draw_arc(p, spread + 7.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(k, 0.0, 1.0), 24, Color(UIStyle.CYAN, 0.8), 2.0)
		for a in 4:
			var d := Vector2.from_angle(a * PI * 0.5 + PI * 0.25)
			draw_line(p + d * spread, p + d * (spread + 5.0), UIStyle.INK, 4.0)
			draw_line(p + d * spread, p + d * (spread + 5.0), c, 2.0)
		if w and w.dual:
			# twin brackets for two guns
			for sgn in [-1.0, 1.0]:
				var bx := p + Vector2(sgn * (spread + 9.0), 0)
				draw_polyline(PackedVector2Array([bx + Vector2(-sgn * 3, -5), bx + Vector2(0, -5), bx + Vector2(0, 5), bx + Vector2(-sgn * 3, 5)]), UIStyle.INK, 3.0)
				draw_polyline(PackedVector2Array([bx + Vector2(-sgn * 3, -5), bx + Vector2(0, -5), bx + Vector2(0, 5), bx + Vector2(-sgn * 3, 5)]), c, 1.4)
		draw_circle(p, 1.5, UIStyle.PAPER)
		# hit / kill confirmation
		var mk := maxf(_hit, _kill)
		if mk > 0.0:
			var col := Color(UIStyle.HOT, _kill) if _kill > 0.0 else Color(1, 1, 1, _hit)
			var r0 := 5.0 + (1.0 - mk) * 3.0
			for a in 4:
				var d := Vector2.from_angle(a * PI * 0.5 + PI * 0.25)
				draw_line(p + d * r0, p + d * (r0 + 5.0 + _kill * 3.0), Color(UIStyle.INK, col.a), 3.5)
				draw_line(p + d * r0, p + d * (r0 + 5.0 + _kill * 3.0), col, 1.6)
		# easy mode guard pips next to the reticle
		var gmax := int(Difficulty.value("player_guard_hits"))
		for i in gmax:
			var filled := i < hud.player.guard_hits
			var gp := p + Vector2(spread + 12.0 + i * 7.0, 8.0)
			draw_rect(Rect2(gp - Vector2(2.5, 2.5), Vector2(5, 5)), UIStyle.INK)
			draw_rect(Rect2(gp - Vector2(2, 2), Vector2(4, 4)), UIStyle.CYAN if filled else Color(0.4, 0.4, 0.45))


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
	func now() -> float:
		return _t
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
			var label: String = tr({"SPOTTED": "SPOTTED", "HIDDEN": "HIDDEN IN THE DARK", "SNEAKING": "SNEAKING", "SHADOW": "IN SHADOW"}[_state])
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
			var bc := Vector2(x + 14, y + 2)
			var fresh := clampf(1.0 - (_t - float(hud.upgrade_times.get(id, -9.0))) / 0.6, 0.0, 1.0)
			UpgradeIcon.badge(self, bc, 15.0 + fresh * 6.0, col2, _t, 0.6 + fresh)
			UpgradeIcon.draw(self, id, bc, 21.0 + fresh * 6.0, col2, _t)
			x += 36.0


## "UPGRADE" pickup card: slides in on the right with a flash and a shine,
## the icon pops out of its hex badge, the text types in, then it slides
## away. Runs in real time so slow-mo doesn't stretch it.
class UpgradeCard extends Control:
	var upgrade_id: StringName
	var _t := 0.0
	const LIFE := 3.4
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _process(delta: float) -> void:
		_t += delta / maxf(Engine.time_scale, 0.05)
		if _t > LIFE:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var d := Upgrades.def(upgrade_id)
		var col: Color = d.color
		var w := 360.0
		var h := 96.0
		var slide_in := 1.0 - pow(1.0 - clampf(_t / 0.35, 0.0, 1.0), 3.0)
		var slide_out := pow(clampf((_t - (LIFE - 0.4)) / 0.4, 0.0, 1.0), 2.0)
		var x := size.x - 24.0 - w * slide_in + (w + 40.0) * slide_out
		var y := size.y * 0.30
		var r := Rect2(x, y, w, h)
		# slanted card body with a coloured spine
		var sk := 14.0
		var body := PackedVector2Array([r.position + Vector2(sk, 0), Vector2(r.end.x, r.position.y), Vector2(r.end.x - sk, r.end.y), Vector2(r.position.x, r.end.y)])
		draw_colored_polygon(body, Color(UIStyle.INK, 0.94))
		var spine := PackedVector2Array([r.position + Vector2(sk, 0), r.position + Vector2(sk + 8, 0), Vector2(r.position.x + 8, r.end.y), Vector2(r.position.x, r.end.y)])
		draw_colored_polygon(spine, col)
		var outline := body.duplicate()
		outline.append(body[0])
		draw_polyline(outline, Color(col, 0.8), 1.5, true)
		# scanlines
		for sy in range(int(r.position.y) + 2, int(r.end.y), 3):
			draw_line(Vector2(r.position.x + 10, sy), Vector2(r.end.x - 4, sy), Color(1, 1, 1, 0.025), 1.0)
		# flash on arrival
		var fl := clampf(1.0 - _t / 0.25, 0.0, 1.0)
		if fl > 0.0:
			draw_colored_polygon(body, Color(col.lightened(0.6), fl * 0.7))
		# shine sweep
		var sh := fmod(_t * 0.9, 2.2) - 0.3
		if sh >= 0.0 and sh <= 1.0:
			var sx := r.position.x + sh * (w + 60.0) - 30.0
			draw_colored_polygon(PackedVector2Array([Vector2(sx, r.position.y), Vector2(sx + 18, r.position.y), Vector2(sx + 4, r.end.y), Vector2(sx - 14, r.end.y)]), Color(1, 1, 1, 0.07))
		# icon pops out of its badge
		var ic := r.position + Vector2(62, h * 0.5)
		var pop := clampf((_t - 0.12) / 0.3, 0.0, 1.0)
		var bounce := 1.0 + sin(pop * PI) * 0.25
		UpgradeIcon.badge(self, ic, 34.0 * bounce, col, _t, 1.0)
		UpgradeIcon.draw(self, upgrade_id, ic, 44.0 * pop * bounce, col, _t)
		# sparks around the badge
		for i in 8:
			var a := i * TAU / 8.0 + _t * 0.6
			var k := fmod(_t * 1.3 + i * 0.125, 1.0)
			draw_circle(ic + Vector2.from_angle(a) * (38.0 + k * 16.0), 1.6 * (1.0 - k), Color(col.lightened(0.4), 1.0 - k))
		# text
		var f := UIStyle.font_bold()
		var tx := r.position.x + 112.0
		var tag := tr("UPGRADE")
		draw_string(f, Vector2(tx, r.position.y + 22), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(col, 0.9))
		var name_s := tr(str(d.name))
		var n := clampi(int((_t - 0.15) * 40.0), 0, name_s.length())
		draw_string_outline(UIStyle.font_display(), Vector2(tx, r.position.y + 50), name_s.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, UIStyle.INK)
		draw_string(UIStyle.font_display(), Vector2(tx, r.position.y + 50), name_s.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UIStyle.PAPER)
		var da := clampf((_t - 0.5) / 0.3, 0.0, 1.0)
		draw_multiline_string(f, Vector2(tx, r.position.y + 70), tr(str(d.desc)), HORIZONTAL_ALIGNMENT_LEFT, w - 130.0, 12, 2, Color(UIStyle.PAPER, 0.75 * da))
