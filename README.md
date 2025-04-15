# Gemini Assistant - Godot Editor Plugin

**Version:** 0.1 
**Author:** Austin Peck
**Godot Version:** 4.2+
**License:** MIT

## Description

Integrates Google's Gemini AI models directly into the Godot editor interface. This plugin provides a dock panel allowing you to send prompts, attach context from your project (scripts, scene nodes, project files), and receive AI-generated responses, assisting with coding, debugging, content generation, and more.

Disclaimer: Gemini 2.5 was heavily leveraged in the creation of this tool, AI generated code is present inside of the scripts.

## Features

*   **Editor Dock:** Dedicated panel for interacting with the Gemini API.
*   **Prompt Input:** Send text prompts directly to the selected Gemini model.
*   **Context Attachments:**
	*   **Manual:** Attach the currently selected text in the script editor.
	*   **Manual:** Attach the entire content of the currently open script.
	*   **Manual (Scene Tree):** Attach the structure or properties of selected nodes via the Scene Tree context menu.
	*   **Automatic (Optional):** Automatically include the current scene tree structure.
	*   **Automatic (Optional):** Automatically include the project file structure (use with caution - large context!).
	*   **Automatic Details (Optional):** Include node properties within automatic tree context (increases context size).
*   **Response Display:** View formatted AI responses, including basic Markdown (bold, italics, code blocks).
*   **Configuration:** Set your API Key and choose the Gemini model via Editor Settings.
*   **Convenience:** Copy responses, clear outputs/attachments.

## Installation

1.  **Asset Library:**
	*   Open the Godot Editor.
	*   Navigate to the `AssetLib` tab.
	*   Search for "Gemini Assistant".
	*   Click `Download`, then `Install`.
	*   Enable the plugin in `Project -> Project Settings -> Plugins`.
2.  **Manual:**
	*   Download the plugin repository (e.g., from GitHub Releases).
	*   Extract the downloaded archive.
	*   Copy the `addons/gemini_godot` folder into your Godot project's `addons/` directory.
	*   Enable the plugin in `Project -> Project Settings -> Plugins`.

## Setup: API Key (Required!)

1.  **Get a Gemini API Key:** You need an API key from Google AI Studio. Visit [https://aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey) (or Google Cloud Console for Vertex AI) to create one. Note that API usage may incur costs based on Google's pricing.
2.  **Configure in Godot:**
	*   Open your Godot project.
	*   Go to `Editor -> Editor Settings`.
	*   In the left panel, navigate to `Plugins -> Gemini Assistant`.
	*   Paste your API key into the `Api Key` field. **The plugin will not work without a valid key.**

## Usage

1.  **Open the Dock:** Once the plugin is enabled, the "Gemini Assistant" dock should appear (by default, often on the bottom left panel). If not visible, go to `Editor -> Editor Docks -> Gemini Assistant`.
2.  **Enter Prompt:** Type your query or request into the "Prompt Input" text area.
3.  **(Optional) Add Context:**
	*   **Selection:** Select text in the Script Editor, then click "Attach Selection".
	*   **Script:** Open a script, then click "Attach Script".
	*   **Scene Node:** Right-click a node in the Scene Tree dock and choose "Gemini: Attach Node Structure" or "Gemini: Attach Node Properties".
	*   **Automatic:** Configure automatic context inclusion in `Editor -> Editor Settings -> Plugins -> Gemini Assistant`. Enabled settings will show as non-removable attachments.
4.  **Send:** Click the "Send" button.
5.  **View Response:** The AI's response will appear in the "Response Output" area.
6.  **Manage:**
	*   Use "Copy Output" to copy the response text.
	*   Use "Clear" to remove the response and all *manual* attachments.
	*   Click the 'X' button on manual attachments to remove them individually.
	*   Click the 'i' button (or delete icon acting as info) on automatic attachments for an explanation.
	*   Use "Open Settings" to quickly jump to the plugin's configuration in Editor Settings.

## Configuration Settings

Found under `Editor -> Editor Settings -> Plugins -> Gemini Assistant`:

*   **Api Key:** (Required) Your Google Gemini API Key.
*   **Api Model:** Select the Gemini model to use (e.g., `gemini-1.5-flash-latest`). Different models have varying capabilities and costs. Note: Only models that supper text input and output have been tested. https://ai.google.dev/gemini-api/docs/models
*   **Include Scene Tree On Select:** Automatically attach the current scene structure.
*   **Include Project Tree On Select:** Automatically attach the project file structure (WARNING: Can be very large!).
*   **Project Tree Max Depth:** Limits how deep the project tree scan goes.
*   **Include Tree Node Details:** Include node properties in automatic scene/project context (increases size).

## Troubleshooting

*   **Error: "API Key not configured..."**: Make sure you've added your Gemini API Key in Editor Settings (see Setup).
*   **Error: Request Failed / Network Error**: Check your internet connection. Ensure your API key is valid and has the necessary permissions/billing enabled on the Google Cloud side. Check the Godot console (Output panel) for more detailed error messages from the `APIHandler`.
*   **Context Menu Missing:** Ensure the plugin is enabled. Ensure you are right-clicking in the correct context (script editor code area, scene tree item).
*   **Slow Response:** Large context attachments (especially automatic project tree) can significantly increase processing time and API costs.


## License

This plugin is released under the MIT License. See the LICENSE file for details.
