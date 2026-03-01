# Godot Terrain Importer
# Imports terrain chunks exported from Blender addon

extends EditorScript

# Configuration
const TERRAIN_MATERIAL = preload("res://materials/terrain.tres")
const CREATE_COLLISION = true
const CREATE_NAVMESH = true
const ASSEMBLE_MASTER = true
const MASTER_NODE_NAME = "MasterTerrain"

# Import settings
var chunk_path = "res://exported_terrain/"
var load_radius = 500.0        # Radius around player to load terrain chunks
var unload_radius = 600.0      # Radius to unload terrain chunks

# State tracking
var loaded_chunks = {}       # Map of chunk_id -> node reference
var active_chunks = {}        # Map of chunk_id -> active status
var master_terrain_node = null

# Called by Blender addon export button
func import_terrain_from_blender():
    print("Importing terrain from Blender export...")
    
    # Create master terrain node if it doesn't exist
    if not master_terrain_node:
        master_terrain_node = Spatial.new()
        master_terrain_node.name = MASTER_NODE_NAME
        
        # Add to editor scene
        var root_node = EditorPlugin.get_editor_interface().get_edited_scene_root()
        root_node.add_child(master_terrain_node)
        
        # Create material
        var mat = SpatialMaterial.new()
        mat.albedo_color = Color(0.6, 0.7, 0.8)  # Earthy terrain color
        master_terrain_node.material_override = mat
        
        # Set to instance
        self.master_terrain_node = master_terrain_node
    
    # Load metadata
    var metadata_path = chunk_path + "terrain_metadata.json"
    var file = File.new()
    if file.open(metadata_path, File.READ):
        var json_string = file.get_as_text()
        file.close()
        
        var json = JSON.parse(json_string)
        
        # Load chunks based on metadata
        _load_terrain_chunks(json.chunks, json.bbox)
        
        print("Terrain import complete!")
        print("Loaded ", loaded_chunks.size(), " terrain chunks")
    else:
        print("Error: Could not find terrain_metadata.json")

# Load terrain chunks based on Blender export metadata
func _load_terrain_chunks(chunks_data, bbox_data):
    # Load all chunk meshes
    for chunk in chunks_data:
        var chunk_filename = chunk.filename + ".mesh"
        var chunk_mesh = load(chunk_path + chunk_filename)
        
        if chunk_mesh:
            var chunk_instance = MeshInstance.new()
            chunk_instance.mesh = chunk_mesh
            chunk_instance.cast_shadow = RenderingServer.SHADOW_CASTING_SETTING_ON
            chunk_instance.material_override = TERRAIN_MATERIAL
            
            # Store chunk reference
            var chunk_id = chunk.chunk
            loaded_chunks[chunk_id] = chunk_instance
            active_chunks[chunk_id] = true
            
            # Add to master terrain node
            master_terrain_node.add_child(chunk_instance)
            
            # Create collision if enabled
            if CREATE_COLLISION:
                var collision = StaticBody.new()
                collision.shape = chunk_mesh.create_trimesh_shape()
                collision.transform = chunk_instance.transform
                collision.name = "Collision_" + chunk_id
                
                # Add collision to scene
                EditorPlugin.get_editor_interface().get_edited_scene_root().add_child(collision)
        
        # Optionally create navigation mesh
        if CREATE_NAVMESH:
            _create_navigation_mesh(bbox_data)
    
    # Load single mesh from resource path
func load(path: String) -> Mesh:
    if ResourceLoader.exists(path):
        return load(path)
    return null

# Create navigation mesh for AI pathfinding
func _create_navigation_mesh(bbox_data):
    var nav_mesh = NavigationMesh.new()
    
    # Use terrain bounding box for navigation area
    var min_v = Vector3(bbox_data.min[0], bbox_data.min[1], bbox_data.min[2])
    var max_v = Vector3(bbox_data.max[0], bbox_data.max[1], bbox_data.max[2])
    
    nav_mesh.create_from_mesh(load(chunk_path + "navmesh_base.mesh"))
    nav_mesh.aabb = AABB(min_v, max_v)
    
    var nav_node = NavigationRegion3D.new()
    nav_node.navmesh = nav_mesh
    nav_node.transform.origin = (min_v + max_v) / 2
    
    EditorPlugin.get_editor_interface().get_edited_scene_root().add_child(nav_node)

# Called during gameplay to load/unload chunks around player
func update_terrain(player_position: Vector3):
    var player_x = player_position.x
    var player_y = player_position.y
    var player_z = player_position.z
    
    # Unload chunks outside unload radius
    for chunk_id in loaded_chunks.keys():
        var chunk_node = loaded_chunks[chunk_id]
        if not chunk_node:
            continue
            
        var chunk_pos = chunk_node.global_transform.origin
        
        # Calculate distance from player
        var distance = chunk_pos.distance_to(player_position)
        
        if distance > unload_radius:
            # Unload chunk
            if CREATE_COLLISION:
                # Remove collision body
                var scene_root = EditorPlugin.get_editor_interface().get_edited_scene_root()
                var collision_node = scene_root.get_node_or_null("Collision_" + chunk_id)
                if collision_node:
                    scene_root.remove_child(collision_node)
                    collision_node.queue_free()
            
            # Remove mesh instance
            master_terrain_node.remove_child(chunk_node)
            chunk_node.queue_free()
            
            del loaded_chunks[chunk_id]
            del active_chunks[chunk_id]
    
    # Load chunks within load radius
    var metadata_file = File.new()
    if metadata_file.open(chunk_path + "terrain_metadata.json", File.READ):
        var json_string = metadata_file.get_as_text()
        metadata_file.close()
        
        var json = JSON.parse(json_string)
        
        for chunk in json.chunks:
            var chunk_id = chunk.chunk
            var chunk_x = chunk.position[0]
            var chunk_y = chunk.position[1]
            var chunk_z = chunk.position[2]
            var chunk_pos = Vector3(chunk_x, chunk_y, chunk_z)
            
            var distance = chunk_pos.distance_to(player_position)
            
            # Load if within radius and not already loaded
            if distance <= load_radius and chunk_id not in loaded_chunks:
                var chunk_filename = chunk.filename + ".mesh"
                var chunk_mesh = load(chunk_path + chunk_filename)
                
                if chunk_mesh:
                    var chunk_instance = MeshInstance.new()
                    chunk_instance.mesh = chunk_mesh
                    chunk_instance.cast_shadow = RenderingServer.SHADOW_CASTING_SETTING_ON
                    chunk_instance.material_override = TERRAIN_MATERIAL
                    
                    loaded_chunks[chunk_id] = chunk_instance
                    active_chunks[chunk_id] = true
                    
                    # Add to master terrain
                    master_terrain_node.add_child(chunk_instance)
                    
                    # Create collision if enabled
                    if CREATE_COLLISION:
                        var collision = StaticBody.new()
                        collision.shape = chunk_mesh.create_trimesh_shape()
                        collision.transform = chunk_instance.transform
                        collision.name = "Collision_" + chunk_id
                        EditorPlugin.get_editor_interface().get_edited_scene_root().add_child(collision)

# Get loaded terrain for gameplay queries
func get_terrain_at(position: Vector3) -> MeshInstance:
    # Find which chunk is at the given position
    # TODO: Implement spatial hash lookup for O(1) performance
    
    for chunk_id in loaded_chunks.keys():
        var chunk_node = loaded_chunks[chunk_id]
        if not chunk_node:
            continue
        
        var chunk_pos = chunk_node.global_transform.origin
        
        # Simple bounding box check (can be improved with proper spatial indexing)
        var chunk_size = 64.0  # Should match CHUNK_SIZE from config
        var half_size = chunk_size / 2.0
        
        if abs(position.x - chunk_pos.x) <= half_size and \
           abs(position.y - chunk_pos.y) <= half_size and \
           abs(position.z - chunk_pos.z) <= half_size:
            return chunk_node
    
    return null

# Clean up terrain resources
func cleanup_terrain():
    print("Cleaning up terrain resources...")
    
    # Remove all chunk instances from master
    for chunk_id in loaded_chunks.keys():
        var chunk_node = loaded_chunks[chunk_id]
        if chunk_node:
            if CREATE_COLLISION:
                var scene_root = EditorPlugin.get_editor_interface().get_edited_scene_root()
                var collision_node = scene_root.get_node_or_null("Collision_" + chunk_id)
                if collision_node:
                    scene_root.remove_child(collision_node)
                    collision_node.queue_free()
            
            master_terrain_node.remove_child(chunk_node)
            chunk_node.queue_free()
    
    # Remove navigation mesh
    var scene_root = EditorPlugin.get_editor_interface().get_edited_scene_root()
    var nav_node = scene_root.get_node_or_null(MASTER_NODE_NAME + "_NavMesh")
    if nav_node:
        scene_root.remove_child(nav_node)
        nav_node.queue_free()
    
    loaded_chunks.clear()
    active_chunks.clear()
    
    print("Terrain cleanup complete!")
