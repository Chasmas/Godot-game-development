extends Control
## The installer and uninstaller, run by the game's own exe:
##   HotshotCalifornia.exe --hotshot-install     (launched by the Setup wrapper)
##   HotshotCalifornia.exe --hotshot-uninstall   (Windows "Apps" > Uninstall)
## A borderless window in the game's look: the motel in the rain behind,
## the neon logo, the title music, and the install shown as a tape rewinding.
##
## Installs per user (no admin prompt), like modern Windows apps:
##   %LOCALAPPDATA%\Programs\HOTSHOT CALIFORNIA\HotshotCalifornia.exe
## Start Menu + optional desktop shortcut, an entry in Apps & features
## (HKCU). Saves live in AppData\Roaming and are never touched.

const APP := "HOTSHOT CALIFORNIA"
const EXE_NAME := "HotshotCalifornia.exe"
const UNINST_KEY := "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\HotshotCalifornia"
const WIN := Vector2i(1120, 630)
const MIN_COPY_TIME := 3.6     ## let the tape rewind even on a fast disk

static var uninstall_mode := false

var shot: StoryShot
var page: Control
var _step := ""
var _t := 0.0
var _dest := ""
var _desktop_cb: CheckBox
var _start_cb: CheckBox
var _path_edit: LineEdit
var _progress := 0.0
var _status := ""
var _copy_src: FileAccess
var _copy_dst: FileAccess
var _copy_total := 0
var _copy_done := 0
var _copy_t := 0.0
var _error := ""
var _drag_from := Vector2i(-1, -1)
var _logo_top: Label
var _logo_bottom: Label

func _ready() -> void:
	theme = UIStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var lang := "pt_PT" if OS.get_locale().begins_with("pt") else "en"
	Loc.apply(lang, false)
	_window_setup.call_deferred()
	_dest = _default_dest()
	# the motel in the rain, the sign flickering
	shot = StoryShot.new()
	shot.ambience = false
	shot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shot.letterbox = false
	shot.shot_time = 40.0
	add_child(shot)
	shot.show_shot(BACKDROPS[0], true)
	var shade := Shade.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_build_logo()
	var bar := TitleBar.new()
	bar.installer = self
	UIStyle.place(bar, Control.PRESET_TOP_WIDE, Vector2.ZERO, Vector2(0, 34))
	add_child(bar)
	page = Control.new()
	UIStyle.place(page, Control.PRESET_LEFT_WIDE, Vector2(46, 196), Vector2(470, -40))
	add_child(page)
	Music.play("title")
	PostFX.set_desaturate(0.0)
	PostFX.set_tint(Color(1, 1, 1, 0))
	PostFX.vhs_glitch(0.8)
	Audio.play("vhs_static", -10.0)
	_go("uninstall_welcome" if uninstall_mode else "welcome")

func _window_setup() -> void:
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.borderless = true
	win.size = WIN
	var scr := DisplayServer.screen_get_usable_rect(win.current_screen)
	win.position = scr.position + (scr.size - WIN) / 2
	win.title = APP + (" - Uninstall" if uninstall_mode else " - Setup")

func _default_dest() -> String:
	if uninstall_mode:
		return OS.get_executable_path().get_base_dir()
	var base := OS.get_environment("LOCALAPPDATA")
	if base == "":
		base = OS.get_user_data_dir().get_base_dir()
	return base.path_join("Programs").path_join(APP)

# ------------------------------------------------------------------ look
func _build_logo() -> void:
	_logo_top = Label.new()
	_logo_top.text = "HOTSHOT"
	_logo_top.add_theme_font_override("font", UIStyle.font_display())
	_logo_top.add_theme_font_size_override("font_size", 76)
	_logo_top.add_theme_color_override("font_shadow_color", Color(0.05, 0.0, 0.12, 0.9))
	_logo_top.add_theme_constant_override("shadow_offset_x", 4)
	_logo_top.add_theme_constant_override("shadow_offset_y", 4)
	_logo_top.position = Vector2(40, 48)
	_logo_top.size = Vector2(520, 100)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/logo_gradient.gdshader")
	m.set_shader_parameter("height", 100.0)
	_logo_top.material = m
	add_child(_logo_top)
	_logo_bottom = Label.new()
	_logo_bottom.text = "California"
	_logo_bottom.add_theme_font_override("font", UIStyle.font_script())
	_logo_bottom.add_theme_font_size_override("font_size", 40)
	_logo_bottom.add_theme_color_override("font_color", Color(1, 0.35, 0.75))
	_logo_bottom.add_theme_color_override("font_outline_color", Color(1, 0.2, 0.6, 0.35))
	_logo_bottom.add_theme_constant_override("outline_size", 10)
	_logo_bottom.rotation = -0.06
	_logo_bottom.position = Vector2(250, 124)
	add_child(_logo_bottom)

## Behind the pages, the story's moments dissolve one into the next.
const BACKDROPS := ["motel_night", "menu_smoke", "t_corridor", "menu_revolver", "t_studio", "menu_tommy", "t_mansion"]
var _bd_i := 0
var _bd_t := 0.0

func _process(delta: float) -> void:
	_t += delta
	_bd_t += delta
	if _bd_t > 8.0:
		_bd_t = 0.0
		for k in BACKDROPS.size():
			_bd_i = (_bd_i + 1) % BACKDROPS.size()
			if StoryShot.has_shot(BACKDROPS[_bd_i]):
				break
		shot.show_shot(BACKDROPS[_bd_i])
	_logo_top.position.y = 48 + sin(_t * 1.3) * 2.0
	var flick := 0.35 if (fmod(_t, 5.1) < 0.08 or fmod(_t, 3.3) < 0.04) else 1.0
	_logo_bottom.modulate.a = flick
	if _step == "copying":
		_pump_copy(delta)
	elif _step == "removing":
		_progress = minf(1.0, _progress + delta / 2.2)
		if _progress >= 1.0:
			_finish_uninstall()

## Swap the page with a quick slide + glitch.
func _go(step: String) -> void:
	_step = step
	for c in page.get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(box)
	match step:
		"welcome": _page_welcome(box)
		"license": _page_license(box)
		"options": _page_options(box)
		"copying": _page_progress(box, tr("Loading the tape..."))
		"done": _page_done(box)
		"error": _page_error(box)
		"uninstall_welcome": _page_uninstall(box)
		"removing": _page_progress(box, tr("Rewinding. Please be kind."))
		"uninstalled": _page_uninstalled(box)
	box.modulate.a = 0.0
	box.position.x = -24.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(box, "modulate:a", 1.0, 0.25)
	tw.tween_property(box, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	PostFX.vhs_glitch(0.35)
	UIStyle.reveal(box, 0.04)

func _h(text: String, size := 30, col := UIStyle.PAPER) -> Label:
	var l := UIStyle.title_label(text, size, col)
	return l

func _p(text: String, col := UIStyle.PAPER, size := 15) -> Label:
	var l := UIStyle.label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	return l

func _button(box: Container, text: String, cb: Callable, big := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280 if big else 200, 44 if big else 36)
	if big:
		b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(func():
		Audio.play("ui_select")
		cb.call())
	b.focus_entered.connect(func(): Audio.play("ui_move", -8.0))
	UIStyle.menu_fx(b)
	box.add_child(b)
	return b

func _spacer(box: Container, h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	box.add_child(c)

# ------------------------------------------------------------------ pages
func _page_welcome(box: VBoxContainer) -> void:
	box.add_child(_h(tr("Rolling. Speed."), 32, UIStyle.PINK))
	box.add_child(_p(tr("California, 1988. There's a package on your doorstep, a motel in Barstow, and somebody filming everything.")))
	box.add_child(_p(tr("Setup will install HOTSHOT CALIFORNIA %s for you.") % _version(), UIStyle.DIM, 13))
	_spacer(box, 12)
	box.add_child(_p(tr("It's a good idea to close other programs first. Your saves (if you've played before) are safe."), UIStyle.DIM, 12))
	var go := _button(box, tr("NEXT ▶"), func(): _go("license"), true)
	_button(box, tr("CANCEL"), _confirm_cancel)
	go.grab_focus.call_deferred()

func _page_license(box: VBoxContainer) -> void:
	box.add_child(_h(tr("The fine print"), 30, UIStyle.PINK))
	var tx := RichTextLabel.new()
	tx.custom_minimum_size = Vector2(460, 170)
	tx.scroll_active = true
	tx.add_theme_font_size_override("normal_font_size", 12)
	tx.text = tr(LICENSE)
	box.add_child(tx)
	var ok := CheckBox.new()
	ok.text = tr("I accept the terms")
	ok.button_pressed = _accepted
	box.add_child(ok)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var next := _button(row, tr("NEXT ▶"), func(): _go("options"), true)
	next.disabled = not _accepted
	ok.toggled.connect(func(v):
		_accepted = v
		next.disabled = not v)
	_button(row, tr("◀ BACK"), func(): _go("welcome"))
	ok.grab_focus.call_deferred()

const LICENSE := """HOTSHOT CALIFORNIA - (c) 2026 Gilberto Lopes / Inverted Index Studio.

This is a test build. You're welcome to play it, and to share this installer with friends so they can play and test it too - free of charge.

You may not sell it, repackage it as your own, or extract its art, music or writing to use elsewhere.

The game is provided as it is, without warranty of any kind. It installs for your user only, needs no administrator rights, and can be removed at any time from Windows Settings > Apps.

HOTSHOT CALIFORNIA is a work of fiction. It contains strong violence, blood and dark themes, and is intended for adults.

Thank you for testing. Feedback makes it better."""

var _accepted := false

func _confirm_cancel() -> void:
	var d := ConfirmationDialog.new()
	d.dialog_text = tr("Stop the setup? Nothing has been installed yet.")
	d.ok_button_text = tr("STOP")
	d.cancel_button_text = tr("KEEP GOING")
	d.confirmed.connect(_quit)
	add_child(d)
	d.popup_centered()

func _page_options(box: VBoxContainer) -> void:
	box.add_child(_h(tr("Location scouting"), 30, UIStyle.PINK))
	box.add_child(_p(tr("Where should we set up the shoot?"), UIStyle.DIM, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_path_edit = LineEdit.new()
	_path_edit.text = _dest.replace("/", "\\")
	_path_edit.custom_minimum_size = Vector2(330, 34)
	_path_edit.text_changed.connect(func(t): _dest = t.replace("\\", "/"))
	row.add_child(_path_edit)
	var browse := Button.new()
	browse.text = tr("Browse...")
	browse.pressed.connect(_browse)
	row.add_child(browse)
	_desktop_cb = CheckBox.new()
	_desktop_cb.text = tr("Desktop shortcut")
	_desktop_cb.button_pressed = _desktop_cb_state
	_desktop_cb.toggled.connect(func(v): _desktop_cb_state = v)
	box.add_child(_desktop_cb)
	_start_cb = CheckBox.new()
	_start_cb.text = tr("Start Menu shortcut")
	_start_cb.button_pressed = _start_cb_state
	_start_cb.toggled.connect(func(v): _start_cb_state = v)
	box.add_child(_start_cb)
	box.add_child(_p(tr("Needs about %d MB. Your saves are kept in your user folder, not here.") % int(ceil(_exe_size() / 1048576.0)), UIStyle.DIM, 12))
	_spacer(box, 6)
	var go := _button(box, tr("INSTALL"), _start_install, true)
	_button(box, tr("◀ BACK"), func(): _go("license"))
	go.grab_focus.call_deferred()

var _desktop_cb_state := true
var _start_cb_state := true

func _browse() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.use_native_dialog = true
	fd.current_dir = _dest.get_base_dir()
	fd.dir_selected.connect(func(d: String):
		_dest = d.path_join(APP) if not d.ends_with(APP) else d
		if _path_edit:
			_path_edit.text = _dest.replace("/", "\\"))
	add_child(fd)
	fd.popup_centered(Vector2i(700, 480))

func _page_progress(box: VBoxContainer, title: String) -> void:
	box.add_child(_h(title, 30, UIStyle.PINK))
	var tape := Tape.new()
	tape.installer = self
	tape.custom_minimum_size = Vector2(440, 170)
	box.add_child(tape)

func _page_done(box: VBoxContainer) -> void:
	box.add_child(_h(tr("That's a wrap."), 34, UIStyle.PINK))
	box.add_child(_p(tr("HOTSHOT CALIFORNIA is installed. Somebody's filming. Make it look good.")))
	box.add_child(_p(tr("Installed to:") + " " + _dest.replace("/", "\"), UIStyle.DIM, 12))
	var launch := CheckBox.new()
	launch.text = tr("Launch HOTSHOT CALIFORNIA now")
	launch.button_pressed = true
	box.add_child(launch)
	var notes := CheckBox.new()
	notes.text = tr("Show what's new in this version")
	notes.button_pressed = false
	box.add_child(notes)
	_spacer(box, 8)
	var go := _button(box, tr("FINISH"), func():
		if notes.button_pressed:
			_show_notes()
		if launch.button_pressed:
			_play()
		else:
			_quit(), true)
	go.grab_focus.call_deferred()
	Audio.play("rank_stamp", -4.0)
	PostFX.flash(UIStyle.GOLD, 0.2)

func _page_error(box: VBoxContainer) -> void:
	box.add_child(_h(tr("Cut. Something went wrong."), 30, UIStyle.HOT))
	box.add_child(_p(_error, UIStyle.PAPER, 13))
	_spacer(box, 10)
	_button(box, tr("◀ BACK"), func(): _go("options"), true)
	_button(box, tr("CLOSE"), _quit)

func _page_uninstall(box: VBoxContainer) -> void:
	box.add_child(_h(tr("Cut."), 34, UIStyle.PINK))
	box.add_child(_p(tr("This will remove HOTSHOT CALIFORNIA from your computer. Your saves and settings stay where they are, in case you want another take.")))
	_spacer(box, 12)
	var go := _button(box, tr("UNINSTALL"), func():
		_progress = 0.0
		_go("removing"), true)
	_button(box, tr("CANCEL"), _quit)
	go.grab_focus.call_deferred()

func _page_uninstalled(box: VBoxContainer) -> void:
	box.add_child(_h(tr("Print it."), 34, UIStyle.PINK))
	box.add_child(_p(tr("HOTSHOT CALIFORNIA has been removed. Thanks for watching. Be kind, rewind.")))
	_spacer(box, 14)
	var b := _button(box, tr("CLOSE"), _quit, true)
	b.grab_focus.call_deferred()

# ------------------------------------------------------------------ install
func _version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))

func _exe_size() -> int:
	var f := FileAccess.open(OS.get_executable_path(), FileAccess.READ)
	return int(f.get_length()) if f else 110 * 1048576

func _start_install() -> void:
	if _path_edit:
		_dest = _path_edit.text.replace("\\", "/")
	_dest = _dest.strip_edges().trim_suffix("/")
	var err := DirAccess.make_dir_recursive_absolute(_dest)
	if err != OK:
		_fail(tr("Couldn't create the folder:") + "\n" + _dest.replace("/", "\\"))
		return
	var src := OS.get_executable_path()
	var dst := _dest.path_join(EXE_NAME)
	_copy_total = _exe_size()
	_copy_done = 0
	_copy_t = 0.0
	_progress = 0.0
	if src.simplify_path().to_lower() == dst.simplify_path().to_lower():
		_copy_total = 0      # already running from the install folder
	else:
		_copy_src = FileAccess.open(src, FileAccess.READ)
		_copy_dst = FileAccess.open(dst, FileAccess.WRITE)
		if _copy_src == null or _copy_dst == null:
			_fail(tr("Couldn't write the game to:") + "\n" + dst.replace("/", "\\") + "\n" + tr("Is the game already running?"))
			return
	_go("copying")

func _pump_copy(delta: float) -> void:
	_copy_t += delta
	if _copy_src:
		var budget := 6 * 1048576
		while budget > 0 and _copy_done < _copy_total:
			var n := mini(budget, mini(1048576, _copy_total - _copy_done))
			_copy_dst.store_buffer(_copy_src.get_buffer(n))
			_copy_done += n
			budget -= n
			if float(_copy_done) / float(_copy_total) > _copy_t / MIN_COPY_TIME:
				break   # pace it: the tape rewinds at its own speed
		if _copy_done >= _copy_total:
			_copy_src.close()
			_copy_dst.close()
			_copy_src = null
			_copy_dst = null
	var real := 1.0 if _copy_total <= 0 else float(_copy_done) / float(_copy_total)
	_progress = minf(real, _copy_t / MIN_COPY_TIME)
	if _progress >= 1.0 and _copy_src == null:
		_post_install()

func _post_install() -> void:
	_step = "finishing"
	var exe := _dest.path_join(EXE_NAME).replace("/", "\\")
	var dir := _dest.replace("/", "\\")
	# Apps & features entry
	var vals := [
		["DisplayName", "REG_SZ", APP], ["DisplayVersion", "REG_SZ", _version()],
		["Publisher", "REG_SZ", "Inverted Index Studio"], ["DisplayIcon", "REG_SZ", exe + ",0"],
		["InstallLocation", "REG_SZ", dir], ["UninstallString", "REG_SZ", "\"%s\" --hotshot-uninstall" % exe],
		["NoModify", "REG_DWORD", "1"], ["NoRepair", "REG_DWORD", "1"],
		["EstimatedSize", "REG_DWORD", str(_exe_size() / 1024)],
	]
	for v in vals:
		OS.execute("reg", ["add", UNINST_KEY, "/v", v[0], "/t", v[1], "/d", v[2], "/f"])
	if _start_cb_state:
		_shortcut(_start_menu_lnk(), exe, dir)
	if _desktop_cb_state:
		_shortcut(_desktop_lnk(), exe, dir)
	_go("done")

func _start_menu_lnk() -> String:
	return OS.get_environment("APPDATA").path_join("Microsoft/Windows/Start Menu/Programs").path_join(APP + ".lnk")

func _desktop_lnk() -> String:
	return OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).path_join(APP + ".lnk")

## A Windows shortcut via PowerShell's WScript.Shell (VBScript as fallback).
func _shortcut(lnk: String, target: String, workdir: String) -> void:
	var l := lnk.replace("/", "\\").replace("'", "''")
	var t := target.replace("'", "''")
	var w := workdir.replace("'", "''")
	var ps := "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%s');$s.TargetPath='%s';$s.WorkingDirectory='%s';$s.IconLocation='%s,0';$s.Description='HOTSHOT CALIFORNIA';$s.Save()" % [l, t, w, t]
	var code := OS.execute("powershell", ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", ps])
	if code != 0 and not FileAccess.file_exists(lnk):
		var vbs := OS.get_temp_dir().path_join("hotshot_lnk.vbs")
		var f := FileAccess.open(vbs, FileAccess.WRITE)
		if f:
			f.store_string('Set s = CreateObject("WScript.Shell").CreateShortcut("%s")\ns.TargetPath = "%s"\ns.WorkingDirectory = "%s"\ns.IconLocation = "%s,0"\ns.Save\n' % [lnk.replace("/", "\\"), target, workdir, target])
			f.close()
			OS.execute("cscript", ["//nologo", vbs.replace("/", "\\")])

func _fail(msg: String) -> void:
	_error = msg
	Audio.play("ui_back")
	_go("error")

## What's new: written next to the game when installed, opened in Notepad.
func _show_notes() -> void:
	var p := _dest.path_join("WHATS_NEW.txt")
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f:
		f.store_string(tr(WHATS_NEW))
		f.close()
		OS.shell_open(p.replace("/", "\\"))

const WHATS_NEW := """HOTSHOT CALIFORNIA - what's new

- Masks: eleven faces to wear, each with an upside and a price. Earn them, or find them hidden.
- Every boss has a health bar and a way to beat them with the room itself - and Dog Days has a boss now.
- A trailer, a new title theme and darker, longer level scores.
- Cutscenes with more painted frames, boss scenes, and a VCR on the menu for the tapes you find.
- Cass arrives and leaves in her Eldorado. The lots have roads now, and the world beyond the walls.
- Dodge roll and stamina, live arms for every punch, stab and swing, kicks, better executions.
- Tutorial cards, side jobs on every level, guards who talk among themselves, meat bones for the dogs.
- Arcade: One in the Chamber, Gun Game and Clock's Ticking.
- Between jobs: Cass's room - the answering machine, the VCR, the mirror, the corkboard.

Thanks for testing!  - Gilberto"""

func _play() -> void:
	OS.create_process(_dest.path_join(EXE_NAME).replace("/", "\\"), [])
	_quit()

func _quit() -> void:
	get_tree().quit()

# ------------------------------------------------------------------ uninstall
func _finish_uninstall() -> void:
	_step = "cleanup"
	for lnk in [_start_menu_lnk(), _desktop_lnk()]:
		if FileAccess.file_exists(lnk):
			DirAccess.remove_absolute(lnk)
	OS.execute("reg", ["delete", UNINST_KEY, "/f"])
	_go("uninstalled")

## The exe can't delete itself while running: a detached cmd waits for us to
## exit, then removes the install folder.
func _exit_tree() -> void:
	if uninstall_mode and _step == "uninstalled":
		var dir := _dest.replace("/", "\\")
		OS.create_process("cmd.exe", ["/c", "ping 127.0.0.1 -n 3 >nul & rmdir /s /q \"%s\"" % dir])


# ================================================================== pieces
## Darkens the left side so the text reads over the art.
class Shade extends Control:
	func _draw() -> void:
		var w := size.x * 0.62
		for i in 32:
			var k := float(i) / 31.0
			draw_rect(Rect2(w * k, 0, w / 31.0 + 1.0, size.y), Color(0.02, 0.0, 0.05, 0.93 * (1.0 - k * k) + 0.05))
		draw_rect(Rect2(0, 0, size.x, size.y), Color(1, 0.24, 0.5, 0.25), false, 2.0)


## Custom title bar: drag to move, minimise and close.
class TitleBar extends Control:
	var installer: Control
	var _drag := false
	var _off := Vector2i.ZERO
	var _hover := -1
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			_hover = _button_at(e.position)
			if _drag:
				get_window().position = DisplayServer.mouse_get_position() - _off
			queue_redraw()
		elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				var b := _button_at(e.position)
				if b == 1:
					Audio.play("ui_back")
					installer.get_tree().quit()
				elif b == 0:
					get_window().mode = Window.MODE_MINIMIZED
				else:
					_drag = true
					_off = DisplayServer.mouse_get_position() - get_window().position
			else:
				_drag = false
	func _button_at(p: Vector2) -> int:
		if p.x > size.x - 44:
			return 1
		if p.x > size.x - 88:
			return 0
		return -1
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.05, 0.55))
		draw_string(UIStyle.font_mono(), Vector2(14, 22), "● REC   HOTSHOT CALIFORNIA — SETUP" if not installer.uninstall_mode else "● REC   HOTSHOT CALIFORNIA — UNINSTALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UIStyle.PAPER, 0.75))
		draw_circle(Vector2(18, 17), 4.0, Color(1, 0.1, 0.15, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)))
		var xs := [size.x - 66, size.x - 22]
		for i in 2:
			var c := Vector2(xs[i], 17)
			if _hover == i:
				draw_rect(Rect2(c - Vector2(22, 17), Vector2(44, 34)), Color(UIStyle.HOT if i == 1 else UIStyle.PINK, 0.35))
			if i == 0:
				draw_line(c + Vector2(-6, 4), c + Vector2(6, 4), UIStyle.PAPER, 2.0)
			else:
				draw_line(c + Vector2(-6, -6), c + Vector2(6, 6), UIStyle.PAPER, 2.0)
				draw_line(c + Vector2(6, -6), c + Vector2(-6, 6), UIStyle.PAPER, 2.0)
	func _process(_d: float) -> void:
		queue_redraw()


## The install/uninstall progress: a VHS cassette whose reels spin and whose
## tape winds from one spool to the other, a neon bar, timecode, percent.
class Tape extends Control:
	var installer: Node
	var _t := 0.0
	var _last_pct := -1
	func _process(d: float) -> void:
		_t += d
		var pct := int(installer._progress * 100.0)
		if pct / 10 != _last_pct / 10 and pct > 0:
			Audio.play("blip", -14.0, 1.0 + pct * 0.004)
		_last_pct = pct
		queue_redraw()
	func _draw() -> void:
		var k: float = installer._progress
		var ink := Color("0b0710")
		var body := Rect2(Vector2(10, 6), Vector2(300, 118))
		draw_rect(Rect2(body.position + Vector2(5, 6), body.size), Color(0, 0, 0, 0.4))
		draw_rect(body, Color("1a1620"))
		draw_rect(body, Color(UIStyle.PINK, 0.8), false, 2.0)
		# label strip
		var lab := Rect2(body.position + Vector2(18, 12), Vector2(264, 26))
		draw_rect(lab, Color("e8e0d0"))
		draw_rect(Rect2(lab.position, Vector2(lab.size.x, 6)), UIStyle.PINK)
		draw_string(UIStyle.font_display(), lab.position + Vector2(8, 22), "HOTSHOT  —  1988", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
		# window with the two spools
		var win := Rect2(body.position + Vector2(60, 50), Vector2(180, 52))
		draw_rect(win, Color("0a080e"))
		var left_c := win.position + Vector2(40, 26)
		var right_c := win.position + Vector2(140, 26)
		var r_left := lerpf(22.0, 9.0, k)
		var r_right := lerpf(9.0, 22.0, k)
		draw_circle(left_c, r_left, Color("3a2a22"))
		draw_circle(right_c, r_right, Color("3a2a22"))
		draw_line(left_c + Vector2(0, r_left), right_c + Vector2(0, r_right), Color("3a2a22"), 1.5)
		var spin := _t * (9.0 if k < 1.0 else 0.0)
		for c in [left_c, right_c]:
			draw_circle(c, 7.0, Color("e8e0d0"))
			for i in 6:
				var a := spin + i * TAU / 6.0
				draw_line(c + Vector2.from_angle(a) * 2.5, c + Vector2.from_angle(a) * 6.5, ink, 1.5)
		# progress bar + readout
		var bar := Rect2(Vector2(10, 138), Vector2(420, 10))
		draw_rect(bar, Color(1, 1, 1, 0.08))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), UIStyle.PINK)
		draw_rect(Rect2(bar.position + Vector2(bar.size.x * k - 3, -3), Vector2(3, 16)), Color(1, 1, 1, 0.9))
		var secs := int(k * 5400.0)
		draw_string(UIStyle.font_mono(), Vector2(330, 40), "%d%%" % int(k * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UIStyle.GOLD)
		draw_string(UIStyle.font_mono(), Vector2(330, 66), "◀◀ %d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UIStyle.PAPER, 0.8))
		draw_string(UIStyle.font_mono(), Vector2(330, 88), "SP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UIStyle.PAPER, 0.6))
