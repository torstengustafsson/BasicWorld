# This class is responsible for updating the world state based on player movement.
# Delegates most of its work to dedicated threads.

class_name DistanceController extends Node3D

var lod_last_player_pos: Vector2
var terrain_last_player_index: Vector2i

var update_close_objects_time = 0
const FORCE_UPDATE_CLOSE_OBJECTS_INTERVAL_SECONDS = 5.0

var distance_controller_threads: Dictionary[String, ThreadWorker]

var player_spawn_set: bool = false
var meshes_initialized: bool = false

func _init():
	lod_last_player_pos = Vector2(WorldState.state.player.position.x, WorldState.state.player.position.z)
	terrain_last_player_index = Vector2i(0, 0)

func _ready() -> void:
	WorldState.state.terrain_generator.add_chunks_around_player(WorldState.state.player.position)

	var terrain_boundary = WorldState.state.terrain_generator.get_terrain_size()
	generate_starting_items(terrain_boundary)

	distance_controller_threads = {
		"cleanup_faraway_meshes": ThreadCleanupFarawayMeshes.new(),
		"cleanup_faraway_objects": ThreadCleanupFarawayObjects.new(),
		"add_meshes": ThreadAddMeshes.new(),
		"add_roads": ThreadAddRoads.new(),
		"add_settlements": ThreadAddSettlements.new(),
	}

func _process(delta: float) -> void:
	TerrainManager.update_angle_positions() # Needed by threads
	WorldState.state.pool_manager.apply_queued_updates() # Threads queue mesh updates like position. Main thread apply them here

	# Check for when threads are fully initialized
	if not player_spawn_set \
		and (distance_controller_threads["add_settlements"].initialization_completed or Engine.get_process_frames() > 5):
		# Player will spawn in the nearest settlement, if it is created within 5 frames. If not, player will spawn at origin
		player_spawn_set = true
		initalize_player_spawn()
	if not meshes_initialized and distance_controller_threads["add_meshes"].initialization_completed:
		# add_nearby_objects need to be called as soon as meshes have been added to avoid empty meshes without colliders near player spawn
		meshes_initialized = true
		add_nearby_objects()

	var player_chunk_index = WorldState.state.terrain_generator.get_player_chunk_index(WorldState.state.player.position)
	if player_chunk_index != terrain_last_player_index:
		WorldState.state.terrain_generator.update_chunks_around_player(WorldState.state.player.position, 1)
		terrain_last_player_index = player_chunk_index

	update_close_objects_time += delta
	var distance_traveled = (Vector2(WorldState.state.player.position.x, WorldState.state.player.position.z) - lod_last_player_pos).length()
	if update_close_objects_time > FORCE_UPDATE_CLOSE_OBJECTS_INTERVAL_SECONDS or distance_traveled > Globals.LOD_UPDATE_DISTANCE:
		add_nearby_objects()
		#cleanup_faraway_objects()
		lod_last_player_pos = Vector2(WorldState.state.player.position.x, WorldState.state.player.position.z)
		update_close_objects_time = 0

	for thread in distance_controller_threads.values():
		thread.wake_up_thread()
		thread.update_player_position(WorldState.state.player.position)

func initalize_player_spawn():
	# Make player spawn in a settlement if possible
	var settlements = WorldState.state.settlement_manager.settlements.query_all()
	if settlements.size() > 0:
		var pos = settlements[0].position
		var angle = TerrainManager.get_terrain_angle_at_position(pos)
		WorldState.state.player.position = pos + Vector3(randf_range(-2.0, 2.0), min(abs(angle), 10.0), randf_range(-2.0, 2.0))
	add_nearby_objects()
	WorldState.state.npc_manager.create_tutorial_npc(WorldState.state.player.position)
	var axe_position = WorldState.state.player.position + Vector3(-1.0, 2.0, -4.0)
	WorldState.state.item_generator.spawn_item(axe_position, ItemProperties.Item.AXE)
	var pickaxe_position = WorldState.state.player.position + Vector3(1.0, 2.0, -4.0)
	WorldState.state.item_generator.spawn_item(pickaxe_position, ItemProperties.Item.PICKAXE)


# This function requires meshes to have been added first, otherwise, no objects will spawn
func add_nearby_objects():
	var nearby_mesh_objects = WorldState.state.pool_manager.get_meshes_in_range(WorldState.state.player.position, Globals.LOD_DISTANCE_FULL)
	for mesh_object: MeshObject in nearby_mesh_objects:
		WorldState.state.pool_manager.add_object(mesh_object)

func cleanup_faraway_objects():
	const INNER_BOUNDS = Globals.LOD_DISTANCE_FULL * Globals.LOD_REMOVE_DISTANCE_MULTIPLIER
	var boundary_to_keep: Rect2 = Rect2(
		Vector2(WorldState.state.player.position.x - INNER_BOUNDS, WorldState.state.player.position.z - INNER_BOUNDS),
		Vector2(INNER_BOUNDS * 2, INNER_BOUNDS * 2)
	)
	WorldState.state.pool_manager.remove_faraway_world_objects(boundary_to_keep)

# TODO: Add object pool for items
func generate_starting_items(boundary):
	var get_random_position = func() -> Vector3:
		return Vector3(
			WorldState.state.rng.randf_range(boundary.position.x, boundary.end.x),
			5.0,
			WorldState.state.rng.randf_range(boundary.position.y, boundary.end.y))

	for berry in 40:
		var berry_position = get_random_position.call()
		WorldState.state.item_generator.spawn_item(berry_position, ItemProperties.Item.BERRY)

	for wood in 40:
		var wood_position = get_random_position.call()
		WorldState.state.item_generator.spawn_item(wood_position, ItemProperties.Item.WOOD)

	for stone in 40:
		var stone_position = get_random_position.call()
		WorldState.state.item_generator.spawn_item(stone_position, ItemProperties.Item.STONE)

func _on_exit():
	for thread in distance_controller_threads.values():
		thread.stop()
