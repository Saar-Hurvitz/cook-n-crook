## ExportBootstrap.gd
## Warms up preloaded runtime assets so exported builds pack and load them correctly.
extends Node


func _ready() -> void:
	GathererAnimations.get_sprite_frames()
	RecipeDatabase.get_all_ingredient_ids()
