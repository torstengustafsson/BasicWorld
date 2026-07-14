class_name SettlementManager extends Node

class SettlementData:
	var grid_index: Vector2i
	var position: Vector3
	var radius: float
	var houses: Array[WorldObject]
	var chest: WorldObject
	func _init(_grid_index, _position, _radius, _houses, _chest) -> void:
		grid_index = _grid_index
		position = _position
		radius = _radius
		houses = _houses
		chest = _chest
	func get_num_houses() -> int:
		return houses.size()

var added_terrain_angle_boundaries: Dictionary[Array, bool] = {}
var settlements: Quadtree = Quadtree.new()

func _init():
	settlements.boundary = Rect2(Vector2(-INF, -INF), Vector2(INF, INF))
	add_to_group("Persist")

func create_settlements(boundary: Rect2) -> Array[SettlementData]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var new_settlements: Array[SettlementData] = []

	var step = int(Globals.WORLD_GRID_STEP * Globals.SETTLEMENT_GRID_STEP)
	var start_pos_x = floor(boundary.position.x / step) * step
	var start_pos_z = floor(boundary.position.y / step) * step
	var end_pos_x = ceil((boundary.position.x + boundary.size.x) / step) * step
	var end_pos_z = ceil((boundary.position.y + boundary.size.y) / step) * step
	var start_index_x: int = start_pos_x / Globals.WORLD_GRID_STEP
	var start_index_z: int = start_pos_z / Globals.WORLD_GRID_STEP
	var end_index_x: int = end_pos_x / Globals.WORLD_GRID_STEP
	var end_index_z: int = end_pos_z / Globals.WORLD_GRID_STEP

	for grid_index_x in range(start_index_x, end_index_x, Globals.SETTLEMENT_GRID_STEP):
		for grid_index_z in range(start_index_z, end_index_z, Globals.SETTLEMENT_GRID_STEP):
			# Need a way to reproduce the same result every time for random values, position is used since we always know it
			# will be the same for the same generation. This only works because we always set bounds to one terrain chunk at a time.
			rng.seed = hash(Vector2i(grid_index_x, grid_index_z))
			var rand_value_x = rng.randi_range(-Globals.SETTLEMENT_GRID_SPREAD, Globals.SETTLEMENT_GRID_SPREAD)
			var rand_value_z = rng.randi_range(-Globals.SETTLEMENT_GRID_SPREAD, Globals.SETTLEMENT_GRID_SPREAD)
			var grid_index = Vector2i(grid_index_x + rand_value_x, grid_index_z + rand_value_z)
			var position = WorldState.state.world_grid.get_grid_position(grid_index)
			var existing_settlement = settlements.get_item(Vector2(position.x, position.z))
			if existing_settlement:
				new_settlements.append(existing_settlement)
				continue
			if not WorldState.state.world_grid.is_grid_position_ok(position):
				continue
			var settlement_data = try_add_settlement(grid_index, rng)
			if settlement_data:
				settlements.insert({"position": Vector2(settlement_data.position.x, settlement_data.position.z), "data": settlement_data})
				new_settlements.append(settlement_data)
	return new_settlements

func try_add_settlement(grid_index: Vector2i, rng: RandomNumberGenerator) -> SettlementData:
	var has_tested_neighbors = false
	var pq: PriorityQueue = PriorityQueue.new()
	pq.push(grid_index, 0.0)
	while not pq.is_empty():
		var current_index = pq.pop()
		var current_position = WorldState.state.world_grid.get_grid_position(current_index)
		var too_steep = false
		var edges = WorldState.state.world_grid.get_grid_index_edges(current_index)
		var has_all_edges = edges.size() == 8 # Non-flat areas lack edges
		if has_all_edges:
			for edge_index in edges:
				var edge_position = WorldState.state.world_grid.get_grid_position(edge_index)
				var height_diff = abs(current_position.y - edge_position.y)
				if height_diff > Globals.MAX_SETTLEMENT_STEEPNESS:
					too_steep = true
					break
		if has_all_edges and not too_steep:
			return add_settlement(current_position, current_index, rng)
		else:
			# Not ok. Add startpoints' edges to check instead
			if not has_tested_neighbors:
				has_tested_neighbors = true
				for edge_index in edges:
					var edge_position = WorldState.state.world_grid.get_grid_position(edge_index)
					var height_diff = abs(current_position.y - edge_position.y)
					if height_diff < Globals.MAX_SETTLEMENT_STEEPNESS:
						pq.push(edge_index, height_diff)
	return null

func add_settlement(grid_position: Vector3, grid_index: Vector2i, rng: RandomNumberGenerator) -> SettlementData:
	const MAX_NUM_HOUSES = 5
	var num_houses = rng.randi_range(2, MAX_NUM_HOUSES)
	var start_rotation: float = rng.randf() * 2 * PI
	var house_spread_angle_multiplier: float = (MAX_NUM_HOUSES * 2 - num_houses)
	var last_angle: float = start_rotation
	var largest_radius: float = 0.0
	var houses: Array[WorldObject] = []
	for house_angle in num_houses:
		var angle = last_angle + PI / 3 * rng.randf_range(0.2, 0.3) * house_spread_angle_multiplier
		last_angle = angle
		var distance_from_town_center = rng.randf_range(10.0, Globals.MAX_SETTLEMENT_RADIUS) * (MAX_NUM_HOUSES + num_houses) / 10.0
		largest_radius = distance_from_town_center
		var rotated = Basis(Vector3.UP,  angle) * Vector3(1, 0, 0) * distance_from_town_center
		var house_position = grid_position + rotated
		house_position.y = WorldState.state.terrain_height_noise.get_height_at(house_position.x, house_position.z)
		houses.append(_add_house(house_position, Vector3(0.0, angle + PI, 0.0)))
	var chest = _add_chest(grid_position, Vector3(0.0, rng.randf_range(0.0, 2 * PI), 0.0))
	var settlement_radius = largest_radius + 5.0
	return SettlementData.new(grid_index, grid_position, settlement_radius, houses, chest)

func is_inside_settlement(position: Vector3, object_id: WorldObject.ObjectId) -> bool:
	var is_removable_type: bool = \
		object_id == WorldObject.ObjectId.TREE or \
		object_id == WorldObject.ObjectId.ROCK or \
		object_id == WorldObject.ObjectId.BERRYBUSH or \
		object_id == WorldObject.ObjectId.BERRYBUSH_FULL
	if is_removable_type:
		var close_settlements = settlements.query_circle(Vector2(position.x, position.z), Globals.MAX_SETTLEMENT_RADIUS + 1.0)
		if close_settlements.size() > 0:
			return true
	return false


func _add_house(position: Vector3, rotation: Vector3) -> WorldObject:
	return WorldObject.create_object(WorldObject.ObjectId.HOUSE, position, rotation)

func _add_chest(position: Vector3, rotation: Vector3) -> WorldObject:
	position.y = WorldState.state.terrain_height_noise.get_height_at(position.x, position.z)
	return WorldObject.create_object(WorldObject.ObjectId.CHEST, position, rotation)

func add_settlement_objects(multimesh_chunk: MultiMeshChunk, object_id: WorldObject.ObjectId) -> void:
	match object_id:
		WorldObject.ObjectId.HOUSE:
			for settlement in settlements.query(multimesh_chunk.chunk_boundary):
				for house in settlement.houses:
					multimesh_chunk.place(house)
		WorldObject.ObjectId.CHEST:
			for settlement in settlements.query(multimesh_chunk.chunk_boundary):
				multimesh_chunk.place(settlement.chest)

func destroy():
	added_terrain_angle_boundaries = {}
	settlements = Quadtree.new()
