## IngredientBox.gd
## Fixed slot showing one ingredient type and how many units the team holds.
## Inherits from: Button (clickable box in the chef ingredient grid).
extends Button
class_name IngredientBox

signal box_clicked(ingredient_id: String)

const STYLE_ALPHA := 0.8

const RED_INGREDIENT_IDS: Array[String] = [
	"bread", "pasta", "cheese", "eggs", "fish",
]

const CYAN_PALETTE := {
	"normal": Color("#1A8FBF"),
	"hover": Color("#22A8D8"),
	"pressed": Color("#147099"),
	"disabled": Color("#3A5060"),
}

const RED_PALETTE := {
	"normal": Color("#E07070"),
	"hover": Color("#F09090"),
	"pressed": Color("#C05050"),
	"disabled": Color("#8A5050"),
}

static var _cyan_styles: Dictionary = {}
static var _red_styles: Dictionary = {}

var ingredient_id: String = ""
var count: int = 0
var _swatch_texture: Texture2D = null

var _is_focused: bool = false

@onready var _focus_frame: Panel = $FocusFrame
@onready var _swatch: TextureRect = $VBox/SwatchRow/Swatch
@onready var _count_label: Label = $VBox/CountLabel


func _ready() -> void:
	pressed.connect(_on_pressed)
	clip_contents = true
	text = ""
	if _count_label:
		QuadrantMatchOverlay.apply_bold_font(_count_label)
	_ignore_mouse_on_children(self)
	_apply_button_styles()
	_apply_visuals()
	_refresh_display()


static func _ensure_style_sets() -> void:
	if not _cyan_styles.is_empty():
		return
	_cyan_styles = _build_style_set(CYAN_PALETTE)
	_red_styles = _build_style_set(RED_PALETTE)


static func _build_style_set(palette: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for state in ["normal", "hover", "pressed", "disabled"]:
		var bg: Color = palette[state]
		bg.a = STYLE_ALPHA
		var border := bg.darkened(0.18)
		border.a = minf(bg.a + 0.15, 1.0)
		out[state] = _make_flat_style(bg, border)
	return out


static func _make_flat_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style


func _apply_button_styles() -> void:
	_ensure_style_sets()
	var styles: Dictionary = _red_styles if ingredient_id in RED_INGREDIENT_IDS else _cyan_styles
	add_theme_stylebox_override("normal", styles["normal"])
	add_theme_stylebox_override("hover", styles["hover"])
	add_theme_stylebox_override("pressed", styles["pressed"])
	add_theme_stylebox_override("disabled", styles["disabled"])


func _ignore_mouse_on_children(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse_on_children(child)


func setup(data: IngredientData) -> void:
	ingredient_id = data.id
	_swatch_texture = data.texture
	_apply_button_styles()
	_apply_visuals()
	_refresh_display()


func _apply_visuals() -> void:
	if _swatch:
		_swatch.texture = _swatch_texture


func set_count(new_count: int) -> void:
	count = maxi(new_count, 0)
	_refresh_display()


func add_one() -> void:
	set_count(count + 1)


func remove_one() -> bool:
	if count <= 0:
		return false
	set_count(count - 1)
	return true


func has_stock() -> bool:
	return count > 0


func set_focused(focused: bool) -> void:
	_is_focused = focused
	if _focus_frame:
		_focus_frame.visible = focused
	_refresh_display()


func _on_pressed() -> void:
	box_clicked.emit(ingredient_id)


func _refresh_display() -> void:
	if _count_label:
		_count_label.text = "x%d" % count
	disabled = count <= 0
	modulate = Color.WHITE

	if _is_focused:
		_set_content_modulate(Color(1.0, 0.95, 0.55) if count > 0 else Color(0.82, 0.78, 0.62))
	elif count > 0:
		_set_content_modulate(Color.WHITE)
	else:
		_set_content_modulate(Color(0.72, 0.76, 0.82))


func _set_content_modulate(tint: Color) -> void:
	if _swatch:
		_swatch.modulate = tint
	if _count_label:
		_count_label.modulate = tint
