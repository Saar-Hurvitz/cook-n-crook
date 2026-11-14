## InputRouter.gd
## Routes input to all four roles at once, each from the controller assigned in the lobby
## (keyboard = device -1). Gatherers move from their device's stick/d-pad and throw with
## Square; chefs navigate from their device and confirm with Circle.
## Inherits from: Node (child of Main scene).
extends Node

@export var chef_nav_cooldown_seconds: float = 0.12
@export var stick_nav_threshold: float = 0.65

## Analog stick magnitude below this counts as no input.
@export var stick_deadzone: float = 0.25

var gatherer_a: Gatherer = null
var gatherer_b: Gatherer = null
var chef_station_a: ChefStation = null
var chef_station_b: ChefStation = null

## Per-device chef navigation timing: device id -> { "cooldown": float, "armed": bool }.
var _chef_nav: Dictionary = {}


## Godot Node lifecycle — _ready originates from Node.
func _ready() -> void:
	GamepadInputSetup.apply()


## Godot Node lifecycle — _process drives every assigned role each frame.
func _process(delta: float) -> void:
	if not GameManager.is_match_running():
		return

	_drive_gatherer(gatherer_a, GameManager.get_device_for_slot(GameManager.PlayerSlot.TEAM_A_GATHERER))
	_drive_gatherer(gatherer_b, GameManager.get_device_for_slot(GameManager.PlayerSlot.TEAM_B_GATHERER))

	_drive_chef(chef_station_a, GameManager.get_device_for_slot(GameManager.PlayerSlot.TEAM_A_CHEF), delta)
	_drive_chef(chef_station_b, GameManager.get_device_for_slot(GameManager.PlayerSlot.TEAM_B_CHEF), delta)


## Moves one gatherer from its assigned device (keyboard when device == -1).
func _drive_gatherer(gatherer: Gatherer, device: int) -> void:
	if gatherer == null or device == GameManager.UNASSIGNED_DEVICE:
		return
	var direction := _read_move(device)
	if direction.length() > 1.0:
		direction = direction.normalized()
	gatherer.set_move_direction(direction)


## Reads movement from a device's stick + d-pad, or the keyboard for device -1.
func _read_move(device: int) -> Vector2:
	if device == -1:
		return _read_keyboard_move()

	var stick := Vector2(
		Input.get_joy_axis(device, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	)
	if stick.length() < stick_deadzone:
		stick = Vector2.ZERO

	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
		stick.x -= 1.0
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
		stick.x += 1.0
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP):
		stick.y -= 1.0
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN):
		stick.y += 1.0
	return stick


## Keyboard movement (WASD / arrows) for whichever role holds device -1.
func _read_keyboard_move() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1.0
	return v


## Steps a chef's grid selection from its assigned device (one box per push).
func _drive_chef(chef: ChefStation, device: int, delta: float) -> void:
	if chef == null or device == GameManager.UNASSIGNED_DEVICE:
		return

	var state: Dictionary = _chef_nav.get(device, {"cooldown": 0.0, "armed": true})
	state.cooldown = maxf(state.cooldown - delta, 0.0)

	var move := _read_move(device)
	if move.length() < stick_nav_threshold:
		state.armed = true
	elif state.armed and state.cooldown <= 0.0:
		chef.navigate_selection(_dominant_cardinal(move))
		state.cooldown = chef_nav_cooldown_seconds
		state.armed = false

	_chef_nav[device] = state


## Collapses analog tilt / d-pad into a single grid direction.
func _dominant_cardinal(stick: Vector2) -> Vector2i:
	if absf(stick.x) >= absf(stick.y):
		return Vector2i(1 if stick.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if stick.y > 0.0 else -1)


## Godot Node lifecycle — _input handles per-device buttons.
## Square (Joypad X) throws for that device's gatherer; Circle (Joypad B) swings the spoon
## or confirms its chef, depending on which role owns the controller.
func _input(event: InputEvent) -> void:
	if not GameManager.is_match_running():
		return

	if event is InputEventJoypadButton and event.pressed and not event.is_echo():
		var device: int = event.device
		if event.button_index == JOY_BUTTON_X:
			var g := _gatherer_for_device(device)
			if g:
				g.throw_knife()
		elif event.button_index == JOY_BUTTON_B:
			var gs := _gatherer_for_device(device)
			if gs:
				gs.swing_spoon()
				return
			var c := _chef_for_device(device)
			if c:
				c.confirm_selection()
		return

	# Keyboard fallbacks for whichever role holds device -1.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var kg := _gatherer_for_device(-1)
		if kg:
			kg.throw_knife()
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_F:
			var kgs := _gatherer_for_device(-1)
			if kgs:
				kgs.swing_spoon()
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			var kc := _chef_for_device(-1)
			if kc:
				kc.confirm_selection()


func register_gatherers(ga: Gatherer, gb: Gatherer) -> void:
	gatherer_a = ga
	gatherer_b = gb


func register_chef_stations(ca: ChefStation, cb: ChefStation) -> void:
	chef_station_a = ca
	chef_station_b = cb


func _gatherer_for_device(device: int) -> Gatherer:
	if device == GameManager.get_device_for_slot(GameManager.PlayerSlot.TEAM_A_GATHERER):
		return gatherer_a
	if device == GameManager.get_device_for_slot(GameManager.PlayerSlot.TEAM_B_GATHERER):
		return gatherer_b
	return null


func _chef_for_device(device: int) -> ChefStation:
	if device == GameManager.get_device_for_slot(GameManager.PlayerSlot.TEAM_A_CHEF):
		return chef_station_a
	if device == GameManager.get_device_for_slot(GameManager.PlayerSlot.TEAM_B_CHEF):
		return chef_station_b
	return null
