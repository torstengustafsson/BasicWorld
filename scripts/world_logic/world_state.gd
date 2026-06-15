extends Node3D

class_name WorldState

var terrain_generator: TerrainGenerator
var object_generator: ObjectGenerator
var item_generator: WorldItemGenerator
var settlements_generator: SettlementGenerator
var road_generator: RoadGenerator
var npcs_generator: NpcGenerator
var world_grid: WorldGrid

# NOTE: Must use this generator for all random values, in order for world generation to be deterministic based on the seed.
var rng: RandomNumberGenerator
var space_state: PhysicsDirectSpaceState3D
var static_objects_qt: Quadtree
var terrain_height_noise: TerrainNoise
var player: Node3D # Only used for position

func _init(_player: Node3D) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = hash(Globals.RANDOM_SEED)
	static_objects_qt = Quadtree.new()
	static_objects_qt.boundary = Rect2(Vector2(-INF, -INF), Vector2(INF, INF))
	terrain_height_noise = TerrainNoise.new(rng)
	player = _player

func _ready() -> void:
	terrain_generator = TerrainGenerator.new(terrain_height_noise)
	object_generator = ObjectGenerator.new(self)
	item_generator = WorldItemGenerator.new(self)
	settlements_generator = SettlementGenerator.new(self)
	road_generator = RoadGenerator.new(self, settlements_generator)
	npcs_generator = NpcGenerator.new(self, settlements_generator)
	world_grid = WorldGrid.new(self)

	add_child(terrain_generator)
	add_child(object_generator)
	add_child(item_generator)
	add_child(world_grid)
	add_child(road_generator)
