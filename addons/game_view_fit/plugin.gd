@tool
extends EditorPlugin
## This is an editor preference, independent of the game's canvas stretch mode.
## Keep it with the project so deleting .godot does not restore a fixed-size view.

func _enter_tree() -> void:
	var settings := EditorInterface.get_editor_settings()
	# GameView::SIZE_MODE_STRETCH (verified in Godot 4.7.2): resize the native game window
	# to fill its host; canvas_items + expand preserves scene/UI proportions.
	settings.set_project_metadata("game_view", "embed_size_mode", 2)
