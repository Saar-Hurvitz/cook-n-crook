## InvisibleCollisionBlock.gd
## Invisible StaticBody2D barrier. Each placed copy can use its own width and height.
## Place under Maze → Background → CollisionBlocks so position tracks the map image.
@tool
extends StaticBody2D
class_name InvisibleCollisionBlock

## Must match gatherer collision_layer (layer 2 in the project).
const GATHERER_LAYER := 2

@export_range(1.0, 4096.0, 1.0, "suffix:px") var block_width: float = 40.0:
	set(value):
		block_width = maxf(value, 1.0)
		_queue_apply_size()

@export_range(1.0, 4096.0, 1.0, "suffix:px") var block_height: float = 40.0:
	set(value):
		block_height = maxf(value, 1.0)
		_queue_apply_size()


func _ready() -> void:
	# Layer 1 = walls (gatherer mask includes this). Mask 2 = gatherers (required for collision).
	collision_layer = 1
	collision_mask = GATHERER_LAYER
	_apply_size()


func _queue_apply_size() -> void:
	if not is_inside_tree():
		return
	if Engine.is_editor_hint():
		_apply_size()
	else:
		call_deferred("_apply_size")


func _apply_size() -> void:
	var shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	shape_node.disabled = false
	var rect := RectangleShape2D.new()
	rect.size = Vector2(block_width, block_height)
	shape_node.shape = rect
