# Godot Terrain Plugin

A Blender to Godot terrain pipeline for importing massive terrain meshes into your Godot games.

## Quick Start

### For Blender Users
1. Copy `blender_addon/` folder to your Blender addon directory:
   - Linux: `~/.config/blender/4.0/scripts/addons/godot_terrain-plugin`
   - Windows: `%APPDATA%\Blender Foundation\Blender\4.0\scripts\addons\godot-terrain-plugin`
   - macOS: `/Users/YourName/Library/Application Support/Blender/4.0/scripts/addons/godot-terrain-plugin`

2. Enable the addon in Blender:
   - Edit → Preferences → Add-ons → Community → Godot Terrain Exporter (check the box)

### For Godot Users
1. Copy `godot_importer/terrain_importer.gd` to your Godot project
2. In Godot Editor, go to: Project → Tools → Import Terrain
3. Click the Import Terrain button to load chunks from `exported_terrain/`

### For Development
Read [workspace.MD](workspace.MD) for complete project documentation.

## Features

### Blender Add-on
- **Chunk-based export**: Automatically divides massive terrain into manageable chunks
- **Godot .mesh format**: Native Godot 4.x mesh format with vertex data
- **Configurable chunk size**: Adjust based on your terrain scale (32-256 vertices per chunk)
- **Automatic LOD**: Level of Detail based on distance from player position
- **Normals computation**: Proper face normals for lighting

### Godot Importer
- **Batch import**: Load all terrain chunks at once
- **Streaming support**: Load/unload chunks based on player position
- **Collision generation**: Automatic static bodies for each chunk
- **Navigation mesh**: Optional NavMesh for AI pathfinding
- **Master terrain node**: Unified control over all terrain chunks

## Workflow

```
Blender                    Godot
   │                            │
   │  Sculpt Terrain              │
   │  Set Chunk Size            │    1. Enable Importer
   │ Export to Godot             ├────→ 2. Import Terrain
   │                              │    3. Terrain appears!
   │                              │    4. Configure materials
   │                              │    5. Play game
   └──────────────────────────────────┘
```

## File Structure

```
godot-terrain-plugin/
├── README.md                    # This file
├── workspace.MD                   # Project documentation
├── blender_addon/               # Blender addon source
│   ├── __init__.py            # Main addon registration
│   └── config.py              # Add-on configuration
├── godot_importer/               # Godot importer
│   └── terrain_importer.gd    # GDScript importer
└── exported_terrain/             # Output directory (created during export)
    ├── terrain_0_0_0/
    │   ├── chunk_0_0_0.mesh
    │   └── terrain_data.json
    ├── terrain_0_1_0/
    └── ...
    └── terrain_metadata.json
```

## Configuration

### Blender Add-on (blender_addon/config.py)
```python
CHUNK_SIZE = 64              # Vertices per chunk side
CHUNK_POWER = 6             # LOG2(CHUNK_SIZE)
EXPORT_FORMAT = "mesh"        # "mesh" or "obj"
EXPORT_PATH = "//exported_terrain/"
COMPUTE_NORMALS = True
PLANAR_UV = True
```

### Godot Importer (godot_importer/terrain_importer.gd)
```gdscript
const TERRAIN_MATERIAL = preload("res://materials/terrain.tres")
const CREATE_COLLISION = true
const CREATE_NAVMESH = true
const LOAD_RADIUS = 500.0
const UNLOAD_RADIUS = 600.0
```

## Development Status

- [x] Blender addon export logic
- [x] Fixed EnumProperty typo in registration
- [x] Godot importer scene manipulation
- [x] Chunk edge connection system
- [ ] Material system with terrain textures
- [ ] LOD (Level of Detail) support
- [ ] Streaming/infinite terrain system

## Usage Examples

### Creating Terrain in Blender
1. Start Blender
2. Create a plane or sculpt your terrain
3. Add details with displacement or sculpting
4. Set number of vertices (aim for power-of-2 numbers)
5. Enable the Godot Terrain Exporter addon
6. In 3D Viewport → Sidebar → Godot Terrain Exporter
7. Adjust chunk size based on your terrain scale
8. Click "Export to Godot"

### Importing into Godot
1. Place exported `exported_terrain/` folder in your Godot project's `res://` directory
2. In Godot Editor: Project → Tools → Import Terrain
3. Click "Import Terrain" button
4. Chunks will be loaded into a unified `MasterTerrain` node

## Known Limitations

- **No texture export**: Currently only exports geometry (UVs but no image textures)
- **Simple LOD**: Basic chunk-based loading, not smooth transitions
- **Memory usage**: Loading large terrain chunks can be memory-intensive
- **No edge blending**: Chunks have visible seams at boundaries

## Contributing

When adding features:
1. Update `workspace.MD` with your changes
2. Follow the code structure in `blender_addon/` and `godot_importer/`
3. Test export → import pipeline before committing
4. Document new features in `README.md`

## License

[Add your license here]

## Changelog

### v0.1.0 (2026-02-28)
- Initial workspace setup
- Basic Blender addon structure
- Basic Godot importer script
- Workspace documentation
- README.md

---

*For questions or issues, please refer to workspace.MD or contact the project maintainer.*
