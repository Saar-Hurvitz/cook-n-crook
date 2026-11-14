## IngredientPickup.gd
## Collectible ingredient node placed in the shared maze.
## Inherits from: Area2D (Godot 2D physics area for overlap detection).
extends Area2D
class_name IngredientPickup

signal collected(by_team: int, ingredient_id: String)

@export var ingredient_id: String = "tomato"

## Pickup footprint in the maze, in pixels (sprite art is scaled to fit this).
const PICKUP_SIZE := 60.0

@onready var _sprite: Sprite2D = $Visual


## Godot Node lifecycle — _ready originates from Node.
func _ready() -> void:
	add_to_group("ingredient_pickups")
	body_entered.connect(_on_body_entered)
	_apply_visual()
	monitoring = true
	monitorable = true


## Configures this pickup from catalog data (used by maze spawner).
func setup_from_data(data: IngredientData) -> void:
	ingredient_id = data.id
	_apply_visual()


func _apply_visual() -> void:
	var data := RecipeDatabase.get_ingredient(ingredient_id)
	if data == null or _sprite == null:
		return
	if data.texture:
		_sprite.texture = data.texture
		var tex_size := data.texture.get_size()
		var longest := maxf(tex_size.x, tex_size.y)
		if longest > 0.0:
			var s := PICKUP_SIZE / longest
			_sprite.scale = Vector2(s, s)


## Godot Area2D callback — body_entered originates from Area2D signal.
func _on_body_entered(body: Node2D) -> void:
	if not body is Gatherer:
		return

	var gatherer := body as Gatherer
	_collect(gatherer.team)


func _collect(team: int) -> void:
	if not GameManager.is_match_running():
		return
	set_deferred("monitoring", false)
	collected.emit(team, ingredient_id)
	EventBus.ingredient_collected.emit(team, ingredient_id)
	GameAudio.play_ingredient_pickup()
	queue_free()
