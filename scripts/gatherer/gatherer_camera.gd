## GathererCamera.gd
## Split-screen camera child of a gatherer; renders into an assigned SubViewport.
## Inherits from: Camera2D (Godot 2D camera node).
extends Camera2D

@export var zoom_level: Vector2 = Vector2(0.75, 0.75)

## SubViewport that displays this gatherer's quadrant (set from main.gd).
var render_viewport: SubViewport = null


## Godot Node2D lifecycle — _ready originates from Node2D (via Node).
func _ready() -> void:
	zoom = zoom_level
	_activate_for_viewport()


## Assigns which quadrant SubViewport this camera draws into, then makes it current.
func setup_for_viewport(viewport: SubViewport) -> void:
	render_viewport = viewport
	if is_inside_tree():
		_activate_for_viewport()


func _activate_for_viewport() -> void:
	if render_viewport:
		custom_viewport = render_viewport
		make_current()
