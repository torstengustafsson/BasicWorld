# This class is responsible for updating the world state based on player movement.
# Delegates most of its work to dedicated threads.

class_name DistanceController extends Node3D

var lod_last_player_pos: Vector2
var terrain_last_player_index: Vector2i

var update_close_objects_time = 0
const FORCE_UPDATE_CLOSE_OBJECTS_INTERVAL_SECONDS = 5.0

const INITIAL_BATCH_SIZE = 1000

var player_spawn_set: bool = false
var meshes_initialized: bool = false

func _init():
	lod_last_player_pos = Vector2(WorldState.state.player.position.x, WorldState.state.player.position.z)
	terrain_last_player_index = Vector2i(0, 0)

func initialize_world(new_game: bool = true) -> void:
	WorldState.state.terrain_generator.add_chunks_around_player(WorldState.state.player.position)
	await get_tree().process_frame

	update_world(INITIAL_BATCH_SIZE)
	if new_game:
		initalize_player_spawn()

		var around_player = Rect2(
			Vector2(WorldState.state.player.position.x - Globals.LOD_DISTANCE_FULL, WorldState.state.player.position.z - Globals.LOD_DISTANCE_FULL),
			Vector2(2 * Globals.LOD_DISTANCE_FULL, 2 * Globals.LOD_DISTANCE_FULL)
		)
		WorldState.state.item_manager.generate_starting_items(around_player, 15)

func _process(delta: float) -> void:
	TerrainManager.update_angle_positions() # Needed by threads

	var player_chunk_index = WorldState.state.terrain_generator.get_player_chunk_index(WorldState.state.player.position)
	if player_chunk_index != terrain_last_player_index:
		WorldState.state.terrain_generator.update_chunks_around_player(WorldState.state.player.position, 1)
		terrain_last_player_index = player_chunk_index

	update_close_objects_time += delta
	var distance_traveled = (Vector2(WorldState.state.player.position.x, WorldState.state.player.position.z) - lod_last_player_pos).length()
	if update_close_objects_time > FORCE_UPDATE_CLOSE_OBJECTS_INTERVAL_SECONDS or distance_traveled > Globals.LOD_UPDATE_DISTANCE:
		update_world()
		lod_last_player_pos = Vector2(WorldState.state.player.position.x, WorldState.state.player.position.z)
		update_close_objects_time = 0

func initalize_player_spawn():
	# Make player spawn in a settlement if possible
	var settlements = WorldState.state.settlement_manager.settlements.query_all()
	if settlements.size() > 0:
		var pos = settlements[0].position + Vector3(WorldState.state.rng.randf_range(-2.0, 2.0), 0.0, WorldState.state.rng.randf_range(-2.0, 2.0))
		var pos_with_height = Vector3(pos.x, WorldState.state.terrain_height_noise.get_height_at(pos.x, pos.z), pos.z)
		WorldState.state.player.position = pos_with_height
	update_world(INITIAL_BATCH_SIZE)
	WorldState.state.npc_manager.create_tutorial_npc(WorldState.state.player.position)

func update_world(batch_size: int = 3):
	_update_world_faraway(batch_size)
	_update_world_close()
	_cleanup_world_faraway()
	_cleanup_world_close()

# We use batched update here to avoid the worst of the performance hit of creating new multimesh chunks
func _update_world_faraway(batch_size: int = 3):
	# Create roads and settlements firther away that object. This is mainly to prevent objects (like trees) being
	# created before them, which would lead to undesired behavior since object creation checks against collision with
	# them, but not the other way around.
	const OUTER_BOUNDS = Globals.LOD_DISTANCE_NO_COLLIDER * 1.5
	var player_position = WorldState.state.player.position
	var outer_boundary: Rect2 = Rect2(
		Vector2(player_position.x - OUTER_BOUNDS, player_position.z - OUTER_BOUNDS),
		Vector2(OUTER_BOUNDS * 2, OUTER_BOUNDS * 2)
	)
	var nearby_settlements: Array[SettlementManager.SettlementData] = WorldState.state.settlement_manager.create_settlements(outer_boundary)
	WorldState.state.npc_manager.create_npcs_in_settlements(nearby_settlements)
	WorldState.state.road_manager.generate_roads(outer_boundary)
	var nearby_road_segments: Array = WorldState.state.road_manager.get_roads_in_area(outer_boundary)
	WorldState.state.terrain_generator.update_shader_data(nearby_settlements, nearby_road_segments)

	# Objects get the "normal" boundary
	var boundary: Rect2 = Rect2(
		Vector2(player_position.x - Globals.LOD_DISTANCE_NO_COLLIDER, player_position.z - Globals.LOD_DISTANCE_NO_COLLIDER),
		Vector2(Globals.LOD_DISTANCE_NO_COLLIDER * 2, Globals.LOD_DISTANCE_NO_COLLIDER * 2)
	)
	WorldState.state.multimesh_manager.add_multimesh_chunks(boundary, batch_size)

# Requires update_world_faraway to have been run before
func _update_world_close():
	const INNER_BOUNDS = Globals.LOD_DISTANCE_FULL
	var player_position = WorldState.state.player.position
	var boundary: Rect2 = Rect2(
		Vector2(player_position.x - INNER_BOUNDS, player_position.z - INNER_BOUNDS),
		Vector2(INNER_BOUNDS * 2, INNER_BOUNDS * 2)
	)
	WorldState.state.multimesh_manager.add_colliders(boundary)

func _cleanup_world_faraway():
	const INNER_BOUNDS = Globals.LOD_DISTANCE_NO_COLLIDER * Globals.LOD_REMOVE_DISTANCE_MULTIPLIER
	var boundary_to_keep: Rect2 = Rect2(
		Vector2(WorldState.state.player.position.x - INNER_BOUNDS, WorldState.state.player.position.z - INNER_BOUNDS),
		Vector2(INNER_BOUNDS * 2, INNER_BOUNDS * 2)
	)
	WorldState.state.multimesh_manager.remove_multimesh_chunks(boundary_to_keep)

func _cleanup_world_close():
	const INNER_BOUNDS = Globals.LOD_DISTANCE_FULL * Globals.LOD_REMOVE_DISTANCE_MULTIPLIER
	var boundary_to_keep: Rect2 = Rect2(
		Vector2(WorldState.state.player.position.x - INNER_BOUNDS, WorldState.state.player.position.z - INNER_BOUNDS),
		Vector2(INNER_BOUNDS * 2, INNER_BOUNDS * 2)
	)
	WorldState.state.multimesh_manager.remove_faraway_colliders(boundary_to_keep)
