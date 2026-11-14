## GameAudio.gd
## Central one-shot and looping SFX for chef, gatherer, and maze events.
extends Node

const SFX_FILE_NAVIGATION := preload("res://assets/audio/game_sound_effects/chef/file_navigation.mp3")
const SFX_SERVING_BELL := preload("res://assets/audio/game_sound_effects/chef/serving_bell.mp3")
const SFX_SOMETHING_IS_BEING_CUT := preload("res://assets/audio/game_sound_effects/chef/something_is_being_cut.mp3")
const SFX_SOMETHING_IS_COOKING := preload("res://assets/audio/game_sound_effects/chef/something_is_cooking.mp3")
const SFX_GATHERER_DAMAGE := preload("res://assets/audio/game_sound_effects/gatherer/gatherer_takes_damage.mp3")
const SFX_GATHERER_WALKING := preload("res://assets/audio/game_sound_effects/gatherer/gatherer_walking.mp3")
const SFX_INGREDIENT_PICKED_UP := preload("res://assets/audio/game_sound_effects/gatherer/ingridient_picked_up.mp3")
const SFX_MONSTER_SPAWN := preload("res://assets/audio/game_sound_effects/maze/monster_burger_is_coming.mp3")

const NAVIGATION_VOLUME := 0.4
const MONSTER_SPAWN_VOLUME := 0.5
const CUT_LOOP_VOLUME := 2.0
const COOK_LOOP_VOLUME := 5.0
const SERVING_BELL_CLIP_SECONDS := 2.0
const DAMAGE_CLIP_SECONDS := 1.0

var _cut_loop: AudioStreamPlayer
var _cook_loop: AudioStreamPlayer
var _pickup_player: AudioStreamPlayer
var _walk_players: Array[AudioStreamPlayer] = []

var _chef_cutting: Dictionary = {}
var _chef_cooking: Dictionary = {}
var _gatherer_walking: Dictionary = {}


func _ready() -> void:
	_cut_loop = _make_loop_player(SFX_SOMETHING_IS_BEING_CUT)
	_cut_loop.volume_db = linear_to_db(CUT_LOOP_VOLUME)
	_cook_loop = _make_loop_player(SFX_SOMETHING_IS_COOKING)
	_cook_loop.volume_db = linear_to_db(COOK_LOOP_VOLUME)
	_pickup_player = _make_one_shot_player()
	for _i in 2:
		_walk_players.append(_make_loop_player(SFX_GATHERER_WALKING))


func _make_loop_player(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var loop_stream: AudioStream = stream.duplicate()
	if loop_stream is AudioStreamMP3:
		(loop_stream as AudioStreamMP3).loop = true
	player.stream = loop_stream
	player.bus = &"Master"
	add_child(player)
	player.finished.connect(func() -> void:
		if player.stream != null:
			player.play()
	)
	return player


func _make_one_shot_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = &"Master"
	add_child(player)
	return player


func play_chef_navigation() -> void:
	_play_one_shot(SFX_FILE_NAVIGATION, NAVIGATION_VOLUME)


func play_serving_bell() -> void:
	_play_timed_clip(SFX_SERVING_BELL, SERVING_BELL_CLIP_SECONDS)


func play_gatherer_damage() -> void:
	_play_timed_clip(SFX_GATHERER_DAMAGE, DAMAGE_CLIP_SECONDS)


func play_ingredient_pickup() -> void:
	if _pickup_player.playing:
		_pickup_player.stop()
	_pickup_player.stream = SFX_INGREDIENT_PICKED_UP
	_pickup_player.volume_db = 0.0
	_pickup_player.play()


func play_monster_spawn() -> void:
	_play_one_shot(SFX_MONSTER_SPAWN, MONSTER_SPAWN_VOLUME)


func set_chef_cutting(team: int, active: bool) -> void:
	_chef_cutting[team] = active
	_sync_loop(_cut_loop, _chef_cutting)


func set_chef_cooking(team: int, active: bool) -> void:
	_chef_cooking[team] = active
	_sync_loop(_cook_loop, _chef_cooking)


func set_gatherer_walking(team: int, active: bool) -> void:
	if _gatherer_walking.get(team, false) == active:
		return
	_gatherer_walking[team] = active
	var player := _walk_player_for_team(team)
	if player == null:
		return
	if active:
		if not player.playing:
			player.play()
	else:
		player.stop()


func _walk_player_for_team(team: int) -> AudioStreamPlayer:
	if team < 0 or team >= _walk_players.size():
		return null
	return _walk_players[team]


func _sync_loop(player: AudioStreamPlayer, flags: Dictionary) -> void:
	var any_active := false
	for active in flags.values():
		if active:
			any_active = true
			break
	if any_active:
		if not player.playing:
			player.play()
	else:
		player.stop()


func _play_one_shot(stream: AudioStream, volume_linear: float = 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(volume_linear)
	player.bus = &"Master"
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _play_timed_clip(stream: AudioStream, duration: float, volume_linear: float = 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(volume_linear)
	player.bus = &"Master"
	add_child(player)
	player.play()
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	, CONNECT_ONE_SHOT)
