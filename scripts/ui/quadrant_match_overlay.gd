## QuadrantMatchOverlay.gd
## During a match: both team scores at the bottom-right of each quadrant screen.
extends Control
class_name QuadrantMatchOverlay

const COLOR_TEAM_A := Color(1.0, 0.45, 0.45, 1.0)
const COLOR_TEAM_B := Color(0.45, 0.65, 1.0, 1.0)

var _score_a_label: Label = null
var _score_b_label: Label = null


static func apply_bold_font(control: Control) -> void:
	var font := SystemFont.new()
	font.font_weight = 700
	control.add_theme_font_override("font", font)


func setup(_player_slot: int) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := VBoxContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_constant_override("separation", 2)
	panel.alignment = BoxContainer.ALIGNMENT_END
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -120.0
	panel.offset_top = -52.0
	panel.offset_right = -8.0
	panel.offset_bottom = -8.0
	add_child(panel)

	_score_a_label = _make_score_label(COLOR_TEAM_A)
	_score_b_label = _make_score_label(COLOR_TEAM_B)
	panel.add_child(_score_a_label)
	panel.add_child(_score_b_label)

	visible = false
	EventBus.match_started.connect(_on_match_started)
	EventBus.match_ended.connect(_on_match_ended)
	EventBus.recipe_completed.connect(_on_score_changed)
	_refresh_scores()


func _make_score_label(color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	apply_bold_font(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _on_match_started() -> void:
	visible = true
	_refresh_scores()


func _on_match_ended(_winner: int, _score_a: int, _score_b: int) -> void:
	visible = false


func _on_score_changed(_team: int, _points: int, _dish_name: String) -> void:
	_refresh_scores()


func _refresh_scores() -> void:
	if _score_a_label:
		_score_a_label.text = "A | %d" % GameManager.get_score(GameManager.Team.A)
	if _score_b_label:
		_score_b_label.text = "B | %d" % GameManager.get_score(GameManager.Team.B)
