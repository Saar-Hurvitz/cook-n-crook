## SpoonSwing.gd
## Melee swing attached to a gatherer's hand. Arcs from -45° above the head,
## through +90° (right) or -180° (left) in front, then back to rest.
## Left/right use separate peak angles; up/down keep their own base rotation.
extends Node2D
class_name SpoonSwing

const SWING_DAMAGE := 100
## Left/right horizontal arcs differ: right sweeps to +90°, left sweeps to -180°.
const START_DEG := -45.0
const PEAK_DEG_RIGHT := 90.0
const PEAK_DEG_LEFT := -180.0
const SWING_UP_TIME := 0.14
const SWING_DOWN_TIME := 0.14
const SWING_RETURN_TIME := 0.12

var _owner: Gatherer = null
var _swinging: bool = false
var _hit_this_swing: bool = false
var _base_rotation: float = 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _hit_area: Area2D = $HitArea


func setup(owner: Gatherer) -> void:
	_owner = owner
	visible = false
	_hit_area.body_entered.connect(_on_body_entered)
	_hit_area.monitoring = false


func is_swinging() -> bool:
	return _swinging


## Plays the swing arc for the gatherer's current facing direction.
func start_swing(facing: Vector2) -> void:
	if _swinging or _owner == null:
		return
	_swinging = true
	_hit_this_swing = false
	visible = true
	var peak_deg := PEAK_DEG_RIGHT
	scale.x = 1.0
	if _is_horizontal(facing):
		_base_rotation = 0.0
		if facing.x < 0.0:
			peak_deg = PEAK_DEG_LEFT
			position = Vector2(-24.0, -6.0)
		else:
			position = Vector2(24.0, -6.0)
	else:
		position = _hand_offset(facing)
		_base_rotation = _facing_base_rotation(facing)
	rotation = _base_rotation + deg_to_rad(START_DEG)
	_hit_area.monitoring = true

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(
		self, "rotation", _base_rotation + deg_to_rad(peak_deg), SWING_UP_TIME
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		self, "rotation", _base_rotation, SWING_DOWN_TIME
	).set_ease(Tween.EASE_IN)
	tween.tween_callback(_finish_swing)


func _finish_swing() -> void:
	_swinging = false
	_hit_area.monitoring = false
	visible = false
	rotation = _base_rotation


func _on_body_entered(body: Node2D) -> void:
	if not _swinging or _hit_this_swing or _owner == null:
		return
	if body is MonsterEnemy:
		var monster := body as MonsterEnemy
		_hit_this_swing = true
		monster.hit_by_spoon(SWING_DAMAGE, _owner.global_position)
		return
	if not body is Gatherer:
		return
	var target := body as Gatherer
	if target.team == _owner.team or target == _owner:
		return
	_hit_this_swing = true
	target.hit_by_spoon(SWING_DAMAGE)


## Hand pivot offset for up/down facing (horizontal left/right set in start_swing).
func _hand_offset(facing: Vector2) -> Vector2:
	if facing.y < 0.0:
		return Vector2(14.0, -30.0)
	return Vector2(14.0, 26.0)


func _is_horizontal(facing: Vector2) -> bool:
	return absf(facing.x) > absf(facing.y)


## Base angle for up/down facing only (left/right use scale flip + 0° base).
func _facing_base_rotation(facing: Vector2) -> float:
	return -PI * 0.5 if facing.y < 0.0 else PI * 0.5
