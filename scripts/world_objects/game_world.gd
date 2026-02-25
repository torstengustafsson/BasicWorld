extends Node

class_name GameWorld

enum InteractResults { NoResult, GainItem, DeleteEquippedItem }

class InteractResult:
	var result: InteractResults
	var item: ItemProperties.Item

	func _init(_result: InteractResults = InteractResults.NoResult, _item: ItemProperties.Item = ItemProperties.Item.NO_ITEM) -> void:
		result = _result
		item = _item

var ground_material = ShaderMaterial.new()
var ground: MeshInstance3D
var world_item_generator: WorldItemGenerator = WorldItemGenerator.new()
var trees_generator: TreeGenerator = TreeGenerator.new()
var bush_generator: BushGenerator = BushGenerator.new()
var settlements_generator: SettlementGenerator = SettlementGenerator.new()
var npcs_generator: NpcGenerator = NpcGenerator.new()
var road_generator: RoadGenerator = RoadGenerator.new(WORLD_GRID, ROAD_WIDTH, ground_material)

const ROAD_WIDTH = 1.5
const WORLD_SIZE = 200.0

# World grid contains evenly spaced points in the terrain
# It is used for pathfinding and similar stuff
const WORLD_GRID_STEP = 5
var WORLD_GRID: Array[Vector2] = create_world_grid()

func create_world_grid() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for x in WORLD_SIZE / WORLD_GRID_STEP:
		for z in WORLD_SIZE / WORLD_GRID_STEP:
			result.append(Vector2(x, z))
	return result

var trees
var berrybushes

func _init(_ground: MeshInstance3D) -> void:
	ground = _ground

func _ready() -> void:
	ground.mesh.size = Vector2(WORLD_SIZE, WORLD_SIZE)
	var size_x = WORLD_SIZE
	var size_z = WORLD_SIZE
	var margin = 5.0
	var start_pos_x = size_x / 2 - size_x + margin
	var start_pos_z = size_z / 2 - size_z + margin
	var end_pos_x = size_x / 2 - margin
	var end_pos_z = size_z / 2 - margin

	var step_trees = 5
	var step_berrybushes = 15
	var step_houses = 75

	trees_generator.create_trees(start_pos_x, start_pos_z, end_pos_x, end_pos_z, step_trees)
	add_child(trees_generator)

	bush_generator.create_berrybushes(start_pos_x, start_pos_z, end_pos_x, end_pos_z, step_berrybushes)
	add_child(bush_generator)

	var settlement_data: Array[SettlementGenerator.SettlementData] = settlements_generator.create_settlements(start_pos_x, start_pos_z, end_pos_x, end_pos_z, step_houses)
	add_child(settlements_generator)

	create_npcs_in_settlements(settlement_data)

	# Create some random NPCs out in the forest as well
	var num_npcs = 25
	npcs_generator.create_npcs(start_pos_x, start_pos_z, end_pos_x, end_pos_z, num_npcs)
	add_child(npcs_generator)

	var axe_position = Vector3(0.0, 2.0, -4.0)
	world_item_generator.spawn_item(axe_position, ItemProperties.Item.AXE)

	for berry in 20:
		var berry_position = Vector3(randf_range(start_pos_x, end_pos_z), 5.0, randf_range(start_pos_z, end_pos_z))
		world_item_generator.spawn_item(berry_position, ItemProperties.Item.BERRY)

	for wood in 20:
		var wood_position = Vector3(randf_range(start_pos_x, end_pos_x), 5.0, randf_range(start_pos_z, end_pos_z))
		world_item_generator.spawn_item(wood_position, ItemProperties.Item.WOOD)

	add_child(world_item_generator)

	var road_edges: Array[RoadGenerator.Edge] = road_generator.generate_roads(settlement_data)

	add_child(road_generator)

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
		shader_road_edges_data.append(Vector4(edge.from.x, edge.from.y, edge.to.x, edge.to.y))
	ground_material.set_shader_parameter("road_edges", shader_road_edges_data)
	ground.material_override = ground_material

	settlements_generator.remove_objects_from_settlements(trees_generator.trees, trees_generator.remove_at)
	settlements_generator.remove_objects_from_settlements(bush_generator.berrybushes, bush_generator.remove_at)
	road_generator.remove_objects_from_roads(trees_generator.trees, trees_generator.remove_at)
	road_generator.remove_objects_from_roads(bush_generator.berrybushes, bush_generator.remove_at)

	print("Number of object in scene = " + str(count_all_children(self)))

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
