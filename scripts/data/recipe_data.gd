## RecipeData.gd
## Describes one dish a chef must assemble from collected ingredients.
## Inherits from: Resource (Godot base class for serializable game data).
class_name RecipeData
extends Resource

## Human-readable dish name for the recipe UI header.
@export var dish_name: String = ""

## Ordered list of ingredient ids required to complete this dish.
## Order matters for UI display; chefs may add ingredients in any click order.
@export var required_ingredient_ids: Array[String] = []

## Points awarded to the team when this recipe is completed.
@export var point_value: int = 10


## Returns true when every required ingredient id appears in `added_ids`.
func is_complete(added_ids: Array[String]) -> bool:
	for required_id in required_ingredient_ids:
		if required_id not in added_ids:
			return false
	return true


## Builds a comma-separated ingredient list for HUD display.
func get_ingredient_summary() -> String:
	return ", ".join(required_ingredient_ids)
