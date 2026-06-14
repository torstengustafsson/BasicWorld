extends Node3D

class_name DistanceController

var world_state: WorldState
var terrain_generator: TerrainGenerator
var world_item_generator: WorldItemGenerator
var object_generator: ObjectGenerator
var settlements_generator: SettlementGenerator
var npcs_generator: NpcGenerator
var road_generator: RoadGenerator

var lod_last_player_pos: Vector3
var terrain_last_player_index: Vector2i

var update_time = 0
const FORCE_UPDATE_INTERVAL_SECONDS = 1.0

func _init(_world_state: WorldState):
	world_state = _world_state
	terrain_generator = TerrainGenerator.new(world_state.terrain_height_noise)
	object_generator = ObjectGenerator.new(world_state)
	world_item_generator = WorldItemGenerator.new(world_state)
	lod_last_player_pos = world_state.player.position
	terrain_last_player_index = Vector2i(0, 0)

func _ready() -> void:
	# CREATE TERRAIN

	terrain_generator.add_chunks_around_player(world_state.player.position)
	add_child(terrain_generator)

	# TODO: Find out why we need to wait here.
	# Without the wait, ground collisions will not be available at start outside of player immediate area.
	# This make below ground-based calculations like removing trees on steep terrain not possible.
	await get_tree().process_frame

	var terrain_boundary = terrain_generator.get_terrain_size()
	world_state.static_objects_qt.update_boundary(terrain_boundary)

	settlements_generator = SettlementGenerator.new(world_state)
	road_generator = RoadGenerator.new(world_state, settlements_generator)
	npcs_generator = NpcGenerator.new(world_state, settlements_generator)
	world_state.world_grid = WorldGrid.new(world_state)

	add_child(object_generator)
	add_child(world_item_generator)
	add_child(world_state.world_grid)
	add_child(road_generator)

	generate_world(terrain_boundary)
	generate_starting_items(terrain_boundary)

func generate_world(boundary: Rect2):
	# Reset global world state seed
	# TODO: Very fragile solution right now. Every calculation must be done in order,
	#       and we want to skip recalculating same things over and over.
	world_state.rng.seed = hash(Globals.RANDOM_SEED)

	# CREATE STATIC OBJECTS AND ITEMS

	object_generator.reset_noise_seeds()
	object_generator.create_world_objects(boundary)

	# Need to reset seed because some calculations above might be skipped for performance reasons
	world_state.rng.seed = hash(Globals.RANDOM_SEED) + 1

	# UPDATE WORLD GRID

	world_state.world_grid.add_grid_boundary(boundary)

	# CREATE SETTLEMENTS

	settlements_generator.create_settlements(boundary)

	# Need to reset seed because some calculations above might be skipped for performance reasons
	world_state.rng.seed = hash(Globals.RANDOM_SEED) + 2

	npcs_generator.create_npcs_in_settlements(boundary)

	# Create some random NPCs out in the forest as well
	var num_npcs = 25
	npcs_generator.create_npcs(boundary, num_npcs)

	settlements_generator.remove_objects_from_settlements(boundary, remove_object_callback)

	# CREATE ROADS

	var road_edges: Array[RoadGenerator.RoadEdge] = road_generator.generate_roads(boundary) # Type: Array[RoadGenerator.RoadEdge]
	road_generator.remove_objects_from_roads(remove_object_callback)

	# Need to reset seed because some calculations above might be skipped for performance reasons
	world_state.rng.seed = hash(Globals.RANDOM_SEED) + 3

	# FINAL TOUCHES

	terrain_generator.update_shader_data(settlements_generator.settlements.query_all(), road_edges)
	update_lods()

func generate_starting_items(boundary):
	var axe_position = Vector3(-1.0, 2.0, -4.0)
	if boundary.has_point(Vector2(axe_position.x, axe_position.z)):
		world_item_generator.spawn_item(axe_position, ItemProperties.Item.AXE)

	var pickaxe_position = Vector3(1.0, 2.0, -4.0)
	if boundary.has_point(Vector2(pickaxe_position.x, pickaxe_position.z)):
		world_item_generator.spawn_item(pickaxe_position, ItemProperties.Item.PICKAXE)

	var get_random_position = func() -> Vector3:
		return Vector3(
			world_state.rng.randf_range(boundary.position.x, boundary.end.x),
			5.0,
			world_state.rng.randf_range(boundary.position.y, boundary.end.y))

	for berry in 40:
		var berry_position = get_random_position.call()
		world_item_generator.spawn_item(berry_position, ItemProperties.Item.BERRY)

	for wood in 40:
		var wood_position = get_random_position.call()
		world_item_generator.spawn_item(wood_position, ItemProperties.Item.WOOD)

	for stone in 40:
		var stone_position = get_random_position.call()
		world_item_generator.spawn_item(stone_position, ItemProperties.Item.STONE)


func _process(_delta: float) -> void:
	if (world_state.player.position - lod_last_player_pos).length() > Globals.LOD_UPDATE_DISTANCE:
		update_lods()
		lod_last_player_pos = world_state.player.position

	var player_chunk_index = terrain_generator.get_player_chunk_index(world_state.player.position)
	if player_chunk_index != terrain_last_player_index:
		terrain_generator.update_chunks_around_player(world_state.player.position, 3)
		terrain_last_player_index = player_chunk_index

	if update_time > FORCE_UPDATE_INTERVAL_SECONDS:
		add_nearby_children_full()
		update_time = 0
	update_time += _delta

func remove_object_callback(object: WorldObject):
	world_state.static_objects_qt.remove({"position": Vector2(object.instance.position.x, object.instance.position.z), "data": object})
	object.delete()
	object = null

func update_lods():
	add_no_collider_children_batched()
	remove_faraway_children_batched()
	add_nearby_children_full()

func add_nearby_children_full():
	var objects_full = world_state.static_objects_qt.query_circle(Vector2(world_state.player.position.x, world_state.player.position.z), Globals.LOD_DISTANCE_FULL)
	for index in objects_full.size():
		var object: WorldObject = objects_full[index]["data"]
		if object.collider.disabled:
			object.collider.disabled = false
			if object.glb_mesh_no_collider.get_parent() == self:
				remove_child(object.glb_mesh_no_collider)
			add_child(object.instance)

func add_no_collider_children_batched(batch_size: int = 500):
	const INNER_RADIUS = Globals.LOD_DISTANCE_FULL
	const OUTER_RADIUS = Globals.LOD_DISTANCE_NO_COLLIDER
	var objects_no_collider = world_state.static_objects_qt.query_circle_holed(Vector2(world_state.player.position.x, world_state.player.position.z), INNER_RADIUS, OUTER_RADIUS)
	var i = 0
	while i < objects_no_collider.size():
		for j in min(batch_size, objects_no_collider.size() - i):
			var object: WorldObject = objects_no_collider[i + j]["data"]
			if object == null or object.instance == null:
				continue
			# Need to verify distance again because batched updating means player may have moved since this loop started
			var distance = object.instance.position.distance_to(world_state.player.position)
			if distance > INNER_RADIUS and distance <= OUTER_RADIUS:
				object.collider.disabled = true
				if object.instance.get_parent() == self:
					remove_child(object.instance)
				if object.glb_mesh_no_collider.get_parent() != self:
					add_child(object.glb_mesh_no_collider)
		i += batch_size
		await get_tree().process_frame

func remove_faraway_children_batched(batch_size: int = 500):
	const MARGIN = 5.0 # Add a small extra margin to ensure no outer radius-objects are missed
	const INNER_RADIUS = Globals.LOD_DISTANCE_NO_COLLIDER
	const OUTER_RADIUS = Globals.LOD_DISTANCE_NO_COLLIDER + Globals.LOD_UPDATE_DISTANCE + MARGIN
	var faraway_objects = world_state.static_objects_qt.query_circle_holed(Vector2(world_state.player.position.x, world_state.player.position.z), INNER_RADIUS, OUTER_RADIUS)
	var i = 0
	while i < faraway_objects.size():
		for j in min(batch_size, faraway_objects.size() - i):
			var object: WorldObject = faraway_objects[i + j]["data"]
			if object == null or object.instance == null:
				continue
			# Need to verify distance again because batched updating means player may have moved since this loop started
			# Outer radius is not checked because anything further away should still be removed
			var distance = object.instance.position.distance_to(world_state.player.position)
			if distance > INNER_RADIUS:
				if object.glb_mesh_no_collider.get_parent() == self:
					remove_child(object.glb_mesh_no_collider)
				if object.instance.get_parent() == self:
					remove_child(object.instance)
		i += batch_size
		await get_tree().process_frame

func interact(collider, item: ItemProperties.Item = ItemProperties.Item.NO_ITEM) -> GameWorld.InteractResult:
	var berries_picked = object_generator.interact(collider)
	if berries_picked > 0:
		return GameWorld.InteractResult.new(GameWorld.InteractResults.GainItem, ItemProperties.Item.BERRY)

	var item_picked = world_item_generator.interact(collider)
	if item_picked != ItemProperties.Item.NO_ITEM:
		return GameWorld.InteractResult.new(GameWorld.InteractResults.GainItem, item_picked)

	if item != ItemProperties.Item.NO_ITEM:
		var npc_took_item: bool = npcs_generator.interact_equipped_item(collider, item)
		if npc_took_item:
			return GameWorld.InteractResult.new(GameWorld.InteractResults.DeleteEquippedItem)
	else:
		npcs_generator.interact(collider)
	return GameWorld.InteractResult.new()

func handle_use_item(collider, item: ItemProperties.Item) -> void:
	if item == ItemProperties.Item.AXE:
		var tree_chopped_down: ObjectGenerator.ChopResult = object_generator.handle_tree_chop(collider)
		if tree_chopped_down.result == ObjectGenerator.ChopResults.ChoppedDown:
			world_item_generator.spawn_item(tree_chopped_down.position, ItemProperties.Item.WOOD)
		npcs_generator.handle_chop(collider)

	if item == ItemProperties.Item.PICKAXE:
		var rock_chopped_down: ObjectGenerator.ChopResult = object_generator.handle_rock_chop(collider)
		if rock_chopped_down.result == ObjectGenerator.ChopResults.ChoppedDown:
			for i in rock_chopped_down.amount_gained:
				world_item_generator.spawn_item(rock_chopped_down.position, ItemProperties.Item.STONE)
