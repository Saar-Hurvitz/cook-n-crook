## QuadrantPanel.gd
## One split-screen cell: SubViewportContainer with click-to-focus and active highlight.
## Inherits from: SubViewportContainer (Godot UI node that displays a SubViewport).
extends SubViewportContainer
class_name QuadrantPanel

## Which player slot this quadrant represents (0–3).
@export var player_slot: int = 0

## Label shown in the corner for debugging / player identification.
@export var quadrant_label: String = ""

@onready var _border: ColorRect = $ActiveBorder
@onready var _label: Label = $OverlayLabel
@onready var _frame: Panel = $Frame


## Godot CanvasItem lifecycle — _ready originates from Node (via CanvasItem).
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	stretch = true
	clip_contents = true

	_setup_overlay_layout()

	if _label:
		_label.queue_free()
		_label = null

	_add_match_overlay()
	EventBus.control_switched.connect(_on_control_switched)


## Anchors overlay UI so labels do not smear when the window is resized.
func _setup_overlay_layout() -> void:
	if _frame:
		_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _border:
		_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_border.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _label:
		_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_label.offset_left = 10.0
		_label.offset_top = 10.0
		_label.offset_right = 220.0
		_label.offset_bottom = 30.0
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
		_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
		_label.add_theme_constant_override("shadow_offset_x", 1)
		_label.add_theme_constant_override("shadow_offset_y", 1)


## Godot Control input — _gui_input originates from Control.
## Clicking this quadrant transfers control to its assigned player slot.
## Gatherer quadrants consume the click (keyboard-only). Chef quadrants let clicks
## pass through to pantry Buttons inside the SubViewport.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			GameManager.set_active_player(player_slot)
			if GameManager.is_gatherer_slot(player_slot):
				accept_event()


func _on_control_switched(slot: int) -> void:
	_set_active_visual(slot == player_slot)


func _set_active_visual(_is_active: bool) -> void:
	if _border:
		_border.visible = false


func _add_match_overlay() -> void:
	var overlay := QuadrantMatchOverlay.new()
	add_child(overlay)
	overlay.setup(player_slot)
