## RecipeDatabase.gd
## Static catalog of ingredients and dish recipes used by the maze and chef stations.
class_name RecipeDatabase
extends RefCounted

static var INGREDIENTS: Dictionary = {}
static var DISHES: Dictionary = {}
static var _initialized: bool = false

const INGREDIENT_ICONS: Dictionary = {
	"bread": preload("res://assets/ingridients/bread.png"),
	"tomato": preload("res://assets/ingridients/tomato.png"),
	"cheese": preload("res://assets/ingridients/cheese.png"),
	"meat": preload("res://assets/ingridients/meat.png"),
	"fish": preload("res://assets/ingridients/fish.png"),
	"potato": preload("res://assets/ingridients/potato.png"),
	"pasta": preload("res://assets/ingridients/pasta.png"),
	"lettuce": preload("res://assets/ingridients/lettuce.png"),
	"egg": preload("res://assets/ingridients/egg.png"),
	"cucumber": preload("res://assets/ingridients/cucumber.png"),
}


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true

	INGREDIENTS = {
		"bread": IngredientData.create("bread", "Bread", Color(0.85, 0.65, 0.35), _icon("bread")),
		"tomato": IngredientData.create("tomato", "Tomato", Color(0.9, 0.2, 0.15), _icon("tomato")),
		"cheese": IngredientData.create("cheese", "Cheese", Color(1.0, 0.85, 0.2), _icon("cheese")),
		"meat": IngredientData.create("meat", "Meat", Color(0.55, 0.25, 0.2), _icon("meat")),
		"fish": IngredientData.create("fish", "Fish", Color(0.55, 0.75, 0.85), _icon("fish")),
		"potato": IngredientData.create("potato", "Potato", Color(0.8, 0.62, 0.38), _icon("potato")),
		"pasta": IngredientData.create("pasta", "Pasta", Color(0.95, 0.85, 0.55), _icon("pasta")),
		"lettuce": IngredientData.create("lettuce", "Lettuce", Color(0.3, 0.8, 0.25), _icon("lettuce")),
		"eggs": IngredientData.create("eggs", "Eggs", Color(0.98, 0.92, 0.7), _icon("egg")),
		"cucumber": IngredientData.create("cucumber", "Cucumber", Color(0.4, 0.75, 0.35), _icon("cucumber")),
	}

	DISHES = {
		"fish_and_chips": DishRecipe.build(
			"fish_and_chips", "Fish & Chips",
			preload("res://assets/dishes/fish_and_chips/fish_and_chips.png"),
			[PlateItem.single("fish", PlateItem.PREP_COOKED), PlateItem.single("potato", PlateItem.PREP_CUT)],
		),
		"burger": DishRecipe.build(
			"burger", "Burger",
			preload("res://assets/dishes/hamburger/burger/burger.png"),
			[
				PlateItem.single("bread"), PlateItem.single("meat", PlateItem.PREP_COOKED),
				PlateItem.single("lettuce", PlateItem.PREP_CUT), PlateItem.single("tomato", PlateItem.PREP_CUT),
			],
		),
		"cheese_burger": DishRecipe.build(
			"cheese_burger", "Cheese Burger",
			preload("res://assets/dishes/hamburger/cheese_burger/cheese_burger.png"),
			[
				PlateItem.single("bread"), PlateItem.single("meat", PlateItem.PREP_COOKED),
				PlateItem.single("lettuce", PlateItem.PREP_CUT), PlateItem.single("tomato", PlateItem.PREP_CUT),
				PlateItem.single("cheese"),
			],
		),
		"cheese_pasta": DishRecipe.build(
			"cheese_pasta", "Cheese Pasta",
			preload("res://assets/dishes/pasta/cheese_pasta/cheese_pasta.png"),
			[PlateItem.single("pasta", PlateItem.PREP_COOKED), PlateItem.single("cheese")],
		),
		"tomato_pasta": DishRecipe.build(
			"tomato_pasta", "Tomato Pasta",
			preload("res://assets/dishes/pasta/tomato_pasta/tomato_pasta.png"),
			[PlateItem.single("pasta", PlateItem.PREP_COOKED), PlateItem.single("tomato", PlateItem.PREP_CUT)],
		),
		"cheese_tomato_pizza": DishRecipe.build(
			"cheese_tomato_pizza", "Cheese Tomato Pizza",
			preload("res://assets/dishes/pizza/cheese_tomato_pizza/cheese_tomato_pizza_postcooked.png"),
			[PlateItem.single("bread"), PlateItem.single("tomato", PlateItem.PREP_CUT), PlateItem.single("cheese")],
		),
		"cheese_tomato_meat_pizza": DishRecipe.build(
			"cheese_tomato_meat_pizza", "Meat Pizza",
			preload("res://assets/dishes/pizza/peperoni_pizza/cheese_tomato_meat_pizza_postcooked.png"),
			[
				PlateItem.single("bread"), PlateItem.single("tomato", PlateItem.PREP_CUT),
				PlateItem.single("cheese"), PlateItem.single("meat", PlateItem.PREP_COOKED),
			],
		),
		"salad": DishRecipe.build(
			"salad", "Salad",
			preload("res://assets/dishes/salad/salad.png"),
			[
				PlateItem.single("cucumber", PlateItem.PREP_CUT),
				PlateItem.single("tomato", PlateItem.PREP_CUT),
				PlateItem.single("lettuce", PlateItem.PREP_CUT),
			],
		),
		"egg_toast": DishRecipe.build(
			"egg_toast", "Egg Toast",
			preload("res://assets/dishes/toast/egg_toast/egg_toast.png"),
			[PlateItem.combined([
				PlateItem.single("eggs"), PlateItem.single("bread"),
			])],
		),
		"tomato_cheese_toast": DishRecipe.build(
			"tomato_cheese_toast", "Tomato Cheese Toast",
			preload("res://assets/dishes/toast/tomato_cheese_toast/tomato_cheese_toast.png"),
			[PlateItem.combined([
				PlateItem.single("bread"), PlateItem.single("cheese"),
				PlateItem.single("tomato", PlateItem.PREP_CUT),
			])],
		),
	}


static func _icon(file_name: String) -> Texture2D:
	return INGREDIENT_ICONS.get(file_name, null) as Texture2D


static func get_ingredient(ingredient_id: String) -> IngredientData:
	_ensure_initialized()
	return INGREDIENTS.get(ingredient_id, null)


static func get_dish(dish_id: String) -> DishRecipe:
	_ensure_initialized()
	return DISHES.get(dish_id, null)


static func get_random_dish() -> DishRecipe:
	_ensure_initialized()
	var ids: Array = DISHES.keys()
	return DISHES[ids[randi() % ids.size()]]


static func get_all_ingredient_ids() -> Array[String]:
	_ensure_initialized()
	var ids: Array[String] = []
	ids.assign(INGREDIENTS.keys())
	ids.shuffle()
	return ids


static func get_ingredient_ids_for_ui() -> Array[String]:
	_ensure_initialized()
	return [
		"bread", "tomato", "cheese", "meat", "fish",
		"potato", "pasta", "lettuce", "eggs", "cucumber",
	]


## Raw pantry ingredient ids required by a dish (ignores prep state).
static func get_dish_base_ingredient_ids(dish_id: String) -> Array[String]:
	_ensure_initialized()
	var dish := get_dish(dish_id)
	if dish == null:
		return []
	var ids: Array[String] = []
	for comp in dish.components:
		if bool(comp.get("combined", false)):
			for part in comp.get("parts", []):
				if part is Dictionary:
					var part_id := String(part.get("ingredient", ""))
					if not part_id.is_empty() and part_id not in ids:
						ids.append(part_id)
		else:
			var ingredient_id := String(comp.get("ingredient", ""))
			if not ingredient_id.is_empty() and ingredient_id not in ids:
				ids.append(ingredient_id)
	return ids
