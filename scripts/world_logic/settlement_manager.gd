extends Node

class_name SettlementManager

class Transform:
	var position: Vector3
	var rotation: Vector3
	var scale: Vector3
	func _init(_position: Vector3, _rotation: Vector3, _scale: Vector3) -> void:
		position = _position
		rotation = _rotation
		scale = _scale

class SettlementData:
	var grid_index: Vector2i
	var position: Vector3
	var radius: float
	var house_transforms: Array[Transform]
	var chest_transform: Transform
	func _init(_grid_index, _position, _radius, _house_transforms, _chest_transform) -> void:
		grid_index = _grid_index
		position = _position
		radius = _radius
		house_transforms = _house_transforms
		chest_transform = _chest_transform

	func get_num_houses():
		return house_transforms.size()

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var settlements: Quadtree = Quadtree.new()

func _init():
	settlements.boundary = Rect2(Vector2(-INF, -INF), Vector2(INF, INF))
	add_to_group("Persist")

func create_settlements(boundary: Rect2) -> Array[SettlementData]:
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
				_add_settlement_to_scene(existing_settlement)
				continue
			if not WorldState.state.world_grid.is_grid_index_ok(grid_index):
				continue
			var settlement_data = try_add_settlement(grid_index)
			if settlement_data:
				settlements.insert({"position": Vector2(position.x, position.z), "data": settlement_data})
				new_settlements.append(settlement_data)
				_add_settlement_to_scene(settlement_data)
	return new_settlements

func try_add_settlement(grid_index: Vector2i) -> SettlementData:
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
			return add_settlement(current_position, current_index)
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

func add_settlement(grid_position: Vector3, grid_index: Vector2i) -> SettlementData:
	const MAX_NUM_HOUSES = 5
	var num_houses = rng.randi_range(2, MAX_NUM_HOUSES)
	var start_rotation: float = rng.randf() * 2 * PI
	var house_spread_angle_multiplier: float = (MAX_NUM_HOUSES * 2 - num_houses)
	var last_angle: float = start_rotation
	var largest_radius: float = 0.0
	var houses: Array[Transform] = []
	for house_angle in num_houses:
		var angle = last_angle + PI / 3 * rng.randf_range(0.2, 0.3) * house_spread_angle_multiplier
		last_angle = angle
		var distance_from_town_center = rng.randf_range(10.0, 16.0) * (MAX_NUM_HOUSES + num_houses) / 10.0
		largest_radius = distance_from_town_center
		var rotated = Basis(Vector3.UP,  angle) * Vector3(1, 0, 0) * distance_from_town_center
		var house_position = grid_position + rotated
		house_position.y = WorldState.state.terrain_height_noise.get_height_at(house_position.x, house_position.z)
		houses.append(_add_house(house_position, Vector3(0.0, angle + PI, 0.0)))
	var chest = _add_chest(grid_position, Vector3(0.0, rng.randf_range(0.0, 2 * PI), 0.0))
	var settlement_radius = largest_radius + 5.0
	return SettlementData.new(grid_index, grid_position, settlement_radius, houses, chest)

func _add_house(position: Vector3, rotation: Vector3) -> Transform:
	var scale = Vector3(1.0 , 1.0, 1.0)
	return Transform.new(position, rotation, scale)

func _add_chest(position: Vector3, rotation: Vector3) -> Transform:
	position.y = WorldState.state.terrain_height_noise.get_height_at(position.x, position.z)
	var scale = Vector3(1.0 , 1.0, 1.0)
	return Transform.new(position, rotation, scale)

func _add_settlement_to_scene(settlement_data: SettlementData):
	for transform in settlement_data.house_transforms:
		var house = WorldState.state.pool_manager.get_mesh(WorldObject.ObjectId.HOUSE, transform.position, transform.scale)
		house.set_rotation(transform.rotation)
	var transform = settlement_data.chest_transform
	var chest = WorldState.state.pool_manager.get_mesh(WorldObject.ObjectId.CHEST, transform.position, transform.scale)
	chest.set_rotation(transform.rotation)

# Removes meshes, which in turn will nesure no object are created there as well
func remove_objects_from_settlements(settlements_to_check: Array[SettlementData]):
	for settlement in settlements_to_check:
		var meshes = WorldState.state.pool_manager.used_meshes_quadtree.query_circle(Vector2(settlement.position.x, settlement.position.z), settlement.radius + 1.0)
		for mesh in meshes:
			var object_id = mesh.get_meta("object_id")
			var is_removable_type: bool = \
				object_id == WorldObject.ObjectId.TREE or \
				object_id == WorldObject.ObjectId.ROCK or \
				object_id == WorldObject.ObjectId.BERRYBUSH_EMPTY or \
				object_id == WorldObject.ObjectId.BERRYBUSH_FULL
			if is_removable_type:
				WorldState.state.pool_manager.remove_mesh_with_id(mesh, object_id)

func save() -> Dictionary:
	#TODO
	return {}

func load(_data: Dictionary):
	#TODO
	pass
