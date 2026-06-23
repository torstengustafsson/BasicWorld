extends Node3D

class_name DistanceController

var lod_last_player_pos: Vector2
var terrain_last_player_index: Vector2i

var update_close_objects_time = 0
const FORCE_UPDATE_CLOSE_OBJECTS_INTERVAL_SECONDS = 2.0

var cleanup_faraway_objects_time = 0
const FORCE_CLEANUP_FARAWAY_OBJECTS_INTERVAL_SECONDS = 10.0


func _init():
	lod_last_player_pos = Vector2(WorldState.state.player.position.x, WorldState.state.player.position.z)
	terrain_last_player_index = Vector2i(0, 0)

func _ready() -> void:
	WorldState.state.terrain_generator.add_chunks_around_player(WorldState.state.player.position)

	# TODO: Find out why we need to wait here.
	# Without the wait, ground collisions will not be available at start outside of player immediate area.
	# This make below ground-based calculations like removing trees on steep terrain not possible.
	await get_tree().process_frame

	var terrain_boundary = WorldState.state.terrain_generator.get_terrain_size()

	generate_starting_items(terrain_boundary)

	update_lods()

func _process(_delta: float) -> void:
	var player_chunk_index = WorldState.state.terrain_generator.get_player_chunk_index(WorldState.state.player.position)
	if player_chunk_index != terrain_last_player_index:
		WorldState.state.terrain_generator.update_chunks_around_player(WorldState.state.player.position, 1)
		terrain_last_player_index = player_chunk_index

	var distance_traveled = (Vector2(WorldState.state.player.position.x, WorldState.state.player.position.z) - lod_last_player_pos).length()
	if distance_traveled > Globals.LOD_UPDATE_DISTANCE:
		update_lods()
		lod_last_player_pos = Vector2(WorldState.state.player.position.x, WorldState.state.player.position.z)
		update_close_objects_time = 0

func update_lods():
	remove_faraway_meshes()
	remove_faraway_objects()
	add_outer_bounds_meshes()
	add_nearby_objects()

func remove_faraway_meshes():
	const OUTER_BOUNDS = Globals.LOD_DISTANCE_NO_COLLIDER * Globals.LOD_REMOVE_DISTANCE_MULTIPLIER
	var start_pos = Vector2(WorldState.state.player.position.x - OUTER_BOUNDS, WorldState.state.player.position.z - OUTER_BOUNDS)
	var size = Vector2(OUTER_BOUNDS * 2, OUTER_BOUNDS * 2)
	var boundary_to_keep: Rect2 = Rect2(start_pos, size)
	WorldState.state.pool_manager.remove_faraway_world_meshes(boundary_to_keep)

func remove_faraway_objects():
	const INNER_BOUNDS = Globals.LOD_DISTANCE_FULL * Globals.LOD_REMOVE_DISTANCE_MULTIPLIER
	var start_pos = Vector2(WorldState.state.player.position.x - INNER_BOUNDS, WorldState.state.player.position.z - INNER_BOUNDS)
	var size = Vector2(INNER_BOUNDS * 2, INNER_BOUNDS * 2)
	var boundary_to_keep: Rect2 = Rect2(start_pos, size)
	WorldState.state.pool_manager.remove_faraway_world_objects(boundary_to_keep)

func add_outer_bounds_meshes():
	const OUTER_BOUNDS = Globals.LOD_DISTANCE_NO_COLLIDER
	var start_pos = Vector2(WorldState.state.player.position.x - OUTER_BOUNDS, WorldState.state.player.position.z - OUTER_BOUNDS)
	var size = Vector2(OUTER_BOUNDS * 2, OUTER_BOUNDS * 2)
	var boundary: Rect2 = Rect2(start_pos, size)
	WorldState.state.object_manager.add_world_meshes(boundary)
	var nearby_settlements: Array[SettlementManager.SettlementData] = WorldState.state.settlement_manager.create_settlements(boundary)
	WorldState.state.npc_manager.create_npcs_meshes_in_settlements(nearby_settlements)
	WorldState.state.settlement_manager.remove_objects_from_settlements(nearby_settlements)
	WorldState.state.road_generator.generate_roads(boundary)
	var quarter_boundary = MathFunctions.resize_rect(boundary, 0.25)
	WorldState.state.road_generator.remove_objects_from_roads(quarter_boundary) # Dont remove until close, to save performance
	var nearby_road_segments = WorldState.state.road_generator.road_segments.query_circle(Vector2(WorldState.state.player.position.x, WorldState.state.player.position.z), OUTER_BOUNDS)
	WorldState.state.terrain_generator.update_shader_data(nearby_settlements, nearby_road_segments)

func add_nearby_objects():
	var nearby_meshes = WorldState.state.pool_manager.get_meshes_in_range(WorldState.state.player.position, Globals.LOD_DISTANCE_FULL)
	for mesh in nearby_meshes:
		WorldState.state.pool_manager.get_object(mesh)

# TODO: Add object pool for items
func generate_starting_items(boundary):
	var axe_position = Vector3(-1.0, 2.0, -4.0)
	if boundary.has_point(Vector2(axe_position.x, axe_position.z)):
		WorldState.state.item_generator.spawn_item(axe_position, ItemProperties.Item.AXE)

	var pickaxe_position = Vector3(1.0, 2.0, -4.0)
	if boundary.has_point(Vector2(pickaxe_position.x, pickaxe_position.z)):
		WorldState.state.item_generator.spawn_item(pickaxe_position, ItemProperties.Item.PICKAXE)

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
