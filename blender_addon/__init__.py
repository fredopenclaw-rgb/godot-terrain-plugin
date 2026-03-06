"""
Terrain Exporter for Blender

This add-on exports terrain meshes from Blender to generic game engine formats.
"""

bl_info = {
    "name": "Terrain Exporter Add-on",
    "author": "Your Name Here",
    "version": (1, 0, 0),
    "blender": (5, 0, 0),
    "location": "View3D > Sidebar > Terrain Exporter",
    "description": "Export terrain meshes to game engines",
    "category": "Import-Export",
}

import bpy
import os
import json
import mathutils
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
    
    chunk_size: bpy.props.FloatProperty(
        name="Chunk Size",
        default=64.0,
        min=1.0,
        subtype='DISTANCE',
        unit='LENGTH',
        description="Size of each terrain chunk in meters"
    )
    
    export_scale: bpy.props.FloatProperty(
        name="Export Scale",
        default=1.0,
        min=0.001,
        description="Explicit Godot scale multiplier (stacks with Blender Scene Unit Scale)"
    )
    
    export_format: bpy.props.EnumProperty(
        name="export_format",
        items=[('MESH', "Godot Mesh", "Export as Godot .mesh format"),
               ('OBJ', "Wavefront OBJ", "Export as .obj format")],
        default='OBJ',
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


class OBJECT_OT_GenerateTerrainChunks(bpy.types.Operator):
    """Generate sliced terrain chunks in a new collection"""
    bl_idname = "object.generate_terrain_chunks"
    bl_label = "Generate Chunks"
    bl_options = {'REGISTER', 'UNDO'}
    
    @classmethod
    def poll(cls, context):
        return context.object is not None and context.object.type == 'MESH'
        
    def execute(self, context):
        obj = context.object
        props = context.scene.terrain_export_props
        chunk_size = props.chunk_size
        
        # Ensure world matrix is updated
        bpy.context.view_layer.update()
        
        # Calculate world-space bounding box
        bbox_corners = [obj.matrix_world @ mathutils.Vector(corner) for corner in obj.bound_box]
        min_x = min([c.x for c in bbox_corners])
        max_x = max([c.x for c in bbox_corners])
        min_y = min([c.y for c in bbox_corners])
        max_y = max([c.y for c in bbox_corners])
        min_z = min([c.z for c in bbox_corners])
        max_z = max([c.z for c in bbox_corners])
        
        size_x = max_x - min_x
        size_y = max_y - min_y
        
        chunks_x = max(1, ceil(size_x / chunk_size))
        chunks_y = max(1, ceil(size_y / chunk_size))
        
        # Get base bmesh BEFORE mutating collections to avoid StructRNA invalidation!
        base_bm = bmesh.new()
        base_bm.from_mesh(obj.data)
        base_bm.transform(obj.matrix_world)
        
        # Setup collection
        collection_name = "TerrainChunks"
        if collection_name in bpy.data.collections:
            chunks_coll = bpy.data.collections[collection_name]
            for o in list(chunks_coll.objects):
                bpy.data.objects.remove(o, do_unlink=True)
        else:
            chunks_coll = bpy.data.collections.new(collection_name)
            context.scene.collection.children.link(chunks_coll)
        
        chunks_generated = 0
        
        for x in range(chunks_x):
            for y in range(chunks_y):
                chunk_min_x = min_x + (x * chunk_size)
                chunk_max_x = min_x + ((x + 1) * chunk_size)
                chunk_min_y = min_y + (y * chunk_size)
                chunk_max_y = min_y + ((y + 1) * chunk_size)
                
                chunk_bm = base_bm.copy()
                
                for plane_co, plane_no, clr_in, clr_out in [
                    ((chunk_min_x, 0, 0), (1, 0, 0), True, False),
                    ((chunk_max_x, 0, 0), (1, 0, 0), False, True),
                    ((0, chunk_min_y, 0), (0, 1, 0), True, False),
                    ((0, chunk_max_y, 0), (0, 1, 0), False, True)
                ]:
                    geom = chunk_bm.faces[:] + chunk_bm.edges[:] + chunk_bm.verts[:]
                    if not geom:
                        break
                    bmesh.ops.bisect_plane(
                        chunk_bm,
                        geom=geom,
                        plane_co=plane_co,
                        plane_no=plane_no,
                        clear_inner=clr_in,
                        clear_outer=clr_out
                    )
                    
                if len(chunk_bm.verts) > 0:
                    center_x = chunk_min_x + (chunk_size / 2.0)
                    center_y = chunk_min_y + (chunk_size / 2.0)
                    
                    for v in chunk_bm.verts:
                        v.co.x -= center_x
                        v.co.y -= center_y
                        
                    res_mesh = bpy.data.meshes.new(f"chunk_{x}_{y}")
                    chunk_bm.to_mesh(res_mesh)
                    
                    res_obj = bpy.data.objects.new(f"TerrainChunk_{x}_{y}", res_mesh)
                    res_obj.location = (center_x, center_y, 0)
                    
                    res_obj["chunk_x"] = x
                    res_obj["chunk_y"] = y
                    
                    chunks_coll.objects.link(res_obj)
                    chunks_generated += 1
                    
                chunk_bm.free()
                
        base_bm.free()
        
        chunks_coll["bbox_min"] = [min_x, min_y, min_z]
        chunks_coll["bbox_max"] = [max_x, max_y, max_z]
        chunks_coll["chunk_size"] = chunk_size
        
        self.report({'INFO'}, f"Generated {chunks_generated} chunks in 'TerrainChunks' collection.")
        return {'FINISHED'}


class OBJECT_OT_ExportTerrain(bpy.types.Operator):
    """Export generated TerrainChunks collection to engine format"""
    bl_idname = "object.export_terrain"
    bl_label = "Export Chunks"
    bl_options = {'REGISTER', 'UNDO'}
    
    @classmethod
    def poll(cls, context):
        return "TerrainChunks" in bpy.data.collections and len(bpy.data.collections["TerrainChunks"].objects) > 0
        
    def execute(self, context):
        chunks_coll = bpy.data.collections.get("TerrainChunks")
        if not chunks_coll:
            self.report({'ERROR'}, "No 'TerrainChunks' collection found. Please generate chunks first.")
            return {'CANCELLED'}
            
        props = context.scene.terrain_export_props
        export_format = props.export_format
        
        # Get scene scale multiplier (e.g., 1000.0 for Kilometers, 1.0 for Meters)
        # And multiply by any manual UI export scale they assign
        global_scale = context.scene.unit_settings.scale_length * props.export_scale
        
        blend_path = bpy.data.filepath
        if blend_path:
            base_path = bpy.path.abspath(props.export_path)
        else:
            fallback_dir = os.path.join(os.path.expanduser("~"), "Documents", "Blender_Terrain_Export")
            path_suffix = props.export_path.replace("//", "", 1)
            base_path = os.path.join(fallback_dir, path_suffix)
            
        base_path = os.path.normpath(base_path)
        os.makedirs(base_path, exist_ok=True)
        
        exported_chunks = []
        bpy.ops.object.select_all(action='DESELECT')
        
        for obj in chunks_coll.objects:
            if obj.type != 'MESH':
                continue
                
            x = obj.get("chunk_x", 0)
            y = obj.get("chunk_y", 0)
            z = 0
            
            chunk_index = f"{x}_{y}_{z}"
            chunk_filename = f"terrain_{chunk_index}"
            
            obj.select_set(True)
            context.view_layer.objects.active = obj
            
            filepath = os.path.join(base_path, chunk_filename + (".obj" if export_format == 'OBJ' else ".mesh"))
            
            if export_format == 'MESH':
                self._export_obj(filepath.replace(".mesh", ".obj"), global_scale)
            else:
                self._export_obj(filepath, global_scale)
                
            obj.select_set(False)
            
            exported_chunks.append({
                'chunk': chunk_index,
                'filename': chunk_filename,
                'position': (x, y, z)
            })
            
        metadata_file = os.path.join(base_path, "terrain_metadata.json")
        raw_min = chunks_coll.get("bbox_min", [0,0,0])
        raw_max = chunks_coll.get("bbox_max", [0,0,0])
        
        metadata = {
            'chunk_size': chunks_coll.get("chunk_size", props.chunk_size) * global_scale,
            'chunks': exported_chunks,
            'total_chunks': len(exported_chunks),
            'bbox': {
                'min': [val * global_scale for val in raw_min],
                'max': [val * global_scale for val in raw_max]
            }
        }
        
        with open(metadata_file, 'w') as f:
            json.dump(metadata, f, indent=2)
            
        self.report({'INFO'}, f"Exported {len(exported_chunks)} terrain chunks to {base_path}")
        return {'FINISHED'}

    def _export_obj(self, filepath, global_scale=1.0):
        """Export selected to .obj format"""
        bpy.ops.wm.obj_export(
            filepath=filepath,
            export_selected_objects=True,
            export_normals=True,
            export_uv=True,
            export_materials=False,
            global_scale=global_scale
        )


class VIEW3D_PT_TerrainPanel(bpy.types.Panel):
    """Creates a Panel in the Object properties window"""
    bl_label = "Terrain Exporter"
    bl_idname = "VIEW3D_PT_terrain_exporter"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = "Terrain Exporter"

    def draw(self, context):
        layout = self.layout
        scene = context.scene
        props = scene.terrain_export_props

        layout.prop(props, "chunk_size")
        layout.prop(props, "export_scale")
        layout.prop(props, "export_format")
        layout.prop(props, "export_path")
        layout.prop(props, "compute_normals")
        layout.prop(props, "planar_uv")

        layout.separator()
        layout.operator(OBJECT_OT_GenerateTerrainChunks.bl_idname)
        layout.operator(OBJECT_OT_ExportTerrain.bl_idname)


def register():
    """Register Blender addon"""
    bpy.utils.register_class(TerrainExportProperties)
    bpy.utils.register_class(OBJECT_OT_GenerateTerrainChunks)
    bpy.utils.register_class(OBJECT_OT_ExportTerrain)
    bpy.utils.register_class(VIEW3D_PT_TerrainPanel)
    bpy.types.Scene.terrain_export_props = bpy.props.PointerProperty(
        type=TerrainExportProperties,
        name="terrain_export_props",
        description="Terrain export settings"
    )


def unregister():
    """Unregister Blender addon"""
    bpy.utils.unregister_class(VIEW3D_PT_TerrainPanel)
    bpy.utils.unregister_class(TerrainExportProperties)
    bpy.utils.unregister_class(OBJECT_OT_ExportTerrain)
    bpy.utils.unregister_class(OBJECT_OT_GenerateTerrainChunks)
    del bpy.types.Scene.terrain_export_props


if __name__ == "__main__":
    register()
