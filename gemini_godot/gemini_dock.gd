# addons/gemini_godot/gemini_dock.gd
@tool
extends PanelContainer

const AttachmentDisplayScene = preload("res://addons/gemini_godot/ui/attachment_display.tscn")

@onready var prompt_input: TextEdit = $VBoxContainer/PromptInput
@onready var attachment_container: VBoxContainer = $VBoxContainer/ScrollContainer/AttachmentContainer
@onready var send_button: Button = $VBoxContainer/ButtonBox/SendButton
@onready var attach_selection_button: Button = $VBoxContainer/ButtonBox/AttachSelectionButton
@onready var attach_script_button: Button = $VBoxContainer/ButtonBox/AttachScriptButton
@onready var status_button: Button = $VBoxContainer/ButtonBox2/StatusButton
@onready var clear_button: Button = $VBoxContainer/ButtonBox2/ClearButton
@onready var settings_status_label: Label = $VBoxContainer/StatusBox/SettingsStatusLabel
@onready var open_settings_button: Button = $VBoxContainer/StatusBox/OpenSettingsButton
@onready var response_output: RichTextLabel = $VBoxContainer/ResponseOutput
@onready var info_dialog: AcceptDialog = AcceptDialog.new()

var main_plugin_instance = null
const STATUS_BUTTON_DEFAULT_TEXT = "Copy Output"
const STATUS_BUTTON_COPIED_TEXT = "Copied!"
var attachments: Array = []

func _ready():
	_connect_button_signal(send_button, "_on_send_button_pressed")
	_connect_button_signal(attach_selection_button, "_on_attach_selection_button_pressed")
	_connect_button_signal(attach_script_button, "_on_attach_script_button_pressed")
	_connect_button_signal(status_button, "_on_status_button_pressed")
	_connect_button_signal(clear_button, "_on_clear_button_pressed")
	_connect_button_signal(open_settings_button, "_on_open_settings_pressed")

	add_child(info_dialog); info_dialog.title = "Attachment Info"
	info_dialog.dialog_text = "This represents an Editor Setting.\nTo change it, go to:\nEditor -> Editor Settings -> Plugins -> Gemini Assistant"
	info_dialog.dialog_hide_on_ok = true

	if not is_instance_valid(main_plugin_instance): if is_instance_valid(settings_status_label): settings_status_label.text = "Error: Plugin link failed."

	if is_instance_valid(status_button): status_button.focus_mode = Control.FOCUS_NONE; status_button.text = STATUS_BUTTON_DEFAULT_TEXT
	if is_instance_valid(attach_selection_button): attach_selection_button.text = "Attach Selection"
	if is_instance_valid(attach_script_button): attach_script_button.text = "Attach Script"

	if is_instance_valid(response_output):
		response_output.selection_enabled = true
		# Check if text is empty on a separate line
		if response_output.text.is_empty():
			response_output.text = "Welcome!"

	_set_send_buttons_disabled(false)
	call_deferred("_render_attachments")

# --- Helper to connect signals safely ---
func _connect_button_signal(button_node: Button, method_name: String):
	if not is_instance_valid(button_node): var name = method_name.trim_prefix("_on_").trim_suffix("_pressed"); printerr("GeminiDock: Node '%s_button' invalid." % name); return
	var callable = Callable(self, method_name); if not button_node.is_connected("pressed", callable): var err = button_node.pressed.connect(callable); if err != OK: printerr("GeminiDock: Failed connect '%s': %s" % [button_node.name, err])

# --- Signal Handlers ---
func _on_send_button_pressed():
	if not is_instance_valid(prompt_input): printerr("GeminiDock: PromptInput invalid."); return
	var prompt_text = prompt_input.text.strip_edges()
	if prompt_text.is_empty() and attachments.is_empty(): display_error("Please enter a prompt or attach some context."); return
	_set_send_buttons_disabled(true)
	display_response("[color=gray]Processing and sending prompt with attachments...[/color]")
	var final_prompt = prompt_text; var manual_attachments_text = ""
	if not attachments.is_empty():
		manual_attachments_text += "\n\n--- Attached Context (Manual) ---\n"
		for attachment in attachments: manual_attachments_text += "\n-- Attachment: %s --\n%s\n" % [str(attachment.get("type", "?")).capitalize().replace("_", " "), attachment.get("data", "")]
	final_prompt += manual_attachments_text
	if main_plugin_instance and main_plugin_instance.has_method("_request_gemini_completion"): main_plugin_instance.call("_request_gemini_completion", final_prompt)
	else: printerr("GeminiDock: Main plugin invalid/missing method!"); display_error("Cannot send request."); _set_send_buttons_disabled(false)

func _on_attach_selection_button_pressed():
	var code = ""
	if main_plugin_instance and main_plugin_instance.has_method("get_selected_script_text"): code = main_plugin_instance.call("get_selected_script_text")
	else: display_error("Plugin link error."); return
	if code.begins_with("[ERROR:") or code.is_empty(): display_error("No code selected or error getting selection."); return
	add_attachment("Script Selection", code); print("GeminiDock: Attached selection.")

func _on_attach_script_button_pressed():
	var info = {"text":"", "name":"Error"}
	if main_plugin_instance and main_plugin_instance.has_method("get_current_script_content"): info = main_plugin_instance.call("get_current_script_content")
	else: display_error("Plugin link error."); return
	if info.text.begins_with("[ERROR:") or info.text.is_empty(): display_error("No active script or error getting content."); return
	add_attachment(info.name, info.text); print("GeminiDock: Attached script '%s'." % info.name)

func _on_status_button_pressed():
	if not is_instance_valid(response_output) or not is_instance_valid(status_button): return
	if not response_output.text.is_empty(): DisplayServer.clipboard_set(response_output.text); print("GeminiDock: Copied output."); status_button.text = STATUS_BUTTON_COPIED_TEXT; get_tree().create_timer(1.5, false).connect("timeout", func(): if is_instance_valid(status_button): status_button.text = STATUS_BUTTON_DEFAULT_TEXT)
	else: print("GeminiDock: No output to copy.")

func _on_clear_button_pressed():
	var cleared = false
	if is_instance_valid(response_output) and not response_output.text.is_empty(): response_output.clear(); print("GeminiDock: Output cleared."); cleared = true
	if not attachments.is_empty(): attachments.clear(); _render_attachments(); print("GeminiDock: Attachments cleared."); cleared = true
	if not cleared: print("GeminiDock: Nothing to clear.")

func _on_open_settings_pressed():
	print("GeminiDock: Opening Editor Settings..."); if not is_instance_valid(main_plugin_instance): display_error("Plugin link error."); return
	var interface = main_plugin_instance.get_editor_interface(); if not interface: display_error("Editor interface error."); return
	var settings = interface.get_editor_settings(); if settings: interface.inspect_object(settings); print("GeminiDock: Inspector focused. Filter: plugins/gemini_godot."); if is_instance_valid(settings_status_label): var text = settings_status_label.text; settings_status_label.text = "Settings shown..."; get_tree().create_timer(3.5, false).connect("timeout", func(): if is_instance_valid(settings_status_label) and settings_status_label.text == "Settings shown...": settings_status_label.text = text , CONNECT_ONE_SHOT)
	else: display_error("Settings object error.")

# --- Public Functions ---
func display_response(text: String):
	if not is_instance_valid(response_output): printerr("GeminiDock: ResponseOutput invalid."); return
	response_output.text = _format_response_text(text); _set_send_buttons_disabled(false)
func display_error(error_text: String):
	if not is_instance_valid(response_output): printerr("GeminiDock: ResponseOutput invalid."); return
	response_output.text = "[color=red]Error:[/color] %s" % error_text; _set_send_buttons_disabled(false)

# --- Update Status Label ---
func update_settings_status():
	if not is_instance_valid(settings_status_label): return
	if not is_instance_valid(main_plugin_instance) or not main_plugin_instance.has_method("get_selected_api_model"): settings_status_label.text = "Error"; return
	var model = main_plugin_instance.get_selected_api_model(); var display_model = model.replace("-latest", "").replace("-preview-", "-prev-")
	var context_flags = ""
	if main_plugin_instance.has_method("should_include_scene_tree") and main_plugin_instance.should_include_scene_tree(): context_flags += "S"
	if main_plugin_instance.has_method("should_include_project_tree") and main_plugin_instance.should_include_project_tree(): context_flags += "P"
	if main_plugin_instance.has_method("should_include_tree_node_details") and main_plugin_instance.should_include_tree_node_details(): context_flags += "D"
	if not context_flags.is_empty(): context_flags = " [%s]" % context_flags
	settings_status_label.text = "Model: %s%s" % [display_model, context_flags]
	settings_status_label.tooltip_text = "Model: %s\nAuto Scene: %s\nAuto Project: %s\nDetails: %s" % [model, "Y" if "S" in context_flags else "N", "Y" if "P" in context_flags else "N", "Y" if "D" in context_flags else "N"]

# --- Attachment Handling ---
func add_attachment(type: String, data: String):
	if data.is_empty(): printerr("GeminiDock: Ignoring empty attachment."); return
	attachments.append({"type": type, "data": data}); _render_attachments(); print("GeminiDock: Added attachment '%s'" % type)

func _render_attachments():
	if not is_instance_valid(attachment_container): printerr("GeminiDock: AttachmentContainer invalid."); return
	for child in attachment_container.get_children(): child.queue_free()
	if is_instance_valid(main_plugin_instance):
		if main_plugin_instance.has_method("should_include_scene_tree") and main_plugin_instance.should_include_scene_tree(): _add_attachment_node({"type": "Scene Tree", "data": "Enabled (Auto)"}, "setting_scene")
		if main_plugin_instance.has_method("should_include_project_tree") and main_plugin_instance.should_include_project_tree(): _add_attachment_node({"type": "Project Tree", "data": "Enabled (Auto)"}, "setting_project")
		if main_plugin_instance.has_method("should_include_tree_node_details") and main_plugin_instance.should_include_tree_node_details(): _add_attachment_node({"type": "Node Details", "data": "Enabled (Auto)"}, "setting_details")
	for i in range(attachments.size()): _add_attachment_node(attachments[i], "manual", i)

func _add_attachment_node(attachment_data: Dictionary, source: String, index: int = -1):
	if AttachmentDisplayScene:
		var node = AttachmentDisplayScene.instantiate()
		attachment_container.add_child(node)
		if node.has_method("set_data"): node.set_data(attachment_data, source)
		else: printerr("GeminiDock: AttachmentDisplay missing set_data.")
		if source == "manual":
			if node.has_signal("delete_requested"): node.delete_requested.connect(_on_attachment_delete_pressed.bind(index))
			else: printerr("GeminiDock: AttachmentDisplay missing delete_requested signal.")
		else:
			if node.has_signal("setting_info_requested"): node.setting_info_requested.connect(_on_attachment_setting_info_pressed.bind(attachment_data))
			else: printerr("GeminiDock: AttachmentDisplay missing setting_info_requested signal.")
	else: printerr("GeminiDock: AttachmentDisplayScene not loaded."); var label = Label.new(); label.text = "[Fallback] %s (%s)" % [attachment_data.get("type","?"), source]; attachment_container.add_child(label)

func _on_attachment_delete_pressed(_attachment_node, index: int): # Only for manual attachments
	if index >= 0 and index < attachments.size():
		print("GeminiDock: Removing manual attachment at index %d" % index)
		attachments.remove_at(index)
		_render_attachments()
	else:
		printerr("GeminiDock: Invalid index %d for manual attachment deletion." % index)

func _on_attachment_setting_info_pressed(_attachment_node, attachment_data: Dictionary):
	var setting_name = attachment_data.get("type", "Unknown")
	print("GeminiDock: Info requested for setting attachment: %s" % setting_name)
	# Show the pre-configured info dialog
	var info_text = "This represents the '%s' setting, which is currently enabled.\n\n" % setting_name
	info_text += "To disable this automatic context, go to:\n"
	info_text += "Editor -> Editor Settings -> Plugins -> Gemini Assistant\n"
	info_text += "and uncheck the corresponding setting."
	if is_instance_valid(info_dialog):
		info_dialog.dialog_text = info_text
		info_dialog.popup_centered()
	else:
		# Fallback if dialog failed
		display_error("Info: '%s' is enabled in Editor Settings -> Plugins -> Gemini Assistant." % setting_name)


# --- Formatting Helper ---
func _format_response_text(raw_text: String) -> String:
	var text = raw_text; var re = RegEx.new()
	re.compile("(?s)```(?:\\w+)?\\n?(.*?)```"); text = re.sub(text, "[code]$1[/code]", true)
	re.compile("\\*\\*((?!\\*\\*).+?)\\*\\*"); text = re.sub(text, "[b]$1[/b]", true)
	re.compile("(?<!\\w)_(?!_)(.+?)(?<!_)_(?!\\w)"); text = re.sub(text, "[i]$1[/i]", true)
	re.compile("(?<!\\*)\\*((?!\\*).+?)(?<!\\*)\\*(?!\\*)"); text = re.sub(text, "[i]$1[/i]", true)
	re.compile("`(.+?)`"); text = re.sub(text, "[code]$1[/code]", true)
	return text

# --- Helper function to manage SEND button states ---
func _set_send_buttons_disabled(disabled_state: bool):
	if is_instance_valid(send_button): send_button.disabled = disabled_state
