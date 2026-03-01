# Blender Add-on Configuration

# Chunk Settings
CHUNK_SIZE = 64              # Vertices per chunk side (must be power of 2 for efficiency)
CHUNK_POWER = 6             # LOG2(CHUNK_SIZE) - ensures efficient chunk sizes

# Export Settings
EXPORT_FORMAT = "mesh"        # "mesh" or "obj"
EXPORT_PATH = "//exported_terrain/"

# Quality Settings
COMPUTE_NORMALS = True         # Calculate face normals for proper lighting
PLANAR_UV = True              # Use planar UV projection for terrain textures
SMOOTH_NORMALS = False          # Don't smooth normals (preserves sharp terrain features)

# Advanced Settings
USE_LOD = False                # Enable Level of Detail (Level of Detail)
LOD_LEVELS = 3                # Number of LOD levels
MIN_CHUNK_VERTICES = 32        # Minimum vertices for a chunk
