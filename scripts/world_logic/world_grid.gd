# Extend Node3D to be able to draw debug meshes
class_name  WorldGrid extends Node3D

class GridPointEdge:
	var grid_point: Vector2i
	var weight: float = 0.0

	func _init(_grid_point: Vector2i) -> void:
		grid_point = _grid_point

class PointWithEdges:
	var point: Vector3
	var edges: Array[GridPointEdge] = []
	func _init(_point: Vector3):
		point = _point

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

var grid_point_edges: Dictionary[Vector2i, PointWithEdges] = {}
var world_bounds: Rect2
var max_weight: float = -1.0

func _init(_world_state: WorldState, _world_bounds: Rect2) -> void:
	world_state = _world_state
	world_bounds = _world_bounds
	create_points_and_edges()

func create_points_and_edges() -> Dictionary[Vector2i, PointWithEdges]:
	grid_point_edges.clear()

	# Add grid points
	for x: int in world_bounds.size.x / Globals.WORLD_GRID_STEP:
		for z: int in world_bounds.size.y / Globals.WORLD_GRID_STEP:
			var pos_x = world_bounds.position.x + x * Globals.WORLD_GRID_STEP
			var pos_z = world_bounds.position.y + z * Globals.WORLD_GRID_STEP
			var height = world_state.terrain_height_noise.get_height_at(pos_x, pos_z)
			var rand_value_x = (-Globals.WORLD_GRID_STEP / 4.0 + world_state.rng.randf_range(0.0, Globals.WORLD_GRID_STEP / 2.0))
			var rand_value_z = (-Globals.WORLD_GRID_STEP / 4.0 + world_state.rng.randf_range(0.0, Globals.WORLD_GRID_STEP / 2.0))
			var point = Vector3(pos_x + rand_value_x, height, pos_z + rand_value_z)
			var current_point = PointWithEdges.new(point)
			grid_point_edges[Vector2i(x, z)] = current_point

	# Add grid edges
	var to_be_removed = []
	for grid_point in grid_point_edges:
		var grid_point_edge = grid_point_edges[grid_point]
		for point_around: Vector2i in POINTS_AROUND:
			var neighbor: Vector2i = grid_point + point_around
			var edge_too_steep = _edge_too_steep(grid_point_edge.point, neighbor)
			if world_bounds.has_point(neighbor) and not edge_too_steep:
				grid_point_edge.edges.append(GridPointEdge.new(neighbor))
		var point_too_steep = MathFunctions.get_terrain_angle_at_position(grid_point_edge.point, world_state.space_state) > Globals.MAX_GRID_STEEPNESS
		if grid_point_edge.edges.size() == 0 or point_too_steep:
			to_be_removed.append(grid_point)

	for grid_point in to_be_removed:
		grid_point_edges.erase(grid_point)

	# Remove edges whose destination has been removed
	for grid_point in grid_point_edges:
		var edges_to_be_removed = []
		var grid_point_edge = grid_point_edges[grid_point]
		for edge in grid_point_edge.edges:
			if not grid_point_edges.has(edge.grid_point):
				edges_to_be_removed.append(edge)
		for edge in edges_to_be_removed:
			grid_point_edge.edges.erase(edge)

	return grid_point_edges

func calculate_weights():
	for grid_point in grid_point_edges:
		var grid_point_edge = grid_point_edges[grid_point]
		for edge in grid_point_edge.edges:
			var neighbor = grid_point_edges.get(edge.grid_point, null)
			if not neighbor:
				continue
			var edge_angle = MathFunctions.calculate_angle_between_points(grid_point_edge.point, neighbor.point)
			var from = grid_point_edge.point
			var to = neighbor.point
			var query_rect = Rect2(
				min(from.x, to.x) - Globals.ROAD_WIDTH,
				min(from.z, to.z) - Globals.ROAD_WIDTH,
				abs(from.x - to.x) + 2 * Globals.ROAD_WIDTH,
				abs(from.z - to.z) + 2 * Globals.ROAD_WIDTH)
			var objects = world_state.static_objects_qt.query(query_rect)
			var num_obstacles = get_num_objects_in_edge(from, to, objects, Globals.ROAD_WIDTH)
			var distance = (from - to).length()
			# Every object in the way adds weight 10, every flat meter adds weight 1, adding a multiplier of 1 more per meter, per 10 degrees steepness
			var weight = num_obstacles * 10.0 + distance * (1 + edge_angle * 0.1)
			if max_weight < weight:
				max_weight = weight
			edge.weight = weight


func get_num_objects_in_edge(from: Vector3, to: Vector3, objects: Array, width_to_check: float) -> int:
	var result: int = 0
	var a = Vector2(from.x, from.z)
	var b = Vector2(to.x, to.z)
	var ab: Vector2 = b - a
	for index in objects.size():
		var object: Node3D = objects[index]["data"].instance
		var object_pos = Vector2(object.position.x, object.position.z)
		var ap: Vector2 = object_pos - a;
		var t: float = clamp(ap.dot(ab) / ab.dot(ab), 0.0, 1.0);
		var closest: Vector2 = a + t * ab;
		var road_dist: float = (object_pos - closest).length()
		if road_dist < width_to_check:
			result += 1
	return result

func get_world_position(settlement: SettlementGenerator.SettlementData) -> Vector3:
	return grid_point_edges[settlement.grid_position].point

func _edge_too_steep(point: Vector3, neighbor: Vector2i) -> bool:
	if not grid_point_edges.has(neighbor):
		return true
	var edge_angle = MathFunctions.calculate_angle_between_points(point, grid_point_edges[neighbor].point)
	return edge_angle > Globals.MAX_GRID_STEEPNESS

# Uncomment to render grid. Tanks performance.
# func _process(_delta):
# 	render_grid()

# func render_grid():
# 	for grid_point in grid_point_edges:
# 		var point_with_edges = grid_point_edges[grid_point]
# 		var point_height = world_state.terrain_height_noise.get_height_at(point_with_edges.point.x, point_with_edges.point.z)
# 		DebugDraw3D.draw_sphere(Vector3(point_with_edges.point.x, point_height + 0.5, point_with_edges.point.z))
# 		for edge in point_with_edges.edges:
# 			var neighbor = grid_point_edges.get(edge.grid_point, null)
# 			if not neighbor:
# 				continue
# 			var red = edge.weight / max_weight
# 			var color = Color(red, 0.0, 0.0, 1.0)
# 			var neighbor_height = world_state.terrain_height_noise.get_height_at(neighbor.point.x, neighbor.point.z)
# 			DebugDraw3D.draw_line(
# 				Vector3(point_with_edges.point.x, point_height + 0.5, point_with_edges.point.z),
# 				Vector3(neighbor.point.x, neighbor_height + 0.5, neighbor.point.z), color
# 			)
