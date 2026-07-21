class_name Globals

# The random seed used for all the worlds objects and logic
# Set to specific string to get repeatable result
static var RANDOM_SEED = MathFunctions.generate_random_seed()

const MAX_INT = 9223372036854775807

# Each terrain resolution halves the detail, and doubles the amount of chunks in the distance
# Must be minimum 1, since that is the max resolution.
const NUM_CHUNK_RESOLUTIONS: int = 3
const TERRAIN_CHUNK_SIZE: int = 256
const TERRAIN_RESOLUTION_MULTIPLIER: float = 0.25

# Average distance between each object on generation.
# Lower values means more clumped up. So Low value for STEP_TREES means dense forests.
const STEP_TREES: int = 6
const STEP_BERRYBUSHES: int = 32
const STEP_ROCKS: int = 16

# World grid is used for determining pathfinding and road generation.
# Step is average distance between grid points. Lower value means more detailed pathfinding, but
# takes longer to generate.
const WORLD_GRID_STEP: float = 32.0

# The max height-angle in degrees that two gridpoints can be connected by
const MAX_GRID_STEEPNESS = 10.0

# Settlement spread must be less than half of settlement grid step to avoid overlap
const SETTLEMENT_GRID_STEP = 12
const SETTLEMENT_GRID_SPREAD = 4
const MAX_SETTLEMENT_RADIUS = 16.0
const MAX_SETTLEMENT_DISTANCE_FOR_ROAD: float = 768.0

# The max height-angle in degrees that a settlements gridpoint and its edges can be connected by
# This gives an approximation of even terrain for the settlement. It assumes the radius of the
# settlement is about the same as the distance between the grid points. (settlement position is always on a grid point)
const MAX_SETTLEMENT_STEEPNESS = 5.0

# The max height-angle in degrees that objects can be generated on
const MAX_OBJECT_STEEPNESS = 25.0

# All roads will have this width, and objects will be removed from the road with extra margin.
const ROAD_WIDTH: float = 1.5
const ROAD_MARGIN: float = 0.5

# All added objects are sorted into chunks of multimeshes. Each such chunk have a fixed size of x- and z dimensions.
const MULTIMESH_CHUNK_SIZE = 128.0
const MULTIMESH_CHUNK_MAX_INSTANCES = 1000

# Level of detail is set up so that objects within LOD_DISTANCE_FULL get a collider, and objects
# outside of LOD_DISTANCE_NO_COLLIDER are removed from the scene. The check is made whenever the
# player moves beyond LOD_UPDATE_DISTANCE from its position at the last update.
# NOTE: LOD_DISTANCE_FULL must be >= LOD_UPDATE_DISTANCE.
const LOD_DISTANCE_FULL = 64.0
const LOD_DISTANCE_NO_COLLIDER = 192.0
const LOD_UPDATE_DISTANCE = LOD_DISTANCE_FULL * 0.5 # Objects will spawn and despawn whenever player moves this distance
const LOD_REMOVE_DISTANCE_MULTIPLIER = 3.0 # A value of 1.2 means wait to remove faraway objects until 20% more distance than LOD_DISTANCE_NO_COLLIDER away

# Internal values, should generally not be touched
const OUT_OF_SIGHT = Vector3(-1000000.0, -1000000.0, -1000000.0)
const NOT_A_NUMBER: float = INF
