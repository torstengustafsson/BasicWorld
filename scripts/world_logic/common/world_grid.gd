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

var max_weight: float = -1.0

var added_boundaries: Dictionary[Rect2, bool] = {}

# Uncomment for debugging generated paths
# class PointData:
# 	var color: Color
# 	var came_from: Vector3
# var added_points: Dictionary[Vector3, PointData] = {}
# func _process(_delta):
# 	for point in added_points.keys():
# 		DebugDraw3D.draw_sphere(point + Vector3(0.0, 1.0, 0.0), 2.5, Color(added_points[point].color, 1.0))
# 		DebugDraw3D.draw_line(point + Vector3(0.0, 1.0, 0.0), added_points[point].came_from + Vector3(0.0, 1.0, 0.0), Color(1.0, 0.0, 0.0, 1.0))


func is_grid_position_ok(grid_position: Vector3) -> bool:
	var angle = TerrainManager.get_terrain_angle_at_position(grid_position)
	return angle != Globals.NOT_A_NUMBER and angle <= Globals.MAX_GRID_STEEPNESS

func get_grid_position(grid_index: Vector2i) -> Vector3:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(grid_index)
	var rand_value_x = (-Globals.WORLD_GRID_STEP / 4.0 + rng.randf_range(0.0, Globals.WORLD_GRID_STEP / 2.0))
	var rand_value_z = (-Globals.WORLD_GRID_STEP / 4.0 + rng.randf_range(0.0, Globals.WORLD_GRID_STEP / 2.0))
	var grid_position_x = grid_index.x * Globals.WORLD_GRID_STEP
	var grid_position_z = grid_index.y * Globals.WORLD_GRID_STEP
	var height = WorldState.state.terrain_height_noise.get_height_at(grid_position_x, grid_position_z)
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
	# var debug_color = Color(randf_range(0.0, 1.0), randf_range(0.0, 1.0), randf_range(0.0, 1.0))
	var a = get_grid_position(grid_from)
	var b = get_grid_position(grid_destination)
	var query_rect = Rect2(
		Vector2(min(a.x, b.x) - Globals.WORLD_GRID_STEP * 3, min(a.z, b.z) - Globals.WORLD_GRID_STEP * 3),
		Vector2(abs(a.x - b.x) + 2 * Globals.WORLD_GRID_STEP * 3, abs(a.z - b.z) + 2 * Globals.WORLD_GRID_STEP * 3))


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

			var existing_road_cost_multiplier = 1.0
			for road_segment in WorldState.state.road_manager.road_segments.query(query_rect):
				if (road_segment.from == Vector2(current_position.x, current_position.z) and road_segment.to == Vector2(next_position.x, next_position.z)) \
					or (road_segment.from == Vector2(next_position.x, next_position.z) and road_segment.to == Vector2(current_position.x, current_position.z)):
					# Following existing road
					existing_road_cost_multiplier = 0.1
					break
				if road_segment.to == Vector2(next_position.x, next_position.z) or road_segment.from == Vector2(next_position.x, next_position.z):
					# Found existing road, but do not yet follow it
					existing_road_cost_multiplier = 0.9

			var new_cost = cost_so_far[current_index] + _calculate_weight(current_position, next_position) * existing_road_cost_multiplier

			if new_cost > max_distance:
				continue
			if not cost_so_far.has(edge_index) or new_cost < cost_so_far[edge_index]:
				cost_so_far[edge_index] = new_cost
				var priority = new_cost + _distance_heuristic(grid_destination, edge_index) * existing_road_cost_multiplier
				pq.push(edge_index, priority)
				# Uncomment together with _process function for debugging
				# added_points[next_position] = PointData.new()
				# added_points[next_position].color = debug_color
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
			print("No path found between ", grid_from, " and ", grid_destination, " (", get_grid_position(grid_from), ", ", get_grid_position(grid_destination), ")")
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

func _get_num_objects_in_edge(grid_position: Vector3, neighbor_position: Vector3, objects: Array) -> int:
	var result: int = 0
	var a = Vector2(grid_position.x, grid_position.z)
	var b = Vector2(neighbor_position.x, neighbor_position.z)
	var ab: Vector2 = b - a
	for object in objects:
		var object_position = Vector2(object.position.x, object.position.z)
		var ap: Vector2 = object_position - a;
		var t: float = clamp(ap.dot(ab) / ab.dot(ab), 0.0, 1.0);
		var closest: Vector2 = a + t * ab;
		var road_dist: float = (object_position - closest).length()
		if road_dist < Globals.ROAD_WIDTH + Globals.ROAD_MARGIN:
			result += 1
	return result

func _calculate_weight(grid_position: Vector3, neighbor_position: Vector3) -> float:
	var query_rect = Rect2(
		min(grid_position.x, neighbor_position.x) - Globals.ROAD_WIDTH - Globals.ROAD_MARGIN,
		min(grid_position.z, neighbor_position.z) - Globals.ROAD_WIDTH - Globals.ROAD_MARGIN,
		abs(grid_position.x - neighbor_position.x) + 2 * Globals.ROAD_WIDTH + Globals.ROAD_MARGIN,
		abs(grid_position.z - neighbor_position.z) + 2 * Globals.ROAD_WIDTH + Globals.ROAD_MARGIN)
	var objects = WorldState.state.multimesh_manager.get_all_objects_in_boundary(query_rect)
	var num_obstacles = 0 if objects.size() == 0 else _get_num_objects_in_edge(grid_position, neighbor_position, objects)
	var distance = (grid_position - neighbor_position).length()
	# Every object in the way adds weight 20, every flat meter adds weight 1, adding a multiplier of 1 more per meter, per 10 degrees steepness
	var edge_angle = MathFunctions.calculate_angle_between_points(grid_position, neighbor_position)
	var weight = num_obstacles * 20.0 + distance * (1 + edge_angle * 0.1)
	if max_weight < weight:
		max_weight = weight
	return weight

func _distance_heuristic(a: Vector2i, b: Vector2i):
	return (a - b).length() * Globals.WORLD_GRID_STEP * 2

func destroy():
	added_boundaries.clear()
