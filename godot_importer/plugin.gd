@tool
extends EditorPlugin

var import_tool_instance = null

func _enter_tree():
	# Initialization of the plugin goes here.
	# We load the import tool script and instantiate it
	var import_tool_script = preload("res://addons/godot_importer/import_plugin.gd")
	if import_tool_script:
		import_tool_instance = import_tool_script.new()
		
		# Adding a menu item to the tools menu
		add_tool_menu_item("Import Terrain from Blender", _on_import_terrain_pressed)
		
		# Also add terrain manager as a custom type so users can add it to their scene
		add_custom_type("TerrainManager", "Node3D", preload("res://addons/godot_importer/terrain_manager.gd"), null)

func _exit_tree():
	# Clean-up of the plugin goes here.
	if import_tool_instance != null:
		remove_tool_menu_item("Import Terrain from Blender")
		# We don't free import_tool_instance because RefCounted/Object lifecycle might handle it, or we call free() if it's explicitly an Object.
		import_tool_instance.free()
		
	remove_custom_type("TerrainManager")

func _on_import_terrain_pressed():
	if import_tool_instance:
		import_tool_instance.import_terrain_from_blender()
		print("Terrain import process finished.")
