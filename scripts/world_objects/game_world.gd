extends Node

class_name GameWorld

enum InteractResults { NoResult, GainItem, DeleteEquippedItem }

class InteractResult:
	var result: InteractResults
	var item: ItemProperties.Item

	func _init(_result: InteractResults = InteractResults.NoResult, _item: ItemProperties.Item = ItemProperties.Item.NO_ITEM) -> void:
		result = _result
		item = _item

var ground: MeshInstance3D
var world_item_generator: WorldItemGenerator
var bush_generator: BushGenerator
var trees_generator: TreeGenerator
var npcs_generator: NpcGenerator
var settlements_generator: SettlementGenerator

const ROAD_WIDTH = 1.5

var trees
var berrybushes

func _init(
	_ground: MeshInstance3D,
	_world_item_generator: WorldItemGenerator,
	_bush_generator: BushGenerator,
	_tree_generator: TreeGenerator,
	_npcs_generator: NpcGenerator,
	_settlements_generator: SettlementGenerator
) -> void:
	ground = _ground
	world_item_generator = _world_item_generator
	bush_generator = _bush_generator
	trees_generator = _tree_generator
	npcs_generator = _npcs_generator
	settlements_generator = _settlements_generator

func _ready() -> void:
	var size_x = ground.get_aabb().size.x
	var size_z = ground.get_aabb().size.z
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

	remove_objects_from_settlement_roads(trees_generator.trees, trees_generator.remove_at, settlement_data)
	remove_objects_from_settlement_roads(bush_generator.berrybushes, bush_generator.remove_at, settlement_data)

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

	var mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/ground.gdshader")
	mat.set_shader_parameter("world_size", Vector2(size_x, size_z))
	mat.set_shader_parameter("grass_albedo_texture", Color(0.25, 0.5, 0.25))
	mat.set_shader_parameter("road_albedo_texture", Color(0.5, 0.5, 0.2, 1.0))
	mat.set_shader_parameter("settlement_count", settlement_data.size())
	var shader_settlement_data: Array[Vector3] = []
	for settlement in settlement_data:
		shader_settlement_data.append(Vector3(settlement.position.x, settlement.position.z, settlement.radius))
	mat.set_shader_parameter("settlement_data", shader_settlement_data)
	mat.set_shader_parameter("road_width", ROAD_WIDTH)
	ground.material_override = mat

func remove_objects_from_settlement_roads(objects, callback: Callable, settlement_data: Array[SettlementGenerator.SettlementData]):
	var to_be_removed: Array[int] = []
	for index in objects.size():
		var object: Node3D = objects[index].instance
		var object_pos = Vector2(object.position.x, object.position.z)
		var found = false
		# Remove around settlements
		for settlement in settlement_data:
			if (object_pos - Vector2(settlement.position.x, settlement.position.z)).length() < settlement.radius + 1.0:
				to_be_removed.append(index)
				found = true
		# Remove along roads
		if settlement_data.size() > 1 and not found:
			for settlement_index in settlement_data.size() - 1:
				var current_settlement = settlement_data[settlement_index]
				var next_settlement = settlement_data[settlement_index + 1]
				var a = Vector2(current_settlement.position.x, current_settlement.position.z)
				var b = Vector2(next_settlement.position.x, next_settlement.position.z)
				var ab: Vector2 = b - a;
				var ap: Vector2 = object_pos - a;
				var t: float = clamp(ap.dot(ab) / ab.dot(ab), 0.0, 1.0);
				var closest: Vector2 = a + t * ab;
				var road_dist: float = (object_pos - closest).length()
				if road_dist < ROAD_WIDTH:
					to_be_removed.append(index)

	to_be_removed.sort()
	to_be_removed.reverse()
	for index in to_be_removed:
		callback.call(index)

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
		add_child(npcs_generator)

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
