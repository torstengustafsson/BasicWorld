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

var added_boundaries: Dictionary[Rect2, bool] = {}

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var world_state: WorldState
var settlements: Quadtree = Quadtree.new()

func _init(_world_state: WorldState):
	world_state = _world_state
	settlements.boundary = Rect2(Vector2(-INF, -INF), Vector2(INF, INF))
	add_to_group("Persist")

func create_settlements(boundary: Rect2) -> void:
	# Need a way to reproduce the same result every time for random values, position is used since we always know it
	# will be the same for the same generation. This only works because we always set bounds to one terrain chunk at a time.
	rng.seed = hash(boundary.position)

	if added_boundaries.has(boundary):
		return
	added_boundaries[boundary] = true

	var start_pos: int = int(boundary.position.x) + int(boundary.position.x) % Globals.SETTLEMENT_GRID_STEP
	for grid_point_x in range(start_pos, boundary.size.x, Globals.SETTLEMENT_GRID_STEP):
		var rand_value_x = rng.randi_range(-Globals.SETTLEMENT_GRID_SPREAD, Globals.SETTLEMENT_GRID_SPREAD)
		for grid_point_z in range(0, boundary.size.y, Globals.SETTLEMENT_GRID_STEP):
			var rand_value_z = rng.randi_range(-Globals.SETTLEMENT_GRID_SPREAD, Globals.SETTLEMENT_GRID_SPREAD)
			var grid_point = Vector2i(grid_point_x + rand_value_x, grid_point_z + rand_value_z)
			var grid_position: WorldGrid.PointWithEdges = world_state.world_grid.grid_point_edges.get(grid_point, null)
			if not grid_position:
				continue
			var settlement_data = try_add_settlement(grid_point, grid_position)
			if settlement_data:
				settlements.insert({"position": Vector2(settlement_data.position.x, settlement_data.position.z), "data": settlement_data})

func try_add_settlement(grid_point: Vector2i, grid_position: WorldGrid.PointWithEdges) -> SettlementData:
	var has_tested_neighbors = false
	var pq: PriorityQueue = PriorityQueue.new()
	pq.push(grid_position, 0.0)
	while not pq.is_empty():
		var current = pq.pop()
		var not_too_steep = true
		for edge in current.edges:
			var height_diff = abs(current.point.y - world_state.world_grid.grid_point_edges[edge.grid_point].point.y)
			if height_diff > Globals.MAX_SETTLEMENT_STEEPNESS:
				not_too_steep = false
				break
		var has_all_egdes = current.edges.size() == 8 # Non-flat areas lack edges
		if has_all_egdes and not_too_steep:
			return add_settlement(grid_point, grid_position.point)
		else:
			# Not ok. Test placing settlement on startpoints' edges instead
			if not has_tested_neighbors:
				has_tested_neighbors = true
				for edge in current.edges:
					var edge_grid_position = world_state.world_grid.grid_point_edges[edge.grid_point]
					var height_diff = abs(current.point.y - world_state.world_grid.grid_point_edges[edge.grid_point].point.y)
					if height_diff < Globals.MAX_SETTLEMENT_STEEPNESS:
						pq.push(edge_grid_position, height_diff)
	return null

func add_settlement(grid_position: Vector2i, position: Vector3) -> SettlementData:
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
		var house_position = position + rotated
		house_position.y = world_state.terrain_height_noise.get_height_at(house_position.x, house_position.z)
		add_house(house_position, Vector3(0.0, angle + PI, 0.0))

	var chest_rotation = rng.randf_range(0.0, 2 * PI)
	add_chest(position, Vector3(0.0, chest_rotation, 0.0))

	var settlement_radius = largest_radius + 5.0
	return SettlementData.new(grid_position, position, settlement_radius, num_houses)

func add_house(position: Vector3, rotation: Vector3) -> WorldObject:
	var house = WorldObject.add_house(position, rotation, world_state.static_objects_qt)
	return house

func add_chest(position: Vector3, rotation: Vector3) -> WorldObject:
	var chest = WorldObject.add_chest(position, rotation, world_state.static_objects_qt)
	return chest

func remove_objects_from_settlements(boundary: Rect2, remove_callback: Callable):
	for settlement in settlements.query(boundary):
		var settlement_data = settlement["data"]
		if not boundary.has_point(Vector2(settlement_data.position.x, settlement_data.position.z)):
			continue
		var objects = world_state.static_objects_qt.query_circle(Vector2(settlement_data.position.x, settlement_data.position.z), settlement_data.radius)
		for index in objects.size():
			var object: WorldObject = objects[index]["data"]
			var object_pos = Vector2(object.instance.position.x, object.instance.position.z)
			var settlement_pos = Vector2(settlement_data.position.x, settlement_data.position.z)
			var is_removable_type: bool = \
				object.object_id == WorldObject.ObjectId.TREE or \
				object.object_id == WorldObject.ObjectId.ROCK or \
				object.object_id == WorldObject.ObjectId.BERRYBUSH
			if is_removable_type and object_pos.distance_to(settlement_pos) < settlement_data.radius + 1.0:
				remove_callback.call(object)


func save() -> Dictionary:
	#TODO
	return {}

func load(_data: Dictionary):
	#TODO
	pass
