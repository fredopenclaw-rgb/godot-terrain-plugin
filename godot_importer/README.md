# Godot Terrain Plugin

This folder contains the Terrain Importer logic for the latest Godot engine versions (4.x+). 

## Proper Plugin Architecture & Orchestration

In Godot Engine, editor extensions should be structured as **EditorPlugins**. Currently, the workflow was structured using `EditorScript`, which requires a user to manually open the Script editor and click `File > Run`. EditorPlugins are a far more robust, proper orchestration method.

### Structure of a Godot Plugin
A proper plugin lives in a directory inside `res://addons/` (e.g., `res://addons/godot_terrain_plugin/`). It requires two main components:

1. **`plugin.cfg`**: The configuration manifest. This tells Godot that the folder contains a plugin, what its name is, and which script to run upon activation.
   ```ini
   [plugin]
   name="Terrain Importer"
   description="Imports chunked terrain from Blender."
   author="Your Name"
   version="1.0"
   script="plugin.gd"
   ```

2. **`plugin.gd` (EditorPlugin)**: The initializer script that extends `EditorPlugin`. This script orchestrates adding UI buttons to the editor (e.g., adding a menu item in `Project > Tools`), registering custom node types, or managing dock panels.

### Separation of Concerns (Editor vs. Runtime)
A plugin should always separate editor tooling logic from runtime logic:
- **Editor Tooling (`import_plugin.gd` / `EditorPlugin`)**: Handles reading the `terrain_metadata.json`, generating the `MeshInstance3D` nodes, baking `NavigationRegion3D`, and creating static collision bodies inside the editor viewport.
- **Runtime Logic (`terrain_manager.gd`)**: A node attached to the scene that runs during the game (`_process` or `_physics_process`). It handles dynamic chunk loading/unloading based on the player's distance to chunks.

### Orchestration & Development Workflow
1. Move the `godot_importer` contents into `res://addons/terrain_importer/` inside your Godot project.
2. Ensure you have `plugin.cfg` and your `EditorPlugin` script initialized.
3. Go to **Project > Project Settings > Plugins** in Godot and enable the "Terrain Importer" plugin.
4. Use the newly added standard toolbar button or Tools menu item to execute the batch import script.
5. Add the `TerrainManager` node to your active scene tree and pass it a reference to your Player to begin runtime chunk streaming.
