extends Node
## Builds the whole input map at runtime (keyboard/mouse + controller) and
## applies player remaps saved in settings. Remapping UI talks to this node.

signal device_changed(using_gamepad: bool)

## action -> [display name, default events]
## event spec: ["key", Key] ["mouse", MouseButton] ["jb", JoyButton] ["ja", JoyAxis, dir]
const ACTIONS := {
	"move_up":    ["Move Up",     [["key", KEY_W], ["key", KEY_UP], ["ja", JOY_AXIS_LEFT_Y, -1], ["jb", JOY_BUTTON_DPAD_UP]]],
	"move_down":  ["Move Down",   [["key", KEY_S], ["key", KEY_DOWN], ["ja", JOY_AXIS_LEFT_Y, 1], ["jb", JOY_BUTTON_DPAD_DOWN]]],
	"move_left":  ["Move Left",   [["key", KEY_A], ["key", KEY_LEFT], ["ja", JOY_AXIS_LEFT_X, -1], ["jb", JOY_BUTTON_DPAD_LEFT]]],
	"move_right": ["Move Right",  [["key", KEY_D], ["key", KEY_RIGHT], ["ja", JOY_AXIS_LEFT_X, 1], ["jb", JOY_BUTTON_DPAD_RIGHT]]],
	"aim_up":     ["Aim Up",      [["ja", JOY_AXIS_RIGHT_Y, -1]]],
	"aim_down":   ["Aim Down",    [["ja", JOY_AXIS_RIGHT_Y, 1]]],
	"aim_left":   ["Aim Left",    [["ja", JOY_AXIS_RIGHT_X, -1]]],
	"aim_right":  ["Aim Right",   [["ja", JOY_AXIS_RIGHT_X, 1]]],
	"fire":       ["Fire / Attack", [["mouse", MOUSE_BUTTON_LEFT], ["ja", JOY_AXIS_TRIGGER_RIGHT, 1]]],
	"secondary":  ["Throw / Secondary", [["mouse", MOUSE_BUTTON_RIGHT], ["ja", JOY_AXIS_TRIGGER_LEFT, 1]]],
	"dash":       ["Dodge / Dash", [["key", KEY_SPACE], ["jb", JOY_BUTTON_A]]],
	"sprint":     ["Sprint",      [["key", KEY_SHIFT], ["jb", JOY_BUTTON_LEFT_STICK]]],
	"interact":   ["Interact / Pick up", [["key", KEY_E], ["jb", JOY_BUTTON_X]]],
	"swap":       ["Quick Swap",  [["key", KEY_Q], ["jb", JOY_BUTTON_Y]]],
	"reload":     ["Reload",      [["key", KEY_R]]],
	"lock_on":    ["Lock-on / Switch", [["key", KEY_V], ["mouse", MOUSE_BUTTON_XBUTTON1], ["jb", JOY_BUTTON_RIGHT_STICK]]],
	"sneak":      ["Sneak", [["key", KEY_CTRL], ["key", KEY_ALT]]],
	"execute":    ["Execute / Kick", [["key", KEY_F], ["jb", JOY_BUTTON_B]]],
	"ability":    ["Ability",     [["key", KEY_C], ["mouse", MOUSE_BUTTON_MIDDLE], ["jb", JOY_BUTTON_RIGHT_SHOULDER]]],
	"equipment":  ["Equipment",   [["key", KEY_G], ["jb", JOY_BUTTON_LEFT_SHOULDER]]],
	"map":        ["Objectives",  [["key", KEY_TAB], ["jb", JOY_BUTTON_BACK]]],
	"pause":      ["Pause",       [["key", KEY_ESCAPE], ["jb", JOY_BUTTON_START]]],
	"restart":    ["Restart",     [["key", KEY_R], ["jb", JOY_BUTTON_A], ["jb", JOY_BUTTON_BACK]]],
	"ui_confirm": ["Confirm",     [["key", KEY_ENTER], ["key", KEY_SPACE], ["jb", JOY_BUTTON_A]]],
	"ui_cancel_alt": ["Back",     [["key", KEY_ESCAPE], ["jb", JOY_BUTTON_B]]],
}
## Actions shown on the remapping screen.
const REMAPPABLE := ["move_up", "move_down", "move_left", "move_right", "fire", "secondary", "dash", "sprint",
	"interact", "swap", "reload", "execute", "lock_on", "sneak", "ability", "equipment", "map", "pause"]

var using_gamepad := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rebuild()

func rebuild() -> void:
	var saved: Dictionary = SaveManager.get_setting("bindings", {})
	for action in ACTIONS.keys():
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, 0.35)
		var specs: Array = ACTIONS[action][1]
		if saved.has(action) and saved[action] is Array and not (saved[action] as Array).is_empty():
			specs = saved[action]
		for s in specs:
			var ev := spec_to_event(s)
			if ev:
				InputMap.action_add_event(action, ev)
	_setup_ui_actions()

## Godot's built-in ui_* actions have no gamepad face buttons and only listen
## to device 0. Make menus fully controller-friendly: A = accept, B = back,
## any controller works.
func _setup_ui_actions() -> void:
	var extra := {
		"ui_accept": [["jb", JOY_BUTTON_A]],
		"ui_cancel": [["jb", JOY_BUTTON_B]],
		"ui_select": [],
		"ui_up": [["jb", JOY_BUTTON_DPAD_UP], ["ja", JOY_AXIS_LEFT_Y, -1]],
		"ui_down": [["jb", JOY_BUTTON_DPAD_DOWN], ["ja", JOY_AXIS_LEFT_Y, 1]],
		"ui_left": [["jb", JOY_BUTTON_DPAD_LEFT], ["ja", JOY_AXIS_LEFT_X, -1]],
		"ui_right": [["jb", JOY_BUTTON_DPAD_RIGHT], ["ja", JOY_AXIS_LEFT_X, 1]],
	}
	for action in extra.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
		# drop existing joypad events (device 0 only) and re-add for all devices
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				InputMap.action_erase_event(action, ev)
			else:
				ev.device = -1
		for s in extra[action]:
			InputMap.action_add_event(action, spec_to_event(s))
		InputMap.action_set_deadzone(action, 0.5)
	# the "restart" action is a hold-free alias: R when no reloadable weapon is handled by player code.

func spec_to_event(s: Array) -> InputEvent:
	if s.is_empty():
		return null
	var ev := _spec_to_event(s)
	if ev:
		ev.device = -1   # match ANY keyboard/controller (pads are often device 1, 2... on Windows)
	return ev

func _spec_to_event(s: Array) -> InputEvent:
	match str(s[0]):
		"key":
			var e := InputEventKey.new()
			e.physical_keycode = int(s[1])
			return e
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = int(s[1])
			return m
		"jb":
			var b := InputEventJoypadButton.new()
			b.button_index = int(s[1])
			return b
		"ja":
			var a := InputEventJoypadMotion.new()
			a.axis = int(s[1])
			a.axis_value = float(s[2])
			return a
	return null

func event_to_spec(e: InputEvent) -> Array:
	if e is InputEventKey:
		return ["key", int(e.physical_keycode if e.physical_keycode != 0 else e.keycode)]
	if e is InputEventMouseButton:
		return ["mouse", int(e.button_index)]
	if e is InputEventJoypadButton:
		return ["jb", int(e.button_index)]
	if e is InputEventJoypadMotion and absf(e.axis_value) > 0.5:
		return ["ja", int(e.axis), signf(e.axis_value)]
	return []

## Replace the binding of one device family (keyboard/mouse or gamepad) for an action.
func remap(action: String, e: InputEvent) -> void:
	var spec := event_to_spec(e)
	if spec.is_empty():
		return
	var is_pad: bool = spec[0] == "jb" or spec[0] == "ja"
	var current: Array = []
	for ev in InputMap.action_get_events(action):
		var sp := event_to_spec(ev)
		if sp.is_empty():
			continue
		var sp_pad: bool = sp[0] == "jb" or sp[0] == "ja"
		if sp_pad != is_pad:
			current.append(sp)
	current.push_front(spec)
	var b: Dictionary = SaveManager.get_setting("bindings", {}).duplicate(true)
	b[action] = current
	SaveManager.set_setting("bindings", b)
	rebuild()

func reset_bindings() -> void:
	SaveManager.set_setting("bindings", {})
	rebuild()

func binding_text(action: String, pad := false) -> String:
	var parts: Array[String] = []
	for ev in InputMap.action_get_events(action):
		var is_pad: bool = ev is InputEventJoypadButton or ev is InputEventJoypadMotion
		if is_pad != pad:
			continue
		parts.append(event_text(ev))
	return " / ".join(parts) if not parts.is_empty() else "-"

func event_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return OS.get_keycode_string(ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode)
	if ev is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB", MOUSE_BUTTON_XBUTTON1: "M4", MOUSE_BUTTON_XBUTTON2: "M5"}.get(ev.button_index, "Mouse %d" % ev.button_index)
	if ev is InputEventJoypadButton:
		return {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB",
			JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Back", JOY_BUTTON_LEFT_STICK: "L3",
			JOY_BUTTON_RIGHT_STICK: "R3"}.get(ev.button_index, "Btn %d" % ev.button_index)
	if ev is InputEventJoypadMotion:
		return {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT", JOY_AXIS_LEFT_X: "LS", JOY_AXIS_LEFT_Y: "LS",
			JOY_AXIS_RIGHT_X: "RS", JOY_AXIS_RIGHT_Y: "RS"}.get(ev.axis, "Axis")
	return "?"

func _input(event: InputEvent) -> void:
	var pad: bool = event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4)
	var kbm: bool = event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length() > 2.0)
	if pad and not using_gamepad:
		using_gamepad = true
		device_changed.emit(true)
	elif kbm and using_gamepad:
		using_gamepad = false
		device_changed.emit(false)

func vibrate(weak: float, strong: float, duration: float) -> void:
	if not SaveManager.get_setting("vibration", true):
		return
	for id in Input.get_connected_joypads():
		Input.start_joy_vibration(id, weak, strong, duration)
