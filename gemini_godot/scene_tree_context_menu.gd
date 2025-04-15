# addons/gemini_godot/scene_tree_context_menu.gd
@tool
extends EditorContextMenuPlugin

# Reference to the main EditorPlugin instance.
var main_plugin_instance = null
var last_selected_paths : PackedStringArray = []

# Called by the editor just before showing the context menu.
func _popup_menu(paths: PackedStringArray) -> void:
	last_selected_paths = paths
	if paths.is_empty(): return

	if not is_instance_valid(main_plugin_instance) or \
	   not main_plugin_instance.has_method("_handle_scene_tree_context_action"):
		printerr("SceneTreeContextMenu: Main plugin invalid or missing handler."); return

	# Add the custom context menu items (Updated text)
	add_context_menu_item("Gemini: Attach Node Structure", _on_send_structure_selected)
	add_context_menu_item("Gemini: Attach Node Properties", _on_send_properties_selected)

# Callback methods within this script.
func _on_send_structure_selected(_user_data = null): # Argument added
	if not last_selected_paths.is_empty():
		main_plugin_instance.call("_handle_scene_tree_context_action", last_selected_paths[0], "send_structure")
	else: printerr("SceneTreeContextMenu: _on_send_structure_selected called but last_selected_paths is empty.")

func _on_send_properties_selected(_user_data = null): # Argument added
	if not last_selected_paths.is_empty():
		main_plugin_instance.call("_handle_scene_tree_context_action", last_selected_paths[0], "send_properties")
	else: printerr("SceneTreeContextMenu: _on_send_properties_selected called but last_selected_paths is empty.")

# Setter function called by the main plugin.
func set_main_plugin(plugin_ref):
	if is_instance_valid(plugin_ref) and plugin_ref is EditorPlugin:
		main_plugin_instance = plugin_ref
	else:
		main_plugin_instance = null
		printerr("SceneTreeContextMenu: Invalid main plugin reference passed.")
