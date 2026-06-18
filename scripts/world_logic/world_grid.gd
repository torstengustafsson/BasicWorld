# Extend Node3D to be able to draw debug meshes
class_name  WorldGrid extends Node3D

# class GridPointEdge:
# 	var grid_point: Vector2i
# 	var weight: float = 0.0

# 	func _init(_grid_point: Vector2i) -> void:
# 		grid_point = _grid_point

# class PointWithEdges:
# 	var point: Vector3
# 	var edges: Array[GridPointEdge] = []
# 	func _init(_point: Vector3):
# 		point = _point

const NO_GRID_POINT = Vector2i(INF, INF)

const POINTS_AROUND: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1),
]

var world_state: WorldState

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var max_weight: float = -1.0

var added_boundaries: Dictionary[Rect2, bool] = {}

# Uncomment for debugging generated paths
# class PointData:
# 	var color: Color
# 	var came_from: Vector3
# var added_points: Dictionary[Vector3, PointData] = {}
# func _process(_delta):
# 	render_grid_points()

# func render_grid_points():
# 	for point in added_points.keys():
# 		DebugDraw3D.draw_sphere(point + Vector3(0.0, 1.0, 0.0), 2.5, Color(added_points[point].color, 1.0))
# 		DebugDraw3D.draw_line(point + Vector3(0.0, 1.0, 0.0), added_points[point].came_from + Vector3(0.0, 1.0, 0.0), Color(1.0, 0.0, 0.0, 1.0))


func _init(_world_state: WorldState) -> void:
	world_state = _world_state

func is_grid_position_ok(grid_position: Vector3) -> bool:
	return MathFunctions.get_terrain_angle_at_position(grid_position, world_state.space_state) <= Globals.MAX_GRID_STEEPNESS

func is_grid_index_ok(grid_index: Vector2i) -> bool:
	return is_grid_position_ok(get_grid_position(grid_index))


func get_grid_position(grid_index: Vector2i) -> Vector3:
	rng.seed = hash(grid_index)
	var rand_value_x = (-Globals.WORLD_GRID_STEP / 4.0 + rng.randf_range(0.0, Globals.WORLD_GRID_STEP / 2.0))
	var rand_value_z = (-Globals.WORLD_GRID_STEP / 4.0 + rng.randf_range(0.0, Globals.WORLD_GRID_STEP / 2.0))
	var grid_position_x = grid_index.x * Globals.WORLD_GRID_STEP
	var grid_position_z = grid_index.y * Globals.WORLD_GRID_STEP
	var height = world_state.terrain_height_noise.get_height_at(grid_position_x, grid_position_z)
	var grid_position = Vector3(grid_position_x + rand_value_x, height, grid_position_z + rand_value_z)
	return grid_position

func get_grid_index_edges(grid_index: Vector2i) -> Array[Vector2i]:
	var edges: Array[Vector2i] = []
	for point_around: Vector2i in POINTS_AROUND:
		var neighbor_index: Vector2i = grid_index + point_around
		if _is_edge_index_position_ok(grid_index, neighbor_index):
			edges.append(neighbor_index)
	return edges

# This will return its result backwards, meaning from destination to start position. Use reverse sort if order is
# important (array.reverse()). This is not done here for performance reasons, and because it is not always needed.
func generate_shortest_distance_between_grid_points(grid_from: Vector2i, grid_destination: Vector2i, max_distance: float) -> Array[Vector3]:
	const MAX_ITERATIONS = 100
	var pq: PriorityQueue = PriorityQueue.new()
	pq.push(grid_from, 0.0)
	var came_from: Dictionary[Vector2i, Vector2i] = { grid_from: NO_GRID_POINT }
	var cost_so_far: Dictionary[Vector2i, float] = { grid_from: 0.0 }
	var iterations = 0
	while not pq.is_empty() and iterations < MAX_ITERATIONS:
		var current_index = pq.pop()
		if current_index == grid_destination:
			break
		var current_position = get_grid_position(current_index)
		for edge_index in get_grid_index_edges(current_index):
			var next_position = get_grid_position(edge_index)
			var new_cost = cost_so_far[current_index] + _calculate_weight(current_position, next_position)
			if new_cost > max_distance:
				continue
			if not cost_so_far.has(edge_index) or new_cost < cost_so_far[edge_index]:
				cost_so_far[edge_index] = new_cost
				var priority = new_cost + _distance_heuristic(grid_destination, edge_index)
				pq.push(edge_index, priority)
				# Uncomment together with _process function for debugging
				# added_points[next_position] = PointData.new()
				# added_points[next_position].color = Color(1.0, 0.0, 0.0) if cost_so_far.size() < 50 else Color(0.0, 1.0, 0.0) if cost_so_far.size() < 100 else Color(0.0, 0.0, 1.0)
				# added_points[next_position].came_from = current_position
				came_from[edge_index] = current_index
		iterations += 1

	if not cost_so_far.has(grid_destination):
		# No path found
		return []

	if cost_so_far[grid_destination] > max_distance:
		# Shortest path is too long
		return []

	# Step backwards to find the shortest path
	var result: Array[Vector3] = []
	var current_step_index = grid_destination
	iterations = 0
	while current_step_index != grid_from:
		if iterations > MAX_ITERATIONS:
			print("No path found between " + str(grid_from) + " and " + str(grid_destination))
			break
		iterations += 1
		var current_position = get_grid_position(current_step_index)
		result.append(current_position)
		var previous_step = came_from[current_step_index]
		current_step_index = previous_step

	result.append(get_grid_position(grid_from))

	return result

# Assumes both inputs are neighbors. If not this will not work as expected.
func _is_edge_index_position_ok(grid_index: Vector2i, neighbor_index: Vector2i) -> bool:
	var grid_position = get_grid_position(grid_index)
	var neighbor_position = get_grid_position(neighbor_index)
	if not (is_grid_position_ok(grid_position) or is_grid_position_ok(neighbor_position)):
		return false
	var angle = MathFunctions.calculate_angle_between_points(grid_position, neighbor_position)
	return angle <= Globals.MAX_GRID_STEEPNESS

func _get_num_objects_in_edge(grid_position: Vector3, neighbor_position: Vector3, objects: Array, width_to_check: float) -> int:
	var result: int = 0
	var a = Vector2(grid_position.x, grid_position.z)
	var b = Vector2(neighbor_position.x, neighbor_position.z)
	var ab: Vector2 = b - a
	for object in objects:
		var instance: Node3D = object["data"].instance
		var instance_pos = Vector2(instance.position.x, instance.position.z)
		var ap: Vector2 = instance_pos - a;
		var t: float = clamp(ap.dot(ab) / ab.dot(ab), 0.0, 1.0);
		var closest: Vector2 = a + t * ab;
		var road_dist: float = (instance_pos - closest).length()
		if road_dist < width_to_check:
			result += 1
	return result

func _calculate_weight(grid_position: Vector3, neighbor_position: Vector3) -> float:
	var edge_angle = MathFunctions.calculate_angle_between_points(grid_position, neighbor_position)
	var query_rect = Rect2(
		min(grid_position.x, neighbor_position.x) - Globals.ROAD_WIDTH,
		min(grid_position.z, neighbor_position.z) - Globals.ROAD_WIDTH,
		abs(grid_position.x - neighbor_position.x) + 2 * Globals.ROAD_WIDTH,
		abs(grid_position.z - neighbor_position.z) + 2 * Globals.ROAD_WIDTH)
	var objects = world_state.static_objects_qt.query(query_rect)
	var num_obstacles = 0 if objects.size() == 0 else _get_num_objects_in_edge(grid_position, neighbor_position, objects, Globals.ROAD_WIDTH)
	var distance = (grid_position - neighbor_position).length()
	# Every object in the way adds weight 10, every flat meter adds weight 1, adding a multiplier of 1 more per meter, per 10 degrees steepness
	var weight = num_obstacles * 10.0 + distance * (1 + edge_angle * 0.1)
	if max_weight < weight:
		max_weight = weight
	return weight

func _distance_heuristic(a: Vector2i, b: Vector2i):
	return (a - b).length() * Globals.WORLD_GRID_STEP * 2
