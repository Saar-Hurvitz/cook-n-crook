## Gatherer.gd
## Playable maze character: movement and combat.
## Inherits from: CharacterBody2D (Godot kinematic 2D body with move_and_slide).
extends CharacterBody2D
class_name Gatherer

@export var team: int = 0  ## 0 = Team A, 1 = Team B
@export var move_speed: float = 330.0
@export var separation_radius: float = 30.0

const MAX_HEALTH := 1000
const KNIFE_DAMAGE := 50
const RESPAWN_LOCK_SECONDS := 10
const MAX_KNIVES := 5
const MAX_SPOONS := 6
const HIT_GLOW_SECONDS := 0.8

const KNIFE_SCENE := preload("res://scenes/weapons/knife.tscn")
const SPOON_SWING_SCENE := preload("res://scenes/weapons/spoon_swing.tscn")

var _move_direction: Vector2 = Vector2.ZERO
var _clash_cooldown: float = 0.0
var _opponent: Gatherer = null
var _current_animation: StringName = &"idle"

## Combat / health state.
var _health: int = MAX_HEALTH
var _facing: Vector2 = Vector2.RIGHT
var _spawn_position: Vector2 = Vector2.ZERO
var _respawning: bool = false
var _respawn_time_left: float = 0.0
var _respawn_last_display: int = 0

## Knife ammo (refilled by this team's chef).
var _knives: int = MAX_KNIVES

## Spoon swing charges (refilled by this team's chef).
var _spoons: int = MAX_SPOONS

## Base sprite tint (team color) so damage flashes can fade back to it.
var _base_modulate: Color = Color.WHITE
var _flash_tween: Tween = null
var _spoon_swing: SpoonSwing = null

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


## Godot Node lifecycle — _ready originates from Node.
func _ready() -> void:
	_setup_animations()
	_apply_team_color()
	_spoon_swing = SPOON_SWING_SCENE.instantiate() as SpoonSwing
	add_child(_spoon_swing)
	_spoon_swing.setup(self)
	EventBus.knife_resupply_requested.connect(_on_knife_resupply_requested)
	EventBus.spoon_resupply_requested.connect(_on_spoon_resupply_requested)
	EventBus.gatherer_health_changed.emit(team, _health, MAX_HEALTH)
	EventBus.gatherer_knives_changed.emit(team, _knives, MAX_KNIVES)
	EventBus.gatherer_spoons_changed.emit(team, _spoons, MAX_SPOONS)


func _setup_animations() -> void:
	if not _animated_sprite:
		return
	_animated_sprite.sprite_frames = GathererAnimations.get_sprite_frames()
	_play_animation(&"idle")


func set_move_direction(direction: Vector2) -> void:
	if _respawning:
		_move_direction = Vector2.ZERO
		return
	_move_direction = direction
	if direction.length() > 0.1:
		_facing = _to_cardinal(direction)


## Snaps an analog direction to the dominant cardinal (left/right/up/down).
func _to_cardinal(direction: Vector2) -> Vector2:
	if absf(direction.x) >= absf(direction.y):
		return Vector2(signf(direction.x), 0.0)
	return Vector2(0.0, signf(direction.y))


## Spawns one knife in the current facing direction. No cooldown — call per press.
## Does nothing if the gatherer is out of knives.
func throw_knife() -> void:
	if _respawning or not GameManager.is_match_running():
		return
	if _knives <= 0:
		return
	_knives -= 1
	EventBus.gatherer_knives_changed.emit(team, _knives, MAX_KNIVES)

	var knife := KNIFE_SCENE.instantiate() as KnifeProjectile
	knife.setup(_facing, team)
	get_parent().add_child(knife)
	knife.global_position = global_position
	EventBus.knife_thrown.emit(team)


## Swings the melee spoon in an arc. Ignored while already swinging, respawning, or out of charges.
func swing_spoon() -> void:
	if _respawning or not GameManager.is_match_running():
		return
	if _spoons <= 0:
		return
	if _spoon_swing == null or _spoon_swing.is_swinging():
		return
	_spoons -= 1
	EventBus.gatherer_spoons_changed.emit(team, _spoons, MAX_SPOONS)
	_spoon_swing.start_swing(_facing)


## Chef resupply: adds one knife to this team's gatherer, capped at MAX_KNIVES.
func _on_knife_resupply_requested(requesting_team: int) -> void:
	if requesting_team != team:
		return
	if _knives >= MAX_KNIVES:
		return
	_knives += 1
	EventBus.gatherer_knives_changed.emit(team, _knives, MAX_KNIVES)


## Chef resupply: adds one spoon charge to this team's gatherer, capped at MAX_SPOONS.
func _on_spoon_resupply_requested(requesting_team: int) -> void:
	if requesting_team != team:
		return
	if _spoons >= MAX_SPOONS:
		return
	_spoons += 1
	EventBus.gatherer_spoons_changed.emit(team, _spoons, MAX_SPOONS)


## Monster contact: deals damage and shows the hit glow.
func hit_by_monster(amount: int) -> void:
	if _respawning or not GameManager.is_match_running():
		return
	take_damage(amount)


## Spoon hit: deals damage and shows the hit glow.
func hit_by_spoon(amount: int) -> void:
	if _respawning or not GameManager.is_match_running():
		return
	take_damage(amount)


## White glow after any damage, fading back to the team tint.
func _flash_hit_glow() -> void:
	if not _animated_sprite:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_animated_sprite.modulate = Color(1.0, 1.0, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_animated_sprite, "modulate", _base_modulate, HIT_GLOW_SECONDS)


## Applies damage from any source. Ignored while respawning (invulnerable).
func take_damage(amount: int) -> void:
	if _respawning or not GameManager.is_match_running():
		return
	_health = maxi(_health - amount, 0)
	GameAudio.play_gatherer_damage()
	_flash_hit_glow()
	EventBus.gatherer_health_changed.emit(team, _health, MAX_HEALTH)
	if _health <= 0:
		_start_respawn()


## Sends the gatherer back to its spawn, refills health, and begins the 10s movement lock.
func _start_respawn() -> void:
	if _respawning:
		return
	_respawning = true
	_respawn_time_left = float(RESPAWN_LOCK_SECONDS)
	_respawn_last_display = RESPAWN_LOCK_SECONDS
	_health = MAX_HEALTH
	global_position = _spawn_position
	velocity = Vector2.ZERO
	_move_direction = Vector2.ZERO
	EventBus.gatherer_health_changed.emit(team, _health, MAX_HEALTH)
	EventBus.gatherer_respawn_started.emit(team)
	EventBus.gatherer_respawn_tick.emit(team, RESPAWN_LOCK_SECONDS)


## Counts the respawn lock down from 10 to 1, then unlocks movement.
func _tick_respawn(delta: float) -> void:
	_respawn_time_left -= delta
	var display := maxi(1, int(ceil(_respawn_time_left)))
	if display != _respawn_last_display:
		_respawn_last_display = display
		EventBus.gatherer_respawn_tick.emit(team, display)
	if _respawn_time_left <= 0.0:
		_respawning = false
		EventBus.gatherer_respawn_finished.emit(team)


## Stores where this gatherer respawns for the current round.
func set_spawn_position(spawn_position: Vector2) -> void:
	_spawn_position = spawn_position


## Links the opposing gatherer for soft separation on overlap.
func set_opponent(opponent: Gatherer) -> void:
	_opponent = opponent


## Godot Node lifecycle — _physics_process originates from Node.
## CharacterBody2D uses velocity + move_and_slide for maze navigation.
func _physics_process(delta: float) -> void:
	# Locked + invulnerable while respawning; count the timer down here.
	if _respawning:
		_tick_respawn(delta)
		velocity = Vector2.ZERO
		_move_direction = Vector2.ZERO
		move_and_slide()
		_update_animation()
		_update_walk_sound()
		return

	if not GameManager.is_match_running():
		velocity = Vector2.ZERO
		_move_direction = Vector2.ZERO
		move_and_slide()
		_update_animation()
		_update_walk_sound()
		return

	velocity = _move_direction * move_speed
	move_and_slide()
	_update_animation()
	_update_walk_sound()

	_clash_cooldown = maxf(_clash_cooldown - delta, 0.0)
	_separate_from_opponent()


## Picks walk_* while moving and idle when no input is held.
func _update_animation() -> void:
	var next_animation := _animation_for_direction(_move_direction)
	if next_animation != _current_animation:
		_play_animation(next_animation)


func _animation_for_direction(direction: Vector2) -> StringName:
	if direction.length_squared() < 0.01:
		return &"idle"
	if absf(direction.y) >= absf(direction.x):
		return &"walk_up" if direction.y < 0.0 else &"walk_down"
	return &"walk_right" if direction.x > 0.0 else &"walk_left"


func _update_walk_sound() -> void:
	var moving := (
		not _respawning
		and GameManager.is_match_running()
		and _move_direction.length_squared() > 0.01
	)
	GameAudio.set_gatherer_walking(team, moving)


func _play_animation(animation_name: StringName) -> void:
	if not _animated_sprite or not _animated_sprite.sprite_frames:
		return
	if not _animated_sprite.sprite_frames.has_animation(animation_name):
		return
	_current_animation = animation_name
	_animated_sprite.play(animation_name)


## Soft separation so gatherers never stick together or ride as one unit.
## Gatherers do not collide on layer 2 — overlap is resolved here instead.
func _separate_from_opponent() -> void:
	if _opponent == null or _opponent.team == team:
		return

	var diff := global_position - _opponent.global_position
	var dist_sq := diff.length_squared()
	var min_sep := separation_radius

	if dist_sq >= min_sep * min_sep:
		return

	var dist := sqrt(dist_sq) if dist_sq > 0.0001 else 0.0001
	var push_dir := diff / dist if dist_sq > 0.0001 else Vector2.RIGHT
	var overlap := min_sep - dist

	global_position += push_dir * overlap

	if _clash_cooldown <= 0.0 and get_instance_id() < _opponent.get_instance_id():
		_clash_cooldown = 0.35
		_resolve_gatherer_clash(_opponent)


func _resolve_gatherer_clash(other: Gatherer) -> void:
	if other.team == team:
		return
	EventBus.gatherer_clash.emit(team, other.team)


func _apply_team_color() -> void:
	if not _animated_sprite:
		return
	match team:
		GameManager.Team.A:
			_base_modulate = Color(0.82, 0.9, 1.0)
		_:
			_base_modulate = Color(1.0, 0.82, 0.78)
	_animated_sprite.modulate = _base_modulate


## Resets position, movement, health, and combat state for a new round.
func reset_for_match(spawn_position: Vector2) -> void:
	_spawn_position = spawn_position
	global_position = spawn_position
	velocity = Vector2.ZERO
	_move_direction = Vector2.ZERO
	_facing = Vector2.RIGHT
	_clash_cooldown = 0.0
	_health = MAX_HEALTH
	_respawning = false
	_respawn_time_left = 0.0
	_knives = MAX_KNIVES
	_spoons = MAX_SPOONS
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	if _animated_sprite:
		_animated_sprite.modulate = _base_modulate
	_play_animation(&"idle")
	GameAudio.set_gatherer_walking(team, false)
	EventBus.gatherer_health_changed.emit(team, _health, MAX_HEALTH)
	EventBus.gatherer_knives_changed.emit(team, _knives, MAX_KNIVES)
	EventBus.gatherer_spoons_changed.emit(team, _spoons, MAX_SPOONS)
	EventBus.gatherer_respawn_finished.emit(team)


## Returns the gatherer's collision rectangle size from the scene shape.
func get_collision_size() -> Vector2:
	var shape_node: CollisionShape2D = $CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		return (shape_node.shape as RectangleShape2D).size
	return Vector2(28, 28)


## Size + offset used by the maze generator to size corridors correctly.
func get_collision_profile() -> Dictionary:
	var shape_node: CollisionShape2D = $CollisionShape2D
	var size := get_collision_size()
	var offset := shape_node.position if shape_node else Vector2.ZERO
	return {"size": size, "offset": offset}
