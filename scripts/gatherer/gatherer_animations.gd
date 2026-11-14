## GathererAnimations.gd
## Builds SpriteFrames from preloaded gatherer animation textures (export-safe).
## Inherits from: RefCounted (stateless loader utility).
class_name GathererAnimations
extends RefCounted

const DEFAULT_FPS := 8.0

## Explicit preloads — exported builds cannot scan folders with DirAccess at runtime.
const FRAMES: Dictionary = {
	"idle": [
		preload("res://assets/characters/gatherer/animations/idle/idle_01.png"),
	],
	"walk_down": [
		preload("res://assets/characters/gatherer/animations/walk_down/Walk_down_1.png"),
		preload("res://assets/characters/gatherer/animations/walk_down/Walk_down_2.png"),
		preload("res://assets/characters/gatherer/animations/walk_down/Walk_down_3.png"),
	],
	"walk_left": [
		preload("res://assets/characters/gatherer/animations/walk_left/Walk_left_01.png"),
		preload("res://assets/characters/gatherer/animations/walk_left/Walk_left_02.png"),
		preload("res://assets/characters/gatherer/animations/walk_left/Walk_left_03.png"),
	],
	"walk_right": [
		preload("res://assets/characters/gatherer/animations/walk_right/Walk_right_01.png"),
		preload("res://assets/characters/gatherer/animations/walk_right/Walk_right_02.png"),
		preload("res://assets/characters/gatherer/animations/walk_right/Walk_right_03.png"),
		preload("res://assets/characters/gatherer/animations/walk_right/Walk_right_04.png"),
	],
	"walk_up": [
		preload("res://assets/characters/gatherer/animations/walk_up/Walk_up_01.png"),
		preload("res://assets/characters/gatherer/animations/walk_up/Walk_up_02.png"),
	],
}

static var _cached_frames: SpriteFrames = null


## Returns a shared SpriteFrames resource built from preloaded gatherer textures.
static func get_sprite_frames() -> SpriteFrames:
	if _cached_frames == null:
		_cached_frames = _build_sprite_frames()
	return _cached_frames


static func _build_sprite_frames() -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	var animation_names: Array[String] = []
	animation_names.assign(FRAMES.keys())
	animation_names.sort()

	for action_name in animation_names:
		var textures: Array = FRAMES[action_name]
		if textures.is_empty():
			continue

		sprite_frames.add_animation(action_name)
		sprite_frames.set_animation_loop(action_name, true)
		sprite_frames.set_animation_speed(action_name, DEFAULT_FPS)

		for texture in textures:
			if texture is Texture2D:
				sprite_frames.add_frame(action_name, texture)

	if sprite_frames.get_animation_names().is_empty():
		push_error("GathererAnimations: no animation frames were loaded.")
	return sprite_frames
