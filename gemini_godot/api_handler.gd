# addons/gemini_godot/api_handler.gd
@tool
extends Node # Inherit from Node to handle HTTPRequest easily

# Signals to communicate results back to the main plugin
signal request_succeeded(response_text: String)
signal request_failed(error_message: String)

const PLUGIN_NAME = "Gemini Assistant" # For logging consistency

var http_request: HTTPRequest = null

# Called when the node is removed from the tree (important for cleanup)
func _exit_tree():
	# Ensure the HTTPRequest node is freed if the handler is freed mid-request
	if is_instance_valid(http_request):
		# Disconnect signals maybe? Might not be needed if node is freeing.
		if http_request.is_connected("request_completed", _on_request_completed):
			http_request.request_completed.disconnect(_on_request_completed)
		http_request.queue_free()
		http_request = null
		print("%s APIHandler: Cleaned up HTTPRequest node on exit." % PLUGIN_NAME)


# Main function called by the plugin to initiate a request
func send_request(api_key: String, model_name: String, prompt: String):
	# If a request is already in progress, cancel it or return an error?
	# For now, let's assume only one request at a time. We could add checks later.
	if is_instance_valid(http_request):
		printerr("%s APIHandler: Request already in progress. Aborting new request." % PLUGIN_NAME)
		emit_signal("request_failed", "Another request is already in progress.")
		# Consider calling queue_free() on self here? Or maybe let the caller handle it.
		return

	# --- Determine API Version ---
	var api_version_path = "v1beta" # Default to v1beta
	# No need for v1 check currently, as gemini-pro isn't supported
	# if model_name == "gemini-pro": api_version_path = "v1"

	# --- Construct URL ---
	var api_url = "https://generativelanguage.googleapis.com/%s/models/%s:generateContent?key=%s" % [api_version_path, model_name, api_key]

	# --- Prepare Request ---
	http_request = HTTPRequest.new()
	# Add as a child of this handler node so it processes correctly
	add_child(http_request)
	# Connect the signal to our internal handler
	# Bind the node itself so we can free it in the callback
	http_request.request_completed.connect(self._on_request_completed.bind(http_request))

	var headers = [ "Content-Type: application/json" ]
	var payload = { "contents": [{ "parts": [{"text": prompt}] }] }
	var body = JSON.stringify(payload)

	print("%s APIHandler: Sending POST to %s..." % [PLUGIN_NAME, api_url.left(api_url.find("?"))]) # Log without key
	var error = http_request.request(api_url, headers, HTTPClient.METHOD_POST, body)

	if error != OK:
		printerr("%s APIHandler: HTTPRequest initiation failed: %s" % [PLUGIN_NAME, error])
		var error_msg = "HTTPRequest failed (Error %s). Check Godot console." % error
		emit_signal("request_failed", error_msg)
		# Clean up immediately if request() failed
		if is_instance_valid(http_request): http_request.queue_free()
		http_request = null
		queue_free() # Free the handler itself if the request fails to start


# Internal handler for the HTTPRequest signal
func _on_request_completed(result, response_code, _headers, body : PackedByteArray, req_node : HTTPRequest):
	# Basic check if the request node is still valid (should be)
	if not is_instance_valid(req_node):
		printerr("%s APIHandler: HTTPRequest node became invalid during completion." % PLUGIN_NAME)
		emit_signal("request_failed", "Internal error: HTTPRequest node lost.")
		queue_free() # Free the handler
		return

	print("%s APIHandler: Request completed. Result: %d, Code: %d" % [PLUGIN_NAME, result, response_code])

	var response_text = ""
	var is_error = true

	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		var response_body_string = body.get_string_from_utf8()
		var parse_result = JSON.parse_string(response_body_string)
		if parse_result == null:
			response_text = "Error: Could not parse JSON response from API."
			printerr("%s APIHandler: Failed JSON parse. Body:\n%s" % [PLUGIN_NAME, response_body_string])
		else:
			var response_json = parse_result
			# Simplified parsing logic (same as before)
			if response_json.has("candidates") and response_json.candidates is Array and not response_json.candidates.is_empty():
				var candidate = response_json.candidates[0]
				if candidate.has("content") and candidate.content.has("parts") and candidate.content.parts is Array and not candidate.content.parts.is_empty() and candidate.content.parts[0].has("text"):
					response_text = candidate.content.parts[0].text
					is_error = false # Success!
				else:
					var reason = candidate.get("finishReason", "UNKNOWN")
					response_text = "API Warning: Request finished reason '%s'. Check response details." % reason
					if candidate.has("safetyRatings"): response_text += " (Safety Filter Triggered)"
					printerr("%s APIHandler: Finish Reason '%s'. Body:\n%s" % [PLUGIN_NAME, reason, response_body_string])
					# Treat non-STOP finish reasons as errors for simplicity now
			elif response_json.has("promptFeedback"):
				var feedback = response_json.promptFeedback
				var reason = feedback.get("blockReason", "Unknown Reason")
				response_text = "API Error: Prompt blocked due to %s." % reason
				printerr("%s APIHandler: Prompt blocked. Reason: %s" % [PLUGIN_NAME, reason])
			else:
				response_text = "Error: Unexpected API JSON structure."
				printerr("%s APIHandler: Unexpected JSON. Body:\n%s" % [PLUGIN_NAME, response_body_string])
	else:
		# Handle HTTP/Connection errors
		var error_body_string = body.get_string_from_utf8()
		response_text = "Error: Request Failed. Code: %d, Result: %d." % [response_code, result]
		printerr("%s APIHandler: Request Failed. Code: %d, Result: %d. Body:\n%s" % [PLUGIN_NAME, response_code, result, error_body_string])
		var error_json = JSON.parse_string(error_body_string)
		if error_json and error_json.has("error") and error_json.error.has("message"):
			response_text += " API Error: %s" % error_json.error.message

	# Emit the appropriate signal
	if is_error:
		emit_signal("request_failed", response_text)
	else:
		emit_signal("request_succeeded", response_text)

	# Clean up the HTTPRequest node reference AFTER processing
	http_request = null
	# Automatically free this APIHandler instance after it finishes its job
	queue_free()
