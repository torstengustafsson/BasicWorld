extends Node3D

class_name WorldState

# NOTE: Must use this generator for all random values, in order for world generation to be deterministic based on the seed.
var rng: RandomNumberGenerator
var space_state: PhysicsDirectSpaceState3D
var world_grid: WorldGrid
var static_objects_qt: Quadtree
var terrain_height_noise: TerrainNoise
var player: Node3D # Only used for position

func _init(_player: Node3D) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = hash(Globals.RANDOM_SEED)
	static_objects_qt = Quadtree.new()
	terrain_height_noise = TerrainNoise.new(rng)
	player = _player
