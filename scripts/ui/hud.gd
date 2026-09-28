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
var weapon_icon: TextureRect
static var _icons: Dictionary = {}
var holster_label: Label
var ability_label: Label
var ability_bar: ColorRect
var meter: AbilityMeter
var tutorials: TutorialCards
var boss_bar: BossBar
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
	beat_meter = BeatMeter.new()
	beat_meter.position = Vector2(26, 94)
	beat_meter.size = Vector2(160, 40)
	beat_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(beat_meter)
	tips = TipCard.new()
	tips.hud = self
	tips.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tips)
	rec = RecOverlay.new()
	rec.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rec)
	# --- weapon (top right)
	# the painted icon of what's in her hands, name and ammo to its left
	weapon_icon = TextureRect.new()
	weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(weapon_icon)
	UIStyle.place(weapon_icon, Control.PRESET_TOP_RIGHT, Vector2(-156, 10), Vector2(140, 70))
	weapon_icon.pivot_offset = Vector2(70, 35)
	# the weapon's name sits under its picture, the ammo count beside it
	weapon_label = _lbl(Vector2(0, 14), 18, UIStyle.PAPER, UIStyle.font_bold())
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.place(weapon_label, Control.PRESET_TOP_RIGHT, Vector2(-172, 80), Vector2(172, 24))
	weapon_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ammo_label = _lbl(Vector2(-566, 28), 28, UIStyle.PINK, UIStyle.font_display())
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIStyle.place(ammo_label, Control.PRESET_TOP_RIGHT, Vector2(-566, 28), Vector2(400, 36))
	holster_label = _lbl(Vector2(-420, 106), 13, UIStyle.DIM, UIStyle.font_mono())
	holster_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIStyle.place(holster_label, Control.PRESET_TOP_RIGHT, Vector2(-420, 106), Vector2(400, 18))
	# --- ability (bottom left)
	# the meter draws itself; the old label/bar stay (hidden) for anything
	# that still reads them
	ability_label = _lbl(Vector2(22, 0), 17, UIStyle.GOLD, UIStyle.font_display())
	UIStyle.place(ability_label, Control.PRESET_BOTTOM_LEFT, Vector2(22, -58))
	ability_label.visible = false
	ability_bg = ColorRect.new()
	ability_bg.visible = false
	root.add_child(ability_bg)
	ability_bar = ColorRect.new()
	ability_bar.visible = false
	root.add_child(ability_bar)
	boss_bar = BossBar.new()
	UIStyle.place(boss_bar, Control.PRESET_CENTER_TOP, Vector2(-330, 64), Vector2(660, 64))
	root.add_child(boss_bar)
	Events.boss_hp.connect(boss_bar.on_hp)
	tutorials = TutorialCards.new()
	UIStyle.place(tutorials, Control.PRESET_TOP_RIGHT, Vector2(-404, 132), Vector2(388, 560))
	root.add_child(tutorials)
	Events.tutorial.connect(func(id): tutorials.show_card(id))
	meter = AbilityMeter.new()
	UIStyle.place(meter, Control.PRESET_BOTTOM_LEFT, Vector2(16, -108), Vector2(310, 74))
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(meter)
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
	# bound methods, not lambdas: autoload signals must let go of a freed HUD
	Score.finisher.connect(_on_finisher)
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
		if player.bones > 0:
			equip_label.text = tr("MEAT BONES %d   [%s]") % [player.bones, InputSetup.binding_text("equipment", InputSetup.using_gamepad)]
		else:
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

var beat_meter: BeatMeter
var rec: RecOverlay
var tips: TipCard

## A one-time tutorial note ("DIRECTOR'S NOTE"): shown the first time its
## situation comes up in this save, never again. {action} names in the text
## become the player's current bindings.
func tip(id: String, text: String) -> void:
	if tips:
		tips.offer(id, text)

func _on_finisher(_pos: Vector2) -> void:
	rec.roll()

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

## Checkpoint saved: a small stamp slides in bottom-right - spinning reel,
## "TAPE SAVED", the area's name - and slides away.
func show_checkpoint(area: String, rewind := false) -> void:
	var st := CheckpointStamp.new()
	st.area = area
	st.rewind = rewind
	st.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in root.get_children():
		if c is CheckpointStamp:
			c.queue_free()
	root.add_child(st)
	Audio.play("tape_rewind" if rewind else "tape_insert", -8.0)

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
	var icon_id := "fists" if w == null else str(w.data.id)
	var tex := weapon_icon_tex(icon_id)
	if weapon_icon.texture != tex:
		weapon_icon.texture = tex
		# a new weapon in hand: the icon punches in
		weapon_icon.scale = Vector2.ONE * 1.35
		weapon_icon.modulate = Color(2.0, 2.0, 2.0)
		var tw := create_tween().set_parallel()
		tw.tween_property(weapon_icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(weapon_icon, "modulate", Color.WHITE, 0.3)
	if w == null:
		weapon_label.text = tr("FISTS")
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

static func weapon_icon_tex(id: String) -> Texture2D:
	if not _icons.has(id):
		var p := "res://assets/art/weapons/%s.png" % id
		_icons[id] = load(p) if ResourceLoader.exists(p) else null
	return _icons[id]

var _spot: SpotlightFX
var _was_active := false

func _on_ability(charge: float, active: bool) -> void:
	if active and not _was_active and player and player.ability.id == &"spotlight":
		_spot = SpotlightFX.new()
		_spot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(_spot)
		root.move_child(_spot, 0)
	if _spot and is_instance_valid(_spot):
		_spot.left = charge if active else 0.0
		if not active:
			_spot.finish()
			_spot = null
	_was_active = active
	ability_bar.size.x = 160.0 * clampf(charge, 0.0, 1.0)
	ability_bar.color = Color.WHITE if active else (UIStyle.GOLD if charge >= 0.999 else Color(UIStyle.GOLD, 0.5))
	var nm := player.ability.display_name() if player else "ABILITY"
	ability_label.text = "%s  [%s]%s" % [tr(nm), InputSetup.binding_text("ability", InputSetup.using_gamepad), tr("  READY") if charge >= 0.999 and not active else ""]
	if meter:
		meter.title = tr(nm)
		meter.key = InputSetup.binding_text("ability", InputSetup.using_gamepad)
		if charge >= 0.999 and meter.charge < 0.999 and not active:
			meter.ready_flash = 1.0
			tutorials.show_card("spotlight")
			Audio.play("power_up", -10.0)
		meter.charge = charge
		meter.active = active

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
		_lock_t += rd
		queue_redraw()
	var _lock_prev: Node2D = null
	var _lock_t := 0.0
	## Small marker over the locked enemy's head: a bobbing pink chevron with
	## a tick, so you can see at a glance who your shots will follow.
	func _draw_lock_marker(tp: Vector2) -> void:
		var z := hud.player.get_viewport().get_canvas_transform().get_scale().y
		var k := clampf(_lock_t / 0.2, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var head := tp + Vector2(0, -14.0 * z - 10.0 - sin(_t * 5.0) * 2.0 - (1.0 - e) * 14.0)
		var w := 7.0
		var pts := PackedVector2Array([head + Vector2(-w, -6), head + Vector2(0, 2), head + Vector2(w, -6), head + Vector2(0, -2)])
		draw_colored_polygon(pts, Color(UIStyle.INK, 0.9 * e))
		var inner := PackedVector2Array([head + Vector2(-w + 2, -5), head + Vector2(0, 0), head + Vector2(w - 2, -5), head + Vector2(0, -2.5)])
		draw_colored_polygon(inner, Color(UIStyle.HOT, e))
		draw_rect(Rect2(head + Vector2(-1, -12), Vector2(2, 4)), Color(UIStyle.PAPER, e * (0.6 + 0.4 * sin(_t * 10.0))))
		if _lock_t < 0.35:
			draw_arc(head + Vector2(0, -3), 6.0 + _lock_t * 50.0, 0, TAU, 20, Color(UIStyle.HOT, 1.0 - _lock_t / 0.35), 1.5)

	func _draw() -> void:
		if hud == null or hud.player == null or not is_instance_valid(hud.player) or not hud.player.alive:
			return
		if get_tree().paused:
			return
		var lt: Node2D = hud.player.lock_target
		if lt != _lock_prev:
			_lock_prev = lt
			_lock_t = 0.0
		if lt and is_instance_valid(lt):
			var tp := hud.player.get_viewport().get_canvas_transform() * lt.global_position
			_draw_lock_marker(tp)
			# brackets snap in from wide when the lock is acquired
			var snap := 1.0 - clampf(_lock_t / 0.18, 0.0, 1.0)
			var rr := 14.0 + sin(_t * 8.0) * 1.5 + snap * snap * 26.0
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
		# the last few: a pulsing chevron round the player and, off screen,
		# a marker on the screen edge with the distance in metres
		var t := Time.get_ticks_msec() / 1000.0
		var pulse := 0.6 + 0.4 * sin(t * 5.0)
		var vr := Rect2(Vector2.ZERO, size).grow(-34.0)
		for e in remaining:
			var ep: Vector2 = ct * (e as Node2D).global_position
			var d := ep - pp
			if d.length() < 140.0:
				continue
			var dir := d.normalized()
			var tip := pp + dir * (72.0 + 4.0 * sin(t * 6.0))
			var pts := PackedVector2Array([tip, tip - dir * 14.0 + dir.orthogonal() * 7.0, tip - dir * 14.0 - dir.orthogonal() * 7.0])
			draw_colored_polygon(pts, Color(UIStyle.HOT, 0.85 * pulse))
			if not vr.has_point(ep):
				var k := 1.0
				if absf(d.x) > 0.001:
					k = minf(k, (vr.size.x * 0.5) / absf(d.x) if d.x != 0.0 else k)
				if absf(d.y) > 0.001:
					k = minf(k, (vr.size.y * 0.5) / absf(d.y))
				var edge := vr.get_center() + d * k
				edge = Vector2(clampf(edge.x, vr.position.x, vr.end.x), clampf(edge.y, vr.position.y, vr.end.y))
				draw_circle(edge, 11.0, Color(0.05, 0.0, 0.08, 0.7))
				draw_arc(edge, 11.0, 0.0, TAU, 20, Color(UIStyle.HOT, pulse), 2.0)
				draw_colored_polygon(PackedVector2Array([edge + dir * 7.0, edge - dir * 3.0 + dir.orthogonal() * 5.0, edge - dir * 3.0 - dir.orthogonal() * 5.0]), UIStyle.HOT)
				var m := int((e as Node2D).global_position.distance_to(hud.player.global_position) / 16.0)
				draw_string(UIStyle.font_bold(), edge + Vector2(-14, 26), "%dm" % m, HORIZONTAL_ALIGNMENT_CENTER, 28, 12, UIStyle.PAPER)


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
		var base := Vector2(26, size.y - 126)   # above the SPOTLIGHT meter
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


## Combo tier callouts under the combo counter (HOT / ON FIRE /
## SHOWSTOPPER) and the FINAL TAKE reminder.
class BeatMeter extends Control:
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var combo := Score.combo
		var tier := ""
		if combo >= 12:
			tier = "SHOWSTOPPER"
		elif combo >= 8:
			tier = "ON FIRE"
		elif combo >= 5:
			tier = "HOT"
		if tier != "":
			var wob := sin(Time.get_ticks_msec() * 0.012) * 1.5
			draw_string_outline(UIStyle.font_display(), Vector2(0, 20 + wob), tr(tier), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, UIStyle.INK)
			draw_string(UIStyle.font_display(), Vector2(0, 20 + wob), tr(tier), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIStyle.HOT if combo >= 8 else UIStyle.GOLD)
			if combo >= 8 and not Score._finisher_used:
				draw_string(UIStyle.font_mono(), Vector2(0, 34), tr("MELEE KILL = FINAL TAKE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(UIStyle.PAPER, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)))


## The finisher: camcorder REC frame, blinking dot, timecode, while the
## world slows for a beat.
class RecOverlay extends Control:
	var _t := -1.0
	const LIFE := 1.6
	func roll() -> void:
		_t = 0.0
		Audio.play("rec_beep", -4.0)
	func _process(delta: float) -> void:
		if _t < 0.0:
			return
		_t += delta / maxf(Engine.time_scale, 0.05)
		if _t > LIFE:
			_t = -1.0
		queue_redraw()
	func _draw() -> void:
		if _t < 0.0:
			return
		var a := clampf(minf(_t / 0.1, (LIFE - _t) / 0.3), 0.0, 1.0)
		var m := 40.0
		var L := 46.0
		var c := Color(1, 1, 1, 0.85 * a)
		for corner in [Vector2(m, m), Vector2(size.x - m, m), Vector2(m, size.y - m), Vector2(size.x - m, size.y - m)]:
			var sx := 1.0 if corner.x < size.x * 0.5 else -1.0
			var sy := 1.0 if corner.y < size.y * 0.5 else -1.0
			draw_line(corner, corner + Vector2(L * sx, 0), c, 3.0)
			draw_line(corner, corner + Vector2(0, L * sy), c, 3.0)
		if fmod(_t, 0.5) < 0.3:
			draw_circle(Vector2(m + 24, m + 30), 8.0, Color(1, 0.1, 0.15, a))
		draw_string(UIStyle.font_bold(), Vector2(m + 40, m + 37), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, c)
		draw_string(UIStyle.font_display(), Vector2(size.x * 0.5 - 120, size.y - m - 12), tr("FINAL TAKE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(UIStyle.PINK, a))
		var fr := int(_t * 30.0)
		draw_string(UIStyle.font_mono(), Vector2(size.x - m - 150, m + 37), "00:00:%02d:%02d" % [fr / 30, fr % 30], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)


## DIRECTOR'S NOTE cards: short tutorial bits the first time something
## happens, slid in on the right like a note clipped to the script, text
## popping in letter by letter. One at a time, queued, each once per save.
## The watcher checks the situations a few times a second.
class TipCard extends Control:
	var hud: HUD
	var _queue: Array = []
	var _cur: Dictionary = {}
	var _t := 0.0
	var _check_t := 0.0
	var _level_t := 0.0
	var _clack_i := -1
	const CPS := 60.0

	## `face`: a painted portrait (assets/characters/portraits/<face>.png)
	## pinned to the note - the first look at a new kind of enemy.
	func offer(id: String, text: String, face := "") -> void:
		if not bool(SaveManager.get_setting("tips", true)):
			return
		if bool(SaveManager.get_flag("tip_" + id, false)):
			return
		if _cur.get("id", "") == id:
			return
		for q in _queue:
			if q.id == id:
				return
		SaveManager.set_flag("tip_" + id, true)
		_queue.append({"id": id, "text": _bind(tr(text)), "face": face})

	## "{fire}" -> the binding for that action on the current device
	static func _bind(t: String) -> String:
		var out := t
		for a in ["fire", "secondary", "dash", "interact", "swap", "reload", "lock_on", "sneak", "execute", "ability", "equipment"]:
			if out.contains("{" + a + "}"):
				out = out.replace("{" + a + "}", "[" + InputSetup.binding_text(a, InputSetup.using_gamepad) + "]")
		return out

	func _process(delta: float) -> void:
		var rd := delta / maxf(Engine.time_scale, 0.05)
		_level_t += rd
		_check_t -= rd
		if _check_t <= 0.0:
			_check_t = 0.25
			_watch()
		if _cur.is_empty():
			if not _queue.is_empty():
				_cur = _queue.pop_front()
				_t = 0.0
				_clack_i = -1
				Audio.play("ui_move", -10.0, 0.8)
		else:
			_t += rd
			var life: float = 2.8 + str(_cur.text).length() / 26.0
			var n := int((_t - 0.25) * CPS)
			if n != _clack_i and n > 0 and n < _cur.text.length() and n % 3 == 0:
				_clack_i = n
				Audio.play("type_clack", -22.0, randf_range(0.9, 1.1))
			if _t > life:
				_cur = {}
		queue_redraw()

	func _draw() -> void:
		if _cur.is_empty():
			return
		var text: String = _cur.text
		var life := 2.8 + text.length() / 26.0
		var face_tex: Texture2D = _face(str(_cur.get("face", "")))
		var fw := 74.0 if face_tex else 0.0
		var w := 330.0 + fw
		var f := UIStyle.font_mono()
		var fs := 13
		var lines := BarkLayer._wrap(f, text, fs, w - 34.0 - fw)
		var lh := f.get_height(fs)
		var h := maxf(34.0 + lines.size() * lh + 12.0, 96.0 if face_tex else 0.0)
		var slide := 1.0 - pow(1.0 - clampf(_t / 0.3, 0.0, 1.0), 3.0)
		var out := pow(clampf((_t - (life - 0.35)) / 0.35, 0.0, 1.0), 2.0)
		var x := size.x - 20.0 - w * slide + (w + 30.0) * out
		var y := 104.0
		var r := Rect2(x, y, w, h)
		draw_set_transform(r.get_center(), -0.012 * (1.0 - slide) - 0.01, Vector2.ONE)
		var lr := Rect2(-r.size * 0.5, r.size)
		# the note: dark card, gold spine, a paper-clip, a tiny slate icon
		draw_rect(Rect2(lr.position + Vector2(4, 5), lr.size), Color(0, 0, 0, 0.35))
		draw_rect(lr, Color(UIStyle.INK, 0.93))
		draw_rect(Rect2(lr.position, Vector2(4, lr.size.y)), UIStyle.GOLD)
		draw_rect(lr, Color(UIStyle.GOLD, 0.35), false, 1.0)
		var clip := lr.position + Vector2(lr.size.x - 34, -6)
		draw_rect(Rect2(clip, Vector2(10, 18)), Color(0.75, 0.75, 0.8), false, 1.5)
		var sl := lr.position + Vector2(14, 10)
		draw_rect(Rect2(sl + Vector2(0, 4), Vector2(16, 10)), UIStyle.PAPER)
		for i in 3:
			draw_line(sl + Vector2(2 + i * 5, 0), sl + Vector2(5 + i * 5, 4), UIStyle.PAPER, 2.0)
		var ft := UIStyle.font_bold()
		draw_string(ft, lr.position + Vector2(38, 22), tr("DIRECTOR'S NOTE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.GOLD)
		# body text pops in
		var shown := (_t - 0.25) * CPS
		var ci := 0
		for li in lines.size():
			var line: String = lines[li]
			var px := lr.position + Vector2(16 + fw, 38 + li * lh + f.get_ascent(fs))
			var cx := 0.0
			for j in line.length():
				var pose := TextFX.letter_pose(ci, shown, _t, "")
				ci += 1
				if not pose.visible:
					break
				var ch := line[j]
				var cw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var col := UIStyle.CYAN if ch == "[" or ch == "]" else UIStyle.PAPER
				draw_string(f, px + Vector2(cx, 0) + pose.offset, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, float(pose.alpha)))
				cx += cw
			ci += 1
		if face_tex:
			# the mugshot, pinned on, a touch crooked
			var fr := Rect2(lr.position + Vector2(12, 32), Vector2(fw - 12, fw - 12))
			draw_rect(fr.grow(3), Color(0.92, 0.9, 0.84))
			draw_texture_rect(face_tex, fr, false)
			draw_rect(fr, Color(0, 0, 0, 0.25), false, 1.0)
		# time left
		var k := clampf(1.0 - _t / life, 0.0, 1.0)
		draw_rect(Rect2(lr.position + Vector2(4, lr.size.y - 2), Vector2((lr.size.x - 4) * k, 2)), Color(UIStyle.GOLD, 0.6))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	static var _faces: Dictionary = {}
	static func _face(id: String) -> Texture2D:
		if id == "":
			return null
		if not _faces.has(id):
			var pth := "res://assets/characters/portraits/%s.png" % id
			_faces[id] = load(pth) if ResourceLoader.exists(pth) else null
		return _faces[id]

	## A first look at each kind of man on the payroll.
	const WHO := {
		"guard": "Motel security. Bored, armed, and paid to not ask questions.",
		"gunner": "Hired gun. Fast hands, slow brain. He won't miss twice.",
		"sniper": "",
		"bellhop": "The bellhop carries more than bags. Don't turn your back on him.",
		"biker": "Biker muscle. He'll close the distance before you blink.",
		"security": "Studio security. Blazer, badge, and a gun under the blazer.",
		"stagehand": "A stagehand. Knows every shortcut on the lot.",
		"scrapper": "Yard crew. He'll come at you with whatever he's holding.",
		"civilian": "",
	}

	# ------------------------------------------------------------ situations
	func _watch() -> void:
		if hud == null or hud.player == null or not is_instance_valid(hud.player) or not hud.player.alive:
			return
		var p: Player = hud.player
		if get_tree().paused:
			return
		if _level_t > 2.5:
			offer("move", "Move and aim; {fire} shoots or swings, {dash} dodges through danger. One hit kills - both ways.")
		var vp := p.get_viewport()
		var view := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
		for e in get_tree().get_nodes_in_group("enemies"):
			if not e.is_alive() or not view.has_point(e.global_position):
				continue
			var d: float = e.global_position.distance_to(p.global_position)
			if e is Sniper and (e as Sniper).charge_k() >= 0.0:
				offer("sniper", "Red laser: a sniper. The shot lands where the dot was a beat ago - keep moving or break line of sight.", "enemy_sniper")
			if e is Handler:
				offer("handler", "Dog handler. Drop him before he sees you - or the dog is off the leash.", "enemy_handler")
			if e.has_method("is_snoozing") and e.is_snoozing() and d < 200.0:
				offer("snooze", "He's dozing. Footsteps and doors won't wake him. Gunfire will.")
			if e.state == Enemy.State.DOWNED and d < 120.0:
				offer("execute", "Downed. {execute} to finish him before he gets up.")
			var kind := String(e.data.id) if e.data else ""
			match kind:
				"heavy": offer("heavy", "Heavy: the vest soaks a bullet and fists do nothing. Shoot twice, or heavy-swing.", "enemy_heavy")
				"riot": offer("riot", "Riot shield blocks bullets from the front. Flank him or slam a door into him.", "enemy_riot")
				"hunter", "bellhop", "biker", "scrapper":
					offer("counter", "Melee rushers wind up before they swing. Hit them first to COUNTER.", "enemy_" + kind)
				"scout": offer("scout", "Unarmed lookout: he runs for the alarm. Stop him first.", "enemy_scout")
				"welder": offer("welder", "Welder's mask stops one hit and narrows his view. Come at him from the side.", "enemy_welder")
			if WHO.has(kind) and str(WHO[kind]) != "" and d < 240.0:
				offer("who_" + kind, WHO[kind], "enemy_" + kind)
			if d < 260.0 and p.lock_target == null:
				offer("lock", "{lock_on} locks on: your aim sticks to the marked target. Press again to switch.")
		for fc in get_tree().get_nodes_in_group("film_cameras"):
			if view.has_point(fc.global_position) and not fc._broken and fc.global_position.distance_to(p.global_position) < 160.0:
				offer("film_camera", "A red light in the corner: somebody is filming. Play to it - kills it sees score more - or cut the feed.")
				break
		for cam in get_tree().get_nodes_in_group("security_cameras"):
			if view.has_point(cam.global_position) and not cam._broken:
				offer("camera", "Security camera: stay out of the cone, or hug the wall right under it - the lens can't see straight down. Shoot it out and a guard or two comes to look.")
				break
		var w = p.current()
		if w and w.data.is_firearm() and w.ammo <= 0 and w.reserve <= 0:
			offer("throw", "Empty? Throw it with {secondary} - a thrown gun stuns whoever it hits.")
		if Score.combo >= 2:
			offer("combo", "COMBO: keep killing before the bar runs out. Mix weapons and methods for more.")
		if Score.combo >= 8:
			offer("finisher", "ON FIRE. Your next melee kill rolls the FINAL TAKE.")
		if p.upgrades.size() > 0:
			offer("upgrade", "Upgrades last until the end of the mission. They show in the bottom-left.")


class CheckpointStamp extends Control:
	## A VHS cassette drops in at the top centre of the screen, lands in a
	## glowing deck slot with a clunk, its reels spin and the OSD reads
	## "▶ PLAY" (or "◀◀ REWIND" after a death); the area's name is set in
	## neon under it between two rules. ~2.9 s, then it lifts away.
	var area := ""
	var rewind := false
	var _t := 0.0
	const LIFE := 2.9
	const W := 176.0
	const H := 104.0
	func _process(delta: float) -> void:
		_t += delta / maxf(Engine.time_scale, 0.05)
		if _t > LIFE:
			queue_free()
		queue_redraw()
	static func _ease_out(k: float) -> float:
		return 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 3.0)
	func _draw() -> void:
		var ink := UIStyle.INK
		var gold := UIStyle.GOLD
		var pink := UIStyle.PINK
		# top-right corner, under the weapon readout: easy to see, out of the way
		var S := 0.9
		var slide := _ease_out(_t / 0.35)
		var drop := _ease_out((_t - 0.35) / 0.2)
		var out := clampf((_t - (LIFE - 0.35)) / 0.35, 0.0, 1.0)
		var a := 1.0 - out * out
		var centre_x := size.x - 40.0 - W * S * 0.5
		var top := 92.0
		# neon title underneath: the area, between two pink rules
		if _t > 0.45 and area != "":
			var ta := a * clampf((_t - 0.45) / 0.25, 0.0, 1.0)
			var fd := UIStyle.font_display()
			var title := area.to_upper()
			var tw := fd.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			var ty := top + (H - 6.0) * S
			var glow := 0.55 + 0.45 * sin(_t * 6.0)
			# a dark band so the name reads over anything
			var band := Rect2(centre_x - maxf(tw * 0.5 + 14.0, W * S * 0.5 + 8.0), ty - 22.0, maxf(tw + 28.0, W * S + 16.0), 44.0)
			draw_rect(band, Color(0.03, 0.01, 0.06, 0.55 * ta))
			draw_rect(Rect2(band.position, Vector2(band.size.x, 1)), Color(pink, 0.35 * ta))
			draw_rect(Rect2(band.position + Vector2(0, band.size.y - 1), Vector2(band.size.x, 1)), Color(pink, 0.35 * ta))
			for k in 3:
				draw_string_outline(fd, Vector2(centre_x - tw * 0.5, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6 + k * 4, Color(pink, 0.12 * ta * glow))
			draw_string_outline(fd, Vector2(centre_x - tw * 0.5, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(ink, ta))
			draw_string(fd, Vector2(centre_x - tw * 0.5, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UIStyle.PAPER, ta))
			var rule := band.size.x * 0.5 * clampf((_t - 0.45) / 0.3, 0.0, 1.0)
			draw_rect(Rect2(centre_x - rule, band.position.y, rule * 2.0, 2.0), Color(pink, ta))
			var sub := tr("TAPE SAVED") if not rewind else tr("REWOUND - FROM THE TOP")
			var sw := UIStyle.font_bold().get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(UIStyle.font_bold(), Vector2(centre_x - sw * 0.5, ty + 16.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(gold, ta))
		draw_set_transform(Vector2(centre_x - W * S * 0.5, top), 0.0, Vector2(S, S))
		var base := Vector2.ZERO
		var off := Vector2((1.0 - slide) * (W + 60.0), drop * 8.0 - out * 20.0)
		# soft neon halo behind the deck
		draw_rect(Rect2(Vector2(-18, 40), Vector2(W + 36, 46)), Color(pink, 0.08 * a * (0.7 + 0.3 * sin(_t * 5.0))))
		# the deck slot the tape drops into
		var slot := Rect2(base + Vector2(-8, 58), Vector2(W + 16, 20))
		draw_rect(slot, Color(0.04, 0.02, 0.07, 0.85 * a))
		draw_rect(Rect2(slot.position, Vector2(slot.size.x, 2)), Color(pink, 0.6 * a))
		draw_rect(Rect2(slot.position + Vector2(0, slot.size.y - 2), Vector2(slot.size.x, 2)), Color(0.25, 0.2, 0.3, a))
		# the cassette (drawn above the slot; after the drop its lower edge
		# hides behind the deck lip)
		var c := base + off
		var body := Rect2(c, Vector2(W, 64))
		draw_rect(Rect2(body.position + Vector2(3, 4), body.size), Color(0, 0, 0, 0.45 * a))   # shadow
		draw_rect(body, Color(0.07, 0.06, 0.09, a))
		draw_rect(body, Color(0.35, 0.3, 0.4, a), false, 1.0)
		for i in 4:   # screw heads
			var sp := body.position + Vector2(6 + (W - 12) * (i % 2), 6 + 52 * (i / 2))
			draw_circle(sp, 1.6, Color(0.5, 0.48, 0.55, a))
		# label: cream strip with a pink band, the area written on it
		var lab := Rect2(c + Vector2(12, 6), Vector2(W - 24, 26))
		draw_rect(lab, Color(0.95, 0.9, 0.8, a))
		draw_rect(Rect2(lab.position + Vector2(0, 18), Vector2(lab.size.x, 4)), Color(pink, a))
		draw_rect(Rect2(lab.position + Vector2(0, 22), Vector2(lab.size.x, 2)), Color(gold, a))
		var f := UIStyle.font_bold()
		draw_string(f, lab.position + Vector2(5, 14), tr("CHECKPOINT"), HORIZONTAL_ALIGNMENT_LEFT, lab.size.x * 0.5, 11, Color(ink, a))
		# window with two reels; tape winds from one to the other
		var win := Rect2(c + Vector2(40, 36), Vector2(W - 80, 22))
		draw_rect(win, Color(0.18, 0.14, 0.2, a))
		draw_rect(win, Color(0.45, 0.4, 0.5, a), false, 1.0)
		var spin := (_t - 0.5) * (-18.0 if rewind else 7.0) if _t > 0.5 else 0.0
		var wind := clampf((_t - 0.5) / (LIFE - 0.8), 0.0, 1.0)
		if rewind:
			wind = 1.0 - wind
		for side in 2:
			var rc := win.position + Vector2(18 + (win.size.x - 36) * side, 11)
			var tape_r := lerpf(9.0, 5.0, wind if side == 0 else 1.0 - wind)
			draw_circle(rc, tape_r, Color(0.28, 0.16, 0.12, a))
			draw_circle(rc, 4.2, Color(0.9, 0.88, 0.85, a))
			for k in 6:
				var ang := spin + k * TAU / 6.0
				draw_line(rc + Vector2.from_angle(ang) * 1.5, rc + Vector2.from_angle(ang) * 3.8, Color(ink, a), 1.0)
		draw_line(win.position + Vector2(18, 20), win.position + Vector2(win.size.x - 18, 20), Color(0.28, 0.16, 0.12, a), 1.0)
		# OSD once it plays: ▶ PLAY / ◀◀ REWIND, blinking, with tracking noise
		if _t > 0.55:
			var osd_a := a * clampf((_t - 0.55) / 0.12, 0.0, 1.0)
			var txt := tr("◀◀ REWIND") if rewind else tr("▶ PLAY")
			var op := base + Vector2(0, -12)
			draw_string_outline(UIStyle.font_display(), op, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(ink, osd_a))
			draw_string(UIStyle.font_display(), op, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UIStyle.PAPER, osd_a))
			if fmod(_t, 0.7) < 0.45:
				draw_circle(op + Vector2(W - 8, -6), 3.5, Color(1, 0.15, 0.2, osd_a))
				draw_string(UIStyle.font_mono(), op + Vector2(W - 44, -1), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.3, 0.35, osd_a))
			# two thin tracking lines wandering over the tape
			for i in 2:
				var ty := c.y + fmod(_t * 70.0 + i * 37.0, 64.0)
				draw_rect(Rect2(Vector2(c.x, ty), Vector2(W, 1)), Color(1, 1, 1, 0.08 * osd_a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)



## SPOTLIGHT on screen: the world goes to stage light. The word slams in
## across the middle in gold with a chromatic split and spreads its letters
## as it fades; warm beams sweep down from the rig, the edges sink into a
## dark vignette, and a film-reel countdown in the corner spins down with
## the time left (kills in the light add a flash of extra reel).
class SpotlightFX extends Control:
	var left := 1.0
	var _t := 0.0
	var _out := -1.0
	var _bonus := 0.0

	func _ready() -> void:
		Events.ability_bonus.connect(func(_s): _bonus = 1.0)

	func finish() -> void:
		_out = 0.0

	func _process(delta: float) -> void:
		var rd := delta / maxf(Engine.time_scale, 0.03)   # real time
		_t += rd
		_bonus = maxf(0.0, _bonus - rd * 2.0)
		if _out >= 0.0:
			_out += rd
			if _out > 0.45:
				queue_free()
		queue_redraw()

	func _draw() -> void:
		var vs := size
		var fade := 1.0 - clampf(_out / 0.45, 0.0, 1.0) if _out >= 0.0 else clampf(_t / 0.15, 0.0, 1.0)
		# vignette: the house lights are down
		var steps := 10
		for i in steps:
			var k := float(i) / steps
			var m := vs * 0.5 * (0.45 + k * 0.55)
			draw_rect(Rect2(vs * 0.5 - m - Vector2(4, 4) * i, m * 2.0 + Vector2(8, 8) * i), Color(0.03, 0.0, 0.03, 0.06 * k * fade), false, vs.y * 0.06)
		# beams from the rig, slowly sweeping
		for b in 3:
			var x := vs.x * (0.2 + 0.3 * b) + sin(_t * 0.6 + b * 2.0) * vs.x * 0.06
			var w := vs.x * 0.05
			draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.3, 0), Vector2(x + w * 0.3, 0), Vector2(x + w * 2.4, vs.y), Vector2(x - w * 2.4, vs.y)]), Color(1.0, 0.85, 0.55, 0.045 * fade))
		# the word: slams in, holds, then spreads out and fades (first 1.3 s)
		var f := UIStyle.font_display()
		var word := tr("SPOTLIGHT")
		if _t < 1.3:
			var k := clampf(_t / 0.12, 0.0, 1.0)
			var sc := lerpf(2.2, 1.0, k * k)
			var spread := maxf(0.0, _t - 0.6) * 60.0
			var a := (1.0 - clampf((_t - 0.8) / 0.5, 0.0, 1.0)) * fade
			var fs := int(96 * sc)
			var total := 0.0
			for ch in word:
				total += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + spread
			var x0 := vs.x * 0.5 - total * 0.5
			var y := vs.y * 0.42
			for i in word.length():
				var ch := word[i]
				var cw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var jit := Vector2(0, sin(_t * 30.0 + i) * 2.0 * (1.0 - k))
				draw_string(f, Vector2(x0 - 4, y) + jit, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.2, 0.45, 0.55 * a))
				draw_string(f, Vector2(x0 + 4, y) + jit, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.9, 1.0, 0.45 * a))
				var gold := Color(1.0, 0.88, 0.4).lerp(Color(1.0, 0.55, 0.2), float(i) / word.length())
				draw_string(f, Vector2(x0, y) + jit, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(gold, a))
				x0 += cw + spread
			var sub := tr("THE WORLD SLOWS. YOU DON'T.")
			draw_string(UIStyle.font_bold(), Vector2(0, y + 40), sub, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 18, Color(1, 0.95, 0.85, 0.8 * a))
		# film-reel countdown, bottom right
		var c := Vector2(vs.x - 70, vs.y - 150)
		var r := 34.0
		var rot := _t * 2.4
		draw_circle(c, r + 6, Color(0.05, 0.02, 0.06, 0.6 * fade))
		draw_arc(c, r, -PI / 2, -PI / 2 + TAU * clampf(left, 0.0, 1.0), 48, Color(1.0, 0.85, 0.4, fade), 5.0, true)
		if _bonus > 0.0:
			draw_arc(c, r + 5, 0, TAU, 48, Color(1, 1, 1, _bonus * fade), 2.0, true)
		for h in 6:
			var hp := c + Vector2.from_angle(rot + h * TAU / 6.0) * r * 0.55
			draw_circle(hp, 5.0, Color(1.0, 0.85, 0.4, 0.5 * fade))
		draw_circle(c, 4.0, Color(1.0, 0.85, 0.4, fade))
		draw_string(UIStyle.font_bold(), c + Vector2(-40, r + 22), tr("SPOTLIGHT"), HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color(1.0, 0.85, 0.4, fade))


## Bottom-left: the SPOTLIGHT meter. A tilted neon plate with a stage lamp,
## the name in the display face and a segmented bar that fills with points.
## Full, it lights up: the bar goes neon, the lamp throws a beam and READY
## blinks with the key. Running, the bar drains white like a reel.
class AbilityMeter extends Control:
	static var _lamp: Texture2D
	var title := "SPOTLIGHT"
	var key := ""
	var charge := 0.0
	var active := false
	var ready_flash := 0.0
	var _t := 0.0
	var _shown := 0.0
	const SEGS := 12

	func _process(delta: float) -> void:
		var rd := delta / maxf(Engine.time_scale, 0.03)
		_t += rd
		_shown = move_toward(_shown, charge, rd * (3.0 if active else 1.2))
		ready_flash = maxf(0.0, ready_flash - rd * 1.5)
		queue_redraw()

	func _draw() -> void:
		var ready := charge >= 0.999 and not active
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		var skew := 10.0
		var w := size.x
		var h := size.y
		# the plate: a slanted dark panel with a neon edge
		var plate := PackedVector2Array([Vector2(skew, 0), Vector2(w, 0), Vector2(w - skew, h), Vector2(0, h)])
		draw_colored_polygon(plate, Color(0.03, 0.01, 0.06, 0.78))
		var edge := UIStyle.GOLD if not ready else UIStyle.PINK.lerp(UIStyle.GOLD, pulse)
		if active:
			edge = Color.WHITE
		var loop := plate.duplicate()
		loop.append(plate[0])
		if ready or active:
			draw_polyline(loop, Color(edge, 0.25), 6.0, true)
		draw_polyline(loop, Color(edge, 0.9 if (ready or active) else 0.45), 1.5, true)
		# the lamp: a little stage spotlight, throwing a beam when it's ready
		var lc := Vector2(30, h * 0.5)
		if ready or active:
			draw_colored_polygon(PackedVector2Array([lc + Vector2(6, -4), lc + Vector2(6, 4), lc + Vector2(40, 22), lc + Vector2(40, -22)]), Color(1.0, 0.85, 0.5, 0.12 + 0.1 * pulse))
		if _lamp == null:
			_lamp = load("res://assets/art/ui/icon_spotlight.png") if ResourceLoader.exists("res://assets/art/ui/icon_spotlight.png") else null
		if _lamp:
			# the painted stage lamp: dim while charging, blazing when ready
			var ls := 44.0 + (4.0 * pulse if ready else 0.0)
			var mod := Color.WHITE if (ready or active) else Color(0.45, 0.4, 0.45)
			draw_texture_rect(_lamp, Rect2(lc - Vector2(ls, ls) * 0.5, Vector2(ls, ls)), false, mod)
		else:
			draw_circle(lc, 12.0, Color(0.1, 0.06, 0.12))
			draw_circle(lc + Vector2(3, 0), 7.0, Color(1.0, 0.85, 0.45) if (ready or active) else Color(0.35, 0.3, 0.3))
			draw_line(lc + Vector2(-6, 12), lc + Vector2(-10, 20), Color(0.5, 0.45, 0.5), 2.0)
			draw_line(lc + Vector2(6, 12), lc + Vector2(10, 20), Color(0.5, 0.45, 0.5), 2.0)
		# the name
		var f := UIStyle.font_display()
		var fb := UIStyle.font_bold()
		var tx := 56.0
		draw_string(f, Vector2(tx + 1, 26), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0, 0, 0, 0.6))
		draw_string(f, Vector2(tx, 25), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIStyle.GOLD if not active else Color.WHITE)
		var tag := ""
		var tag_c := UIStyle.DIM
		if active:
			tag = tr("ON AIR")
			tag_c = UIStyle.HOT
		elif ready:
			tag = tr("READY") + "  [" + key + "]"
			tag_c = Color(UIStyle.PINK, 0.6 + 0.4 * pulse)
		else:
			tag = "%d%%" % int(_shown * 100.0)
		draw_string(fb, Vector2(tx, 66), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tag_c)
		# the bar: segments on a slant
		var bx := tx
		var by := 36.0
		var bw := w - tx - 22.0
		var sw := bw / SEGS
		for i in SEGS:
			var k := clampf(_shown * SEGS - i, 0.0, 1.0)
			var r := Rect2(bx + i * sw, by, sw - 3.0, 14.0)
			var poly := PackedVector2Array([r.position + Vector2(3, 0), Vector2(r.end.x + 3, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
			draw_colored_polygon(poly, Color(1, 1, 1, 0.08))
			if k <= 0.0:
				continue
			var col := UIStyle.GOLD.lerp(UIStyle.PINK, float(i) / SEGS)
			if active:
				col = Color.WHITE
			elif ready:
				col = UIStyle.PINK.lerp(UIStyle.CYAN, 0.5 + 0.5 * sin(_t * 4.0 + i * 0.5))
			var fill := PackedVector2Array([poly[0], poly[0].lerp(poly[1], k), poly[3].lerp(poly[2], k), poly[3]])
			if ready or active:
				draw_rect(r.grow(2.0), Color(col, 0.18), true)
			draw_colored_polygon(fill, col)
		if ready_flash > 0.0:
			draw_polyline(loop, Color(1, 1, 1, ready_flash), 3.0 + 6.0 * (1.0 - ready_flash), true)


## The boss's health: a name in the display face over a slanted neon bar,
## a white trail that catches up after each hit, a notch where phase two
## starts, a shake when it's hit. Slides in when the fight starts, drains
## away after it.
class BossBar extends Control:
	var _boss: Node
	var _hp := 1.0
	var _trail := 1.0
	var _shake := 0.0
	var _a := 0.0
	var _t := 0.0
	var _name := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func on_hp(boss: Node, hp: float, max_hp: float) -> void:
		var k := clampf(hp / maxf(max_hp, 0.01), 0.0, 1.0)
		if _boss != boss:
			_boss = boss
			_hp = k
			_trail = k
			var sd: Dictionary = Dialogue.speakers.get(str(boss.get("data").id) if boss.get("data") else "", {})
			_name = tr(str(sd.get("name", ""))) if not sd.is_empty() else ""
			if _name == "":
				_name = {"night_manager": "LYLE HARCOURT", "fireman": "DUTCH 'THE FIREMAN' KOWALSKI", "burning_man": "TOMMY?"}.get(str(boss.get("data").id), "BOSS")
		if k < _hp:
			_shake = 1.0
		_hp = k

	func _process(delta: float) -> void:
		_t += delta
		var live: bool = _boss != null and is_instance_valid(_boss) and _boss.is_alive() and not bool(_boss.get("_defeated"))
		_a = move_toward(_a, 1.0 if live else 0.0, delta * (3.0 if live else 1.0))
		_trail = move_toward(_trail, _hp, delta * (0.25 if _trail - _hp < 0.3 else 0.6))
		_shake = maxf(0.0, _shake - delta * 3.0)
		queue_redraw()

	func _draw() -> void:
		if _a <= 0.01:
			return
		var w := size.x
		var off := Vector2(sin(_t * 70.0) * 4.0 * _shake, (1.0 - _a) * -20.0)
		var fd := UIStyle.font_display()
		draw_string(fd, off + Vector2(2, 24), _name, HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color(0, 0, 0, 0.7 * _a))
		draw_string(fd, off + Vector2(0, 22), _name, HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color(UIStyle.GOLD, _a))
		var y := 34.0
		var h := 16.0
		var skew := 12.0
		var poly := func(k: float) -> PackedVector2Array:
			var x1 := skew + (w - skew * 2.0) * k
			return PackedVector2Array([off + Vector2(skew, y), off + Vector2(x1 + skew, y), off + Vector2(x1, y + h), off + Vector2(0, y + h)])
		draw_colored_polygon(poly.call(1.0), Color(0.05, 0.0, 0.07, 0.85 * _a))
		if _trail > _hp:
			draw_colored_polygon(poly.call(_trail), Color(1, 1, 1, 0.85 * _a))
		if _hp > 0.0:
			var col := UIStyle.HOT.lerp(UIStyle.PINK, 0.5 + 0.5 * sin(_t * 3.0))
			draw_colored_polygon(poly.call(_hp), Color(col, _a))
			# a glossy strip along the top
			var g: PackedVector2Array = poly.call(_hp)
			draw_line(g[0] + Vector2(1, 2), g[1] + Vector2(-1, 2), Color(1, 1, 1, 0.35 * _a), 2.0)
		# the phase-two notch
		var nk := BossNightManager.PHASE2_AT
		var nx := skew + (w - skew * 2.0) * nk
		draw_line(off + Vector2(nx + skew, y - 3), off + Vector2(nx, y + h + 3), Color(UIStyle.CYAN, 0.9 * _a), 2.0)
		var outline := poly.call(1.0)
		outline.append(outline[0])
		draw_polyline(outline, Color(UIStyle.PINK, 0.9 * _a), 1.5, true)
