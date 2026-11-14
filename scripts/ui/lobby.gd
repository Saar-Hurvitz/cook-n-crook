## Lobby.gd
## Controller join + role-select screen. Each controller joins by pressing any button,
## appears in the middle column, then moves left/right into Team A / Team B and up/down to
## pick Chef or Gatherer (one player per role). When at least one player has joined,
## "Press X to start" appears; pressing X locks the roles and starts the match.
## Inherits from: Control.
extends Control
class_name Lobby

## Emitted when the lobby is confirmed. `role_devices` maps PlayerSlot -> device id.
signal start_requested(role_devices: Dictionary)

enum Loc { MIDDLE, A_CHEF, A_GATH, B_CHEF, B_GATH }

## PS5 Cross ("X") joins/starts; change here if you prefer a different button.
const START_BUTTON := JOY_BUTTON_A

## Keyboard counts as device -1 so the lobby can be tested without controllers.
const KEYBOARD_DEVICE := -1

const MAX_PLAYERS := 4
const NAV_THRESHOLD := 0.6

const HIGHLIGHT := Color(1.0, 0.92, 0.4)
const NORMAL := Color(1.0, 1.0, 1.0)

var _active: bool = false
var _locked: bool = false

## device id -> { "num": int, "loc": Loc }
var _players: Dictionary = {}
var _join_count: int = 0

## device id -> bool; false until the stick/d-pad returns to neutral (one step per push).
var _nav_armed: Dictionary = {}

@onready var _join_prompt: Label = $JoinPrompt
@onready var _start_prompt: Label = $StartPrompt
@onready var _middle_boxes: Array[Panel] = [
	$Middle/PlayerBox0, $Middle/PlayerBox1, $Middle/PlayerBox2, $Middle/PlayerBox3,
]
@onready var _role_boxes: Dictionary = {
	Loc.A_CHEF: $TeamA/ChefBox,
	Loc.A_GATH: $TeamA/GathBox,
	Loc.B_CHEF: $TeamB/ChefBox,
	Loc.B_GATH: $TeamB/GathBox,
}


## Enables/disables the lobby; turning it on resets everyone.
func set_active(active: bool) -> void:
	_active = active
	if active:
		_reset()


func _reset() -> void:
	_locked = false
	_players.clear()
	_nav_armed.clear()
	_join_count = 0
	_join_prompt.visible = true
	_start_prompt.visible = false
	_start_prompt.text = "Press X to start"
	_refresh()


## Godot Node lifecycle — _input handles joins, keyboard, and the start button.
func _input(event: InputEvent) -> void:
	if not _active or _locked:
		return

	if event is InputEventJoypadButton and event.pressed and not event.is_echo():
		var device: int = event.device
		if not _players.has(device):
			_join(device)
		elif event.button_index == START_BUTTON:
			_try_start()
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if not _players.has(KEYBOARD_DEVICE):
				_join(KEYBOARD_DEVICE)
			else:
				_try_start()


## Godot Node lifecycle — _process polls each joined device for navigation steps.
func _process(_delta: float) -> void:
	if not _active or _locked:
		return
	for device in _players.keys():
		var card := _read_cardinal(device)
		if card == Vector2i.ZERO:
			_nav_armed[device] = true
			continue
		if _nav_armed.get(device, true):
			_nav_armed[device] = false
			_move_player(device, card)


func _join(device: int) -> void:
	if _join_count >= MAX_PLAYERS:
		return
	_join_count += 1
	_players[device] = {"num": _join_count, "loc": Loc.MIDDLE}
	_nav_armed[device] = false
	_join_prompt.visible = false
	_refresh()


## Returns a single cardinal step for a device, or ZERO when below the move threshold.
func _read_cardinal(device: int) -> Vector2i:
	var v := _read_vector(device)
	if v.length() < NAV_THRESHOLD:
		return Vector2i.ZERO
	if absf(v.x) >= absf(v.y):
		return Vector2i(1 if v.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if v.y > 0.0 else -1)


func _read_vector(device: int) -> Vector2:
	if device == KEYBOARD_DEVICE:
		var k := Vector2.ZERO
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
			k.x -= 1.0
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
			k.x += 1.0
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
			k.y -= 1.0
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
			k.y += 1.0
		return k

	var v := Vector2(
		Input.get_joy_axis(device, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	)
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
		v.x -= 1.0
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
		v.x += 1.0
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP):
		v.y -= 1.0
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN):
		v.y += 1.0
	return v


func _move_player(device: int, card: Vector2i) -> void:
	var loc: int = _players[device].loc
	var target := _target_loc(loc, card)
	if target == loc:
		return
	if target != Loc.MIDDLE and _is_occupied(target):
		return
	_players[device].loc = target
	_refresh()


## Resolves where a step leads. Returns the same loc when the move is not allowed.
func _target_loc(loc: int, card: Vector2i) -> int:
	match loc:
		Loc.MIDDLE:
			if card.x < 0:
				return _enter_team(Loc.A_CHEF, Loc.A_GATH)
			if card.x > 0:
				return _enter_team(Loc.B_CHEF, Loc.B_GATH)
			return loc
		Loc.A_CHEF:
			if card.x > 0:
				return Loc.MIDDLE
			if card.y > 0:
				return Loc.A_GATH
			return loc
		Loc.A_GATH:
			if card.x > 0:
				return Loc.MIDDLE
			if card.y < 0:
				return Loc.A_CHEF
			return loc
		Loc.B_CHEF:
			if card.x < 0:
				return Loc.MIDDLE
			if card.y > 0:
				return Loc.B_GATH
			return loc
		Loc.B_GATH:
			if card.x < 0:
				return Loc.MIDDLE
			if card.y < 0:
				return Loc.B_CHEF
			return loc
	return loc


## Picks the first free role when entering a team; blocks if both are taken.
func _enter_team(chef_loc: int, gath_loc: int) -> int:
	if not _is_occupied(chef_loc):
		return chef_loc
	if not _is_occupied(gath_loc):
		return gath_loc
	return Loc.MIDDLE


func _is_occupied(loc: int) -> bool:
	for device in _players:
		if _players[device].loc == loc:
			return true
	return false


func _player_at(loc: int) -> int:
	for device in _players:
		if _players[device].loc == loc:
			return _players[device].num
	return -1


func _can_start() -> bool:
	return _join_count >= 1


## Repaints every box and the start prompt from the current player state.
func _refresh() -> void:
	for loc in _role_boxes.keys():
		var box: Panel = _role_boxes[loc]
		var content: Label = box.get_node("VBox/Content")
		var num := _player_at(loc)
		if num > 0:
			content.text = "Player %d" % num
			box.self_modulate = HIGHLIGHT
		else:
			content.text = "—"
			box.self_modulate = NORMAL

	for i in _middle_boxes.size():
		var mbox := _middle_boxes[i]
		var label: Label = mbox.get_node("Label")
		var player_num := i + 1
		var device = _device_for_num(player_num)
		if device == null or _players[device].loc != Loc.MIDDLE:
			mbox.visible = false
			continue
		mbox.visible = true
		label.text = "Player %d" % player_num
		mbox.self_modulate = HIGHLIGHT

	if not _locked:
		_start_prompt.visible = _can_start()


## Returns the device id for a player number, or null if unjoined.
func _device_for_num(num: int):
	for device in _players:
		if _players[device].num == num:
			return device
	return null


func _try_start() -> void:
	if _locked or not _can_start():
		return
	_locked = true
	_start_prompt.text = "Starting..."

	# Anyone still in the middle column gets the first open role.
	for device in _players:
		if _players[device].loc == Loc.MIDDLE:
			var slot := _first_free_role()
			if slot != Loc.MIDDLE:
				_players[device].loc = slot

	var mapping: Dictionary = {}
	for device in _players:
		var loc: int = _players[device].loc
		if loc == Loc.MIDDLE:
			continue
		mapping[_slot_for_loc(loc)] = device
	start_requested.emit(mapping)


func _first_free_role() -> int:
	for loc in [Loc.A_CHEF, Loc.A_GATH, Loc.B_CHEF, Loc.B_GATH]:
		if not _is_occupied(loc):
			return loc
	return Loc.MIDDLE


func _slot_for_loc(loc: int) -> int:
	match loc:
		Loc.A_CHEF:
			return GameManager.PlayerSlot.TEAM_A_CHEF
		Loc.A_GATH:
			return GameManager.PlayerSlot.TEAM_A_GATHERER
		Loc.B_CHEF:
			return GameManager.PlayerSlot.TEAM_B_CHEF
		_:
			return GameManager.PlayerSlot.TEAM_B_GATHERER
