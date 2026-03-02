extends Node3D
class_name TerrainManager

# Import settings
@export var chunk_path: String = "res://exported_terrain/"
@export var load_radius: float = 500.0        # Radius around player to load terrain chunks
@export var unload_radius: float = 600.0      # Radius to unload terrain chunks
@export var target_player: Node3D = null      # The player character or camera tracking target

# State tracking
var loaded_chunks = {}       # Map of chunk_id -> node reference
var active_chunks = {}        # Map of chunk_id -> active status

func _ready():
	# If we have preloaded nodes spawned by the editor tool mapping them
	# into the `loaded_chunks` cache.
	for child in get_children():
		if child is MeshInstance3D and child.name.begins_with("terrain_"):
			var chunk_id = child.name.replace("terrain_", "")
			loaded_chunks[chunk_id] = child
			active_chunks[chunk_id] = true

func _physics_process(_delta):
	if target_player:
		update_terrain(target_player.global_position)

# Called during gameplay to load/unload chunks around player
func update_terrain(player_position: Vector3):
	# Unload chunks outside unload radius
	for chunk_id in loaded_chunks.keys():
		var chunk_node = loaded_chunks[chunk_id]
		if not is_instance_valid(chunk_node):
			continue
			
		var chunk_pos = chunk_node.global_position
		var distance = chunk_pos.distance_to(player_position)
		
		# For efficiency we might not delete the Node but simply hide it and disable its collision
		if distance > unload_radius:
			if active_chunks[chunk_id]:
				chunk_node.visible = false
				active_chunks[chunk_id] = false
				_set_collision_enabled(chunk_node, false)
				
	# If we needed to dynamically instance .obj files at runtime we would do it here reading from terrain_metadata.json
	# But in modern workflows, the editor imports the full scene, and the manager toggles visibility/processing to avoid hitching

func _set_collision_enabled(chunk_node: Node3D, enabled: bool):
	for child in chunk_node.get_children():
		if child is StaticBody3D:
			for shape in child.get_children():
				if shape is CollisionShape3D:
					shape.disabled = not enabled

# Get loaded terrain for gameplay queries
func get_terrain_at(position: Vector3) -> MeshInstance3D:
	for chunk_id in loaded_chunks.keys():
		var chunk_node = loaded_chunks[chunk_id]
		if not is_instance_valid(chunk_node):
			continue
		
		var chunk_pos = chunk_node.global_position
		
		# Simple bounding box check (can be improved with proper spatial indexing)
		var chunk_size = 64.0  # Should match CHUNK_SIZE from config
		var half_size = chunk_size / 2.0
		
		if abs(position.x - chunk_pos.x) <= half_size and \
		   abs(position.y - chunk_pos.y) <= half_size and \
		   abs(position.z - chunk_pos.z) <= half_size:
			return chunk_node
	
	return null
