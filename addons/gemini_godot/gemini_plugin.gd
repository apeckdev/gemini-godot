# addons/gemini_godot/gemini_plugin.gd
@tool
extends EditorPlugin

# --- Constants ---
const PLUGIN_NAME = "Gemini Assistant"
const API_KEY_SETTING_PATH = "plugins/gemini_godot/api_key"
const API_MODEL_SETTING_PATH = "plugins/gemini_godot/api_model"
const ALLOWED_MODELS = "gemini-2.5-pro-preview-03-25,gemini-2.0-flash,gemini-2.0-flash-lite,gemini-1.5-flash,gemini-1.5-flash-8b,gemini-1.5-pro,gemini-embedding-exp,imagen-3.0-generate-002,veo-2.0-generate-001,gemini-2.0-flash-live-001"
const DEFAULT_MODEL = "gemini-1.5-flash-latest"
const INCLUDE_SCENE_TREE_SETTING = "plugins/gemini_godot/include_scene_tree_on_select"
const INCLUDE_PROJECT_TREE_SETTING = "plugins/gemini_godot/include_project_tree_on_select"
const PROJECT_TREE_MAX_DEPTH_SETTING = "plugins/gemini_godot/project_tree_max_depth"
const INCLUDE_TREE_NODE_DETAILS_SETTING = "plugins/gemini_godot/include_tree_node_details"

# --- Preloads ---
const GeminiDockScene = preload("res://addons/gemini_godot/gemini_dock.tscn")
const ScriptContextMenuPluginScript = preload("res://addons/gemini_godot/script_editor_context_menu.gd")
const SceneTreeContextMenuPluginScript = preload("res://addons/gemini_godot/scene_tree_context_menu.gd")
const APIHandlerScript = preload("res://addons/gemini_godot/api_handler.gd")

# --- Variables ---
var editor_settings : EditorSettings
var gemini_dock_instance = null
var script_editor_instance : ScriptEditor = null
var script_context_menu_instance = null
var scene_tree_context_menu_instance = null

# --- Lifecycle Methods ---
func _enter_tree():
	print("%s Plugin: Initializing..." % PLUGIN_NAME)
	var interface : EditorInterface = get_editor_interface(); if not interface: printerr("%s: No EditorInterface." % PLUGIN_NAME); return
	editor_settings = interface.get_editor_settings(); if not is_instance_valid(editor_settings): printerr("%s: No EditorSettings." % PLUGIN_NAME); editor_settings = null; return
	script_editor_instance = interface.get_script_editor(); if not is_instance_valid(script_editor_instance): print("%s: No ScriptEditor instance." % PLUGIN_NAME)
	print("%s Plugin: Initializing UI Dock..." % PLUGIN_NAME)
	if not is_instance_valid(gemini_dock_instance):
		if GeminiDockScene:
			gemini_dock_instance = GeminiDockScene.instantiate()
			if is_instance_valid(gemini_dock_instance):
				gemini_dock_instance.main_plugin_instance = self
				if gemini_dock_instance.has_method("update_settings_status"): gemini_dock_instance.call_deferred("update_settings_status")
				else: printerr("%s: Dock missing update_settings_status." % PLUGIN_NAME)
				add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BL, gemini_dock_instance)
				print("%s Plugin: UI Dock added." % PLUGIN_NAME)
			else: printerr("%s Plugin: Failed to instantiate GeminiDockScene." % PLUGIN_NAME); return
		else: printerr("%s Plugin: Failed to load GeminiDockScene resource." % PLUGIN_NAME); return
		
	# --- Setup Editor Settings ---
	var settings_changed = false
	editor_settings.add_property_info({"name": API_KEY_SETTING_PATH, "type": TYPE_STRING, "hint": PROPERTY_HINT_PASSWORD})
	if not editor_settings.has_setting(API_KEY_SETTING_PATH): editor_settings.set_setting(API_KEY_SETTING_PATH, ""); editor_settings.set_initial_value(API_KEY_SETTING_PATH, "", false); settings_changed = true
	editor_settings.add_property_info({"name": API_MODEL_SETTING_PATH, "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": ALLOWED_MODELS})
	if not editor_settings.has_setting(API_MODEL_SETTING_PATH): editor_settings.set_setting(API_MODEL_SETTING_PATH, DEFAULT_MODEL); editor_settings.set_initial_value(API_MODEL_SETTING_PATH, DEFAULT_MODEL, false); settings_changed = true
	editor_settings.add_property_info({ "name": INCLUDE_SCENE_TREE_SETTING, "type": TYPE_BOOL })
	if not editor_settings.has_setting(INCLUDE_SCENE_TREE_SETTING): editor_settings.set_setting(INCLUDE_SCENE_TREE_SETTING, false); editor_settings.set_initial_value(INCLUDE_SCENE_TREE_SETTING, false, false); settings_changed = true
	editor_settings.add_property_info({ "name": INCLUDE_PROJECT_TREE_SETTING, "type": TYPE_BOOL, "hint_string": "WARNING: Including the project tree can send a LOT of data and may be slow/expensive. Use with caution!" })
	if not editor_settings.has_setting(INCLUDE_PROJECT_TREE_SETTING): editor_settings.set_setting(INCLUDE_PROJECT_TREE_SETTING, false); editor_settings.set_initial_value(INCLUDE_PROJECT_TREE_SETTING, false, false); settings_changed = true
	editor_settings.add_property_info({ "name": PROJECT_TREE_MAX_DEPTH_SETTING, "type": TYPE_INT, "hint": PROPERTY_HINT_RANGE, "hint_string": "1,10,1" })
	if not editor_settings.has_setting(PROJECT_TREE_MAX_DEPTH_SETTING): editor_settings.set_setting(PROJECT_TREE_MAX_DEPTH_SETTING, 3); editor_settings.set_initial_value(PROJECT_TREE_MAX_DEPTH_SETTING, 3, false); settings_changed = true
	editor_settings.add_property_info({ "name": INCLUDE_TREE_NODE_DETAILS_SETTING, "type": TYPE_BOOL, "hint_string": "Include node properties within automatic Scene/Project Tree context (Can increase context size significantly)." })
	if not editor_settings.has_setting(INCLUDE_TREE_NODE_DETAILS_SETTING): editor_settings.set_setting(INCLUDE_TREE_NODE_DETAILS_SETTING, false); editor_settings.set_initial_value(INCLUDE_TREE_NODE_DETAILS_SETTING, false, false); settings_changed = true
	if settings_changed: print("%s: Initial settings created/restored." % PLUGIN_NAME)
	
	# --- Initialize Context Menu Plugins ---
	print("%s Plugin: Initializing Script Editor Context Menu Plugin..." % PLUGIN_NAME)
	if ScriptContextMenuPluginScript:
		if not is_instance_valid(script_context_menu_instance):
			script_context_menu_instance = ScriptContextMenuPluginScript.new()
			if is_instance_valid(script_context_menu_instance):
				if script_context_menu_instance.has_method("set_main_plugin"): script_context_menu_instance.set_main_plugin(self)
				else: printerr("%s: Script context menu missing set_main_plugin." % PLUGIN_NAME)
				add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR_CODE, script_context_menu_instance); print("%s: Script context menu registered." % PLUGIN_NAME)
			else: printerr("%s: Failed create ScriptContextMenu instance!" % PLUGIN_NAME)
		else: print("%s: Script context menu instance exists." % PLUGIN_NAME)
	else: printerr("%s: Failed load ScriptContextMenu script." % PLUGIN_NAME)
	print("%s Plugin: Initializing Scene Tree Context Menu Plugin..." % PLUGIN_NAME)
	if SceneTreeContextMenuPluginScript:
		if not is_instance_valid(scene_tree_context_menu_instance):
			scene_tree_context_menu_instance = SceneTreeContextMenuPluginScript.new()
			if is_instance_valid(scene_tree_context_menu_instance):
				if scene_tree_context_menu_instance.has_method("set_main_plugin"): scene_tree_context_menu_instance.set_main_plugin(self)
				else: printerr("%s: Scene tree context menu missing set_main_plugin." % PLUGIN_NAME)
				add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE, scene_tree_context_menu_instance); print("%s: Scene tree context menu registered." % PLUGIN_NAME)
			else: printerr("%s: Failed create SceneTreeContextMenu instance!" % PLUGIN_NAME)
		else: print("%s: Scene tree context menu instance exists." % PLUGIN_NAME)
	else: printerr("%s: Failed load SceneTreeContextMenu script." % PLUGIN_NAME)
	# --- Connect to EditorSettings changed signal ---
	if is_instance_valid(editor_settings):
		if not editor_settings.is_connected("settings_changed", _on_editor_settings_changed): editor_settings.settings_changed.connect(_on_editor_settings_changed); print("%s: Connected settings_changed signal." % PLUGIN_NAME)
	else: printerr("%s: Cannot connect settings_changed, EditorSettings invalid." % PLUGIN_NAME)
	print("%s Plugin: Initialization complete." % PLUGIN_NAME)

func _exit_tree():
	print("%s Plugin: Cleaning up..." % PLUGIN_NAME)
	if is_instance_valid(editor_settings):
		if editor_settings.is_connected("settings_changed", _on_editor_settings_changed): editor_settings.settings_changed.disconnect(_on_editor_settings_changed); print("%s: Disconnected settings signal." % PLUGIN_NAME)
	if is_instance_valid(script_context_menu_instance): remove_context_menu_plugin(script_context_menu_instance); script_context_menu_instance.queue_free(); script_context_menu_instance = null; print("%s: Script context menu cleaned up." % PLUGIN_NAME)
	if is_instance_valid(scene_tree_context_menu_instance): remove_context_menu_plugin(scene_tree_context_menu_instance); scene_tree_context_menu_instance.queue_free(); scene_tree_context_menu_instance = null; print("%s: Scene tree context menu cleaned up." % PLUGIN_NAME)
	if is_instance_valid(gemini_dock_instance): remove_control_from_docks(gemini_dock_instance); gemini_dock_instance.queue_free(); gemini_dock_instance = null; print("%s: Dock cleaned up." % PLUGIN_NAME)
	editor_settings = null; script_editor_instance = null
	print("%s Plugin: Cleanup complete." % PLUGIN_NAME)

# --- Editor Settings Changed Signal Handler ---
func _on_editor_settings_changed():
	if is_instance_valid(gemini_dock_instance) and gemini_dock_instance.has_method("update_settings_status"): gemini_dock_instance.call_deferred("update_settings_status")
	if is_instance_valid(gemini_dock_instance) and gemini_dock_instance.has_method("_render_attachments"): gemini_dock_instance.call_deferred("_render_attachments")

# --- Helper Functions to Read Settings (ADDED explicit returns) ---
func get_api_key() -> String:
	if not is_instance_valid(editor_settings): return "" # Return default if invalid
	var key = editor_settings.get_setting(API_KEY_SETTING_PATH); return key as String if key != null else ""
func get_selected_api_model() -> String:
	if not is_instance_valid(editor_settings): return DEFAULT_MODEL # Return default if invalid
	var model = editor_settings.get_setting(API_MODEL_SETTING_PATH); return model as String if model is String and not model.is_empty() else DEFAULT_MODEL
func should_include_scene_tree() -> bool:
	if not is_instance_valid(editor_settings): return false # Return default if invalid
	var value = editor_settings.get_setting(INCLUDE_SCENE_TREE_SETTING); return value if value is bool else false
func should_include_project_tree() -> bool:
	if not is_instance_valid(editor_settings): return false # Return default if invalid
	var value = editor_settings.get_setting(INCLUDE_PROJECT_TREE_SETTING); return value if value is bool else false
func get_project_tree_max_depth() -> int:
	if not is_instance_valid(editor_settings): return 3 # Return default if invalid
	var value = editor_settings.get_setting(PROJECT_TREE_MAX_DEPTH_SETTING); return value if value is int else 3
func should_include_tree_node_details() -> bool:
	if not is_instance_valid(editor_settings): return false # Return default if invalid
	var value = editor_settings.get_setting(INCLUDE_TREE_NODE_DETAILS_SETTING); return value if value is bool else false

# --- Functions to Get Editor Context ---
func get_selected_script_text() -> String:
	var interface = get_editor_interface(); if not interface: return "[ERROR: No Interface]"
	var editor = script_editor_instance if is_instance_valid(script_editor_instance) else interface.get_script_editor(); if not editor: return "[ERROR: No ScriptEditor]"
	script_editor_instance = editor
	var base = editor.get_current_editor(); if not base: return ""
	if not base.has_method("get_base_editor"): return "[ERROR: No get_base_editor()]"
	var code_edit = base.get_base_editor(); if not code_edit: return "[ERROR: No base_editor node]"
	if not code_edit.has_method("get_selected_text"): return "[ERROR: No get_selected_text()]"
	return code_edit.get_selected_text()

func get_current_script_content() -> Dictionary:
	var result = {"text": "", "name": "Current Script"}; var interface = get_editor_interface(); if not interface: result.text = "[ERROR: No Interface]"; return result
	var editor = script_editor_instance if is_instance_valid(script_editor_instance) else interface.get_script_editor(); if not editor: result.text = "[ERROR: No ScriptEditor]"; return result
	script_editor_instance = editor
	var script = editor.get_current_script(); if not script: result.text = "[ERROR: No active script]"; return result
	if script.resource_path: result.name = script.resource_path.get_file()
	var base = editor.get_current_editor(); if not base: result.text = "[ERROR: No editor base]"; return result
	if not base.has_method("get_base_editor"): result.text = "[ERROR: No get_base_editor()]"; return result
	var code_edit = base.get_base_editor(); if not code_edit: result.text = "[ERROR: No base_editor node]"; return result
	if not code_edit.has_method("get_text"): result.text = "[ERROR: No get_text()]"; return result
	result.text = code_edit.get_text(); return result

# --- Context Menu Action Handlers (Call add_attachment) ---
func _handle_context_menu_action(): # Script Editor Menu
	print("%s: Handling script attach action..." % PLUGIN_NAME); var text = get_selected_script_text()
	if not is_instance_valid(gemini_dock_instance): printerr("%s: Dock invalid" % PLUGIN_NAME); return
	if text.begins_with("[ERROR:") and gemini_dock_instance.has_method("display_error"): gemini_dock_instance.call("display_error", "Get selection failed: %s" % text.trim_prefix("[ERROR:").strip_edges())
	elif not text.is_empty() and gemini_dock_instance.has_method("add_attachment"): gemini_dock_instance.call("add_attachment", "Script Selection", "```gdscript\n" + text + "\n```")
	elif text.is_empty() and gemini_dock_instance.has_method("display_error"): gemini_dock_instance.call("display_error", "No text selected.")
	else: printerr("%s: Dock missing required methods." % PLUGIN_NAME)

func _handle_scene_tree_context_action(node_path_string: String, action_type: String): # Scene Tree Menu
	print("%s: Scene Tree attach action '%s' for: %s" % [PLUGIN_NAME, action_type, node_path_string]); var interface = get_editor_interface(); if not interface: return
	var root = interface.get_edited_scene_root(); if not root: if is_instance_valid(gemini_dock_instance): gemini_dock_instance.call("display_error", "No active scene."); return
	var target_node = root.get_node_or_null(NodePath(node_path_string)); if not target_node: if is_instance_valid(gemini_dock_instance): gemini_dock_instance.call("display_error", "Node not found: %s" % node_path_string); return
	var context_data = ""; var context_type = "Unknown"
	match action_type:
		"send_structure": context_type = "Node Structure"; context_data = _serialize_node_structure(target_node)
		"send_properties": context_type = "Node Properties"; context_data = _serialize_node_properties(target_node)
		_: printerr("%s: Unknown action: %s" % [PLUGIN_NAME, action_type]); return
	if context_data.is_empty(): var msg = "Could not serialize %s for %s." % [context_type, target_node.name]; printerr("%s: %s" % [PLUGIN_NAME, msg]); if is_instance_valid(gemini_dock_instance): gemini_dock_instance.call("display_error", msg); return
	if is_instance_valid(gemini_dock_instance) and gemini_dock_instance.has_method("add_attachment"): gemini_dock_instance.call("add_attachment", context_type, context_data)
	else: printerr("%s: Dock invalid or missing add_attachment." % PLUGIN_NAME)

# --- Main function to initiate the Gemini API call (Includes auto context again) ---
func _request_gemini_completion(prompt: String): # Receives prompt from dock (with manual attachments)
	# --- API Key Check ---
	var api_key = get_api_key()
	if api_key.is_empty():
		printerr("%s: API Key is empty. Cannot send request." % PLUGIN_NAME)
		# Use the failure handler directly to display the error in the dock
		_on_api_request_failed("API Key not configured. Please set it in Editor Settings -> Plugins -> Gemini Assistant.")
		return # Stop execution here

	# --- Provide Immediate Feedback ---
	if is_instance_valid(gemini_dock_instance) and gemini_dock_instance.has_method("display_response"):
		# Display a working message immediately
		gemini_dock_instance.call("display_response", "[color=gray]Processing context and sending request...[/color]")
	else:
		printerr("%s: Dock instance invalid or missing display_response for status update." % PLUGIN_NAME)
		# Still proceed, but log the issue

	var final_prompt = prompt
	var context_prefix = ""

	# --- Add Automatic Context Based on Settings ---
	var include_details = should_include_tree_node_details()
	if should_include_scene_tree():
		var root = get_editor_interface().get_edited_scene_root()
		if is_instance_valid(root): var data = _serialize_node_structure(root, "", 5, include_details); if not data.is_empty(): context_prefix += "\n--- Scene Tree %s ---\n%s" % ["(Details)" if include_details else "", data]; print("%s: Auto-incl Scene%s." % [PLUGIN_NAME, " (Details)" if include_details else ""])
		else: print("%s: No scene root for auto-context." % PLUGIN_NAME)
	if should_include_project_tree():
		var depth = get_project_tree_max_depth(); var data = _serialize_project_tree("res://", "", depth, include_details)
		if not data.is_empty(): context_prefix += "\n--- Project Tree (Depth:%d)%s ---\n%s" % [depth, " (Details)" if include_details else "", data]; print("%s: Auto-incl Project (Depth:%d)%s." % [PLUGIN_NAME, depth, " (Details)" if include_details else ""])
		else: print("%s: Failed serializing project tree." % PLUGIN_NAME)
	if not context_prefix.is_empty(): final_prompt = context_prefix + "\n\n--- Prompt / Manual Attachments ---\n" + prompt; print("%s: Prepended auto context." % PLUGIN_NAME)

	# --- Prepare and Send Request ---
	print("%s: Preparing API req (Final Len:%d)" % [PLUGIN_NAME, final_prompt.length()])
	var model = get_selected_api_model()
	var handler = APIHandlerScript.new()
	if not handler:
		printerr("%s: Failed to create APIHandler instance." % PLUGIN_NAME)
		_on_api_request_failed("Internal Error: Failed to create API request handler.")
		return

	add_child(handler) # Add handler as child to process signals
	# Connect signals with CONNECT_ONE_SHOT so they automatically disconnect after firing
	handler.request_succeeded.connect(_on_api_request_succeeded, CONNECT_ONE_SHOT)
	handler.request_failed.connect(_on_api_request_failed, CONNECT_ONE_SHOT)

	# Now send the request
	handler.send_request(api_key, model, final_prompt)

# --- Handlers for APIHandler Signals ---
func _on_api_request_succeeded(response_text: String):
	print("%s: API request succeeded." % PLUGIN_NAME)
	if not is_instance_valid(gemini_dock_instance):
		printerr("%s: Dock instance became invalid before displaying response." % PLUGIN_NAME)
		return # Cannot display response

	if gemini_dock_instance.has_method("display_response"):
		gemini_dock_instance.call("display_response", response_text)
	else:
		# This case should ideally not happen if the dock was valid earlier
		printerr("%s: Dock instance valid but missing display_response method." % PLUGIN_NAME)
		# As a fallback, maybe disable the send button again?
		if gemini_dock_instance.has_method("_set_send_buttons_disabled"):
			gemini_dock_instance.call("_set_send_buttons_disabled", false)

func _on_api_request_failed(error_message: String):
	# This function now handles both API errors AND pre-flight errors like missing API key
	printerr("%s: API request FAILED: %s" % [PLUGIN_NAME, error_message])
	if not is_instance_valid(gemini_dock_instance):
		printerr("%s: Dock instance became invalid before displaying error." % PLUGIN_NAME)
		return # Cannot display error

	if gemini_dock_instance.has_method("display_error"):
		gemini_dock_instance.call("display_error", error_message)
	else:
		printerr("%s: Dock instance valid but missing display_error method." % PLUGIN_NAME)

	# Always ensure buttons are re-enabled after a failure message is processed
	if gemini_dock_instance.has_method("_set_send_buttons_disabled"):
		gemini_dock_instance.call("_set_send_buttons_disabled", false)

# --- Serialization Functions ---
func _serialize_node_structure(node: Node, indent: String = "", max_depth: int = 5, include_details: bool = false) -> String:
	if not is_instance_valid(node) or max_depth <= 0: return ""
	var node_info = node.name + " (" + node.get_class() + ")"; if include_details: var props_str = _serialize_node_properties(node, indent + "\t\t", 50).replace("--- Properties for %s (%s) ---\n" % [node.name, node.get_class()], "").strip_edges(); if not props_str.is_empty(): node_info += "\n" + indent + "\t[Details]\n" + props_str
	var result = indent + node_info + "\n"; for child in node.get_children(): result += _serialize_node_structure(child, indent + "\t", max_depth - 1, include_details)
	return result
	
func _serialize_node_properties(node: Node, indent: String = "\t", max_value_length: int = 100) -> String:
	if not is_instance_valid(node): return ""
	var result = "--- Properties for %s (%s) ---\n" % [node.name, node.get_class()]; var props = node.get_property_list()
	for prop in props:
		if prop.usage & PROPERTY_USAGE_CATEGORY or prop.usage & PROPERTY_USAGE_GROUP: continue
		if prop.name.begins_with("_") or prop.name == "script" or prop.name == "resource_name" or prop.name == "resource_path" or prop.name == "resource_local_to_scene": continue
		var value = node.get(prop.name); var value_str = ""; var value_type = typeof(value)
		match value_type:
			TYPE_NIL: value_str = "null"
			TYPE_BOOL, TYPE_INT, TYPE_FLOAT: value_str = str(value)
			TYPE_STRING, TYPE_STRING_NAME: value_str = "\"%s\"" % str(value)
			TYPE_VECTOR2: value_str = "Vector2(%.2f, %.2f)" % [value.x, value.y]; 
			TYPE_VECTOR2I: value_str = "Vector2i(%d, %d)" % [value.x, value.y]
			TYPE_VECTOR3: value_str = "Vector3(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]; 
			TYPE_VECTOR3I: value_str = "Vector3i(%d, %d, %d)" % [value.x, value.y, value.z]
			TYPE_RECT2: value_str = "Rect2(%.1f,%.1f %.1f,%.1f)" % [value.position.x, value.position.y, value.size.x, value.size.y]; 
			TYPE_RECT2I: value_str = "Rect2i(%d,%d %d,%d)" % [value.position.x, value.position.y, value.size.x, value.size.y]
			TYPE_COLOR: value_str = value.to_html(value.a < 1.0); 
			TYPE_NODE_PATH: value_str = "NodePath(\"%s\")" % value
			TYPE_RID, TYPE_SIGNAL, TYPE_CALLABLE, TYPE_PLANE, TYPE_QUATERNION, TYPE_AABB, TYPE_BASIS, TYPE_TRANSFORM2D, TYPE_TRANSFORM3D, TYPE_PROJECTION: value_str = "[%s]" % type_string(value_type).capitalize()
			TYPE_OBJECT:
				if value == null: value_str = "null"
				elif not is_instance_valid(value): value_str = "[FreedInstance?]"
				elif value is Resource: value_str = "Resource(%s)" % value.resource_path.get_file() if value.resource_path else "[Built-In:%s]"%value.get_class()
				elif value is Node: value_str = "[Node:%s]" % value.get_path_to(node)
				else: value_str = "[Object:%s]" % value.get_class()
			TYPE_DICTIONARY: value_str = "[Dict size:%d]" % value.size()
			TYPE_ARRAY: value_str = "[Array size:%d]" % value.size()
			_: value_str = str(value)
		var trunc_val = value_str.left(max_value_length) + ("..." if value_str.length() > max_value_length else "")
		result += "%s%s: %s\n" % [indent, prop.name, trunc_val]
	return result
	
func _serialize_project_tree(dir_path: String = "res://", indent: String = "", max_depth: int = 3, _include_details: bool = false) -> String:
	if max_depth <= 0: return ""
	var result = ""; var dir_access = DirAccess.open(dir_path)
	if not DirAccess.dir_exists_absolute(dir_path): printerr("Proj tree: Dir not found - %s" % dir_path); return indent + "[ERROR: Dir not found]\n"
	if not dir_access: printerr("Proj tree: Cannot access dir - %s" % dir_path); return indent + "[ERROR: Cannot access dir]\n"
	dir_access.list_dir_begin(); var item = dir_access.get_next()
	while item != "":
		if item == "." or item == ".." or item.begins_with("."): item = dir_access.get_next(); continue
		var full_path = dir_path.path_join(item)
		if dir_access.current_is_dir(): result += indent + item + "/" + "\n"; result += _serialize_project_tree(full_path, indent + "\t", max_depth - 1, _include_details)
		else:
			if not (item.ends_with(".import") or item.ends_with(".mesh") or item.ends_with(".material") or item.ends_with(".png") or item.ends_with(".jpg") or item.ends_with(".tres") or item.ends_with(".tscn")): result += indent + item + "\n"
		item = dir_access.get_next()
	dir_access.list_dir_end()
	return result
