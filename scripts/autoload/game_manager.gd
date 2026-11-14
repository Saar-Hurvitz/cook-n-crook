## GameManager.gd
## Authoritative match state: timer, scores, win condition, and team constants.
## Inherits from: Node (registered as an autoload singleton).
extends Node

enum Team { A = 0, B = 1 }

## Player slot indices — map to split-screen quadrants.
enum PlayerSlot {
	TEAM_A_GATHERER = 0,
	TEAM_A_CHEF = 1,
	TEAM_B_GATHERER = 2,
	TEAM_B_CHEF = 3,
}

## Total match duration in seconds (editable from the inspector on the autoload).
@export var match_duration_seconds: float = 300.0

## Currently active controllable slot; -1 means no input routed yet.
var active_player_slot: int = -1

## Sentinel meaning "no controller assigned to this role yet".
const UNASSIGNED_DEVICE := -1000

## Role slot (PlayerSlot) -> input device id chosen in the lobby (-1 = keyboard).
var role_devices: Dictionary = {}

var team_scores: Dictionary = {
	Team.A: 0,
	Team.B: 0,
}

var _time_remaining: float = 0.0
var _match_running: bool = false

## Shared dish both chefs race to complete (dish id key in RecipeDatabase.DISHES).
var current_order_dish_id: String = ""


## Godot Node lifecycle — _ready originates from Node.
func _ready() -> void:
	# Listen for recipe completions to update scoreboard.
	EventBus.recipe_completed.connect(_on_recipe_completed)


## Godot Node lifecycle — _process originates from Node; drives the global timer.
func _process(delta: float) -> void:
	if not _match_running:
		return

	_time_remaining -= delta
	EventBus.timer_updated.emit(maxf(_time_remaining, 0.0))

	if _time_remaining <= 0.0:
		_end_match()


## Resets scores, timer display, and order without starting gameplay (used before countdown).
func prepare_round() -> void:
	team_scores[Team.A] = 0
	team_scores[Team.B] = 0
	_time_remaining = match_duration_seconds
	_match_running = false
	active_player_slot = PlayerSlot.TEAM_A_GATHERER
	EventBus.control_switched.emit(active_player_slot)
	EventBus.timer_updated.emit(_time_remaining)
	generate_new_order()


## Starts the live match after the pre-game countdown finishes.
func start_match() -> void:
	_match_running = true
	EventBus.timer_updated.emit(_time_remaining)
	EventBus.match_started.emit()


## Picks a random dish and broadcasts it so both chef stations refresh.
func generate_new_order() -> void:
	var dish := RecipeDatabase.get_random_dish()
	if dish == null:
		return
	current_order_dish_id = dish.id
	EventBus.order_assigned.emit(dish.id)


## Awards points to the given team and returns the new total.
func add_score(team: int, points: int) -> int:
	team_scores[team] += points
	return team_scores[team]


func get_score(team: int) -> int:
	return team_scores.get(team, 0)


func is_match_running() -> bool:
	return _match_running


func get_time_remaining() -> float:
	return _time_remaining


## Switches keyboard/gamepad input focus to the clicked quadrant's character.
func set_active_player(slot: int) -> void:
	if slot < 0 or slot > PlayerSlot.TEAM_B_CHEF:
		return
	active_player_slot = slot
	EventBus.control_switched.emit(slot)


## Stores the lobby's role -> device assignment used to route gameplay input.
func set_role_devices(devices: Dictionary) -> void:
	role_devices = devices.duplicate()


## Returns the device controlling a role slot, or UNASSIGNED_DEVICE if none.
func get_device_for_slot(slot: int) -> int:
	return int(role_devices.get(slot, UNASSIGNED_DEVICE))


func get_team_for_slot(slot: int) -> int:
	match slot:
		PlayerSlot.TEAM_A_GATHERER, PlayerSlot.TEAM_A_CHEF:
			return Team.A
		_:
			return Team.B


func is_gatherer_slot(slot: int) -> bool:
	return slot == PlayerSlot.TEAM_A_GATHERER or slot == PlayerSlot.TEAM_B_GATHERER


func is_chef_slot(slot: int) -> bool:
	return slot == PlayerSlot.TEAM_A_CHEF or slot == PlayerSlot.TEAM_B_CHEF


func _on_recipe_completed(team: int, points: int, _dish_name: String) -> void:
	add_score(team, points)


func _end_match() -> void:
	_match_running = false
	_time_remaining = 0.0

	var score_a := get_score(Team.A)
	var score_b := get_score(Team.B)
	var winner := Team.A if score_a > score_b else (Team.B if score_b > score_a else -1)

	EventBus.match_ended.emit(winner, score_a, score_b)
