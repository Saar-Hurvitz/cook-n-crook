## IngredientData.gd
## Resource definition for a single ingredient type used across maze pickups and chef UI.
## Inherits from: Resource (Godot base class for serializable game data).
class_name IngredientData
extends Resource

## Unique string key used for recipe matching and network-safe references.
@export var id: String = ""

## Display name shown on chef UI and recipe panels.
@export var display_name: String = ""

## Tint color used as a fallback when no texture is supplied.
@export var color: Color = Color.WHITE

## Artwork shown in the chef pantry box and on the maze pickup.
@export var texture: Texture2D = null


## Factory helper — creates runtime ingredient data without a .tres file.
static func create(p_id: String, p_name: String, p_color: Color, p_texture: Texture2D = null) -> IngredientData:
	var data := IngredientData.new()
	data.id = p_id
	data.display_name = p_name
	data.color = p_color
	data.texture = p_texture
	return data
