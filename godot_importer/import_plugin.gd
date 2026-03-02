@tool
extends RefCounted

# Configuration
const TERRAIN_MATERIAL = preload("res://materials/terrain.tres")
const CREATE_COLLISION = true
const CREATE_NAVMESH = true
const ASSEMBLE_MASTER = true
const MASTER_NODE_NAME = "MasterTerrain"

# Import settings
var chunk_path = "res://exported_terrain/"

# Called by plugin menu item
func import_terrain_from_blender():
	print("Importing terrain from Blender export...")
	var root_node = EditorInterface.get_edited_scene_root()
	if not root_node:
		push_error("No open scene to import into. Please open a scene first.")
		return
	
	# Create master terrain node if it doesn't exist
	var master_terrain_node = root_node.get_node_or_null(MASTER_NODE_NAME)
	if not master_terrain_node:
		master_terrain_node = Node3D.new()
		master_terrain_node.name = MASTER_NODE_NAME
		
		# Add to editor scene
		root_node.add_child(master_terrain_node)
		master_terrain_node.owner = root_node
		
		# Create material
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 0.7, 0.8)  # Earthy terrain color
		# Assign default material to all instances instead of geometry overrides, unless configured globally
		
	# Load metadata
	var metadata_path = chunk_path + "terrain_metadata.json"
	if not FileAccess.file_exists(metadata_path):
		push_error("Error: Could not find " + metadata_path)
		return
		
	var file = FileAccess.open(metadata_path, FileAccess.READ)
	var json_string = file.get_as_text()
	var json = JSON.parse_string(json_string)
	
	if json:
		# Load chunks based on metadata
		_load_terrain_chunks(json.chunks, json.bbox, master_terrain_node, root_node)
		print("Terrain import complete!")
	else:
		push_error("Error parsing JSON terrain metadata")

# Load terrain chunks based on Blender export metadata
func _load_terrain_chunks(chunks_data: Array, bbox_data: Dictionary, master_node: Node3D, root_node: Node):
	# Load all chunk meshes
	for chunk in chunks_data:
		var chunk_filename = chunk.filename + ".obj"  # Assuming wavefront fallback or .mesh
		var chunk_object = load(chunk_path + chunk_filename)
		
		if chunk_object:
			var chunk_instance = MeshInstance3D.new()
			if chunk_object is Mesh:
				chunk_instance.mesh = chunk_object
			elif chunk_object is PackedScene:
				# OBJ imports as PackedScene in Godot 4 by default
				var instantiated = chunk_object.instantiate()
				for child in instantiated.get_children():
					if child is MeshInstance3D:
						chunk_instance.mesh = child.mesh
						break
				instantiated.queue_free()

			chunk_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			chunk_instance.name = chunk.filename
			
			# Add to master terrain node
			master_node.add_child(chunk_instance)
			chunk_instance.owner = root_node
			
			# Assign material if missing
			if TERRAIN_MATERIAL:
				chunk_instance.material_override = TERRAIN_MATERIAL
			
			# Create collision if enabled
			if CREATE_COLLISION and chunk_instance.mesh:
				chunk_instance.create_trimesh_collision()
				# The new physics body becomes a child of `chunk_instance`.
				var static_body = chunk_instance.get_child(0)
				if static_body:
					static_body.name = "Collision_" + str(chunk.chunk)
					static_body.owner = root_node
					
					# Assign node ownership recursive to collision subnodes
					for shape in static_body.get_children():
						shape.owner = root_node
		
	# Optionally create navigation mesh based on bounding box
	if CREATE_NAVMESH:
		_create_navigation_mesh(bbox_data, master_node, root_node)

# Create navigation mesh for AI pathfinding
func _create_navigation_mesh(bbox_data: Dictionary, master_node: Node3D, root_node: Node):
	var min_v = Vector3(bbox_data.min[0], bbox_data.min[1], bbox_data.min[2])
	var max_v = Vector3(bbox_data.max[0], bbox_data.max[1], bbox_data.max[2])
	
	var nav_node = NavigationRegion3D.new()
	nav_node.name = MASTER_NODE_NAME + "_NavRegion"
	
	var nav_mesh = NavigationMesh.new()
	nav_node.navmesh = nav_mesh
	
	master_node.add_child(nav_node)
	nav_node.owner = root_node
	
	# Setting baking properties AABB from bounding box is mostly deprecated/handled internally 
	# User should click "Bake Navmesh" button on the NavigationRegion3D node to properly bake geometry from children.
	print("NavigationRegion3D created. Please select it in the tree and BAKE NAVMESH.")
