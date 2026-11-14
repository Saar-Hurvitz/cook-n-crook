## GlobalHUD.gd
## Match-wide overlay: start/countdown/end flow and battle music.
extends CanvasLayer
class_name GlobalHUD

const BATTLE_MUSIC := preload("res://assets/audio/music/battle_music.mp3")

const MUSIC_VOLUME_DEFAULT := 0.6
const MUSIC_VOLUME_TWO_MINUTES := 0.8
const MUSIC_VOLUME_FINAL_MINUTE := 1.0
const TWO_MINUTES_REMAINING := 120.0
const ONE_MINUTE_REMAINING := 60.0

const RESTART_BUTTON := JOY_BUTTON_A

@onready var _start_panel: ColorRect = $StartPanel
@onready var _lobby: Lobby = $StartPanel/Lobby
@onready var _countdown_panel: ColorRect = $CountdownPanel
@onready var _countdown_label: Label = $CountdownPanel/CountdownCenter/CountdownLabel
@onready var _end_panel: PanelContainer = $EndPanel
@onready var _winner_label: Label = $EndPanel/EndVBox/WinnerLabel
@onready var _score_label: Label = $EndPanel/EndVBox/ScoreLabel
@onready var _restart_prompt: Label = $EndPanel/EndVBox/RestartPrompt
@onready var _music: AudioStreamPlayer = $Music

var _countdown_running: bool = false


func _ready() -> void:
	_music.stream = BATTLE_MUSIC
	_end_panel.visible = false
	_countdown_panel.visible = false
	_start_panel.visible = true

	for label in [_winner_label, _score_label, _restart_prompt]:
		QuadrantMatchOverlay.apply_bold_font(label)

	_lobby.start_requested.connect(_on_lobby_start_requested)
	_lobby.set_active(true)
	EventBus.timer_updated.connect(_on_timer_updated)
	EventBus.match_ended.connect(_on_match_ended)


func _input(event: InputEvent) -> void:
	if not _end_panel.visible or _countdown_running:
		return

	if event is InputEventJoypadButton and event.pressed and not event.is_echo():
		if event.button_index == RESTART_BUTTON:
			_restart_match()
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_restart_match()


func _on_match_ended(winning_team: int, score_a: int, score_b: int) -> void:
	_winner_label.text = _winner_text(winning_team)
	_score_label.text = "A: %d  |  B: %d" % [score_a, score_b]
	_end_panel.visible = true
	_music.stop()


func _winner_text(winning_team: int) -> String:
	match winning_team:
		GameManager.Team.A:
			return "Team A Won!"
		GameManager.Team.B:
			return "Team B Won!"
		_:
			return "It's a Tie!"


func _on_lobby_start_requested(role_devices: Dictionary) -> void:
	GameManager.set_role_devices(role_devices)
	_lobby.set_active(false)
	_start_panel.visible = false
	_begin_round_sequence()


func _restart_match() -> void:
	if not _end_panel.visible:
		return
	_end_panel.visible = false
	_begin_round_sequence()


func _begin_round_sequence() -> void:
	if _countdown_running:
		return
	_countdown_running = true

	var main: Node = get_parent()
	if main.has_method("begin_round_reset"):
		main.begin_round_reset()

	await _run_countdown()

	if main.has_method("await_round_reset_finished"):
		await main.await_round_reset_finished()

	_start_music()
	GameManager.start_match()
	_countdown_running = false


func _run_countdown() -> void:
	_countdown_panel.visible = true
	for number in [3, 2, 1]:
		_countdown_label.text = str(number)
		await get_tree().create_timer(1.0).timeout
	_countdown_panel.visible = false


func _start_music() -> void:
	_music.stop()
	_update_music_volume(GameManager.get_time_remaining())
	_music.play()


func _update_music_volume(seconds_remaining: float) -> void:
	var volume := MUSIC_VOLUME_DEFAULT
	if seconds_remaining <= ONE_MINUTE_REMAINING:
		volume = MUSIC_VOLUME_FINAL_MINUTE
	elif seconds_remaining <= TWO_MINUTES_REMAINING:
		volume = MUSIC_VOLUME_TWO_MINUTES
	_music.volume_db = linear_to_db(volume)


func _on_timer_updated(seconds: float) -> void:
	if _music.playing:
		_update_music_volume(seconds)
