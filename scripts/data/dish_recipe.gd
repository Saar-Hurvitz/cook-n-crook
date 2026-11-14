## DishRecipe.gd
## One completable dish: artwork plus the prepped ingredients that must be on the plate.
class_name DishRecipe
extends RefCounted

var id: String = ""
var display_name: String = ""
var texture: Texture2D = null

## Each entry is a PlateItem-style dictionary (single or combined).
var components: Array = []


static func build(p_id: String, p_name: String, p_texture: Texture2D, p_components: Array) -> DishRecipe:
	var dish := DishRecipe.new()
	dish.id = p_id
	dish.display_name = p_name
	dish.texture = p_texture
	dish.components = p_components
	return dish


## Sorted tokens describing what must be on the serve plate before the dish image appears.
func component_tokens() -> Array[String]:
	var tokens: Array[String] = []
	for comp in components:
		tokens.append(PlateItem.token(comp))
	tokens.sort()
	return tokens
