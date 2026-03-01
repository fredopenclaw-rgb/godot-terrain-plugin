# Godot Terrain Plugin

A Blender to Godot terrain pipeline for importing massive terrain meshes into your Godot games.

## Version History

### v1.0.1 - Current Release (2026-03-01)
- Fixed Blender addon installation by creating proper ZIP package
- Direct Blender UI installation from ZIP file
- Works with both folder-based and ZIP-based installation
- Latest and recommended version

### v1.0.0 - Initial Release (2026-03-01)
- Initial release with folder-based installation
- Required dragging and dropping files into Blender

### v1.0.2 - Broken (Deleted 2026-03-01)
- Attempted to create duplicate release tag
- Deleted (was duplicate of v1.0.1)

---

## Quick Start

### For Blender Users
1. **Download v1.0.1 (recommended):** https://github.com/fredopenclaw-rgb/godot-terrain-plugin/releases/download/v1.0.1/godot-terrain-plugin-blender-addon-v1.0.1.zip
2. **Install in Blender:**
   - Edit → Preferences → Add-ons → Community → Godot Terrain Exporter (check to box)
3. **Open 3D Viewport** → Sidebar → Godot Terrain Exporter
4. Adjust settings if needed (chunk size, export format)
5. **Select your terrain mesh**
6. Click **"Export to Godot"**

### For Godot Users
1. **Download v1.0.1:** Copy `godot_importer/terrain_importer.gd` to your Godot project
2. **In Godot Editor:**
   - Project → Tools → Import Terrain
3. Click **"Import Terrain"** button
4. Your terrain appears as `MasterTerrain` node!

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
   │  Set Chunk Size            │    1. Install Importer
   │  Export to Godot             ├────→ 2. Import Terrain
   │                              │    3. Terrain appears!
   │                              │    4. Configure materials
   │                              │    5. Play game
   └──────────────────────────────────┘
```

## File Structure

```
godot-terrain-plugin/
├── README.md                    # This file
├── CHANGELOG.md                # Version history and changes
├── workspace.MD                   # Project documentation
├── blender_addon/               # Blender addon source
│   ├── __init__.py            # Main addon with export operator
│   └── config.py              # Add-on configuration
├── godot_importer/               # Godot importer
│   └── terrain_importer.gd    # GDScript with chunk loading
└── exported_terrain/             # Output directory (created during export)
```

## Development Status

- [x] Blender addon export logic (working)
- [x] Godot importer scene manipulation (working)
- [x] Chunk edge connection system (not implemented)
- [x] Material system with terrain textures (not implemented)
- [x] LOD (Level of Detail) support (not implemented)
- [x] Streaming/infinite terrain system (not implemented)

## License

MIT License - Free to use, modify, and distribute

## Contributing

When adding features:
1. Update `CHANGELOG.md` with your changes
2. Update version numbers in `blender_addon/__init__.py`
3. Test export → import pipeline before committing
4. Document new features in `README.md`

---

*For questions or issues, please refer to README.md or contact: project maintainer*
