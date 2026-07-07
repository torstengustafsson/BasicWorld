extends Node3D

class_name WorldState

static var state: WorldState

var terrain_generator: TerrainGenerator
var pool_manager: PoolManager
var object_manager: ObjectManager
var item_generator: WorldItemGenerator
var settlement_manager: SettlementManager
var road_generator: RoadGenerator
var npc_manager: NpcManager
var world_grid: WorldGrid
var audio_manager: AudioManager

# NOTE: Must use this generator for all random values, in order for world generation to be deterministic based on the seed.
var rng: RandomNumberGenerator
var space_state: PhysicsDirectSpaceState3D
var terrain_height_noise: TerrainNoise
var player: Node3D # Only used for position

func _init(_player: Node3D) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = hash(Globals.RANDOM_SEED)
	terrain_height_noise = TerrainNoise.new(rng)
	player = _player

	terrain_generator = TerrainGenerator.new(terrain_height_noise)
	pool_manager = PoolManager.new()
	object_manager = ObjectManager.new(rng)
	item_generator = WorldItemGenerator.new()
	settlement_manager = SettlementManager.new()
	road_generator = RoadGenerator.new()
	npc_manager = NpcManager.new()
	world_grid = WorldGrid.new()
	audio_manager = AudioManager.new()


func _ready() -> void:
	add_child(terrain_generator)
	add_child(pool_manager)
	add_child(object_manager)
	add_child(item_generator)
	add_child(settlement_manager)
	add_child(npc_manager)
	add_child(world_grid)
	add_child(road_generator)
	add_child(audio_manager)
