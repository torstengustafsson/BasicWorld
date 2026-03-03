extends Node

class_name GameWorld

enum InteractResults { NoResult, GainItem, DeleteEquippedItem }

class InteractResult:
	var result: InteractResults
	var item: ItemProperties.Item

	func _init(_result: InteractResults = InteractResults.NoResult, _item: ItemProperties.Item = ItemProperties.Item.NO_ITEM) -> void:
		result = _result
		item = _item

const ROAD_WIDTH = 1.5
const WORLD_SIZE = 320.0

var world_grid: WorldGrid
var ground_material = ShaderMaterial.new()
var ground: StaticBody3D
var world_item_generator: WorldItemGenerator = WorldItemGenerator.new()
var trees_generator: TreeGenerator = TreeGenerator.new()
var bush_generator: BushGenerator = BushGenerator.new()
var rock_generator: RockGenerator = RockGenerator.new()
var settlements_generator: SettlementGenerator = SettlementGenerator.new()
var npcs_generator: NpcGenerator = NpcGenerator.new()
var road_generator: RoadGenerator

func _init(_ground: StaticBody3D) -> void:
	ground = _ground

func _ready() -> void:
	var start_time = Time.get_ticks_msec()

	ground.get_node("PlaneMesh").mesh.size = Vector2(WORLD_SIZE, WORLD_SIZE)
	ground.get_node("GroundCollider").shape.size = Vector3(WORLD_SIZE, 0.1, WORLD_SIZE)
	var size_x = WORLD_SIZE
	var size_z = WORLD_SIZE
	var margin = 5.0
	var start_pos_x = size_x / 2 - size_x + margin
	var start_pos_z = size_z / 2 - size_z + margin
	var end_pos_x = size_x / 2 - margin
	var end_pos_z = size_z / 2 - margin

	var step_trees = 3
	var step_berrybushes = 10
	var step_rocks = 10

	# CREATE STATIC OBJECTS AND ITEMS

	var forest_noise = NoiseFunctions.create_forest_noise()
	var rocks_noise = NoiseFunctions.create_rocks_noise()


	var trees: Array[WorldObject] = trees_generator.create_trees(start_pos_x, start_pos_z, end_pos_x, end_pos_z, step_trees, forest_noise)
	add_child(trees_generator)

	var bushes: Array[WorldObject] = bush_generator.create_berrybushes(start_pos_x, start_pos_z, end_pos_x, end_pos_z, step_berrybushes, forest_noise)
	add_child(bush_generator)

	var rocks: Array[WorldObject] = rock_generator.create_rocks(start_pos_x, start_pos_z, end_pos_x, end_pos_z, step_rocks, rocks_noise)
	add_child(rock_generator)

	var axe_position = Vector3(-1.0, 2.0, -4.0)
	world_item_generator.spawn_item(axe_position, ItemProperties.Item.AXE)

	var pickaxe_position = Vector3(1.0, 2.0, -4.0)
	world_item_generator.spawn_item(pickaxe_position, ItemProperties.Item.PICKAXE)

	for berry in 40:
		#var berry_position = Vector3(randf_range(start_pos_x, end_pos_z), 5.0, randf_range(start_pos_z, end_pos_z))
		var berry_position = Vector3(randf_range(-5.0, 5.0), 5.0, randf_range(-5.0, 5.0))
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

	var all_objects = trees + bushes + rocks
	world_grid = WorldGrid.new(Vector2(start_pos_x, start_pos_z), Vector2(end_pos_x, end_pos_z), ROAD_WIDTH)
	world_grid.calculate_weights(all_objects)
	add_child(world_grid)

	var create_world_grid_time = Time.get_ticks_msec()
	var create_world_grid_elapsed = create_world_grid_time - create_objects_time
	print("Time to generate world grid = " + str(create_world_grid_elapsed / 1000.0) + " seconds")

	# CREATE SETTLEMENTS

	var settlement_data = settlements_generator.create_settlements(world_grid)
	add_child(settlements_generator)

	var create_settlements_time = Time.get_ticks_msec()
	var create_settlements_elapsed = create_settlements_time - create_world_grid_time
	print("Time to generate settlements = " + str(create_settlements_elapsed / 1000.0) + " seconds")

	create_npcs_in_settlements(settlement_data)

	# Create some random NPCs out in the forest as well
	var num_npcs = 25
	npcs_generator.create_npcs(start_pos_x, start_pos_z, end_pos_x, end_pos_z, num_npcs)
	add_child(npcs_generator)

	# CREATE ROADS

	road_generator = RoadGenerator.new(world_grid, ROAD_WIDTH)
	var road_edges: Array = road_generator.generate_roads(settlement_data) # Type: Array[RoadGenerator.RoadEdge]
	add_child(road_generator)

	var create_roads_time = Time.get_ticks_msec()
	var create_roads_elapsed = create_roads_time - create_settlements_time
	print("Time to generate roads = " + str(create_roads_elapsed / 1000.0) + " seconds")

	# SETUP SHADER PARAMETERS

	ground_material.shader = load("res://shaders/ground.gdshader")
	ground_material.set_shader_parameter("world_size", Vector2(size_x, size_z))
	ground_material.set_shader_parameter("grass_albedo_texture", Color(0.25, 0.5, 0.25))
	ground_material.set_shader_parameter("road_albedo_texture", Color(0.5, 0.5, 0.2, 1.0))
	ground_material.set_shader_parameter("settlement_count", settlement_data.size())
	var shader_settlement_data: Array[Vector3] = []
	for settlement in settlement_data:
		shader_settlement_data.append(Vector3(settlement.position.x, settlement.position.z, settlement.radius))
	ground_material.set_shader_parameter("settlement_data", shader_settlement_data)
	ground_material.set_shader_parameter("road_width", ROAD_WIDTH)
	ground_material.set_shader_parameter("road_edge_count", road_edges.size())
	var shader_road_edges_data: Array[Vector4] = []
	for edge in road_edges:
		shader_road_edges_data.append(Vector4(edge.from.x, edge.from.z, edge.to.x, edge.to.z))
	ground_material.set_shader_parameter("road_edges", shader_road_edges_data)
	ground.get_node("PlaneMesh").material_override = ground_material

	settlements_generator.remove_objects_from_settlements(trees_generator.trees, trees_generator.remove_at)
	settlements_generator.remove_objects_from_settlements(bush_generator.berrybushes, bush_generator.remove_at)
	settlements_generator.remove_objects_from_settlements(rock_generator.rocks, rock_generator.remove_at)
	road_generator.remove_objects_from_roads(trees_generator.trees, trees_generator.remove_at)
	road_generator.remove_objects_from_roads(bush_generator.berrybushes, bush_generator.remove_at)
	road_generator.remove_objects_from_roads(rock_generator.rocks, rock_generator.remove_at)

	var elapsed = Time.get_ticks_msec() - start_time

	print("")
	print("Total time to generate world = " + str(elapsed / 1000.0) + " seconds")
	print("Number of objects in scene = " + str(count_all_children(self)))

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
		npcs_generator.create_npcs(start_pos_x, start_pos_z, end_pos_x, end_pos_z, num_npcs)
		npcs_generator.create_npc_children(start_pos_x, start_pos_z, end_pos_x, end_pos_z, num_npcs)

func interact(collider, item: ItemProperties.Item = ItemProperties.Item.NO_ITEM) -> InteractResult:
	var berries_picked = bush_generator.interact(collider)
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
		var tree_chopped_down: TreeGenerator.ChopResult = trees_generator.handle_chop(collider)
		if tree_chopped_down.result == TreeGenerator.ChopResults.ChoppedDown:
			world_item_generator.spawn_item(tree_chopped_down.position, ItemProperties.Item.WOOD)
		npcs_generator.handle_chop(collider)

	if item == ItemProperties.Item.PICKAXE:
		var rock_chopped_down: RockGenerator.ChopResult = rock_generator.handle_chop(collider)
		if rock_chopped_down.result == RockGenerator.ChopResults.ChoppedDown:
			for i in rock_chopped_down.amount_gained:
				world_item_generator.spawn_item(rock_chopped_down.position, ItemProperties.Item.STONE)
