## GathererHUD.gd
## Per-screen overlay: health bar, match timer (top-right), and respawn countdown.
extends CanvasLayer
class_name GathererHUD

@export var team: int = 0

const FILL_FULL_WIDTH := 176.0
const TIMER_FONT_SIZE := 19
const TIMER_COLOR := Color(1.0, 0.92, 0.2)

@onready var _fill: ColorRect = $Root/HealthBar/Fill
@onready var _knife_label: Label = $Root/AmmoRow/KnifeAmmo/KnifeLabel
@onready var _spoon_label: Label = $Root/AmmoRow/SpoonAmmo/SpoonLabel
@onready var _timer_root: Control = $Root/MatchTimer
@onready var _timer_label: Label = $Root/MatchTimer/TimerLabel
@onready var _respawn_label: Label = $Root/RespawnCenter/RespawnLabel


func _ready() -> void:
	_configure_timer_label()
	_configure_respawn_label()
	_configure_ammo_labels()
	_timer_root.visible = false
	_respawn_label.visible = false

	EventBus.gatherer_health_changed.connect(_on_health_changed)
	EventBus.gatherer_knives_changed.connect(_on_knives_changed)
	EventBus.gatherer_spoons_changed.connect(_on_spoons_changed)
	EventBus.timer_updated.connect(_on_timer_updated)
	EventBus.match_started.connect(_on_match_started)
	EventBus.match_ended.connect(_on_match_ended)
	EventBus.gatherer_respawn_started.connect(_on_respawn_started)
	EventBus.gatherer_respawn_tick.connect(_on_respawn_tick)
	EventBus.gatherer_respawn_finished.connect(_on_respawn_finished)


func _configure_timer_label() -> void:
	if _timer_label == null:
		return
	QuadrantMatchOverlay.apply_bold_font(_timer_label)
	_timer_label.add_theme_color_override("font_color", TIMER_COLOR)
	_timer_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_timer_label.add_theme_constant_override("shadow_offset_x", 1)
	_timer_label.add_theme_constant_override("shadow_offset_y", 1)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _configure_respawn_label() -> void:
	if _respawn_label == null:
		return
	QuadrantMatchOverlay.apply_bold_font(_respawn_label)


func _configure_ammo_labels() -> void:
	if _knife_label:
		QuadrantMatchOverlay.apply_bold_font(_knife_label)
	if _spoon_label:
		QuadrantMatchOverlay.apply_bold_font(_spoon_label)


func _on_health_changed(changed_team: int, current_health: int, max_health: int) -> void:
	if changed_team != team:
		return
	var ratio := clampf(float(current_health) / float(max_health), 0.0, 1.0)
	_fill.size.x = FILL_FULL_WIDTH * ratio
	_fill.color = Color(1.0 - ratio, 0.75 * ratio + 0.15, 0.2)


func _on_knives_changed(changed_team: int, count: int, _max_knives: int) -> void:
	if changed_team != team or _knife_label == null:
		return
	_knife_label.text = "x%d" % count


func _on_spoons_changed(changed_team: int, count: int, _max_spoons: int) -> void:
	if changed_team != team or _spoon_label == null:
		return
	_spoon_label.text = "x%d" % count


func _on_timer_updated(seconds: float) -> void:
	if _timer_label == null or not _timer_root.visible:
		return
	var minutes := int(seconds) / 60
	var secs := int(seconds) % 60
	_timer_label.text = "Time: %02d:%02d" % [minutes, secs]


func _on_match_started() -> void:
	_timer_root.visible = true
	_on_timer_updated(GameManager.get_time_remaining())


func _on_match_ended(_winner: int, _score_a: int, _score_b: int) -> void:
	_timer_root.visible = false


func _on_respawn_started(dead_team: int) -> void:
	if dead_team != team:
		return
	_respawn_label.visible = true


func _on_respawn_tick(dead_team: int, seconds_left: int) -> void:
	if dead_team != team:
		return
	_respawn_label.text = str(seconds_left)


func _on_respawn_finished(dead_team: int) -> void:
	if dead_team != team:
		return
	_respawn_label.visible = false
