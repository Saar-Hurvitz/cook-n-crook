## IngredientButton.gd
## Clickable collected ingredient on the chef's station screen.
## Inherits from: Button (Godot UI control for mouse interaction).
extends Button
class_name IngredientButton

signal ingredient_clicked(ingredient_id: String)

var ingredient_id: String = ""


## Godot CanvasItem lifecycle — _ready originates from Node (via CanvasItem).
func _ready() -> void:
	pressed.connect(_on_pressed)


## Configures label and color from catalog data.
func setup(data: IngredientData) -> void:
	ingredient_id = data.id
	text = data.display_name
	modulate = data.color


## Godot BaseButton callback — pressed signal originates from Button.
func _on_pressed() -> void:
	ingredient_clicked.emit(ingredient_id)
