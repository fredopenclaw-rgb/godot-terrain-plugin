# Terrain Exporter Add-on for Blender

This folder contains the source code for the "Terrain Exporter Add-on".

## Proper Plugin Architecture & Orchestration

For Blender 5.0 and later, the add-on landscape exclusively uses **Blender Extensions**. The traditional add-on structure (`__init__.py` with `bl_info` only) is legacy, but for compatibility, a hybrid or full extension approach is used.

### Standard Add-on Structure
1. **`__init__.py`**: The entry point. It contains the `bl_info` dictionary that Blender reads to populate the Add-on Preferences menu. It registers properties and UI panels/operators.
2. **`config.py`**: A modular approach to keeping global constants clean.
3. **Installation**: You zip the `blender_addon/` directory and use **Edit > Preferences > Add-ons > Install...** to load it into Blender.

### Blender 5.0+ Extension Structure
Blender 5.0 requires this structure to be a Blender Extension by placing a `blender_manifest.toml` file at the root.

**Example `blender_manifest.toml`:**
```toml
schema_version = "1.0.0"
id = "godot_terrain_exporter"
version = "1.0.0"
name = "Terrain Exporter Add-on"
description = "Export terrain meshes to Godot game engine in manageable chunks."
license = "SPDX-License-Identifier: MIT"
maintainer = "Your Name"
```

### Orchestration & Development Workflow
1. **Develop Local Script**: During active development, you can symlink this folder to your Blender's extensions directory.
   - Windows: `mklink /D "%APPDATA%\Blender Foundation\Blender\5.0\extensions\user_default\godot_terrain_exporter" "c:\Users\silas\Documents\GitHub\godot-terrain-plugin\blender_addon"`
2. **Reload Scripts**: In Blender, press `F3` and run "Reload Scripts" to see code changes instantly without restarting the application.
3. **Export Process**: The addon slices the terrain logic inside `OBJECT_OT_ExportTerrainToGodot` using `bmesh` operations and drops files in the target directory alongside a `.json` mapping file.
