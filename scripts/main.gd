## Main.gd
## Top-level match bootstrap: wires maze, gatherers, chefs, input, and GameManager.
## Inherits from: Node (root of the main scene).
extends Node

@onready var _maze: Maze = $WorldHost/SharedMazeWorld/Maze
@onready var _input_router: Node = $InputRouter
@onready var _gatherer_a: Gatherer = $WorldHost/SharedMazeWorld/GathererA
@onready var _gatherer_b: Gatherer = $WorldHost/SharedMazeWorld/GathererB
@onready var _chef_a: ChefStation = $SplitScreenRoot/Grid/QuadrantA_Chef/SubViewport/ChefStation
@onready var _chef_b: ChefStation = $SplitScreenRoot/Grid/QuadrantB_Chef/SubViewport/ChefStation
@onready var _viewport_a: SubViewport = $SplitScreenRoot/Grid/QuadrantA_Gatherer/SubViewport
@onready var _viewport_b: SubViewport = $SplitScreenRoot/Grid/QuadrantB_Gatherer/SubViewport
@onready var _camera_a: Camera2D = $WorldHost/SharedMazeWorld/GathererA/GathererCamera
@onready var _camera_b: Camera2D = $WorldHost/SharedMazeWorld/GathererB/GathererCamera
@onready var _hud: GlobalHUD = $GlobalHUD
@onready var _world: Node2D = $WorldHost/SharedMazeWorld

const MONSTER_SCENE := preload("res://scenes/enemies/monster_enemy.tscn")

## Monster spawn milestones (seconds remaining on the match clock).
const SPAWN_AT_FOUR_MINUTES := 240.0
const SPAWN_AT_THREE_TEN := 190.0
const SPAWN_AT_TWO_THIRTY := 150.0
const SPAWN_AT_ONE_TEN := 70.0
const FINAL_WAVE_MIN_COUNT := 3
const FINAL_WAVE_MAX_COUNT := 10
const FINAL_WAVE_INTERVAL := 4.0

var _round_reset_busy: bool = false
var _spawn_milestones_done: Dictionary = {}
var _final_wave_spawns_left: int = 0
var _final_wave_cooldown: float = 0.0
var _monster_spawn_count: int = 0


## Godot Node lifecycle — _ready originates from Node.
func _ready() -> void:
	# Root viewport only draws UI — maze lives in WorldHost to prevent ghosting.
	get_viewport().world_2d = World2D.new()

	_setup_cameras()
	_maze.reset_for_match(_gatherer_a.get_collision_profile())
	_setup_gatherers()
	_input_router.register_gatherers(_gatherer_a, _gatherer_b)
	_input_router.register_chef_stations(_chef_a, _chef_b)
	EventBus.timer_updated.connect(_on_timer_updated)
	GameManager.prepare_round()


func _process(delta: float) -> void:
	if _final_wave_spawns_left <= 0 or not GameManager.is_match_running():
		return
	_final_wave_cooldown -= delta
	if _final_wave_cooldown > 0.0:
		return
	_spawn_monster()
	_final_wave_spawns_left -= 1
	if _final_wave_spawns_left > 0:
		_final_wave_cooldown = FINAL_WAVE_INTERVAL


func _on_timer_updated(time_left: float) -> void:
	if not GameManager.is_match_running():
		return

	if not _spawn_milestones_done.get(SPAWN_AT_FOUR_MINUTES, false) and time_left <= SPAWN_AT_FOUR_MINUTES:
		_spawn_milestones_done[SPAWN_AT_FOUR_MINUTES] = true
		_spawn_monster()

	if not _spawn_milestones_done.get(SPAWN_AT_THREE_TEN, false) and time_left <= SPAWN_AT_THREE_TEN:
		_spawn_milestones_done[SPAWN_AT_THREE_TEN] = true
		_spawn_monster()

	if not _spawn_milestones_done.get(SPAWN_AT_TWO_THIRTY, false) and time_left <= SPAWN_AT_TWO_THIRTY:
		_spawn_milestones_done[SPAWN_AT_TWO_THIRTY] = true
		_spawn_monster()
		_spawn_monster()

	if not _spawn_milestones_done.get(SPAWN_AT_ONE_TEN, false) and time_left <= SPAWN_AT_ONE_TEN:
		_spawn_milestones_done[SPAWN_AT_ONE_TEN] = true
		_final_wave_spawns_left = randi_range(FINAL_WAVE_MIN_COUNT, FINAL_WAVE_MAX_COUNT)
		_final_wave_cooldown = 0.0


func _spawn_monster() -> void:
	GameAudio.play_monster_spawn()
	var monster: MonsterEnemy = MONSTER_SCENE.instantiate()
	_world.add_child(monster)
	var texture := MonsterEnemy.TEX_BURGER
	if _monster_spawn_count > 0:
		texture = MonsterEnemy.MONSTER_TEXTURES[
			randi() % MonsterEnemy.MONSTER_TEXTURES.size()
		]
	_monster_spawn_count += 1
	monster.apply_texture(texture)
	monster.global_position = _maze_center()
	monster.setup([_gatherer_a, _gatherer_b])


## Center of the maze world — a neutral spot away from both gatherer spawns.
func _maze_center() -> Vector2:
	return Vector2(_maze.maze_size.x * _maze.cell_size, _maze.maze_size.y * _maze.cell_size) * 0.5


## Starts world reset on the next frame so it overlaps with the countdown.
func begin_round_reset() -> void:
	_round_reset_busy = true
	call_deferred("_finish_round_reset")


func _finish_round_reset() -> void:
	_reset_match_world()
	GameManager.prepare_round()
	_round_reset_busy = false


## Waits until a deferred round reset has finished (no-op if already done).
func await_round_reset_finished() -> void:
	while _round_reset_busy:
		await get_tree().process_frame


func _reset_match_world() -> void:
	_clear_knives()
	_clear_monsters()
	var profile := _gatherer_a.get_collision_profile()
	_maze.reset_for_match(profile)
	var spawns: Array[Vector2] = _maze.get_gatherer_spawn_points()
	_gatherer_a.reset_for_match(spawns[0])
	_gatherer_b.reset_for_match(spawns[1])
	_chef_a.reset_for_match()
	_chef_b.reset_for_match()


## Removes any knives left flying from a previous round.
func _clear_knives() -> void:
	for knife in get_tree().get_nodes_in_group("knives"):
		knife.queue_free()


## Removes all monsters and resets spawn scheduling for the next round.
func _clear_monsters() -> void:
	for monster in get_tree().get_nodes_in_group("monsters"):
		monster.queue_free()
	_spawn_milestones_done.clear()
	_final_wave_spawns_left = 0
	_final_wave_cooldown = 0.0
	_monster_spawn_count = 0


func _setup_gatherers() -> void:
	_gatherer_a.team = GameManager.Team.A
	_gatherer_b.team = GameManager.Team.B
	_gatherer_a.set_opponent(_gatherer_b)
	_gatherer_b.set_opponent(_gatherer_a)

	var spawns: Array[Vector2] = _maze.get_gatherer_spawn_points()
	_gatherer_a.position = spawns[0]
	_gatherer_b.position = spawns[1]
	_gatherer_a.set_spawn_position(spawns[0])
	_gatherer_b.set_spawn_position(spawns[1])


func _setup_cameras() -> void:
	if _camera_a and _viewport_a:
		_camera_a.setup_for_viewport(_viewport_a)
	if _camera_b and _viewport_b:
		_camera_b.setup_for_viewport(_viewport_b)
