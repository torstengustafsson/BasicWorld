extends Node

class_name SettlementGenerator

class SettlementData:
	var grid_position: Vector2i
	var position: Vector3
	var radius: float
	var num_houses: int
	func _init(_grid_position, _position, _radius, _num_houses) -> void:
		grid_position = _grid_position
		position = _position
		radius = _radius
		num_houses = _num_houses

# spread must be less than half of grid step to avoid overlap
const SETTLEMENT_GRID_STEP = 10
const SETTLEMENT_GRID_SPREAD = 3
const WORLD_EDGE_MARGIN = 1 + SETTLEMENT_GRID_SPREAD

var houses: Array[WorldObject] = []
var settlements: Array[SettlementData]

func _init():
	add_to_group("Persist")

func create_settlements(world_grid: WorldGrid) -> Array[SettlementData]:
	var result: Array[SettlementData] = []

	for grid_point_x in range(WORLD_EDGE_MARGIN + 1, world_grid.grid_size - WORLD_EDGE_MARGIN, SETTLEMENT_GRID_STEP):
		var rand_value_x = randi_range(-SETTLEMENT_GRID_SPREAD, SETTLEMENT_GRID_SPREAD)
		for grid_point_z in range(WORLD_EDGE_MARGIN + 1, world_grid.grid_size - WORLD_EDGE_MARGIN, SETTLEMENT_GRID_STEP):
			print(str(grid_point_x) + ", " + str(grid_point_z))
			var rand_value_z = randi_range(-SETTLEMENT_GRID_SPREAD, SETTLEMENT_GRID_SPREAD)
			var grid_point = Vector2i(grid_point_x + rand_value_x, grid_point_z + rand_value_z)
			var grid_position = world_grid.grid_point_edges.get(grid_point, null)
			if not grid_position:
				continue
			var settlement_data = add_settlement(grid_point, grid_position.point)
			result.append(settlement_data)

	print("world_grid.grid_size = " + str(world_grid.grid_size))

	settlements.append_array(result)
	return result

# Returns radius of settlement
func add_settlement(grid_position: Vector2i, position: Vector3) -> SettlementData:
	const MAX_NUM_HOUSES = 5
	var num_houses = randi_range(2, MAX_NUM_HOUSES)
	var start_rotation: float = randf() * 2 * PI
	var house_spread_angle_multiplier: float = (MAX_NUM_HOUSES * 2 - num_houses)
	var last_angle: float = start_rotation
	var largest_radius: float = 0.0
	for house_angle in num_houses:
		var angle = last_angle + PI / 3 * randf_range(0.2, 0.3) * house_spread_angle_multiplier
		last_angle = angle
		var distance_from_town_center = randf_range(10.0, 16.0) * (MAX_NUM_HOUSES + num_houses) / 10.0
		largest_radius = distance_from_town_center
		var rotated = Basis(Vector3.UP,  angle) * Vector3(1, 0, 0) * distance_from_town_center
		add_house(position + rotated, Vector3(0.0, angle + PI, 0.0))

	var chest_rotation = randf_range(0.0, 2 * PI)
	add_chest(position, Vector3(0.0, chest_rotation, 0.0))

	var settlement_radius = largest_radius + 5.0
	return SettlementData.new(grid_position, position, settlement_radius, num_houses)

func add_house(position: Vector3, rotation: Vector3) -> WorldObject:
	var house = WorldObject.add_house(position, rotation)
	houses.append(house)
	add_child(house.instance)
	return house

func add_chest(position: Vector3, rotation: Vector3) -> WorldObject:
	var chest = WorldObject.add_chest(position, rotation)
	houses.append(chest)
	add_child(chest.instance)
	return chest

func remove_objects_from_settlements(objects, callback: Callable):
	var to_be_removed: Array[int] = []
	for index in objects.size():
		var object: Node3D = objects[index].instance
		var object_pos = Vector2(object.position.x, object.position.z)
		for settlement in settlements:
			if (object_pos - Vector2(settlement.position.x, settlement.position.z)).length() < settlement.radius + 1.0:
				to_be_removed.append(index)
	to_be_removed.sort()
	to_be_removed.reverse()
	for index in to_be_removed:
		callback.call(index)


func save() -> Dictionary:
	#TODO
	return {}

func load(data: Dictionary):
	#TODO
	pass
