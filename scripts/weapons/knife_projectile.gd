## KnifeProjectile.gd
## Thrown knife. Horizontal throws arc up then keep falling under gravity; vertical
## throws fly in a straight line. Damages the opposing gatherer and dies on any wall.
## Inherits from: Area2D (overlap detection against walls and gatherers).
extends Area2D
class_name KnifeProjectile

## Forward travel speed in pixels per second.
const SPEED := 520.0

## Upward launch speed for horizontal throws — the knife rises, then gravity takes over.
## Kept gentle so the initial rise stays inside a corridor before it starts falling.
const LAUNCH_UP_SPEED := 160.0

## Downward acceleration (pixels/sec^2) applied to horizontal throws so they keep falling.
const GRAVITY := 640.0

## Safety cleanup if the knife somehow never hits anything.
const MAX_LIFETIME := 6.0

var _velocity: Vector2 = Vector2.RIGHT * SPEED
var _thrower_team: int = -1
var _is_horizontal: bool = true
var _elapsed: float = 0.0

@onready var _sprite: Sprite2D = $Sprite


## Sets travel direction (cardinal) and which team is immune (the thrower's team).
## Call before adding the knife to the tree.
func setup(direction: Vector2, thrower_team: int) -> void:
	_thrower_team = thrower_team
	_is_horizontal = absf(direction.x) >= absf(direction.y)
	if _is_horizontal:
		# Forward + initial upward launch; gravity pulls it down over time.
		_velocity = Vector2(signf(direction.x) * SPEED, -LAUNCH_UP_SPEED)
	else:
		# Straight up or down, no gravity.
		_velocity = Vector2(0.0, signf(direction.y) * SPEED)


## Godot Node lifecycle — _ready originates from Node (via CanvasItem/Area2D).
func _ready() -> void:
	add_to_group("knives")
	collision_layer = 0
	collision_mask = 1 | 2 | 8  # walls (1) + gatherers (2) + monster (4th layer = 8)
	body_entered.connect(_on_body_entered)
	_face_velocity()


## Points the sprite along the current travel direction.
func _face_velocity() -> void:
	if _sprite and _velocity.length() > 0.01:
		_sprite.rotation = _velocity.angle()


## Godot Node lifecycle — _physics_process originates from Node.
func _physics_process(delta: float) -> void:
	_elapsed += delta

	# Horizontal throws keep accelerating downward so they rise then keep falling.
	if _is_horizontal:
		_velocity.y += GRAVITY * delta

	position += _velocity * delta
	_face_velocity()

	if _elapsed >= MAX_LIFETIME:
		queue_free()


## Godot Area2D callback — body_entered originates from Area2D signal.
func _on_body_entered(body: Node2D) -> void:
	if body is Gatherer:
		var gatherer := body as Gatherer
		# Ignore the thrower / same team; only the opponent is hit.
		if gatherer.team == _thrower_team:
			return
		gatherer.take_damage(50)
		queue_free()
		return

	if body is MonsterEnemy:
		(body as MonsterEnemy).take_damage(50)
		queue_free()
		return

	# Anything else solid (maze wall) destroys the knife.
	queue_free()
