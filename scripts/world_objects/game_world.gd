extends Node3D

class_name GameWorld

enum InteractResults { NoResult, GainItem, DeleteEquippedItem }

class InteractResult:
	var result: InteractResults
	var item: ItemProperties.Item

	func _init(_result: InteractResults = InteractResults.NoResult, _item: ItemProperties.Item = ItemProperties.Item.NO_ITEM) -> void:
		result = _result
		item = _item

var terrain_height_noise: TerrainNoise

var last_player_pos: Vector3

var static_objects_qt: Quadtree = Quadtree.new(Rect2(-Globals.WORLD_SIZE / 2, -Globals.WORLD_SIZE / 2,Globals.WORLD_SIZE, Globals.WORLD_SIZE))
var world_grid: WorldGrid
var terrain_generator: TerrainGenerator
var player: Node3D # Only used for position
var world_item_generator: WorldItemGenerator = WorldItemGenerator.new()
var object_generator: ObjectGenerator
var settlements_generator: SettlementGenerator
var npcs_generator: NpcGenerator = NpcGenerator.new(static_objects_qt)
var road_generator: RoadGenerator

func _init(_player: Node3D) -> void:
	player = _player
	last_player_pos = player.position

func _ready() -> void:
	var start_time = Time.get_ticks_msec()

	seed(Globals.RANDOM_SEED.hash())

	var space_state = get_world_3d().direct_space_state

	var size_x = Globals.WORLD_SIZE
	var size_z = Globals.WORLD_SIZE
	var margin = 5.0
	var start_pos_x = size_x / 2 - size_x + margin
	var start_pos_z = size_z / 2 - size_z + margin
	var end_pos_x = size_x / 2 - margin
	var end_pos_z = size_z / 2 - margin

	# CREATE TERRAIN

	terrain_height_noise = TerrainNoise.new()

	terrain_generator = TerrainGenerator.new(terrain_height_noise)
	terrain_generator.add_chunks_around_player(player.position)
	add_child(terrain_generator)

	# TODO: Find out why we need to wait here.
	# Without the wait, ground collisions will not be available at start outside of player immediate area.
	# This make below ground-based calculations like removing trees on steep terrain not possible.
	await get_tree().create_timer(0.1).timeout

	var create_terrain_time = Time.get_ticks_msec()
	var create_terrain_elapsed = create_terrain_time - start_time
	print("Time to generate terrain = " + str(create_terrain_elapsed / 1000.0) + " seconds")

	# CREATE STATIC OBJECTS AND ITEMS

	object_generator = ObjectGenerator.new(static_objects_qt, space_state)
	object_generator.create_world_objects(start_pos_x, start_pos_z, end_pos_x, end_pos_z, terrain_height_noise)
	add_child(object_generator)

	var axe_position = Vector3(-1.0, 2.0, -4.0)
	world_item_generator.spawn_item(axe_position, ItemProperties.Item.AXE)

	var pickaxe_position = Vector3(1.0, 2.0, -4.0)
	world_item_generator.spawn_item(pickaxe_position, ItemProperties.Item.PICKAXE)

	for berry in 40:
		var berry_position = Vector3(randf_range(start_pos_x, end_pos_x), 5.0, randf_range(start_pos_z, end_pos_z))
		world_item_generator.spawn_item(berry_position, ItemProperties.Item.BERRY)

	for wood in 40:
		var wood_position = Vector3(randf_range(start_pos_x, end_pos_x), 5.0, randf_range(start_pos_z, end_pos_z))
		world_item_generator.spawn_item(wood_position, ItemProperties.Item.WOOD)

	for stone in 40:
		var stone_position = Vector3(randf_range(start_pos_x, end_pos_x), 5.0, randf_range(start_pos_z, end_pos_z))
		world_item_generator.spawn_item(stone_position, ItemProperties.Item.STONE)

	add_child(world_item_generator)

	var create_objects_time = Time.get_ticks_msec()
	var create_objects_elapsed = create_objects_time - start_time
	print("Time to generate static objects = " + str(create_objects_elapsed / 1000.0) + " seconds")

	# CREATE WORLD GRID

	world_grid = WorldGrid.new(Vector2(start_pos_x, start_pos_z), Vector2(end_pos_x, end_pos_z), terrain_height_noise, space_state)
	world_grid.calculate_weights(static_objects_qt)
	add_child(world_grid)

	var create_world_grid_time = Time.get_ticks_msec()
	var create_world_grid_elapsed = create_world_grid_time - create_objects_time
	print("Time to generate world grid = " + str(create_world_grid_elapsed / 1000.0) + " seconds")

	# CREATE SETTLEMENTS

	settlements_generator = SettlementGenerator.new(static_objects_qt, world_grid, terrain_height_noise)
	var settlement_data = settlements_generator.create_settlements()

	create_npcs_in_settlements(settlement_data)

	# Create some random NPCs out in the forest as well
	var num_npcs = 25
	npcs_generator.create_npcs(start_pos_x, start_pos_z, end_pos_x, end_pos_z, num_npcs, terrain_height_noise)

	settlements_generator.remove_objects_from_settlements(remove_object)

	var create_settlements_time = Time.get_ticks_msec()
	var create_settlements_elapsed = create_settlements_time - create_world_grid_time
	print("Time to generate settlements = " + str(create_settlements_elapsed / 1000.0) + " seconds")

	# CREATE ROADS

	road_generator = RoadGenerator.new(world_grid)
	var road_edges: Array[RoadGenerator.RoadEdge] = road_generator.generate_roads(settlement_data) # Type: Array[RoadGenerator.RoadEdge]
	add_child(road_generator)

	road_generator.remove_objects_from_roads(static_objects_qt, remove_object)

	var create_roads_time = Time.get_ticks_msec()
	var create_roads_elapsed = create_roads_time - create_settlements_time
	print("Time to generate roads = " + str(create_roads_elapsed / 1000.0) + " seconds")

	# SETUP SHADER PARAMETERS

	for chunk: TerrainChunk in terrain_generator.get_chunks():
		chunk.set_shader_data(settlement_data, road_edges)

	# By default all collisions are disabled. They will be later re-added on distance calculations from player
	for item in static_objects_qt.query_all():
		item["data"].collider.disabled = true
	update_lods()

	var elapsed = Time.get_ticks_msec() - start_time

	print("")
	print("Total time to generate world = " + str(elapsed / 1000.0) + " seconds")
	print("Number of objects in scene = " + str(count_all_children(self)))


func _process(_delta: float) -> void:
	if (player.position - last_player_pos).length() > Globals.LOD_UPDATE_DISTANCE:
		update_lods()
		last_player_pos = player.position


func update_lods():
	var player_pos = player.global_transform.origin
	add_no_collider_children_batched(player_pos)
	remove_faraway_children_batched(player_pos)
	add_nearby_children_full(player_pos)

func add_nearby_children_full(player_position: Vector3):
	var objects_full = static_objects_qt.query_circle(Vector2(player_position.x, player_position.z), Globals.LOD_DISTANCE_FULL)
	for index in objects_full.size():
		var object: WorldObject = objects_full[index]["data"]
		if not object.in_scene or object.collider.disabled:
			object.collider.disabled = false
			if object.glb_mesh_no_collider.get_parent() == self:
				remove_child(object.glb_mesh_no_collider)
			add_child(object.instance)
			object.in_scene = true


func add_no_collider_children_batched(player_position: Vector3, batch_size: int = 1000):
	var objects_no_collider = static_objects_qt.query_circle_holed(Vector2(player_position.x, player_position.z), Globals.LOD_DISTANCE_NO_COLLIDER, Globals.LOD_DISTANCE_FULL)
	var i = 0
	while i < objects_no_collider.size():
		for j in min(batch_size, objects_no_collider.size() - i):
			var object: WorldObject = objects_no_collider[i + j]["data"]
			# Need to verify that object is not already a child, since we otherwise would disable its collider
			if not object.in_scene:
				object.collider.disabled = true
				if object.instance.get_parent() == self:
					remove_child(object.instance)
				add_child(object.glb_mesh_no_collider)
				object.in_scene = true
		i += batch_size
		await get_tree().process_frame

# TODO: Bug, Some objects are not removed sometimes
func remove_faraway_children_batched(player_position: Vector3, batch_size: int = 200):
	var faraway_objects = static_objects_qt.query_circle_holed(Vector2(player_position.x, player_position.z), Globals.LOD_DISTANCE_NO_COLLIDER + Globals.LOD_UPDATE_DISTANCE + 5.0, Globals.LOD_DISTANCE_NO_COLLIDER)
	var i = 0
	while i < faraway_objects.size():
		for j in min(batch_size, faraway_objects.size() - i):
			var object: WorldObject = faraway_objects[i + j]["data"]
			# Need to verify again that object is still out-of-bounds, since we use batched removal
			if object.in_scene and object.instance.position.distance_to(player_position) > Globals.LOD_DISTANCE_NO_COLLIDER:
				if object.glb_mesh_no_collider.get_parent() == self:
					remove_child(object.glb_mesh_no_collider)
				object.in_scene = false
		i += batch_size
		await get_tree().process_frame


func count_all_children(node: Node) -> int:
	var count = node.get_child_count()
	for child in node.get_children():
		count += count_all_children(child)
	return count

func create_npcs_in_settlements(settlement_data: Array[SettlementGenerator.SettlementData]):
	for settlement in settlement_data:
		var num_npcs = randf_range(settlement.num_houses, settlement.num_houses * 2)
		var square_in_circle_multiplier = 0.7 # sin(45degrees)
		var start_pos_x = settlement.position.x - settlement.radius * square_in_circle_multiplier
		var start_pos_z = settlement.position.z - settlement.radius * square_in_circle_multiplier
		var end_pos_x = settlement.position.x + settlement.radius * square_in_circle_multiplier
		var end_pos_z = settlement.position.z + settlement.radius * square_in_circle_multiplier
		npcs_generator.create_npcs(start_pos_x, start_pos_z, end_pos_x, end_pos_z, num_npcs, terrain_height_noise)
		npcs_generator.create_npc_children(start_pos_x, start_pos_z, end_pos_x, end_pos_z, num_npcs, terrain_height_noise)


func remove_object(object: WorldObject):
	static_objects_qt.remove({"position": Vector2(object.instance.position.x, object.instance.position.z), "data": object})
	object.delete()
	object = null


func interact(collider, item: ItemProperties.Item = ItemProperties.Item.NO_ITEM) -> InteractResult:
	var berries_picked = object_generator.interact(collider)
	if berries_picked > 0:
		return InteractResult.new(InteractResults.GainItem, ItemProperties.Item.BERRY)

	var item_picked = world_item_generator.interact(collider)
	if item_picked != ItemProperties.Item.NO_ITEM:
		return InteractResult.new(InteractResults.GainItem, item_picked)

	if item != ItemProperties.Item.NO_ITEM:
		var npc_took_item: bool = npcs_generator.interact_equipped_item(collider, item)
		if npc_took_item:
			return InteractResult.new(InteractResults.DeleteEquippedItem)
	else:
		npcs_generator.interact(collider)
	return InteractResult.new()

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
