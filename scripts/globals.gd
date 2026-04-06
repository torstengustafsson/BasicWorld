class_name Globals

# The random seed used for all the worlds objects and logic
const RANDOM_SEED = "random"

# The size of the world. Objects will only be created in this area.
# TODO: Set to INF for infinite world.
const WORLD_SIZE: float = 1000.0

# Each terrain resolution halves the detail, and doubles the amount of chunks in the distance
const NUM_CHUNK_RESOLUTIONS: int = 4
const TERRAIN_CHUNK_SIZE: int = 256

# Average distance between each object on generation.
# Lower values means more clumped up. So Low value for STEP_TREES means dense forests.
const STEP_TREES = 4
const STEP_BERRYBUSHES = 10
const STEP_ROCKS = 10

# World grid is used for determining pathfinding and road generation.
# Step is average distance between grid points. Lower value means more detailed pathfinding, but
# takes longer to generate.
const WORLD_GRID_STEP: float = 10.0

# Settlement spread must be less than half of settlement grid step to avoid overlap
const SETTLEMENT_GRID_STEP = 20
const SETTLEMENT_GRID_SPREAD = 8
# Adda margin to avoid having settlements at the edge of the world
const SETTLEMENT_WORLD_EDGE_MARGIN = 1 + Globals.SETTLEMENT_GRID_SPREAD
const MAX_SETTLEMENT_DISTANCE_FOR_ROAD: float = 300.0

# All roads will have this width
const ROAD_WIDTH: float = 1.5

# Level of detail is set up so that objects within LOD_DISTANCE_FULL get a collider, and objects
# outside of LOD_DISTANCE_NO_COLLIDER are removed from the scene. The check is made whenever the
# player moves beyond LOD_UPDATE_DISTANCE from its position at the last update.
const LOD_DISTANCE_FULL = 50.0
const LOD_DISTANCE_NO_COLLIDER = 300.0
const LOD_UPDATE_DISTANCE = 25.0 # Objects will spawn and despawn whenever player moves this distance
