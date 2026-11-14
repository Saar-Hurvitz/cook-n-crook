## SplitScreenRoot.gd
## Lays out four equal quadrants in a 2×2 grid with divider lines.
## Inherits from: Control (root UI container for the split-screen layout).
extends Control

const DIVIDER_THICKNESS := 4

## Host viewport that owns the shared maze world (not displayed on screen).
@onready var _world_host: SubViewport = $"../WorldHost"
@onready var _grid: GridContainer = $Grid
@onready var _dividers: Control = $Dividers
@onready var _vertical_line: ColorRect = $Dividers/VerticalLine
@onready var _horizontal_line: ColorRect = $Dividers/HorizontalLine

@onready var quadrant_a_gatherer: QuadrantPanel = $Grid/QuadrantA_Gatherer
@onready var quadrant_a_chef: QuadrantPanel = $Grid/QuadrantA_Chef
@onready var quadrant_b_gatherer: QuadrantPanel = $Grid/QuadrantB_Gatherer
@onready var quadrant_b_chef: QuadrantPanel = $Grid/QuadrantB_Chef


## Godot CanvasItem lifecycle — _ready originates from Node (via CanvasItem).
func _ready() -> void:
	# Dark backdrop visible in any gutter space between quadrants.
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.1)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

	_configure_quadrant(quadrant_a_gatherer)
	_configure_quadrant(quadrant_a_chef)
	_configure_quadrant(quadrant_b_gatherer)
	_configure_quadrant(quadrant_b_chef)

	_bind_gatherer_viewport(quadrant_a_gatherer)
	_bind_gatherer_viewport(quadrant_b_gatherer)

	resized.connect(_update_divider_positions)
	_update_divider_positions()


## Ensures each SubViewport clears every frame and shares the maze world.
func _configure_quadrant(panel: QuadrantPanel) -> void:
	var viewport := panel.get_node("SubViewport") as SubViewport
	if viewport == null:
		return
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


## Points a gatherer SubViewport at the hidden WorldHost's World2D.
func _bind_gatherer_viewport(panel: QuadrantPanel) -> void:
	var viewport := panel.get_node("SubViewport") as SubViewport
	if viewport and _world_host:
		viewport.world_2d = _world_host.world_2d


## Keeps the cross divider lines centered after resize / fullscreen changes.
func _update_divider_positions() -> void:
	if _vertical_line == null or _horizontal_line == null:
		return

	var half_w := size.x * 0.5
	var half_h := size.y * 0.5
	var half_t := DIVIDER_THICKNESS * 0.5

	_vertical_line.position = Vector2(half_w - half_t, 0.0)
	_vertical_line.size = Vector2(DIVIDER_THICKNESS, size.y)

	_horizontal_line.position = Vector2(0.0, half_h - half_t)
	_horizontal_line.size = Vector2(size.x, DIVIDER_THICKNESS)
