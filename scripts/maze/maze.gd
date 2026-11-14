## Maze.gd
## Open playfield with ingredient spawning and a looping cartoon map video background (no walls).
@tool
extends Node2D
class_name Maze

## Target world size in pixels. Cell size grows to fit the gatherer, then the cell
## COUNT is recomputed so the playable area stays roughly this big.
const TARGET_WORLD_WIDTH := 2720.0
const TARGET_WORLD_HEIGHT := 1904.0

## Gatherer collision size used for editor layout preview (matches gatherer.tscn).
const EDITOR_GATHERER_SIZE := Vector2(31.5, 68)

## Empty space (pixels) added around the gatherer collision box so it never snags on walls.
const GATHERER_FIT_MARGIN := 16.0

@export var maze_size: Vector2i = Vector2i(20, 14)
@export var cell_size: int = 80
@export var max_pickups_on_map: int = 7
@export var respawn_delay_seconds: float = 3.0

## Distance between carved corridor nodes (3 = wider halls, 2 = tighter classic maze).
@export_range(2, 4, 1) var carve_step: int = 2

## When true, uses generation_seed for reproducible layouts (debug / testing).
@export var use_fixed_seed: bool = false
@export var generation_seed: int = 0

## Fraction of internal wall cells randomly opened after carving (higher = fewer walls).
@export_range(0.0, 0.5, 0.01) var extra_loop_percent: float = 0.18

## Extra passes that bulldoze walls sandwiched between open floor (creates wider routes).
@export_range(0, 4, 1) var open_area_passes: int = 1

@onready var _walls: Node2D = $Walls
@onready var _pickups: Node2D = $Pickups

const MAP_VIDEO_PATH := "res://assets/map/cartoon_map_video.ogv"
const MAP_SIZE_TEXTURE := preload("res://assets/map/map_cartoon.png")

const INGREDIENT_SCENE := preload("res://scenes/maze/ingredient_pickup.tscn")
const MIN_PICKUP_SEPARATION := 72.0
const INGREDIENT_SPAWN_RADIUS := 28.0
const WALL_COLLISION_MASK := 1
const ORDER_INGREDIENT_SPAWN_CHANCE := 0.85
const PICKUP_COUNT_MULTIPLIER := 0.55

## Map-texture region inside the invisible wall boundary (Background local space).
const INTERIOR_SPAWN_RECT_MAP := Rect2(680.0, 640.0, 1380.0, 680.0)

## Grid: true = walkable floor, false = wall. Indexed [y][x].
var _floor_grid: Array = []

## World-space centers of every walkable cell (used for spawns and pickups).
var _walkable_world_positions: Array[Vector2] = []

## Gatherer collision data for the current generate pass.
var _gatherer_body_size: Vector2 = Vector2(28, 28)
var _gatherer_body_offset: Vector2 = Vector2.ZERO

var _map_video_started := false


## Godot Node lifecycle — _ready originates from Node.
func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_refresh_layout()


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("_editor_refresh_layout")


## Matches in-game map scale in the editor so collision blocks line up with the art.
func _editor_refresh_layout() -> void:
	if not Engine.is_editor_hint():
		return
	_gatherer_body_size = EDITOR_GATHERER_SIZE
	_apply_cell_sizing()
	_update_background()


## Builds an open playfield (no walls) sized for the gatherer and background art.
func generate(gatherer_profile: Variant = null) -> void:
	_apply_gatherer_profile(gatherer_profile)
	_apply_cell_sizing()
	_clear_walls()
	_init_open_field()
	_rebuild_walkable_positions()
	_update_background()
	_ensure_map_video_playing()


func _apply_gatherer_profile(gatherer_profile: Variant) -> void:
	if gatherer_profile is Dictionary:
		_gatherer_body_size = gatherer_profile.get("size", Vector2(28, 28))
		_gatherer_body_offset = gatherer_profile.get("offset", Vector2.ZERO)
	elif gatherer_profile is Vector2:
		_gatherer_body_size = gatherer_profile
		_gatherer_body_offset = Vector2.ZERO
	else:
		_gatherer_body_size = Vector2(28, 28)
		_gatherer_body_offset = Vector2.ZERO


## Makes one cell big enough to hold the gatherer in either orientation, then recomputes
## the cell COUNT so the overall playfield stays close to the target world size.
func _apply_cell_sizing() -> void:
	var needed := maxf(_gatherer_body_size.x, _gatherer_body_size.y) + GATHERER_FIT_MARGIN
	cell_size = maxi(40, int(ceil(needed)))
	maze_size = Vector2i(
		maxi(9, int(round(TARGET_WORLD_WIDTH / cell_size))),
		maxi(7, int(round(TARGET_WORLD_HEIGHT / cell_size)))
	)


## Every cell is walkable — the cartoon background is the only map visuals.
func _init_open_field() -> void:
	_floor_grid.clear()
	for y in maze_size.y:
		var row: Array = []
		row.resize(maze_size.x)
		row.fill(true)
		_floor_grid.append(row)


func _run_carve_pipeline() -> void:
	_init_grid_all_walls()
	_carve_maze_recursive_backtracker()
	_add_extra_loops()
	_open_wide_areas()


func _setup_rng() -> void:
	if use_fixed_seed:
		seed(generation_seed)
	else:
		randomize()


func _clear_walls() -> void:
	for child in _walls.get_children():
		child.queue_free()
	_floor_grid.clear()
	_walkable_world_positions.clear()


## Fills the grid with walls, then forces a solid outer border.
func _init_grid_all_walls() -> void:
	_floor_grid.clear()
	for y in maze_size.y:
		var row: Array = []
		row.resize(maze_size.x)
		row.fill(false)
		_floor_grid.append(row)
	_enforce_outer_border()


## Recursive backtracker (DFS carve) — carves 1-cell-wide corridors between nodes.
func _carve_maze_recursive_backtracker() -> void:
	var start := _snap_to_carve_grid(Vector2i(1, 1))
	_dfs_carve(start.x, start.y)


## Godot-internal DFS — carves current cell and randomly visits unvisited neighbors.
func _dfs_carve(x: int, y: int) -> void:
	_floor_grid[y][x] = true
	var directions: Array[Vector2i] = [
		Vector2i(0, -carve_step), Vector2i(0, carve_step),
		Vector2i(-carve_step, 0), Vector2i(carve_step, 0),
	]
	directions.shuffle()

	for dir in directions:
		var nx: int = x + dir.x
		var ny: int = y + dir.y
		if not _is_in_bounds(nx, ny):
			continue
		if _floor_grid[ny][nx]:
			continue
		_carve_passage(x, y, dir)
		_dfs_carve(nx, ny)


## Turns every cell between two carved nodes into walkable floor.
func _carve_passage(from_x: int, from_y: int, dir: Vector2i) -> void:
	var step_x: int = 0 if dir.x == 0 else (1 if dir.x > 0 else -1)
	var step_y: int = 0 if dir.y == 0 else (1 if dir.y > 0 else -1)
	for t in range(1, carve_step):
		var wx: int = from_x + step_x * t
		var wy: int = from_y + step_y * t
		_floor_grid[wy][wx] = true


## Removes random internal wall cells to create loops and alternate routes.
func _add_extra_loops() -> void:
	var candidates: Array[Vector2i] = []
	for y in range(1, maze_size.y - 1):
		for x in range(1, maze_size.x - 1):
			if _floor_grid[y][x]:
				continue
			if _count_adjacent_floor(x, y) >= 2:
				candidates.append(Vector2i(x, y))

	candidates.shuffle()
	var remove_count := int(candidates.size() * extra_loop_percent)
	for i in remove_count:
		var cell: Vector2i = candidates[i]
		_floor_grid[cell.y][cell.x] = true


## Deterministic passes that remove walls trapped between open areas (more room to move).
func _open_wide_areas() -> void:
	for _pass in open_area_passes:
		var to_open: Array[Vector2i] = []
		for y in range(1, maze_size.y - 1):
			for x in range(1, maze_size.x - 1):
				if _floor_grid[y][x]:
					continue
				if _count_adjacent_floor(x, y) >= 3:
					to_open.append(Vector2i(x, y))
		for cell in to_open:
			_floor_grid[cell.y][cell.x] = true


## BFS flood-fill — perfect mazes are connected, but this guards against regressions.
func _verify_connectivity() -> void:
	var start_cell := _find_first_floor_cell()
	if start_cell == Vector2i(-1, -1):
		push_warning("Maze: no floor cells after generation.")
		return

	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start_cell]
	visited[_cell_key(start_cell)] = true
	var reachable := 0

	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		reachable += 1
		for neighbor in _get_cardinal_neighbors(cell.x, cell.y):
			var key := _cell_key(neighbor)
			if visited.has(key):
				continue
			if not _floor_grid[neighbor.y][neighbor.x]:
				continue
			visited[key] = true
			queue.append(neighbor)

	var total_floor := _count_floor_cells()
	if reachable != total_floor:
		push_warning("Maze: connectivity mismatch (%d / %d). Regenerating." % [reachable, total_floor])
		_run_carve_pipeline()


func _rebuild_walkable_positions() -> void:
	_walkable_world_positions.clear()
	for y in maze_size.y:
		for x in maze_size.x:
			if _floor_grid[y][x]:
				_walkable_world_positions.append(_cell_to_world(Vector2i(x, y)))


## Wall bodies are disabled — the map has no collision blocks.
func _spawn_wall_bodies() -> void:
	pass


## Returns two gatherer spawn positions inside the walled play area (Marker2D nodes under Background).
func get_gatherer_spawn_points() -> Array[Vector2]:
	var marker_a := get_node_or_null("Background/GathererSpawns/GathererSpawnA") as Node2D
	var marker_b := get_node_or_null("Background/GathererSpawns/GathererSpawnB") as Node2D
	if marker_a and marker_b:
		return [_spawn_marker_to_world(marker_a), _spawn_marker_to_world(marker_b)]
	push_warning("Maze: missing gatherer spawn markers under Background/GathererSpawns.")
	return [_map_local_to_world(Vector2(1300, 900)), _map_local_to_world(Vector2(1900, 900))]


func _spawn_marker_to_world(marker: Node2D) -> Vector2:
	var bg := get_node("Background") as Node2D
	var spawns_root := bg.get_node("GathererSpawns") as Node2D
	var map_local := spawns_root.position + marker.position
	return bg.to_global(map_local)


## Converts a point from Background/map texture space to SharedMazeWorld space.
func _map_local_to_world(map_local: Vector2) -> Vector2:
	var bg := get_node_or_null("Background") as Node2D
	if bg == null:
		return map_local
	return bg.to_global(map_local)


## Stretches the cartoon map video to cover the full playfield.
## Collision blocks should be children of Background so they move/scale with the art.
func _update_background() -> void:
	var bg := get_node_or_null("Background") as Node2D
	if bg == null:
		return
	var tex_size := MAP_SIZE_TEXTURE.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var world_size := Vector2(maze_size.x * cell_size, maze_size.y * cell_size)
	bg.position = Vector2.ZERO
	bg.scale = Vector2(world_size.x / tex_size.x, world_size.y / tex_size.y)

	var map_sprite := bg.get_node_or_null("MapSprite") as Sprite2D
	if map_sprite:
		map_sprite.centered = false
		map_sprite.position = Vector2.ZERO

	var viewport := bg.get_node_or_null("VideoViewport") as SubViewport
	if viewport:
		viewport.size = Vector2i(tex_size)
		var player := viewport.get_node_or_null("VideoStreamPlayer") as VideoStreamPlayer
		if player:
			player.set_size(tex_size)
		if map_sprite:
			if Engine.is_editor_hint():
				map_sprite.texture = MAP_SIZE_TEXTURE
			else:
				map_sprite.texture = viewport.get_texture()


func _ensure_map_video_playing() -> void:
	if Engine.is_editor_hint() or _map_video_started:
		return
	var player := get_node_or_null("Background/VideoViewport/VideoStreamPlayer") as VideoStreamPlayer
	if player == null:
		return
	var stream := load(MAP_VIDEO_PATH) as VideoStream
	if stream == null:
		push_warning("Maze: missing map video at %s" % MAP_VIDEO_PATH)
		return
	player.stream = stream
	if not player.finished.is_connected(_on_map_video_finished):
		player.finished.connect(_on_map_video_finished)
	player.play()
	_map_video_started = true


func _on_map_video_finished() -> void:
	var player := get_node_or_null("Background/VideoViewport/VideoStreamPlayer") as VideoStreamPlayer
	if player:
		player.play()


func _spawn_single_ingredient() -> void:
	var pos := _find_random_spawn_position()
	if pos == Vector2.ZERO:
		push_warning("Maze: could not find a valid ingredient spawn position.")
		return

	var data_id := _pick_spawn_ingredient_id()
	if data_id.is_empty():
		return
	var data := RecipeDatabase.get_ingredient(data_id)
	if data == null:
		return

	var pickup: IngredientPickup = INGREDIENT_SCENE.instantiate()
	pickup.setup_from_data(data)
	pickup.position = pos
	pickup.collected.connect(_on_pickup_collected)
	_pickups.add_child(pickup)


func _effective_max_pickups() -> int:
	return maxi(1, roundi(float(max_pickups_on_map) * PICKUP_COUNT_MULTIPLIER))


func _pick_spawn_ingredient_id() -> String:
	var all_ids := RecipeDatabase.get_all_ingredient_ids()
	if all_ids.is_empty():
		return ""

	var order_ids := RecipeDatabase.get_dish_base_ingredient_ids(GameManager.current_order_dish_id)
	if not order_ids.is_empty() and randf() < ORDER_INGREDIENT_SPAWN_CHANCE:
		return order_ids[randi() % order_ids.size()]
	return all_ids[randi() % all_ids.size()]


func _spawn_initial_pickups() -> void:
	for _i in _effective_max_pickups():
		_spawn_single_ingredient()


func _on_pickup_collected(_by_team: int, _ingredient_id: String) -> void:
	await get_tree().create_timer(respawn_delay_seconds).timeout
	if not GameManager.is_match_running():
		return
	if _pickups.get_child_count() < _effective_max_pickups():
		_spawn_single_ingredient()


## Clears pickups and rebuilds the maze for a fresh round.
func reset_for_match(gatherer_profile: Variant = null) -> void:
	for child in _pickups.get_children():
		child.queue_free()
	generate(gatherer_profile)
	call_deferred("_spawn_initial_pickups")


## Forces a solid one-cell wall around the whole maze (called before and after carving).
func _enforce_outer_border() -> void:
	for x in maze_size.x:
		_floor_grid[0][x] = false
		_floor_grid[maze_size.y - 1][x] = false
	for y in maze_size.y:
		_floor_grid[y][0] = false
		_floor_grid[y][maze_size.x - 1] = false


func _find_random_spawn_position() -> Vector2:
	for _attempt in 256:
		var pos := _map_local_to_world(Vector2(
			randf_range(INTERIOR_SPAWN_RECT_MAP.position.x, INTERIOR_SPAWN_RECT_MAP.end.x),
			randf_range(INTERIOR_SPAWN_RECT_MAP.position.y, INTERIOR_SPAWN_RECT_MAP.end.y)
		))
		if _is_valid_spawn_position(pos):
			return pos

	for _attempt in 128:
		var seed_pos := _random_gatherer_spawn_seed()
		var pos := seed_pos + Vector2(randf_range(-220.0, 220.0), randf_range(-220.0, 220.0))
		if _is_valid_spawn_position(pos):
			return pos

	for marker_path in ["Background/GathererSpawns/GathererSpawnA", "Background/GathererSpawns/GathererSpawnB"]:
		var marker := get_node_or_null(marker_path) as Node2D
		if marker:
			var pos := _spawn_marker_to_world(marker)
			if _is_valid_spawn_position(pos):
				return pos

	return Vector2.ZERO


func _random_gatherer_spawn_seed() -> Vector2:
	var marker_a := get_node_or_null("Background/GathererSpawns/GathererSpawnA") as Node2D
	var marker_b := get_node_or_null("Background/GathererSpawns/GathererSpawnB") as Node2D
	if marker_a and marker_b:
		return _spawn_marker_to_world(marker_a if randf() < 0.5 else marker_b)
	if marker_a:
		return _spawn_marker_to_world(marker_a)
	if marker_b:
		return _spawn_marker_to_world(marker_b)
	return _map_local_to_world(INTERIOR_SPAWN_RECT_MAP.get_center())


func _is_valid_spawn_position(pos: Vector2) -> bool:
	if not _is_valid_pickup_position(pos):
		return false
	return not _is_position_blocked_by_walls(pos)


func _is_position_blocked_by_walls(world_pos: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	if space == null:
		return false
	var params := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = INGREDIENT_SPAWN_RADIUS
	params.shape = shape
	params.transform = Transform2D(0.0, world_pos)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.collision_mask = WALL_COLLISION_MASK
	return not space.intersect_shape(params, 1).is_empty()


func _is_valid_pickup_position(pos: Vector2) -> bool:
	for child in _pickups.get_children():
		if child is Node2D and child.position.distance_to(pos) < MIN_PICKUP_SEPARATION:
			return false
	return true


func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * cell_size + cell_size * 0.5,
		cell.y * cell_size + cell_size * 0.5
	)


func _is_in_bounds(x: int, y: int) -> bool:
	return x > 0 and x < maze_size.x - 1 and y > 0 and y < maze_size.y - 1


func _snap_to_carve_grid(cell: Vector2i) -> Vector2i:
	var x: int = 1 + ((cell.x - 1) / carve_step) * carve_step
	var y: int = 1 + ((cell.y - 1) / carve_step) * carve_step
	x = clampi(x, 1, maze_size.x - 2)
	y = clampi(y, 1, maze_size.y - 2)
	return Vector2i(x, y)


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _get_cardinal_neighbors(x: int, y: int) -> Array[Vector2i]:
	return [
		Vector2i(x, y - 1), Vector2i(x, y + 1),
		Vector2i(x - 1, y), Vector2i(x + 1, y),
	]


func _count_adjacent_floor(x: int, y: int) -> int:
	var count := 0
	for n in _get_cardinal_neighbors(x, y):
		if _is_in_bounds(n.x, n.y) and _floor_grid[n.y][n.x]:
			count += 1
	return count


func _find_first_floor_cell() -> Vector2i:
	for y in range(1, maze_size.y - 1):
		for x in range(1, maze_size.x - 1):
			if _floor_grid[y][x]:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _count_floor_cells() -> int:
	var count := 0
	for y in maze_size.y:
		for x in maze_size.x:
			if _floor_grid[y][x]:
				count += 1
	return count


func _find_nearest_walkable_world(target_cell: Vector2i) -> Vector2:
	if _walkable_world_positions.is_empty():
		return Vector2.ZERO
	var target_world := _cell_to_world(target_cell)
	var best_pos: Vector2 = _walkable_world_positions[0]
	var best_dist := INF
	for pos in _walkable_world_positions:
		var dist := pos.distance_squared_to(target_world)
		if dist < best_dist:
			best_dist = dist
			best_pos = pos
	return best_pos


func _find_farthest_walkable_from_world(from: Vector2) -> Vector2:
	if _walkable_world_positions.is_empty():
		return Vector2.ZERO
	var best_pos: Vector2 = _walkable_world_positions[0]
	var best_dist := -1.0
	for pos in _walkable_world_positions:
		var dist := pos.distance_squared_to(from)
		if dist > best_dist:
			best_dist = dist
			best_pos = pos
	return best_pos
