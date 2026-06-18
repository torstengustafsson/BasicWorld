extends Node

class_name SettlementGenerator

class SettlementData:
	var grid_index: Vector2i
	var position: Vector3
	var radius: float
	var num_houses: int
	func _init(_grid_index, _position, _radius, _num_houses) -> void:
		grid_index = _grid_index
		position = _position
		radius = _radius
		num_houses = _num_houses

var added_boundaries: Dictionary[Rect2, bool] = {}

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var world_state: WorldState
var settlements: Quadtree = Quadtree.new()

func _init(_world_state: WorldState):
	world_state = _world_state
	settlements.boundary = Rect2(Vector2(-INF, -INF), Vector2(INF, INF))
	add_to_group("Persist")

func create_settlements(boundary: Rect2) -> Array[SettlementData]:
	if added_boundaries.has(boundary):
		return []
	added_boundaries[boundary] = true
	var new_settlements: Array[SettlementData] = []
	# Need a way to reproduce the same result every time for random values, position is used since we always know it
	# will be the same for the same generation. This only works because we always set bounds to one terrain chunk at a time.
	rng.seed = hash(boundary.position)

	var previous_start_pos_x = boundary.position.x - MathFunctions.mod(int(boundary.position.x), int(Globals.WORLD_GRID_STEP * Globals.SETTLEMENT_GRID_STEP))
	var previous_start_pos_z = boundary.position.y - MathFunctions.mod(int(boundary.position.y), int(Globals.WORLD_GRID_STEP * Globals.SETTLEMENT_GRID_STEP))
	var start_pos_x = previous_start_pos_x + Globals.WORLD_GRID_STEP * Globals.SETTLEMENT_GRID_STEP
	var start_pos_z = previous_start_pos_z + Globals.WORLD_GRID_STEP * Globals.SETTLEMENT_GRID_STEP
	var end_pos_x = boundary.position.x + boundary.size.x - MathFunctions.mod(int(boundary.position.x + boundary.size.x), int(Globals.WORLD_GRID_STEP * Globals.SETTLEMENT_GRID_STEP))
	var end_pos_z = boundary.position.y + boundary.size.y - MathFunctions.mod(int(boundary.position.x + boundary.size.x), int(Globals.WORLD_GRID_STEP * Globals.SETTLEMENT_GRID_STEP))
	var start_index_x: int = start_pos_x / Globals.WORLD_GRID_STEP
	var start_index_z: int = start_pos_z / Globals.WORLD_GRID_STEP
	var end_index_x: int = end_pos_x / Globals.WORLD_GRID_STEP
	var end_index_z: int = end_pos_z / Globals.WORLD_GRID_STEP

	# Ensure loop run once in case there is only one settlement to place within x and z bounds
	if end_index_x == start_index_x:
		end_index_x += 1
	if end_index_z == start_index_z:
		end_index_z += 1

	for grid_index_x in range(start_index_x, end_index_x, Globals.SETTLEMENT_GRID_STEP):
		for grid_index_z in range(start_index_z, end_index_z, Globals.SETTLEMENT_GRID_STEP):
			var rand_value_x = rng.randi_range(-Globals.SETTLEMENT_GRID_SPREAD, Globals.SETTLEMENT_GRID_SPREAD)
			var rand_value_z = rng.randi_range(-Globals.SETTLEMENT_GRID_SPREAD, Globals.SETTLEMENT_GRID_SPREAD)
			var grid_index = Vector2i(grid_index_x + rand_value_x, grid_index_z + rand_value_z)
			if not world_state.world_grid.is_grid_index_ok(grid_index):
				continue
			var settlement_data = try_add_settlement(grid_index)
			if settlement_data:
				settlements.insert({"position": Vector2(settlement_data.position.x, settlement_data.position.z), "data": settlement_data})
				new_settlements.append(settlement_data)
	return new_settlements

func try_add_settlement(grid_index: Vector2i) -> SettlementData:
	var has_tested_neighbors = false
	var pq: PriorityQueue = PriorityQueue.new()
	pq.push(grid_index, 0.0)
	while not pq.is_empty():
		var current_index = pq.pop()
		var current_position = world_state.world_grid.get_grid_position(current_index)
		var too_steep = false
		var edges = world_state.world_grid.get_grid_index_edges(current_index)
		var has_all_edges = edges.size() == 8 # Non-flat areas lack edges
		if has_all_edges:
			for edge_index in edges:
				var edge_position = world_state.world_grid.get_grid_position(edge_index)
				var height_diff = abs(current_position.y - edge_position.y)
				if height_diff > Globals.MAX_SETTLEMENT_STEEPNESS:
					too_steep = true
					break
		if has_all_edges and not too_steep:
			return add_settlement(current_position, current_index)
		else:
			# Not ok. Add startpoints' edges to check instead
			if not has_tested_neighbors:
				has_tested_neighbors = true
				for edge_index in edges:
					var edge_position = world_state.world_grid.get_grid_position(edge_index)
					var height_diff = abs(current_position.y - edge_position.y)
					if height_diff < Globals.MAX_SETTLEMENT_STEEPNESS:
						pq.push(edge_index, height_diff)
	return null

func add_settlement(grid_position: Vector3, grid_index: Vector2i) -> SettlementData:
	const MAX_NUM_HOUSES = 5
	var num_houses = rng.randi_range(2, MAX_NUM_HOUSES)
	var start_rotation: float = rng.randf() * 2 * PI
	var house_spread_angle_multiplier: float = (MAX_NUM_HOUSES * 2 - num_houses)
	var last_angle: float = start_rotation
	var largest_radius: float = 0.0
	for house_angle in num_houses:
		var angle = last_angle + PI / 3 * rng.randf_range(0.2, 0.3) * house_spread_angle_multiplier
		last_angle = angle
		var distance_from_town_center = rng.randf_range(10.0, 16.0) * (MAX_NUM_HOUSES + num_houses) / 10.0
		largest_radius = distance_from_town_center
		var rotated = Basis(Vector3.UP,  angle) * Vector3(1, 0, 0) * distance_from_town_center
		var house_position = grid_position + rotated
		house_position.y = world_state.terrain_height_noise.get_height_at(house_position.x, house_position.z)
		add_house(house_position, Vector3(0.0, angle + PI, 0.0))
	var chest_position = grid_position
	chest_position.y = world_state.terrain_height_noise.get_height_at(chest_position.x, chest_position.z)
	var chest_rotation = Vector3(0.0, rng.randf_range(0.0, 2 * PI), 0.0)
	WorldObject.add_chest(chest_position, chest_rotation, world_state.static_objects_qt)
	var settlement_radius = largest_radius + 5.0
	return SettlementData.new(grid_index, grid_position, settlement_radius, num_houses)

func add_house(position: Vector3, rotation: Vector3) -> WorldObject:
	var house = WorldObject.add_house(position, rotation, world_state.static_objects_qt)
	return house

func remove_objects_from_settlements(settlements_to_check: Array[SettlementData], remove_callback: Callable):
	for settlement in settlements_to_check:
		var objects = world_state.static_objects_qt.query_circle(Vector2(settlement.position.x, settlement.position.z), settlement.radius + 1.0)
		for object_data in objects:
			var object: WorldObject = object_data["data"]
			var is_removable_type: bool = \
				object.object_id == WorldObject.ObjectId.TREE or \
				object.object_id == WorldObject.ObjectId.ROCK or \
				object.object_id == WorldObject.ObjectId.BERRYBUSH
			if is_removable_type:
				remove_callback.call(object)


func save() -> Dictionary:
	#TODO
	return {}

func load(_data: Dictionary):
	#TODO
	pass
