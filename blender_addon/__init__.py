"""
Godot Terrain Exporter for Blender

This add-on exports terrain meshes from Blender to Godot 4.x format.
"""

bl_info = {
    "name": "Godot Terrain Exporter",
    "author": "Your Name Here",
    "version": (1, 0, 0),
    "blender": (4, 0, 0),
    "location": "View3D > Sidebar > Godot Terrain",
    "description": "Export terrain meshes to Godot game engine",
    "category": "Import-Export",
}

import bpy
import os
import json
from math import floor, ceil
from pathlib import Path
import bmesh

# Configuration
CHUNK_SIZE = 64
EXPORT_FORMAT = "mesh"
EXPORT_PATH = "//exported_terrain/"
PLANAR_UV = True
COMPUTE_NORMALS = True


class TerrainExportProperties(bpy.types.PropertyGroup):
    """Properties for terrain export settings"""
    bl_label = "Export Settings"
    bl_options = {'HIDDEN'}
    
    chunk_size: bpy.props.IntProperty(
        name="chunk_size",
        default=64,
        min=32,
        max=256,
        description="Vertices per chunk side"
    )
    
    export_format: bpy.props.EnumProperty(
        name="export_format",
        items=['MESH', 'OBJ'],
        default='MESH',
        description="Export format"
    )
    
    export_path: bpy.props.StringProperty(
        name="export_path",
        default=EXPORT_PATH,
        description="Export directory path"
    )
    
    compute_normals: bpy.props.BoolProperty(
        name="compute_normals",
        default=True,
        description="Calculate face normals"
    )
    
    planar_uv: bpy.props.BoolProperty(
        name="planar_uv",
        default=True,
        description="Use planar UV projection"
    )


class OBJECT_OT_ExportTerrainToGodot(bpy.types.Operator):
    """Export selected terrain mesh to Godot format"""
    bl_idname = "object.export_terrain_to_godot"
    bl_label = "Export to Godot"
    bl_options = {'REGISTER', 'UNDO'}
    
    @classmethod
    def poll(cls, context):
        return context.object is not None
    
    def execute(self, context):
        # Get selected object
        obj = context.object
        if not obj or obj.type != 'MESH':
            self.report({'ERROR'}, "Please select a mesh object to export")
            return {'CANCELLED'}
        
        # Get properties
        props = context.scene.terrain_export_props
        chunk_size = props.chunk_size
        export_format = props.export_format
        compute_normals = props.compute_normals
        
        # Get mesh data
        mesh = obj.data
        if not mesh or len(mesh.vertices) == 0:
            self.report({'ERROR'}, "Selected mesh has no vertices")
            return {'CANCELLED'}
        
        # Calculate chunk dimensions
        bbox_min, bbox_max = self._get_bbox(mesh)
        size_x = bbox_max[0] - bbox_min[0]
        size_y = bbox_max[1] - bbox_min[1]
        size_z = bbox_max[2] - bbox_min[2]
        
        chunks_x = ceil(size_x / chunk_size)
        chunks_y = ceil(size_y / chunk_size)
        chunks_z = ceil(size_z / chunk_size)
        
        # Create export directory
        base_path = bpy.path.abspath(props.export_path.strip('/'))
        os.makedirs(base_path, exist_ok=True)
        
        # Export each chunk
        exported_chunks = []
        for x in range(chunks_x):
            for y in range(chunks_y):
                for z in range(chunks_z):
                    chunk_index = f"{x}_{y}_{z}"
                    chunk_filename = f"terrain_{chunk_index}"
                    
                    # Create chunk mesh
                    chunk_mesh, chunk_vertices = self._create_chunk_mesh(
                        mesh, x, y, z, chunk_size, 
                        bbox_min, bbox_max
                    )
                    
                    if export_format == 'MESH':
                        chunk_file = os.path.join(base_path, chunk_filename + ".mesh")
                        self._export_mesh(chunk_mesh, chunk_file, compute_normals)
                    else:
                        chunk_file = os.path.join(base_path, chunk_filename + ".obj")
                        self._export_obj(chunk_mesh, chunk_file)
                    
                    exported_chunks.append({
                        'chunk': chunk_index,
                        'filename': chunk_filename,
                        'position': (x, y, z)
                    })
        
        # Export metadata
        metadata_file = os.path.join(base_path, "terrain_metadata.json")
        metadata = {
            'chunk_size': chunk_size,
            'chunks': exported_chunks,
            'total_chunks': len(exported_chunks),
            'bbox': {
                'min': [bbox_min[0], bbox_min[1], bbox_min[2]],
                'max': [bbox_max[0], bbox_max[1], bbox_max[2]]
            }
        }
        
        with open(metadata_file, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        self.report({'INFO'}, 
                 f"Exported {len(exported_chunks)} terrain chunks to {base_path}")
        return {'FINISHED'}
    
    def _get_bbox(self, mesh):
        """Get bounding box of mesh"""
        min_coords = [float('inf')] * 3
        max_coords = [float('-inf')] * 3
        
        for v in mesh.vertices:
            for i in range(3):
                coord = v.co[i]
                if coord < min_coords[i]:
                    min_coords[i] = coord
                if coord > max_coords[i]:
                    max_coords[i] = coord
        
        return min_coords, max_coords
    
    def _create_chunk_mesh(self, source_mesh, chunk_x, chunk_y, chunk_z, chunk_size, bbox_min, bbox_max):
        """Create a mesh for one terrain chunk"""
        chunk_mesh = bmesh.new()
        
        # Calculate chunk boundaries
        min_x = bbox_min[0] + chunk_x * chunk_size
        max_x = min(bbox_min[0] + (chunk_x + 1) * chunk_size, bbox_max[0])
        
        min_y = bbox_min[1] + chunk_y * chunk_size
        max_y = min(bbox_min[1] + (chunk_y + 1) * chunk_size, bbox_max[1])
        
        min_z = bbox_min[2] + chunk_z * chunk_size
        max_z = min(bbox_min[2] + (chunk_z + 1) * chunk_size, bbox_max[2])
        
        # Create chunk vertices
        chunk_vertices = []
        for v in source_mesh.vertices:
            # Check if vertex is within chunk bounds
            if (min_x <= v.co[0] < max_x and 
                min_y <= v.co[1] < max_y and 
                min_z <= v.co[2] < max_z):
                
                # Offset vertex position to chunk-local space
                local_x = v.co[0] - min_x
                local_y = v.co[1] - min_y
                local_z = v.co[2] - min_z
                
                chunk_vertices.append((local_x, local_y, local_z))
        
        # Create mesh from vertices
        chunk_bm = bmesh.new()
        if chunk_vertices:
            chunk_bm.from_verts(chunk_vertices)
            
            # Create faces connecting vertices
            # Simple grid connection - each vertex connected to neighbors
            # TODO: Implement proper face generation based on source mesh topology
            
        return chunk_bm
    
    def _export_mesh(self, mesh, filepath, compute_normals):
        """Export mesh to Godot .mesh format"""
        if compute_normals:
            mesh.calc_normals_split()
        
        mesh.export(filepath)
    
    def _export_obj(self, mesh, filepath):
        """Export mesh to .obj format"""
        mesh.export(filepath)


def register():
    """Register Blender addon"""
    bpy.utils.register_class(TerrainExportProperties)
    bpy.utils.register_class(OBJECT_OT_ExportTerrainToGodot)
    bpy.types.Scene.terrain_export_props = bpy.props.PointerProperty(
        type=TerrainExportProperties,
        name="terrain_export_props",
        description="Terrain export settings"
    )


def unregister():
    """Unregister Blender addon"""
    bpy.utils.unregister_class(TerrainExportProperties)
    bpy.utils.unregister_class(OBJECT_OT_ExportTerrainToGodot)
    del bpy.types.Scene.terrain_export_props


if __name__ == "__main__":
    register()
