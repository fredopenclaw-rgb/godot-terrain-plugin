@tool
extends RefCounted

# Called by import_dock.gd when user clicks "Create World From Tiles"
func import_external_assets(world_name: String, directory_path: String):
	print("Step 1: Importing external chunks from " + directory_path)
	
	var world_dir = "res://terrain_worlds/" + world_name + "/"
	var raw_dir = world_dir + "raw_assets/"
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(world_dir):
		dir.make_dir_recursive(world_dir)
	if not dir.dir_exists(raw_dir):
		dir.make_dir_recursive(raw_dir)
		
	var da = DirAccess.open(directory_path)
	if da:
		da.list_dir_begin()
		var file_name = da.get_next()
		while file_name != "":
			if not da.current_is_dir() and not file_name.begins_with("."):
				var ext = file_name.get_extension().to_lower()
				if ext in ["obj", "mesh", "json", "mtl"]:
					var src = directory_path + "/" + file_name
					var dst = raw_dir + file_name
					if not FileAccess.file_exists(dst):
						DirAccess.copy_absolute(src, dst)
			file_name = da.get_next()
			
	print("Meshes staged! Triggering Godot EditorFileSystem scan...")
	EditorInterface.get_resource_filesystem().scan()

# Called by import_dock.gd when user clicks "Step 2: Create World From Tiles"
func generate_world(world_name: String, directory_path: String, metadata: Dictionary):
	print("Step 2: Generating world '" + world_name + "' from chunks in " + directory_path)
	
	var world_dir = "res://terrain_worlds/" + world_name + "/"
	var chunks_dir = world_dir + "chunks/"
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(chunks_dir):
		dir.make_dir_recursive(chunks_dir)
		
	var chunks_data = metadata.get("chunks", [])
	var chunk_size = metadata.get("chunk_size", 64.0)
	
	print("Prefabricating terrain chunks...")
	
	# Process each chunk into a saved .tscn prefab. We read from directory_path directly (which is raw_assets now)
	for chunk in chunks_data:
		_process_chunk(chunk, directory_path, chunks_dir)
		
	# Create the Master World Scene
	_create_master_world_scene(world_name, world_dir, chunks_dir, chunk_size, metadata)
	
	print("World Generation Complete! Open " + world_dir + world_name + ".tscn")

func _process_chunk(chunk_data: Dictionary, source_dir: String, target_dir: String):
	var chunk_filename = chunk_data.get("filename", "")
	if chunk_filename.is_empty():
		return
		
	var obj_path = source_dir + "/" + chunk_filename + ".obj"
	var tscn_path = target_dir + chunk_filename + ".tscn"
	
	if not FileAccess.file_exists(obj_path):
		obj_path = source_dir + "/" + chunk_filename + ".mesh"
		if not FileAccess.file_exists(obj_path):
			push_error("Source mesh not found for chunk: " + chunk_filename)
			return
			
	# Load the actual raw mesh object (PackedScene if OBJ, Mesh if .mesh)
	var raw_mesh_data = load(obj_path)
	if not raw_mesh_data:
		push_error("Failed to load generic Godot mesh/scene for: " + obj_path)
		return
		
	var root_node = null
	
	# CONTINUOUS UPDATE LOGIC: Check if the chunk already exists
	if FileAccess.file_exists(tscn_path):
		var existing_scene = load(tscn_path)
		if existing_scene and existing_scene is PackedScene:
			root_node = existing_scene.instantiate()
			# Purge the old mesh and collision logic
			var old_mesh = root_node.get_node_or_null("Mesh")
			if old_mesh:
				old_mesh.free() # Safely delete the old terrain math synchronously
	
	# If chunk didn't exist or failed to load, create a new root
	if not root_node:
		root_node = Node3D.new()
		root_node.name = chunk_filename
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	
	var extracted_mesh: Mesh = null
	
	# Extract mesh data depending on format
	if raw_mesh_data is Mesh:
		extracted_mesh = raw_mesh_data
	elif raw_mesh_data is PackedScene:
		var state = raw_mesh_data.instantiate()
		if state is MeshInstance3D and state.mesh:
			extracted_mesh = state.mesh.duplicate(true) # Deep copy to decouple from OBJ
		elif state.get_class() == "ImporterMeshInstance3D" and state.mesh:
			extracted_mesh = state.mesh.duplicate(true)
		else:
			for child in state.get_children():
				if (child is MeshInstance3D or child.get_class() == "ImporterMeshInstance3D") and child.mesh:
					extracted_mesh = child.mesh.duplicate(true)
					break
		state.free()
		
	if not extracted_mesh:
		push_error("Could not find Mesh data inside imported file: " + obj_path)
		if root_node.get_parent() == null:
			root_node.free()
		mesh_instance.free()
		return
		
	mesh_instance.mesh = extracted_mesh
		
	root_node.add_child(mesh_instance)
	mesh_instance.owner = root_node
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	
	# Try material
	if ResourceLoader.exists("res://materials/terrain.tres"):
		var mat = load("res://materials/terrain.tres")
		if mat:
			mesh_instance.material_override = mat
			
	# Create Trimesh Collision
	mesh_instance.create_trimesh_collision()
	var static_body = mesh_instance.get_child(0)
	if static_body:
		static_body.name = "Collision"
		static_body.owner = root_node
		for shape in static_body.get_children():
			shape.owner = root_node
			
	# Explicitly re-own any PRE-EXISTING custom user children (like trees/houses) 
	# so they aren't lost when we repack the scene!
	for child in root_node.get_children():
		if not child.owner:
			child.owner = root_node
		_recursive_own(child, root_node)
			
	# Save the scene
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(root_node)
	if result == OK:
		ResourceSaver.save(packed_scene, tscn_path)
	else:
		push_error("Failed to pack scene for chunk " + chunk_filename)
		
	# Clean up memory
	if root_node.get_parent() == null:
		root_node.free()

func _recursive_own(node: Node, new_owner: Node):
	for child in node.get_children():
		if not child.owner:
			child.owner = new_owner
		_recursive_own(child, new_owner)

func _create_master_world_scene(world_name: String, world_dir: String, chunks_dir: String, chunk_size: float, metadata: Dictionary):
	var scene_path = world_dir + world_name + ".tscn"
	
	# CONTINUOUS UPDATE LOGIC: Never overwrite the Master Scene if the user already built one
	# BUT we MUST update the Terrain Manager node with the newest scaled metadata properties!
	if FileAccess.file_exists(scene_path):
		var existing_scene = load(scene_path)
		if existing_scene and existing_scene is PackedScene:
			var root = existing_scene.instantiate()
			var manager = root.get_node_or_null("TerrainManager")
			if manager:
				manager.chunk_size = chunk_size
				manager.total_chunks = metadata.get("total_chunks", 0)
				manager.chunk_metadata_json = JSON.stringify(metadata)
				
				for child in root.get_children():
					if not child.owner:
						child.owner = root
					_recursive_own(child, root)
					
				var packed = PackedScene.new()
				packed.pack(root)
				ResourceSaver.save(packed, scene_path)
				
		print("Master scene already exists. Updated TerrainManager metadata and preserved Player setup.")
		EditorInterface.open_scene_from_path(scene_path)
		return
		
	var root_node = Node3D.new()
	root_node.name = world_name
	
	# Create Terrain Manager
	var manager = preload("res://addons/godot_importer/terrain_manager.gd").new()
	manager.name = "TerrainManager"
	root_node.add_child(manager)
	manager.owner = root_node
	
	manager.chunk_path = chunks_dir
	manager.chunk_size = chunk_size
	manager.total_chunks = metadata.get("total_chunks", 0)
	
	# Provide the JSON data string so the manager knows the coordinates of every file
	manager.chunk_metadata_json = JSON.stringify(metadata)
	
	# Save main scene
	scene_path = world_dir + world_name + ".tscn"
	var packed_scene = PackedScene.new()
	packed_scene.pack(root_node)
	ResourceSaver.save(packed_scene, scene_path)
	
	# Open it in the editor
	EditorInterface.open_scene_from_path(scene_path)
