@tool
extends Node3D
class_name TerrainManager

@export_category("Terrain Configuration")
@export_dir var chunk_path: String = ""
@export var chunk_size: float = 64.0
@export var total_chunks: int = 0
@export_multiline var chunk_metadata_json: String = ""

@export_category("Streaming Logic")
## Assign any Node3D (like a Player, Camera, or a simple Cube) to stream terrain around it.
@export var target_node: Node3D = null
## Number of chunks to keep loaded around the target in grid units
@export var load_distance_tiles: int = 2

@export_category("Editor Visuals")
## Check this to load EVERY chunk into the editor viewport (Memory intensive for massive maps)
@export var preview_all_chunks: bool = false:
	set(value):
		preview_all_chunks = value
		if value and Engine.is_editor_hint():
			_update_editor_preview()
		elif Engine.is_editor_hint():
			_clear_editor_chunks()

## Check this to dynamically load and unload chunks around the 'Target Node' while in the Godot Editor
@export var stream_in_editor: bool = false

var _chunk_data: Array = []
var _loaded_chunk_nodes: Dictionary = {}
var _last_grid_pos: Vector2i = Vector2i(-99999, -99999)
var _bbox_min_x: float = 0.0
var _bbox_min_y: float = 0.0

func _ready():
	_parse_metadata()
	if Engine.is_editor_hint():
		if preview_all_chunks:
			_update_editor_preview()
	else:
		# If no target assigned, try to find a camera in the scene by default
		if not target_node:
			var cam = get_viewport().get_camera_3d()
			if cam:
				target_node = cam

func _parse_metadata():
	if chunk_metadata_json.is_empty():
		return
	var json = JSON.parse_string(chunk_metadata_json)
	if json and typeof(json) == TYPE_DICTIONARY and json.has("chunks"):
		_chunk_data = json["chunks"]
		if json.has("bbox") and json["bbox"].has("min"):
			var bbox_min = json["bbox"]["min"]
			_bbox_min_x = float(bbox_min[0])
			_bbox_min_y = float(bbox_min[1])
		if json.has("chunk_size"):
			chunk_size = float(json["chunk_size"])
		if json.has("total_chunks"):
			total_chunks = int(json["total_chunks"])

func _physics_process(_delta):
	if Engine.is_editor_hint():
		if not stream_in_editor or preview_all_chunks:
			return
		
	if not target_node:
		return
		
	var player_pos = target_node.global_position
	
	# Convert Godot's right-handed (Y-Up) world coordinates back to Blender's (Z-Up) coordinate plane mapping
	var player_blender_x = player_pos.x
	var player_blender_y = -player_pos.z # Godot's positive Z points backwards, which is Blender's negative Y
	
	# Calculate relative offset from the terrain's original bounding box origin
	var relative_x = player_blender_x - _bbox_min_x
	var relative_y = player_blender_y - _bbox_min_y
	
	# Convert into chunk grid indices
	var grid_x = floori(relative_x / chunk_size)
	var grid_y = floori(relative_y / chunk_size)
	var current_grid_pos = Vector2i(grid_x, grid_y)
	
	if current_grid_pos != _last_grid_pos:
		_last_grid_pos = current_grid_pos
		_update_terrain_streaming(current_grid_pos)

func _update_terrain_streaming(center_grid: Vector2i):
	# Calculate which chunk coordinates fall within our bounding radius
	var target_loaded_chunks = {}
	
	for x in range(center_grid.x - load_distance_tiles, center_grid.x + load_distance_tiles + 1):
		for y in range(center_grid.y - load_distance_tiles, center_grid.y + load_distance_tiles + 1):
			var hash_pos = "%d_%d_0" % [x, y]
			target_loaded_chunks[hash_pos] = true
			
	# Unload chunks that are out of bounds
	var chunks_to_unload = []
	for chunk_id in _loaded_chunk_nodes.keys():
		if not target_loaded_chunks.has(chunk_id):
			chunks_to_unload.append(chunk_id)
			
	for chunk_id in chunks_to_unload:
		var node = _loaded_chunk_nodes[chunk_id]
		if is_instance_valid(node):
			node.queue_free()
		_loaded_chunk_nodes.erase(chunk_id)
		
	# Load new chunks
	for chunk_id in target_loaded_chunks.keys():
		if not _loaded_chunk_nodes.has(chunk_id):
			_load_chunk(chunk_id)

func _load_chunk(chunk_id: String):
	# Look up the filename from our parsed database
	var filename = ""
	for data in _chunk_data:
		if data.chunk == chunk_id:
			filename = data.filename
			break
			
	if filename.is_empty():
		return # Chunk doesn't exist in the generated dataset (player walked off map)
		
	var scene_path = chunk_path + "/" + filename + ".tscn"
	if not FileAccess.file_exists(scene_path):
		return
		
	var packed_scene = load(scene_path)
	if packed_scene:
		var instance = packed_scene.instantiate()
		add_child(instance)
		_loaded_chunk_nodes[chunk_id] = instance

func _clear_editor_chunks():
	for chunk_id in _loaded_chunk_nodes.keys():
		var node = _loaded_chunk_nodes[chunk_id]
		if is_instance_valid(node):
			node.queue_free()
	_loaded_chunk_nodes.clear()

func _update_editor_preview():
	if not Engine.is_editor_hint():
		return
		
	# Unload everything first
	_clear_editor_chunks()
	
	if preview_all_chunks:
		_parse_metadata()
		for chunk in _chunk_data:
			var scene_path = chunk_path + "/" + chunk.filename + ".tscn"
			if FileAccess.file_exists(scene_path):
				var packed_scene = load(scene_path)
				if packed_scene:
					var instance = packed_scene.instantiate()
					add_child(instance)
					# Editor visibility hack requires setting owner
					instance.owner = owner if owner else self
					_loaded_chunk_nodes[chunk.chunk] = instance
