# addons/gemini_godot/ui/attachment_display.gd
@tool
extends PanelContainer

# Signal emitted when the delete button is pressed for a MANUAL attachment
signal delete_requested(attachment_node: PanelContainer)
# Signal emitted when the delete button is pressed for a SETTING attachment
signal setting_info_requested(attachment_node: PanelContainer)

@onready var name_label: Label = %NameLabel
@onready var delete_button: Button = %DeleteButton
@onready var content_snippet_label: RichTextLabel = %ContentSnippetLabel

# Data associated with this attachment
var attachment_data : Dictionary = {}
# NEW: Store the source ("manual", "setting_scene", "setting_project", "setting_details")
var source : String = "manual"

const MAX_SNIPPET_LINES = 5
const MAX_SNIPPET_CHARS = 100

func _ready():
	if not is_instance_valid(name_label): printerr("AttachmentDisplay: NameLabel not found.")
	if not is_instance_valid(delete_button): printerr("AttachmentDisplay: DeleteButton not found.")
	else: delete_button.pressed.connect(_on_delete_button_pressed)
	if not is_instance_valid(content_snippet_label): printerr("AttachmentDisplay: ContentSnippetLabel not found.")


# MODIFIED: Accept and store source
func set_data(data: Dictionary, p_source: String = "manual"):
	attachment_data = data
	source = p_source # Store the source

	var type_str : String = str(attachment_data.get("type", "Unknown")).capitalize().replace("_", " ")
	var data_str : String = str(attachment_data.get("data", "")) # Data might be just "Enabled" for settings
	var snippet : String = ""
	var display_name : String = type_str

	# Prefix name for settings
	if source.begins_with("setting_"):
		display_name = "[Setting] " + type_str
		# Use placeholder text for setting snippet
		snippet = "[i]Controlled via Editor Settings.[/i]"
		# Disable delete button visually? Or change icon? Let's keep it for info for now.
		# if is_instance_valid(delete_button): delete_button.icon = load("res://addons/gemini_godot/icons/info_icon.svg") # Example icon
	else: # Manual attachment snippet generation
		# Determine Display Name
		if type_str.ends_with(".gd"): display_name = type_str
		elif type_str == "Script Selection": display_name = "Script Selection"

		# Generate Snippet
		var is_code = type_str.contains("Script") or type_str.ends_with(".gd")
		if is_code:
			var lines = data_str.split("\n"); var line_count = 0
			for line in lines:
				if line_count >= MAX_SNIPPET_LINES: snippet += "..."; break
				snippet += line + "\n"; line_count += 1
			if not snippet.ends_with("..."): snippet = snippet.substr(0, snippet.length() - 1)
			snippet = "[code]%s[/code]" % snippet
		elif type_str == "Node Properties" or type_str == "Node Structure":
			# Assume properties/structure are already formatted reasonably
			var lines = data_str.split("\n"); var line_count = 0
			for line in lines:
				if line_count >= MAX_SNIPPET_LINES: snippet += "..."; break
				# Don't add extra newline if line already ends with one
				snippet += line + ("" if line.ends_with("\n") else "\n"); line_count += 1
			if not snippet.ends_with("..."): snippet = snippet.substr(0, snippet.length() - 1)
		else: # Generic snippet
			snippet = data_str.left(MAX_SNIPPET_CHARS) + ("..." if data_str.length() > MAX_SNIPPET_CHARS else "")

	# Set UI elements
	if is_instance_valid(name_label):
		name_label.text = display_name
		if display_name != type_str and not source.begins_with("setting_"): name_label.tooltip_text = "Type: %s" % type_str
		elif source.begins_with("setting_"): name_label.tooltip_text = "This is controlled by an Editor Setting."
		else: name_label.tooltip_text = ""

	if is_instance_valid(content_snippet_label):
		content_snippet_label.text = snippet
		# Only show full data tooltip for manual attachments
		if source == "manual": content_snippet_label.tooltip_text = "Full Data:\n----\n%s" % data_str
		else: content_snippet_label.tooltip_text = ""


# MODIFIED: Emit different signal based on source
func _on_delete_button_pressed():
	if source == "manual":
		emit_signal("delete_requested", self)
	else: # It's a setting
		emit_signal("setting_info_requested", self)
