# Godot AAA Terrain Importer

This folder contains the Terrain Importer plugin for Godot 4.x. It works in tandem with the Blender Terrain Exporter add-on to bring perfectly chunked, massive terrain into Godot as a fully streamlined, distance-based memory loading system.

## Features
- **Custom Editor Dock**: A dedicated UI panel inside Godot to select your exported terrain folder and parse metadata.
- **Automated Prefabrication**: Automatically wraps raw `.obj` chunk meshes into Godot `.tscn` scenes complete with generated Trimesh Static Collisions.
- **AAA Tile Streaming (`TerrainManager`)**: A dynamic 2D grid partition manager that asynchronously loads chunks into memory when the player gets near, and actively `queue_free()`s them when they walk away to maintain rock-solid performance on huge open worlds.

## Installation Guide (Step-by-Step)

Godot requires plugins to live in a very specific directory structure inside your project. Here is how to install this importer:

1. **Create the Addons Folder**: Open your Godot project. In the **FileSystem dock** (bottom left), if you don't already have an `addons` folder, right-click `res://` and select **Create New > Folder**. Name it exactly `addons`.
2. **Copy the Plugin**: Open your computer's file explorer. Navigate to this repository and copy the entire `godot_importer` folder.
3. **Paste into Godot**: Paste the `godot_importer` folder inside your Godot project's `addons` folder.
   - *Crucial Check*: The final path inside Godot MUST be exactly `res://addons/godot_importer/`. (It must contain `plugin.cfg` and `plugin.gd` directly inside it).
4. **Enable the Plugin**: In the Godot top menu, go to **Project > Project Settings**.
5. Click on the **Plugins** tab at the top of the window.
6. You will see **Terrain Importer** in the list. Check the **Enable** box next to it.
7. The **Terrain Importer** UI dock will instantly appear on the right side of your editor!

## How to Use

1. **Export from Blender**: Use the Blender add-on to export your chunks. You will get a folder containing `.obj` files and a `terrain_metadata.json` file.
2. **Select Folder**: In the Godot Terrain Importer dock on the right, click **Browse** and select that exported folder.
3. **Verify Metadata**: The dock should say "Valid Metadata Found" and display the Chunk Size and Total Chunks.
4. **Create World**: Click **Create World From Tiles**, give your world a name (e.g., "Overworld"), and hit Create.
5. **Wait for Generation**: The plugin will freeze for a moment as it processes every chunk, adds collision, and saves them as `.tscn` files in `res://terrain_worlds/`.
6. **Open Your World**: When it prints "Complete!", open `res://terrain_worlds/Overworld/Overworld.tscn`. 
7. **Configure the Streamer**: Click the `TerrainManager` node in your scene. In the inspector, assign your Player or Camera node to the **Target Player** slot. Adjust the **Load Distance Tiles** to control how far out chunks spawn (e.g., 2 tiles). Disable or enable `Preview in Editor` as desired.
