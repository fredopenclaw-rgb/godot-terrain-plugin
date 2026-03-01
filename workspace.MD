# Godot Terrain Plugin Workspace

## Project Overview
This workspace contains development files for a Blender add-on that exports terrain meshes to Godot game engine. The plugin generates massive terrain from Blender and exports it in a format ready for use in Godot 4.x.

## Project Structure

```
godot-terrain-plugin/
├── workspace.MD              # This file - project documentation
├── blender_addon/           # Blender Python addon source code
├── godot_importer/         # Godot importer script
└── exported_terrain/         # Output directory for terrain chunks (created during export)
```

## Terrain Export System

### Chunk Organization
The Blender add-on slices massive terrain into manageable chunks and exports them with the following naming convention:

**Position-based chunks:** `terrain_X_Y_Z`
- Example: `terrain_0_0_0` (first chunk at origin 0,0,0)
- Example: `terrain_1_0_0` (next chunk at x=1, y=0, z=0)
- Example: `terrain_0_-1_0` (chunk at x=0, y=-1, z=0)

**Mesh files:** `chunk_<position>.mesh`
- Example: `chunk_0_0_0.mesh` (mesh file for first chunk)
- Example: `chunk_1_0_0.mesh` (mesh file for x=1 chunk)

### Export Folder Structure
```
exported_terrain/
├── terrain_0_0_0/
│   ├── chunk_0_0_0.mesh
│   ├── chunk_0_0_0.mesh
│   └── terrain_data.json
├── terrain_0_1_0/
│   └── chunk_0_1_0.mesh
└── terrain_0_-1_0/
    └── chunk_0_-1_0.mesh
```

## Blender Add-on Features

### Export Settings
- **Chunk Size:** Configurable grid division (e.g., 64x64, 128x128 vertices per chunk)
- **LOD System:** Automatic Level of Detail based on distance from origin
- **Normals:** Calculated per face for proper lighting
- **UV Unwrapping:** Automatic planar projection for terrain textures
- **Format Options:** .obj or .mesh (Godot 4.x compatible)

### Export Process
1. User selects terrain mesh in Blender
2. Click "Export to Godot" button in terrain panel
3. Add-on calculates optimal chunk division
4. Slices terrain into grid-based chunks
5. Exports each chunk as separate .mesh file
6. Creates `exported_terrain/` folder with organized structure
7. Generates metadata JSON for chunk positions and connections

## Godot Importer

### Import Button
Located in Godot's `Project > Tools > Import Terrain`

Features:
- **Batch Import:** Import all terrain chunks at once
- **Auto-Assembly:** Automatically positions chunks based on world coordinates
- **Collision Shapes:** Generates static bodies for each terrain chunk
- **Material Assignment:** Applies default terrain material (configurable)
- **Navigation Mesh:** Optionally creates NavMesh for AI pathfinding

### Master Terrain Node
All chunks are parented to a master `MasterTerrain` node for unified control:
```
MasterTerrain
├── terrain_0_0_0 (Spatial)
├── terrain_0_1_0 (Spatial)
├── terrain_0_-1_0 (Spatial)
└── terrain_1_0_0 (Spatial)
```

## Usage Workflow

### For Developers
1. **Setup:** Open workspace in your code editor
2. **Develop:** Modify Blender add-on or Godot importer as needed
3. **Test:** Export terrain from Blender, import into Godot
4. **Iterate:** Adjust chunk size, LOD settings, based on performance

### For Game Designers
1. **Create Terrain:** Design terrain in Blender using sculpting, displacement, or height maps
2. **Export:** Use Blender add-on to export to Godot format
3. **Import:** Click "Import Terrain" button in Godot
4. **Configure:** Adjust materials, collision settings as needed
5. **Use:** Terrain appears in Godot scene ready for gameplay

## File Formats

### Blender Add-on (blender_addon/)
- Python files for Blender 4.0+ addon development
- Main entry point: `__init__.py` registers panels and operators
- Export operators handle mesh generation and file I/O

### Godot Importer (godot_importer/)
- GDScript file (.gd) for Godot 4.x
- Runs in editor context (tools menu)
- Handles scene manipulation and node creation

### Exported Data (exported_terrain/)
- Output directory - created during Blender export
- Contains `.mesh` files and optional metadata
- Committed to version control when terrain is finalized

## Configuration Files

### blender_addon/config.py
```python
# Blender Add-on Configuration

CHUNK_SIZE = 64  # Vertices per chunk side
EXPORT_FORMAT = "mesh"  # "mesh" or "obj"
EXPORT_PATH = "//exported_terrain/"
COMPUTE_NORMALS = True
PLANAR_UV = True
```

### godot_importer/settings.gd
```gdscript
# Godot Importer Configuration

const TERRAIN_MATERIAL = preload("res://materials/terrain.tres")
const CREATE_COLLISION = true
const CREATE_NAVMESH = true
const ASSEMBLE_MASTER = true
```

## Development Notes

### Current Status
- Workspace created
- Basic structure documented
- Ready for addon and importer development

### TODO Items
- [ ] Implement Blender addon export logic
- [ ] Implement Godot importer scene manipulation
- [ ] Add chunk edge connection system
- [ ] Create material system
- [ ] Add LOD (Level of Detail) support
- [ ] Implement streaming/infinite terrain system

## AI Agent Instructions

When working on this project:

1. **Read workspace.MD** first to understand project structure
2. **Check blender_addon/** for existing code before modifying**
3. **Update workspace.MD** with your changes
4. **Test export → import pipeline** before committing

## Contact & Support
- **Project:** Godot Terrain Plugin
- **Workspace:** `/home/silas/.openclaw/workspace/godot-terrain-plugin/`
- **Blender Version:** 4.0+
- **Godot Version:** 4.x
- **Status:** Initial workspace setup

---

*Last updated: February 28, 2026*
