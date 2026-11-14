## MonsterEnemy.gd
## "Monster Pizza Caesar Salad Burger" — spawns late in the match, ignores walls, and
## chases the gatherers along a weaving sine path. Touching a gatherer hurts them;
## knives hurt the monster until it dies.
## Inherits from: CharacterBody2D (moved by hand so it can pass through walls).
extends CharacterBody2D
class_name MonsterEnemy

const MAX_HEALTH := 820
const TOUCH_DAMAGE := 30

## How close (pixels) the monster must be to a gatherer to land a touch hit.
## Matches the (now 3x larger) body so contact triggers when the sprite overlaps.
const CONTACT_RADIUS := 150.0

## Minimum time (seconds) between touch hits on the same gatherer.
const CONTACT_COOLDOWN := 0.7

## Forward chase speed toward the nearest gatherer (pixels/sec).
const CHASE_SPEED := 87.0

## Side-to-side sine weave: how far it swings and how fast it oscillates.
const WEAVE_AMPLITUDE := 55.0
const WEAVE_FREQUENCY := 4.5

## A gatherer's accumulated monster damage only influences targeting once this many
## seconds have passed since they were last hit by the monster.
const PRIORITY_DELAY := 3.5
const HIT_FLASH_SECONDS := 0.8
const SPOON_KNOCKBACK_SPEED := 180.0

const TEX_BURGER := preload("res://assets/enemies/monster_burger.png")
const TEX_EGG_TOAST := preload("res://assets/enemies/monster_egg_toast.png")
const TEX_FISH_AND_CHIPS := preload("res://assets/enemies/monster_fish_and_chips.png")
const TEX_SPAGHETTI_PANCAKE := preload("res://assets/enemies/monster_spaghetti_pancake.png")
const TEX_PIZZA_SALAD := preload("res://assets/enemies/moster_pizza_ceaser_salad.png")

const MONSTER_TEXTURES: Array[Texture2D] = [
	TEX_BURGER,
	TEX_EGG_TOAST,
	TEX_FISH_AND_CHIPS,
	TEX_SPAGHETTI_PANCAKE,
	TEX_PIZZA_SALAD,
]
const BASE_SPRITE_SCALE := 0.18
const LARGE_SPRITE_SCALE := BASE_SPRITE_SCALE * 1.5

var _health: int = MAX_HEALTH
var _targets: Array[Gatherer] = []
var _time: float = 0.0
var _knockback: Vector2 = Vector2.ZERO

## Per-gatherer touch cooldown timers (Gatherer -> seconds left).
var _contact_cooldowns: Dictionary = {}

## Total monster damage dealt to each gatherer (Gatherer -> float).
var _damage_taken: Dictionary = {}

## When each gatherer was last hit by the monster (Gatherer -> _time stamp).
var _last_monster_hit_time: Dictionary = {}

var _flash_tween: Tween = null

@onready var _sprite: Sprite2D = $Sprite


## Godot Node lifecycle — _ready originates from Node.
func _ready() -> void:
	add_to_group("monsters")


## Provides the gatherers to hunt; called right after the monster is spawned.
func setup(targets: Array) -> void:
	_targets.clear()
	for t in targets:
		if t is Gatherer:
			_targets.append(t)


func apply_texture(texture: Texture2D) -> void:
	if _sprite and texture:
		_sprite.texture = texture
		var scale := BASE_SPRITE_SCALE
		if texture != TEX_BURGER:
			scale = LARGE_SPRITE_SCALE
		_sprite.scale = Vector2(scale, scale)


## Godot Node lifecycle — _physics_process originates from Node.
func _physics_process(delta: float) -> void:
	if not GameManager.is_match_running():
		return

	_time += delta

	var target := _select_target()
	if target == null:
		return

	var to_target := target.global_position - global_position
	var dir := to_target.normalized() if to_target.length_squared() > 0.0001 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)

	# Forward chase plus a perpendicular sine weave (velocity = d/dt of amplitude*sin).
	var weave_speed := WEAVE_AMPLITUDE * WEAVE_FREQUENCY * cos(_time * WEAVE_FREQUENCY)
	var move := dir * CHASE_SPEED + perp * weave_speed

	# Passes through walls: move by hand instead of move_and_slide.
	global_position += move * delta
	if _knockback.length_squared() > 1.0:
		global_position += _knockback * delta
		_knockback = _knockback.lerp(Vector2.ZERO, minf(1.0, 8.0 * delta))
	_face(dir)
	_check_contacts(delta)


## Chooses who to chase. Damage-priority activates only once some gatherer's monster
## damage is at least PRIORITY_DELAY seconds old; until then it's pure nearest-chase.
## When active, the LESS-damaged gatherer is the primary target (more damage = second).
func _select_target() -> Gatherer:
	var priority_active := false
	for g in _targets:
		if not is_instance_valid(g):
			continue
		if float(_damage_taken.get(g, 0.0)) <= 0.0:
			continue
		if _time - float(_last_monster_hit_time.get(g, -INF)) >= PRIORITY_DELAY:
			priority_active = true
			break

	if not priority_active:
		return _nearest_target()

	var best: Gatherer = null
	var best_damage := INF
	for g in _targets:
		if not is_instance_valid(g):
			continue
		var dmg := float(_damage_taken.get(g, 0.0))
		if dmg < best_damage:
			best_damage = dmg
			best = g
		elif dmg == best_damage and best != null:
			var here := global_position.distance_squared_to(g.global_position)
			var there := global_position.distance_squared_to(best.global_position)
			if here < there:
				best = g
	return best if best != null else _nearest_target()


func _nearest_target() -> Gatherer:
	var best: Gatherer = null
	var best_dist := INF
	for g in _targets:
		if not is_instance_valid(g):
			continue
		var dist := global_position.distance_squared_to(g.global_position)
		if dist < best_dist:
			best_dist = dist
			best = g
	return best


func _face(dir: Vector2) -> void:
	if _sprite and absf(dir.x) > 0.01:
		_sprite.flip_h = dir.x < 0.0


## Hits any gatherer within reach (respecting a per-gatherer cooldown).
func _check_contacts(delta: float) -> void:
	for g in _targets:
		if not is_instance_valid(g):
			continue
		var cd: float = maxf(float(_contact_cooldowns.get(g, 0.0)) - delta, 0.0)
		if cd <= 0.0 and global_position.distance_to(g.global_position) <= CONTACT_RADIUS:
			g.hit_by_monster(TOUCH_DAMAGE)
			_damage_taken[g] = float(_damage_taken.get(g, 0.0)) + TOUCH_DAMAGE
			_last_monster_hit_time[g] = _time
			cd = CONTACT_COOLDOWN
		_contact_cooldowns[g] = cd


## Spoon hit: damage plus knockback away from the attacker.
func hit_by_spoon(amount: int, attacker_position: Vector2) -> void:
	var dir := global_position - attacker_position
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	_knockback = dir * SPOON_KNOCKBACK_SPEED
	take_damage(amount)


## Applies damage from knives or the spoon. The monster dies and leaves the game at 0 HP.
func take_damage(amount: int) -> void:
	_health -= amount
	if _health <= 0:
		queue_free()
		return
	_flash_white()


## White hit flash for 0.8 seconds after any damage.
func _flash_white() -> void:
	if not _sprite:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.modulate = Color(0.35, 0.35, 0.35)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, HIT_FLASH_SECONDS)
