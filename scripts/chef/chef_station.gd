## ChefStation.gd
## Chef quadrant: pantry, Cut / Cook prep, and a Serve plate with dish-based scoring.
extends Control
class_name ChefStation

@export var team: int = 0

const POINTS_PER_ORDER := 10
const PREP_SECONDS := 4.0
const ICON_SIZE := 26

@onready var _recipe_ui: RecipeUI = $RecipeUI
@onready var _ingredient_grid: GridContainer = $IngredientGrid
@onready var _knife_button: Button = $KnifeResupplyButton
@onready var _spoon_button: Button = $SpoonResupplyButton

@onready var _cut_box: Button = $Stations/CutBox
@onready var _cut_icons: HBoxContainer = $Stations/CutBox/VBox/IconRow
@onready var _cut_progress: ProgressBar = $Stations/CutBox/VBox/Progress
@onready var _cook_box: Button = $Stations/CookBox
@onready var _cook_icons: HBoxContainer = $Stations/CookBox/VBox/IconRow
@onready var _cook_progress: ProgressBar = $Stations/CookBox/VBox/Progress
@onready var _serve_box: Button = $Stations/ServeBox
@onready var _serve_vbox: VBoxContainer = $Stations/ServeBox/VBox
@onready var _serve_icons: HBoxContainer = $Stations/ServeBox/VBox/IconRow
@onready var _serve_dish_image: TextureRect = $Stations/ServeBox/VBox/DishImage
@onready var _serve_progress: ProgressBar = $Stations/ServeBox/VBox/Progress

@onready var _action_popup: PanelContainer = $ActionPopup
@onready var _cut_button: Button = $ActionPopup/VBox/Buttons/CutButton
@onready var _cook_button: Button = $ActionPopup/VBox/Buttons/CookButton
@onready var _serve_ingredient_button: Button = $ActionPopup/VBox/Buttons/ServeButton

@onready var _serve_popup: PanelContainer = $ServePopup
@onready var _deliver_button: Button = $ServePopup/VBox/Buttons/DeliverButton
@onready var _cook_all_button: Button = $ServePopup/VBox/Buttons/CookAllButton
@onready var _throw_button: Button = $ServePopup/VBox/Buttons/ThrowButton

const INGREDIENT_BOX_SCENE := preload("res://scenes/ui/ingredient_box.tscn")
const GRID_COLUMNS := 5

const READY_GLOW := Color(0.45, 1.0, 0.45)
const FOCUS_CONTENT_TINT := Color(1.0, 0.95, 0.55)

enum Focus { GRID, STATIONS, SPOON, KNIFE }
const STATION_ORDER: Array[String] = ["cut", "cook", "serve"]

static var _nav_focus_style: StyleBoxFlat = null

var _nav_focus_frames: Dictionary = {}

var _ordered_boxes: Array[IngredientBox] = []
var _ordered_ingredient_ids: Array[String] = []
var _selected_index: int = 0
var _focus: Focus = Focus.GRID
var _station_index: int = 0
var _station_boxes: Array[Button] = []
var _ingredient_boxes: Dictionary = {}

## Active order dish id (shared with the other chef).
var _current_dish_id: String = ""

## Items waiting on the serve plate (PlateItem dictionaries).
var _plate: Array = []

## Set when plate contents match the order recipe — shows the finished dish image.
var _completed_dish_id: String = ""

## Prep stations: state is empty / processing / ready; item holds the in-progress PlateItem.
var _stations: Dictionary = {
	"cut": {"state": "empty", "item": {}, "time_left": 0.0},
	"cook": {"state": "empty", "item": {}, "time_left": 0.0},
}

## Ingredient action popup (cut / cook / serve to plate).
var _popup_open: bool = false
var _popup_ingredient_id: String = ""
var _popup_index: int = 0
var _popup_buttons: Array[Button] = []
var _popup_actions: Array[String] = ["cut", "cook", "serve"]

## Serve-box action popup (deliver / cook all / throw).
var _serve_popup_open: bool = false
var _serve_popup_index: int = 0
var _serve_popup_buttons: Array[Button] = []
var _serve_popup_actions: Array[String] = ["deliver", "cook_all", "throw"]


func _ready() -> void:
	_build_ingredient_grid()
	_knife_button.focus_mode = Control.FOCUS_NONE
	_knife_button.pressed.connect(_on_knife_resupply_pressed)
	_spoon_button.focus_mode = Control.FOCUS_NONE
	_spoon_button.pressed.connect(_on_spoon_resupply_pressed)

	_station_boxes = [_cut_box, _cook_box, _serve_box]
	for b in _station_boxes:
		b.focus_mode = Control.FOCUS_NONE
	_cut_box.pressed.connect(_on_station_pressed.bind("cut"))
	_cook_box.pressed.connect(_on_station_pressed.bind("cook"))
	_serve_box.pressed.connect(_open_serve_popup)

	_popup_buttons = [_cut_button, _cook_button, _serve_ingredient_button]
	for btn in _popup_buttons:
		btn.focus_mode = Control.FOCUS_NONE
	_cut_button.pressed.connect(_perform_ingredient_action.bind("cut"))
	_cook_button.pressed.connect(_perform_ingredient_action.bind("cook"))
	_serve_ingredient_button.pressed.connect(_perform_ingredient_action.bind("serve"))

	_serve_popup_buttons = [_deliver_button, _cook_all_button, _throw_button]
	for btn in _serve_popup_buttons:
		btn.focus_mode = Control.FOCUS_NONE
	_deliver_button.pressed.connect(_perform_serve_action.bind("deliver"))
	_cook_all_button.pressed.connect(_perform_serve_action.bind("cook_all"))
	_throw_button.pressed.connect(_perform_serve_action.bind("throw"))

	_configure_station_buttons()
	_configure_labeled_buttons()
	_setup_nav_focus_frames()

	_update_focus_visuals()
	_reset_stations()
	_clear_serve_state()
	_close_action_popup()
	_close_serve_popup()

	EventBus.ingredient_collected.connect(_on_ingredient_collected)
	EventBus.ingredient_stolen.connect(_on_ingredient_stolen)
	EventBus.order_assigned.connect(_on_order_assigned)
	EventBus.gatherer_respawn_started.connect(_on_gatherer_respawn_started)


func _configure_station_buttons() -> void:
	for box in _station_boxes:
		box.text = ""
		box.clip_contents = true
		var vbox := box.get_node_or_null("VBox") as Control
		if vbox == null:
			continue
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.offset_left = 4.0
		vbox.offset_top = 2.0
		vbox.offset_right = -4.0
		vbox.offset_bottom = -4.0


static func _make_nav_focus_style() -> StyleBoxFlat:
	if _nav_focus_style != null:
		return _nav_focus_style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.92, 0.35, 0.35)
	style.border_color = Color(1.0, 0.85, 0.1, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	_nav_focus_style = style
	return _nav_focus_style


func _setup_nav_focus_frames() -> void:
	for btn in _station_boxes:
		_attach_nav_focus_frame(btn)
	for btn in [_knife_button, _spoon_button]:
		_attach_nav_focus_frame(btn)
	for btn in _popup_buttons:
		_attach_nav_focus_frame(btn)
	for btn in _serve_popup_buttons:
		_attach_nav_focus_frame(btn)


func _attach_nav_focus_frame(btn: Control) -> void:
	if btn == null or _nav_focus_frames.has(btn):
		return
	var frame := Panel.new()
	frame.name = "NavFocusFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", _make_nav_focus_style())
	btn.add_child(frame)
	_nav_focus_frames[btn] = frame


func _set_nav_focused(btn: Control, focused: bool, idle_modulate: Color = Color.WHITE) -> void:
	if btn == null:
		return
	var frame: Panel = _nav_focus_frames.get(btn, null)
	if frame:
		frame.visible = focused
	btn.modulate = FOCUS_CONTENT_TINT if focused else idle_modulate


func _configure_labeled_buttons() -> void:
	var buttons: Array[Button] = [_knife_button, _spoon_button]
	buttons.append_array(_popup_buttons)
	buttons.append_array(_serve_popup_buttons)
	for btn in buttons:
		btn.clip_contents = true
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		QuadrantMatchOverlay.apply_bold_font(btn)


func _process(delta: float) -> void:
	if not GameManager.is_match_running():
		GameAudio.set_chef_cutting(team, false)
		GameAudio.set_chef_cooking(team, false)
		return
	_tick_station("cut", delta)
	_tick_station("cook", delta)
	_sync_chef_loop_sounds()


func _build_ingredient_grid() -> void:
	for ingredient_id in RecipeDatabase.get_ingredient_ids_for_ui():
		var data := RecipeDatabase.get_ingredient(ingredient_id)
		if data == null:
			continue
		var box: IngredientBox = INGREDIENT_BOX_SCENE.instantiate()
		box.clip_contents = true
		box.box_clicked.connect(_on_ingredient_box_clicked)
		_ingredient_grid.add_child(box)
		box.setup(data)
		_ingredient_boxes[ingredient_id] = box
		_ordered_boxes.append(box)
		_ordered_ingredient_ids.append(ingredient_id)
	_set_selected_index(0, false)


func _on_order_assigned(dish_id: String) -> void:
	_current_dish_id = dish_id
	_clear_serve_state()
	_reset_stations()
	if _recipe_ui:
		_recipe_ui.show_dish(dish_id)


func _on_gatherer_respawn_started(dead_team: int) -> void:
	if dead_team != team:
		return
	_apply_gatherer_death_penalty()


func _apply_gatherer_death_penalty() -> void:
	var total_units := 0
	for ingredient_id in _ordered_ingredient_ids:
		var box: IngredientBox = _ingredient_boxes.get(ingredient_id, null)
		if box:
			total_units += box.count

	if total_units <= 3:
		for box in _ingredient_boxes.values():
			box.set_count(0)
		return

	for _i in 3:
		var stocked: Array[String] = []
		for ingredient_id in _ordered_ingredient_ids:
			var box: IngredientBox = _ingredient_boxes.get(ingredient_id, null)
			if box and box.count > 0:
				stocked.append(ingredient_id)
		if stocked.is_empty():
			break
		var pick := stocked[randi() % stocked.size()]
		_ingredient_boxes[pick].remove_one()


func _on_ingredient_collected(collected_team: int, ingredient_id: String) -> void:
	if collected_team != team:
		return
	var box: IngredientBox = _ingredient_boxes.get(ingredient_id, null)
	if box == null:
		return
	box.add_one()


func _on_ingredient_stolen(thief_team: int, victim_team: int, ingredient_id: String) -> void:
	var box: IngredientBox = _ingredient_boxes.get(ingredient_id, null)
	if box == null:
		return
	if team == victim_team and box.has_stock():
		box.remove_one()
	elif team == thief_team:
		box.add_one()


func _on_ingredient_box_clicked(ingredient_id: String) -> void:
	if not GameManager.is_match_running():
		return
	var idx := _ordered_ingredient_ids.find(ingredient_id)
	if idx >= 0:
		_set_selected_index(idx, false)
	_open_action_popup(ingredient_id)


func _open_action_popup(ingredient_id: String) -> void:
	var box: IngredientBox = _ingredient_boxes.get(ingredient_id, null)
	if box == null:
		return
	if not box.has_stock():
		return
	_close_serve_popup()
	_popup_ingredient_id = ingredient_id
	_popup_open = true
	_popup_index = 0
	if _action_popup:
		_action_popup.visible = true
	_update_popup_focus()
	_update_focus_visuals()


func _close_action_popup() -> void:
	_popup_open = false
	_popup_ingredient_id = ""
	if _action_popup:
		_action_popup.visible = false
	_update_popup_focus()
	_update_focus_visuals()


func _open_serve_popup() -> void:
	if not GameManager.is_match_running():
		return
	_close_action_popup()
	_serve_popup_open = true
	_serve_popup_index = 0
	if _serve_popup:
		_serve_popup.visible = true
	_update_serve_popup_focus()
	_update_focus_visuals()


func _close_serve_popup() -> void:
	_serve_popup_open = false
	if _serve_popup:
		_serve_popup.visible = false
	_update_serve_popup_focus()
	_update_focus_visuals()


func _perform_ingredient_action(action: String) -> void:
	if not _popup_open or not GameManager.is_match_running():
		_close_action_popup()
		return

	var ingredient_id := _popup_ingredient_id
	var box: IngredientBox = _ingredient_boxes.get(ingredient_id, null)
	if box == null or not box.remove_one():
		_close_action_popup()
		return

	if action == "serve":
		_plate.append(PlateItem.single(ingredient_id))
		_refresh_serve_box()
		_try_complete_dish_on_plate()
		_close_action_popup()
		return

	var station: Dictionary = _stations.get(action, {})
	if station.is_empty() or station.state != "empty":
		box.add_one()
		_close_action_popup()
		return

	station.state = "processing"
	station.item = PlateItem.single(ingredient_id)
	station.time_left = PREP_SECONDS
	_refresh_station_visual(action)
	_sync_chef_loop_sounds()
	_close_action_popup()


func _perform_serve_action(action: String) -> void:
	if not GameManager.is_match_running():
		_close_serve_popup()
		return

	match action:
		"deliver":
			_attempt_deliver()
		"throw":
			_clear_serve_state()
		"cook_all":
			_start_serve_cook()
	_close_serve_popup()


func _tick_station(action: String, delta: float) -> void:
	var station: Dictionary = _stations[action]
	if station.state != "processing":
		return
	station.time_left = maxf(station.time_left - delta, 0.0)
	var progress := _station_progress(action)
	if progress:
		progress.value = (1.0 - station.time_left / PREP_SECONDS) * 100.0
	if station.time_left <= 0.0:
		var was_serve_batch := action == "cook" and bool(station.item.get("from_serve_box", false))
		if was_serve_batch:
			var parts: Array = []
			for batch_item in station.item.get("batch_items", []):
				parts.append_array(_expand_item_parts(batch_item))
			station.item = PlateItem.combined(parts)
		else:
			var prep := PlateItem.PREP_CUT if action == "cut" else PlateItem.PREP_COOKED
			var item: Dictionary = station.item
			station.item = PlateItem.single(String(item.get("ingredient", "")), prep)
		station.state = "ready"
		_refresh_station_visual(action)
		_sync_chef_loop_sounds()


func _start_serve_cook() -> void:
	var cook_station: Dictionary = _stations["cook"]
	if String(cook_station.get("state", "")) != "empty" or _completed_dish_id != "" or _plate.is_empty():
		return
	cook_station.state = "processing"
	cook_station.item = {
		"from_serve_box": true,
		"batch_items": _plate.duplicate(true),
	}
	cook_station.time_left = PREP_SECONDS
	_plate.clear()
	_refresh_serve_box()
	_refresh_station_visual("cook")
	_sync_chef_loop_sounds()


func _expand_item_parts(item: Dictionary) -> Array:
	if item.get("combined", false):
		return item.get("parts", []).duplicate(true)
	return [item]


func _on_station_pressed(action: String) -> void:
	if not GameManager.is_match_running():
		return
	var station: Dictionary = _stations[action]
	if station.state == "ready":
		_plate.append(station.item.duplicate(true))
		station.state = "empty"
		station.item = {}
		station.time_left = 0.0
		_refresh_station_visual(action)
		_refresh_serve_box()
		_try_complete_dish_on_plate()
		_sync_chef_loop_sounds()


## When the plate matches the current order recipe, swap ingredients for the dish image.
func _try_complete_dish_on_plate() -> void:
	if _completed_dish_id != "" or _current_dish_id == "":
		return
	if String(_stations["cook"].get("state", "")) == "processing":
		return
	var dish := RecipeDatabase.get_dish(_current_dish_id)
	if dish == null:
		return
	var have := PlateItem.tokens_from_plate(_plate)
	var need := dish.component_tokens()
	if not PlateItem.tokens_match(have, need):
		return
	_completed_dish_id = _current_dish_id
	_plate.clear()
	_refresh_serve_box()


func _attempt_deliver() -> void:
	GameAudio.play_serving_bell()
	if _completed_dish_id == _current_dish_id and _current_dish_id != "":
		EventBus.recipe_completed.emit(team, POINTS_PER_ORDER, _current_dish_id)
		GameManager.generate_new_order()
	else:
		EventBus.recipe_completed.emit(team, -POINTS_PER_ORDER, "Wrong dish")
	_clear_serve_state()


func _clear_serve_state() -> void:
	_plate.clear()
	_completed_dish_id = ""
	_refresh_serve_box()


func _ingredient_name(ingredient_id: String) -> String:
	var data := RecipeDatabase.get_ingredient(ingredient_id)
	return data.display_name if data else ingredient_id


func navigate_selection(direction: Vector2i) -> void:
	if _popup_open:
		if direction.x != 0:
			var next := clampi(_popup_index + direction.x, 0, _popup_buttons.size() - 1)
			if next != _popup_index:
				_popup_index = next
				GameAudio.play_chef_navigation()
			_update_popup_focus()
		elif direction.y > 0:
			_close_action_popup()
		return
	if _serve_popup_open:
		if direction.x != 0:
			var next := clampi(_serve_popup_index + direction.x, 0, _serve_popup_buttons.size() - 1)
			if next != _serve_popup_index:
				_serve_popup_index = next
				GameAudio.play_chef_navigation()
			_update_serve_popup_focus()
		elif direction.y > 0:
			_close_serve_popup()
		return

	if _ordered_boxes.is_empty():
		return

	match _focus:
		Focus.KNIFE:
			if direction.y > 0:
				_focus_spoon_button()
				GameAudio.play_chef_navigation()
		Focus.SPOON:
			if direction.y < 0:
				_focus_knife_button()
				GameAudio.play_chef_navigation()
			elif direction.y > 0:
				_focus_stations(_station_index)
				GameAudio.play_chef_navigation()
		Focus.STATIONS:
			if direction.x != 0:
				var next := clampi(_station_index + direction.x, 0, _station_boxes.size() - 1)
				if next != _station_index:
					_station_index = next
					GameAudio.play_chef_navigation()
				_update_focus_visuals()
			elif direction.y < 0:
				_focus_spoon_button()
				GameAudio.play_chef_navigation()
			elif direction.y > 0:
				_focus_grid(clampi(_station_index, 0, GRID_COLUMNS - 1))
				GameAudio.play_chef_navigation()
		Focus.GRID:
			var row: int = _selected_index / GRID_COLUMNS
			if direction.y < 0 and row == 0:
				_focus_stations(clampi(_selected_index % GRID_COLUMNS, 0, _station_boxes.size() - 1))
				GameAudio.play_chef_navigation()
				return
			var col: int = _selected_index % GRID_COLUMNS
			row = clampi(row + direction.y, 0, (_ordered_boxes.size() - 1) / GRID_COLUMNS)
			col = clampi(col + direction.x, 0, GRID_COLUMNS - 1)
			var new_index: int = row * GRID_COLUMNS + col
			new_index = clampi(new_index, 0, _ordered_boxes.size() - 1)
			_set_selected_index(new_index, false, true)


func confirm_selection() -> void:
	if _popup_open:
		_perform_ingredient_action(_popup_actions[_popup_index])
		return
	if _serve_popup_open:
		_perform_serve_action(_serve_popup_actions[_serve_popup_index])
		return

	match _focus:
		Focus.KNIFE:
			_on_knife_resupply_pressed()
		Focus.SPOON:
			_on_spoon_resupply_pressed()
		Focus.STATIONS:
			var action := STATION_ORDER[_station_index]
			if action == "serve":
				_open_serve_popup()
			else:
				_on_station_pressed(action)
		Focus.GRID:
			if not _ordered_ingredient_ids.is_empty():
				_on_ingredient_box_clicked(_ordered_ingredient_ids[_selected_index])


func _update_popup_focus() -> void:
	for i in _popup_buttons.size():
		_set_nav_focused(_popup_buttons[i], _popup_open and i == _popup_index)


func _update_serve_popup_focus() -> void:
	for i in _serve_popup_buttons.size():
		_set_nav_focused(_serve_popup_buttons[i], _serve_popup_open and i == _serve_popup_index)


func _focus_knife_button() -> void:
	_focus = Focus.KNIFE
	_update_focus_visuals()


func _focus_spoon_button() -> void:
	_focus = Focus.SPOON
	_update_focus_visuals()


func _focus_stations(index: int) -> void:
	_focus = Focus.STATIONS
	_station_index = clampi(index, 0, _station_boxes.size() - 1)
	_update_focus_visuals()


func _focus_grid(top_row_column: int = -1) -> void:
	_focus = Focus.GRID
	if top_row_column >= 0:
		_selected_index = clampi(top_row_column, 0, _ordered_boxes.size() - 1)
	_update_focus_visuals()


func _update_focus_visuals() -> void:
	var main_nav_active := not _popup_open and not _serve_popup_open
	for i in _ordered_boxes.size():
		_ordered_boxes[i].set_focused(
			main_nav_active and _focus == Focus.GRID and i == _selected_index
		)
	_set_nav_focused(_knife_button, main_nav_active and _focus == Focus.KNIFE)
	_set_nav_focused(_spoon_button, main_nav_active and _focus == Focus.SPOON)
	for i in _station_boxes.size():
		var action := STATION_ORDER[i]
		var focused := main_nav_active and _focus == Focus.STATIONS and i == _station_index
		var idle := Color.WHITE
		if not focused and action != "serve" and _stations[action].state == "ready":
			idle = READY_GLOW
		_set_nav_focused(_station_boxes[i], focused, idle)
	if not _popup_open:
		for btn in _popup_buttons:
			_set_nav_focused(btn, false)
	if not _serve_popup_open:
		for btn in _serve_popup_buttons:
			_set_nav_focused(btn, false)


func _on_knife_resupply_pressed() -> void:
	if not GameManager.is_match_running():
		return
	EventBus.knife_resupply_requested.emit(team)


func _on_spoon_resupply_pressed() -> void:
	if not GameManager.is_match_running():
		return
	EventBus.spoon_resupply_requested.emit(team)


func _set_selected_index(index: int, _from_mouse: bool, play_nav_sound: bool = false) -> void:
	if _ordered_boxes.is_empty():
		return
	var next := clampi(index, 0, _ordered_boxes.size() - 1)
	if play_nav_sound and next != _selected_index:
		GameAudio.play_chef_navigation()
	_focus = Focus.GRID
	_selected_index = next
	_update_focus_visuals()


func _sync_chef_loop_sounds() -> void:
	var cut_station: Dictionary = _stations["cut"]
	var cook_station: Dictionary = _stations["cook"]
	var cutting: bool = String(cut_station.get("state", "")) == "processing"
	var cooking: bool = String(cook_station.get("state", "")) == "processing"
	GameAudio.set_chef_cutting(team, cutting)
	GameAudio.set_chef_cooking(team, cooking)


func _station_box(action: String) -> Button:
	match action:
		"cut": return _cut_box
		"cook": return _cook_box
		_: return _serve_box


func _station_icons(action: String) -> HBoxContainer:
	match action:
		"cut": return _cut_icons
		"cook": return _cook_icons
		_: return _serve_icons


func _station_progress(action: String) -> ProgressBar:
	match action:
		"cut": return _cut_progress
		"cook": return _cook_progress
		_: return _serve_progress


func _refresh_station_visual(action: String) -> void:
	if action == "serve":
		_refresh_serve_box()
		return

	var station: Dictionary = _stations[action]
	var box := _station_box(action)
	var icons := _station_icons(action)
	var progress := _station_progress(action)

	match station.state:
		"processing", "ready":
			var items_to_show: Array = _items_for_station_display(station)
			_populate_icon_row(icons, items_to_show)
			if progress:
				progress.visible = station.state == "processing"
				if station.state == "processing":
					progress.value = (1.0 - station.time_left / PREP_SECONDS) * 100.0
				else:
					progress.visible = false
		_:
			_clear_icon_row(icons)
			if progress:
				progress.visible = false
				progress.value = 0.0

	if box:
		var idx := STATION_ORDER.find(action)
		var main_nav_active := not _popup_open and not _serve_popup_open
		var focused := main_nav_active and _focus == Focus.STATIONS and idx == _station_index
		var idle := Color.WHITE
		if not focused and action != "serve" and station.state == "ready":
			idle = READY_GLOW
		_set_nav_focused(box, focused, idle)


func _refresh_serve_box() -> void:
	var has_content := false

	if _completed_dish_id != "":
		var dish := RecipeDatabase.get_dish(_completed_dish_id)
		_clear_icon_row(_serve_icons)
		if dish and dish.texture:
			_add_texture_to_icon_row(_serve_icons, dish.texture)
			has_content = true
		if _serve_dish_image:
			_serve_dish_image.visible = false
			_serve_dish_image.texture = null
		if _serve_progress:
			_serve_progress.visible = false
		_apply_serve_box_layout(has_content)
		return

	if _serve_dish_image:
		_serve_dish_image.visible = false
		_serve_dish_image.texture = null

	if _plate.is_empty():
		_clear_icon_row(_serve_icons)
		if _serve_progress:
			_serve_progress.visible = false
		_apply_serve_box_layout(false)
		return

	_populate_icon_row(_serve_icons, _plate)
	if _serve_progress:
		_serve_progress.visible = false
	_apply_serve_box_layout(true)


func _apply_serve_box_layout(has_content: bool) -> void:
	if _serve_vbox == null:
		return
	_serve_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN if has_content else BoxContainer.ALIGNMENT_CENTER
	_serve_vbox.add_theme_constant_override("separation", 0 if has_content else 1)


func _add_texture_to_icon_row(row: HBoxContainer, texture: Texture2D) -> void:
	if row == null or texture == null:
		return
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = texture
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)


func _items_for_station_display(station: Dictionary) -> Array:
	if bool(station.item.get("from_serve_box", false)):
		return station.item.get("batch_items", [])
	if station.item.is_empty():
		return []
	return [station.item]


func _populate_icon_row(row: HBoxContainer, items: Array) -> void:
	if row == null:
		return
	_clear_icon_row(row)
	for item in items:
		if item.is_empty():
			continue
		for tex in _textures_for_item(item):
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture = tex
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon)


func _textures_for_item(item: Dictionary) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if item.get("combined", false):
		for part in item.get("parts", []):
			var data := RecipeDatabase.get_ingredient(String(part.get("ingredient", "")))
			if data and data.texture:
				out.append(data.texture)
	else:
		var data := RecipeDatabase.get_ingredient(String(item.get("ingredient", "")))
		if data and data.texture:
			out.append(data.texture)
	return out


func _clear_icon_row(row: HBoxContainer) -> void:
	if row == null:
		return
	for child in row.get_children():
		child.queue_free()


func _reset_stations() -> void:
	for action in ["cut", "cook"]:
		_stations[action].state = "empty"
		_stations[action].item = {}
		_stations[action].time_left = 0.0
		_refresh_station_visual(action)


func reset_for_match() -> void:
	GameAudio.set_chef_cutting(team, false)
	GameAudio.set_chef_cooking(team, false)
	for box in _ingredient_boxes.values():
		box.set_count(0)
	_current_dish_id = ""
	_clear_serve_state()
	_reset_stations()
	_close_action_popup()
	_close_serve_popup()
	if _recipe_ui:
		_recipe_ui.show_dish("")
	_set_selected_index(0, false)
