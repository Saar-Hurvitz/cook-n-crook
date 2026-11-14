## GamepadInputSetup.gd
## Registers PS5 / DualSense and generic gamepad bindings on the InputMap once.
## Inherits from: RefCounted (stateless utility, no scene tree node).
class_name GamepadInputSetup
extends RefCounted

static var _applied: bool = false


## Adds joypad motion/button events to move_* and chef_confirm if not already present.
static func apply() -> void:
	if _applied:
		return
	_applied = true

	_set_deadzone("move_left", 0.25)
	_set_deadzone("move_right", 0.25)
	_set_deadzone("move_up", 0.25)
	_set_deadzone("move_down", 0.25)

	# Left analog stick.
	_add_motion("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_motion("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_motion("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_motion("move_down", JOY_AXIS_LEFT_Y, 1.0)

	# D-pad (left side of controller).
	_add_button("move_up", JOY_BUTTON_DPAD_UP)
	_add_button("move_down", JOY_BUTTON_DPAD_DOWN)
	_add_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_button("move_right", JOY_BUTTON_DPAD_RIGHT)

	# Chef confirm — Circle on PS5 maps to Joypad B in Godot.
	if not InputMap.has_action("chef_confirm"):
		InputMap.add_action("chef_confirm", 0.2)
	_set_deadzone("chef_confirm", 0.2)
	_add_button("chef_confirm", JOY_BUTTON_B)
	_add_key("chef_confirm", KEY_ENTER)
	_add_key("chef_confirm", KEY_SPACE)

	# Throw knife — right mouse button or Square (PS5 = Joypad X in Godot).
	if not InputMap.has_action("throw_knife"):
		InputMap.add_action("throw_knife", 0.2)
	_set_deadzone("throw_knife", 0.2)
	_add_button("throw_knife", JOY_BUTTON_X)
	_add_mouse_button("throw_knife", MOUSE_BUTTON_RIGHT)

	# Swing spoon — Circle on PS5 (Joypad B in Godot) or F on keyboard.
	if not InputMap.has_action("swing_spoon"):
		InputMap.add_action("swing_spoon", 0.2)
	_set_deadzone("swing_spoon", 0.2)
	_remove_joypad_button("swing_spoon", JOY_BUTTON_Y)
	_add_button("swing_spoon", JOY_BUTTON_B)
	_add_key("swing_spoon", KEY_F)


static func _set_deadzone(action: String, deadzone: float) -> void:
	if InputMap.has_action(action):
		InputMap.action_set_deadzone(action, deadzone)


static func _add_motion(action: String, axis: JoyAxis, axis_value: float) -> void:
	if not InputMap.has_action(action):
		return
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = axis_value
	if not _has_event(action, event):
		InputMap.action_add_event(action, event)


static func _remove_joypad_button(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		return
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and existing.button_index == button:
			InputMap.action_erase_event(action, existing)


static func _add_button(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	if not _has_event(action, event):
		InputMap.action_add_event(action, event)


static func _add_mouse_button(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		return
	var event := InputEventMouseButton.new()
	event.button_index = button
	if not _has_event(action, event):
		InputMap.action_add_event(action, event)


static func _add_key(action: String, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	if not _has_event(action, event):
		InputMap.action_add_event(action, event)


static func _has_event(action: String, probe: InputEvent) -> bool:
	for existing in InputMap.action_get_events(action):
		if existing.is_match(probe):
			return true
	return false
