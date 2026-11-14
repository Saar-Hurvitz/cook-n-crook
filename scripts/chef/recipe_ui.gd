## RecipeUI.gd
## Displays the current dish order: dish photo plus required ingredients and prep steps.
extends Control
class_name RecipeUI

const TEX_CUT := preload("res://assets/cooking/cut.png")
const TEX_COOK := preload("res://assets/cooking/cook.png")

const INGREDIENT_ICON_SIZE := 23
const PREP_ICON_SIZE := 33
const COMBINED_COOK_ICON_SIZE := 48
const MULTI_INGREDIENT_MIN_SIZE := 27
const MULTI_INGREDIENT_MAX_SIZE := 42

@onready var _dish_image: TextureRect = $VBox/DishRow/DishImage
@onready var _ingredients_scroll: ScrollContainer = $VBox/DishRow/IngredientsScroll
@onready var _ingredients_row: HBoxContainer = $VBox/DishRow/IngredientsScroll/IngredientsRow

var _current_dish_id: String = ""
var _ingredient_icon_size: int = INGREDIENT_ICON_SIZE
var _prep_icon_size: int = PREP_ICON_SIZE
var _combined_cook_size: int = COMBINED_COOK_ICON_SIZE
var _cell_width: int = 40
var _cell_height: int = 100

static var _frame_style: StyleBoxFlat = null


func _ready() -> void:
	if _ingredients_scroll:
		_ingredients_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if _ingredients_row:
		_ingredients_row.add_theme_constant_override("separation", 4)
	resized.connect(_on_layout_changed)
	show_dish("")


func _on_layout_changed() -> void:
	if _current_dish_id.is_empty():
		return
	call_deferred("_reload_current_dish")


func _reload_current_dish() -> void:
	show_dish(_current_dish_id)


## Shows the target dish and every component with cut/cook prep hints.
func show_dish(dish_id: String) -> void:
	_current_dish_id = dish_id
	_clear_ingredients_row()
	var dish := RecipeDatabase.get_dish(dish_id)
	if _dish_image:
		if dish and dish.texture:
			_dish_image.texture = dish.texture
			_dish_image.visible = true
		else:
			_dish_image.texture = null
			_dish_image.visible = false
	if dish == null:
		return
	var ingredient_count := _count_ingredients(dish)
	var column_count := maxi(dish.components.size(), 1)
	_update_icon_metrics(ingredient_count, column_count)
	for comp in dish.components:
		_add_component_display(comp)


func _count_ingredients(dish: DishRecipe) -> int:
	var total := 0
	for comp in dish.components:
		if comp.get("combined", false):
			for part in comp.get("parts", []):
				if part is Dictionary:
					total += 1
		else:
			total += 1
	return total


func _update_icon_metrics(ingredient_count: int, column_count: int) -> void:
	var area := _ingredients_scroll.get_rect().size
	if area.y < 8.0:
		area.y = 100.0
	if area.x < 8.0:
		area.x = 220.0

	var separation := float(_ingredients_row.get_theme_constant("separation"))
	_cell_width = int((area.x - separation * float(column_count - 1)) / float(column_count))
	_cell_height = int(area.y)

	if ingredient_count <= 1:
		_ingredient_icon_size = INGREDIENT_ICON_SIZE
		_prep_icon_size = PREP_ICON_SIZE
		_combined_cook_size = COMBINED_COOK_ICON_SIZE
		return

	var max_prep_stack := PREP_ICON_SIZE * 2 + 4
	var height_limit := int(clampf(area.y - max_prep_stack, float(MULTI_INGREDIENT_MIN_SIZE), float(MULTI_INGREDIENT_MAX_SIZE)))
	var width_limit := _cell_width - 4
	width_limit = clampi(width_limit, MULTI_INGREDIENT_MIN_SIZE, MULTI_INGREDIENT_MAX_SIZE)

	_ingredient_icon_size = mini(height_limit, width_limit)
	_prep_icon_size = int(clampf(float(_ingredient_icon_size) * 1.25, 30.0, 39.0))
	_combined_cook_size = int(clampf(float(_ingredient_icon_size) * 1.45, 36.0, 48.0))


func _clear_ingredients_row() -> void:
	if _ingredients_row == null:
		return
	for child in _ingredients_row.get_children():
		child.queue_free()


func _add_component_display(comp: Dictionary) -> void:
	if comp.get("combined", false):
		_add_combined_display(comp)
	else:
		_add_single_display(comp)


func _add_single_display(comp: Dictionary) -> void:
	var column := _make_column_container()
	var ingredient_id := String(comp.get("ingredient", ""))
	var prep := String(comp.get("prep", PlateItem.PREP_RAW))

	if _prep_requires_frame(prep):
		var inner := _make_inner_column(2)
		inner.add_child(_make_ingredient_icon(ingredient_id))
		var prep_stack := _make_prep_stack(prep)
		if prep_stack.get_child_count() > 0:
			inner.add_child(prep_stack)
		column.add_child(_make_framed_panel(inner, true))
	else:
		column.add_child(_make_framed_panel(_make_ingredient_icon(ingredient_id), true))

	_ingredients_row.add_child(column)


func _add_combined_display(comp: Dictionary) -> void:
	var column := _make_column_container()
	var group_inner := _make_inner_column(2)

	var parts_row := HBoxContainer.new()
	parts_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parts_row.add_theme_constant_override("separation", 2)
	parts_row.alignment = BoxContainer.ALIGNMENT_CENTER
	parts_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var parts: Array = comp.get("parts", [])
	var part_count := maxi(parts.size(), 1)
	var part_cell_w := maxi((_cell_width - 4 - 2 * (part_count - 1)) / part_count, _ingredient_icon_size + 2)

	for part in parts:
		if not part is Dictionary:
			continue
		var part_id := String(part.get("ingredient", ""))
		var part_prep := String(part.get("prep", PlateItem.PREP_RAW))
		if part_prep == PlateItem.PREP_CUT:
			var part_inner := _make_inner_column(2)
			part_inner.add_child(_make_ingredient_icon(part_id))
			part_inner.add_child(_make_prep_icon(TEX_CUT, _prep_icon_size))
			parts_row.add_child(_make_framed_panel(part_inner, false, part_cell_w))
		else:
			parts_row.add_child(_make_framed_panel(_make_ingredient_icon(part_id), false, part_cell_w))

	group_inner.add_child(parts_row)
	group_inner.add_child(_make_prep_icon(TEX_COOK, _combined_cook_size))
	column.add_child(_make_framed_panel(group_inner, true))
	_ingredients_row.add_child(column)


func _make_column_container() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.0
	return column


func _make_inner_column(separation: int) -> VBoxContainer:
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", separation)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	return inner


static func _get_frame_style() -> StyleBoxFlat:
	if _frame_style == null:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1.0, 1.0, 1.0, 0.05)
		style.border_color = Color(0.82, 0.84, 0.9, 0.55)
		style.set_border_width_all(1)
		style.set_corner_radius_all(2)
		style.content_margin_left = 1.0
		style.content_margin_top = 1.0
		style.content_margin_right = 1.0
		style.content_margin_bottom = 1.0
		_frame_style = style
	return _frame_style


func _make_framed_panel(content: Control, fill_cell: bool, fixed_width: int = -1) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _get_frame_style())

	if fill_cell:
		panel.custom_minimum_size = Vector2(_cell_width, _cell_height)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	elif fixed_width > 0:
		panel.custom_minimum_size = Vector2(fixed_width, _ingredient_icon_size + _prep_icon_size + 6)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_stretch_ratio = 1.0

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(content)
	panel.add_child(center)
	return panel


func _prep_requires_frame(prep: String) -> bool:
	return prep != PlateItem.PREP_RAW and not prep.is_empty()


## Prep icons below a single ingredient (cut, cook, or cut then cook).
func _make_prep_stack(prep: String) -> Control:
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 1)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER

	match prep:
		PlateItem.PREP_CUT:
			stack.add_child(_make_prep_icon(TEX_CUT, _prep_icon_size))
		PlateItem.PREP_COOKED:
			stack.add_child(_make_prep_icon(TEX_COOK, _prep_icon_size))
		"cut_then_cooked":
			stack.add_child(_make_prep_icon(TEX_CUT, _prep_icon_size))
			stack.add_child(_make_prep_icon(TEX_COOK, _prep_icon_size))

	return stack


func _make_ingredient_icon(ingredient_id: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(_ingredient_icon_size, _ingredient_icon_size)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var data := RecipeDatabase.get_ingredient(ingredient_id)
	if data and data.texture:
		icon.texture = data.texture
	return icon


func _make_prep_icon(texture: Texture2D, size: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = texture
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
