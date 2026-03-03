@tool
extends MarginContainer

const SETTINGS_KEY = "godot_terrain_importer/last_export_path"

@onready var world_dropdown = %WorldDropdown
@onready var refresh_worlds_button = %RefreshWorldsButton
@onready var new_world_button = %NewWorldButton
@onready var new_world_hbox = %NewWorldHBox
@onready var world_name_edit = %WorldNameEdit
@onready var confirm_new_world_button = %ConfirmNewWorldButton
@onready var cancel_new_world_button = %CancelNewWorldButton

@onready var path_line_edit = %PathLineEdit
@onready var browse_button = %BrowseButton
@onready var import_external_button = %ImportExternalButton
@onready var create_world_button = %CreateWorldButton
@onready var metadata_label = %MetadataLabel
@onready var file_dialog = %FileDialog

var current_path: String = ""
var valid_metadata: Dictionary = {}

var plugin_ref: EditorPlugin = null # Set by plugin.gd

func _ready():
	browse_button.pressed.connect(_on_browse_pressed)
	import_external_button.pressed.connect(_on_import_external_pressed)
	create_world_button.pressed.connect(_on_create_world_pressed)
	file_dialog.dir_selected.connect(_on_dir_selected)
	
	refresh_worlds_button.pressed.connect(_populate_worlds)
	new_world_button.pressed.connect(_show_new_world_ui)
	confirm_new_world_button.pressed.connect(_on_confirm_new_world)
	cancel_new_world_button.pressed.connect(_hide_new_world_ui)
	world_dropdown.item_selected.connect(_on_world_selected)
	
	_load_settings()
	_populate_worlds()
	
	_load_settings()

func _load_settings():
	var settings = EditorInterface.get_editor_settings()
	if settings.has_setting(SETTINGS_KEY):
		var saved_path = settings.get_setting(SETTINGS_KEY)
		if saved_path and not saved_path.is_empty():
			_set_path(saved_path)

func _save_settings(path: String):
	var settings = EditorInterface.get_editor_settings()
	settings.set_setting(SETTINGS_KEY, path)

func _on_browse_pressed():
	if current_path and not current_path.is_empty() and DirAccess.dir_exists_absolute(current_path):
		file_dialog.current_dir = current_path
	file_dialog.popup_centered()

func _on_dir_selected(dir: String):
	_set_path(dir)
	_save_settings(dir)

func _set_path(path: String):
	current_path = path
	path_line_edit.text = path
	_check_metadata()

func _populate_worlds():
	world_dropdown.clear()
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("res://terrain_worlds"):
		dir.make_dir_recursive("res://terrain_worlds")
		
	var worlds_dir = DirAccess.open("res://terrain_worlds")
	var worlds = []
	if worlds_dir:
		worlds_dir.list_dir_begin()
		var folder = worlds_dir.get_next()
		while folder != "":
			if worlds_dir.current_is_dir() and not folder.begins_with("."):
				worlds.append(folder)
			folder = worlds_dir.get_next()
			
	for w in worlds:
		world_dropdown.add_item(w)
		
	if worlds.size() > 0:
		_check_metadata()
	else:
		metadata_label.text = "[color=gray]No worlds found. Create a new one![/color]"
		import_external_button.disabled = true
		create_world_button.disabled = true

func _show_new_world_ui():
	world_dropdown.get_parent().visible = false
	new_world_hbox.visible = true
	world_name_edit.text = ""

func _hide_new_world_ui():
	world_dropdown.get_parent().visible = true
	new_world_hbox.visible = false

func _on_confirm_new_world():
	var txt = world_name_edit.text.strip_edges()
	if txt.is_empty():
		return
		
	var dir = DirAccess.open("res://")
	var new_path = "res://terrain_worlds/" + txt
	if not dir.dir_exists(new_path):
		dir.make_dir_recursive(new_path)
	if not dir.dir_exists(new_path + "/raw_assets"):
		dir.make_dir_recursive(new_path + "/raw_assets")
		
	_hide_new_world_ui()
	_populate_worlds()
	
	# Select the new world
	for i in range(world_dropdown.item_count):
		if world_dropdown.get_item_text(i) == txt:
			world_dropdown.select(i)
			break
			
	_check_metadata()

func _on_world_selected(_idx: int):
	_check_metadata()

func _get_current_world_name() -> String:
	if world_dropdown.item_count > 0:
		return world_dropdown.get_item_text(world_dropdown.selected)
	return ""

func _check_metadata():
	# 1. First, check if there is an external path loaded in Step 1
	var external_valid = false
	if current_path and not current_path.is_empty() and DirAccess.dir_exists_absolute(current_path):
		if not current_path.begins_with("res://"):
			import_external_button.disabled = false
			external_valid = true
		else:
			import_external_button.disabled = true
	else:
		import_external_button.disabled = true
		
	var world_name = _get_current_world_name()
	valid_metadata = {}
	create_world_button.disabled = true
	
	if world_name.is_empty():
		metadata_label.text = "[color=yellow]Awaiting World Creation...[/color]"
		return
		
	# 2. Check the internal Godot project folder for the target World's raw metadata
	var internal_path = "res://terrain_worlds/" + world_name + "/raw_assets"
	var internal_metadata_path = internal_path + "/terrain_metadata.json"
	
	# If no internal metadata, check the external folder as a fallback to display what is waiting to be imported
	var scan_path = internal_path
	var meta_path = internal_metadata_path
	var is_internal = true
	
	if not FileAccess.file_exists(meta_path) and external_valid:
		scan_path = current_path
		meta_path = current_path + "/terrain_metadata.json"
		is_internal = false
	
	if not FileAccess.file_exists(meta_path):
		metadata_label.text = "[color=gray]No terrain_metadata.json found for world '%s'[/color]\n[color=yellow]Export from Blender into the external mapped folder and press 'Import External Chunks', or export directly to %s.[/color]" % [world_name, internal_path]
		return
		
	var file = FileAccess.open(meta_path, FileAccess.READ)
	var json_string = file.get_as_text()
	var json = JSON.parse_string(json_string)
	
	if json and typeof(json) == TYPE_DICTIONARY and json.has("chunk_size") and json.has("total_chunks"):
		valid_metadata = json
		var chunk_size = json["chunk_size"]
		var total_chunks = json["total_chunks"]
		
		if is_internal:
			metadata_label.text = "[color=green]Ready to Create/Update World '%s'![/color]\n" % world_name + \
								  "Found in: [b]res://.../raw_assets/[/b]\n" + \
								  "Chunk Size: [b]%sm[/b]  |  Total: [b]%s[/b]" % [str(chunk_size), str(total_chunks)]
			create_world_button.disabled = false
			create_world_button.tooltip_text = ""
		else:
			metadata_label.text = "[color=yellow]External Terrain Found[/color]\n" + \
								  "Found in: [b]%s[/b]\n" + \
								  "Chunk Size: [b]%sm[/b]  |  Total: [b]%s[/b]\n" % [scan_path, str(chunk_size), str(total_chunks)] + \
								  "[color=orange]Please click 'Import External Chunks' to copy these into World '%s'.[/color]" % world_name
			create_world_button.disabled = true
			create_world_button.tooltip_text = "You must import the external chunks into the Godot project first."
	else:
		metadata_label.text = "[color=red]Error: Invalid terrain_metadata.json format in %s.[/color]" % scan_path

func _on_import_external_pressed():
	var world_name = _get_current_world_name()
	if world_name.is_empty():
		push_error("World name cannot be empty.")
		return
		
	if plugin_ref and plugin_ref.has_method("import_external_assets"):
		plugin_ref.import_external_assets(world_name, current_path)
		
		# Assume they clicked it and Godot is importing, re-enable the create button for step 2
		create_world_button.disabled = false
		create_world_button.tooltip_text = "Wait for Godot's bottom-right progress bar to finish before clicking."
	else:
		var import_script = preload("res://addons/godot_importer/import_plugin.gd").new()
		import_script.import_external_assets(world_name, current_path)
		create_world_button.disabled = false
		create_world_button.tooltip_text = "Wait for Godot to finish importing before clicking."

func _on_create_world_pressed():
	var world_name = _get_current_world_name()
	if world_name.is_empty():
		push_error("World name cannot be empty.")
		return
		
	# Assume the raw assets are either already heavily nested in res:// or were copied into raw_assets
	var target_path = current_path
	if not current_path.begins_with("res://"):
		target_path = "res://terrain_worlds/" + world_name + "/raw_assets"
		
	if plugin_ref and plugin_ref.has_method("generate_world"):
		plugin_ref.generate_world(world_name, target_path, valid_metadata)
	else:
		# Fallback if method doesn't exist on plugin_ref
		var import_script = preload("res://addons/godot_importer/import_plugin.gd").new()
		import_script.generate_world(world_name, target_path, valid_metadata)

