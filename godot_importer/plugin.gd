@tool
extends EditorPlugin

var dock_instance = null
var import_tool_instance = null

func _enter_tree():
	# Initialization of the plugin goes here.
	# Instantiate the importer logic
	var import_tool_script = preload("res://addons/godot_importer/import_plugin.gd")
	if import_tool_script:
		import_tool_instance = import_tool_script.new()
		
	# Load and instantiate the dock UI
	var dock_scene = preload("res://addons/godot_importer/import_dock.tscn")
	if dock_scene:
		dock_instance = dock_scene.instantiate()
		dock_instance.plugin_ref = self 
		# Add the dock to the left dock area
		add_control_to_dock(DOCK_SLOT_LEFT_UR, dock_instance)
		
	# Add terrain manager as a custom type so users can add it to their scene manually if they want
	add_custom_type("TerrainManager", "Node3D", preload("res://addons/godot_importer/terrain_manager.gd"), null)

func _exit_tree():
	# Clean-up of the plugin goes here.
	if dock_instance != null:
		remove_control_from_docks(dock_instance)
		dock_instance.free()
		
	if import_tool_instance != null:
		import_tool_instance.free()
		
	remove_custom_type("TerrainManager")

func import_external_assets(world_name: String, directory_path: String):
	if import_tool_instance and import_tool_instance.has_method("import_external_assets"):
		import_tool_instance.import_external_assets(world_name, directory_path)
	else:
		push_error("Import tool instance is missing import_external_assets method.")

func generate_world(world_name: String, directory_path: String, metadata: Dictionary):
	if import_tool_instance and import_tool_instance.has_method("generate_world"):
		import_tool_instance.generate_world(world_name, directory_path, metadata)
	else:
		push_error("Import tool instance is missing or does not have generate_world method.")
