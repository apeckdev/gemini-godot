# addons/gemini_godot/script_editor_context_menu.gd
@tool
extends EditorContextMenuPlugin

# Reference to the main EditorPlugin instance.
var main_plugin_instance = null

# This method is called by the editor just before showing the context menu.
func _popup_menu(paths: PackedStringArray) -> void:
	if not is_instance_valid(main_plugin_instance): printerr("ContextMenuPlugin: Main plugin instance invalid."); return
	if not main_plugin_instance.has_method("_handle_context_menu_action"): printerr("ContextMenuPlugin: Main plugin missing handler."); return

	var item_text = "Gemini: Attach Selection to Prompt" # Updated text
	var callback = Callable(self, "_on_ask_gemini_selected")
	add_context_menu_item(item_text, callback, null)

# Callback method within this script.
func _on_ask_gemini_selected(_user_data = null): # Argument added
	print("ContextMenuPlugin: '%s' option clicked." % "Gemini: Attach Selection to Prompt")
	if is_instance_valid(main_plugin_instance) and main_plugin_instance.has_method("_handle_context_menu_action"):
		main_plugin_instance.call("_handle_context_menu_action")
	else:
		printerr("ContextMenuPlugin: Cannot call main plugin handler. Instance valid: %s, Has method: %s" % [is_instance_valid(main_plugin_instance), main_plugin_instance.has_method("_handle_context_menu_action") if is_instance_valid(main_plugin_instance) else "N/A"])

# Setter function called by the main plugin.
func set_main_plugin(plugin_ref):
	if is_instance_valid(plugin_ref) and plugin_ref is EditorPlugin:
		main_plugin_instance = plugin_ref
		print("ContextMenuPlugin: Main plugin reference successfully set.")
	else:
		printerr("ContextMenuPlugin: Invalid reference passed to set_main_plugin.")
		main_plugin_instance = null
