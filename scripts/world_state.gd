class_name WorldState extends Node3D

# Contains all information needed to recreate a modified world state
class StateInformation:
	var world_seed: String
	var player: Node3D
	var deleted_objects: Array[Vector2] = []
	var deleted_npcs: Array[Vector2] = []
	var tutorial_npc_position: Vector2 = Vector2.INF
	var world_items: Array[Vector4] = []

static var state: WorldState

var rng: RandomNumberGenerator
var terrain_generator: TerrainGenerator
var multimesh_manager: MultiMeshManager
var object_manager: ObjectManager
var item_manager: WorldItemManager
var settlement_manager: SettlementManager
var road_manager: RoadManager
var npc_manager: NpcManager
var world_grid: WorldGrid
var audio_manager: AudioManager

var state_info: StateInformation
var space_state: PhysicsDirectSpaceState3D
var terrain_height_noise: TerrainNoise
var player: Node3D # Only used for position

static func create_state(_state_info: StateInformation):
	var result: WorldState = WorldState.new()
	result.state_info = _state_info
	result.rng = RandomNumberGenerator.new()
	result.rng.seed = hash(result.state_info.world_seed)
	result.player = result.state_info.player
	result.terrain_height_noise = TerrainNoise.new(result.rng)
	result.terrain_generator = TerrainGenerator.new(result.terrain_height_noise)
	result.multimesh_manager = MultiMeshManager.new(result.state_info.deleted_objects)
	result.object_manager = ObjectManager.new(result.rng)
	result.item_manager = WorldItemManager.new(result.rng, result.state_info.world_items)
	result.settlement_manager = SettlementManager.new()
	result.road_manager = RoadManager.new()
	result.npc_manager = NpcManager.new()
	result.world_grid = WorldGrid.new()
	result.audio_manager = AudioManager.new()
	return result

func _ready() -> void:
	add_child(terrain_generator)
	add_child(multimesh_manager)
	add_child(object_manager)
	add_child(item_manager)
	add_child(settlement_manager)
	add_child(npc_manager)
	add_child(world_grid)
	add_child(road_manager)
	add_child(audio_manager)

func destroy():
	terrain_generator.destroy()
	multimesh_manager.destroy()
	object_manager.destroy()
	item_manager.destroy()
	settlement_manager.destroy()
	npc_manager.destroy()
	world_grid.destroy()
	road_manager.destroy()
	audio_manager.destroy()

func save() -> Dictionary:
	var result: Dictionary = {}
	result["world_seed"] = state_info.world_seed
	result["player_transform"] = MathFunctions.transform_to_array(player.transform)
	result["world_item_manager"] = item_manager.save()
	result["multimesh_manager"] = multimesh_manager.save()
	result["npc_manager"] = npc_manager.save()
	return result

static func load(data: Dictionary, _player: Node3D) -> StateInformation:
	var result: StateInformation = StateInformation.new()
	result.world_seed = data["world_seed"]
	result.player = _player
	result.player.transform = MathFunctions.array_to_transform(data["player_transform"])
	result.world_items = WorldItemManager.load(data["world_item_manager"])
	result.deleted_objects = MultiMeshManager.load(data["multimesh_manager"])
	var npc_data = NpcManager.load(data["npc_manager"])
	# Special case: Tutorial NPC position will always be stored last in NpcManager.load()
	if data["npc_manager"].has("tutorial_npc"):
		result.tutorial_npc_position = npc_data.pop_back()
	result.deleted_npcs = npc_data
	return result
