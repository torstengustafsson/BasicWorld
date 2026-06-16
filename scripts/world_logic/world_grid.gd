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
	Vector2i(-Globals.WORLD_GRID_STEP, -Globals.WORLD_GRID_STEP),
	Vector2i(0, -Globals.WORLD_GRID_STEP),
	Vector2i(Globals.WORLD_GRID_STEP, -Globals.WORLD_GRID_STEP),
	Vector2i(-Globals.WORLD_GRID_STEP, 0),
	Vector2i(Globals.WORLD_GRID_STEP, 0),
	Vector2i(-Globals.WORLD_GRID_STEP, Globals.WORLD_GRID_STEP),
	Vector2i(0, Globals.WORLD_GRID_STEP),
	Vector2i(Globals.WORLD_GRID_STEP, Globals.WORLD_GRID_STEP),
]

var world_state: WorldState

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var grid_point_edges: Quadtree = Quadtree.new() # Data type: Dictionary[Vector2i, PointWithEdges]

var max_weight: float = -1.0
var grid_boundary: Rect2 = Rect2(Vector2(0.0, 0.0), Vector2(0.0, 0.0))

func _init(_world_state: WorldState) -> void:
	world_state = _world_state
	grid_point_edges.boundary = Rect2(Vector2(-INF, -INF), Vector2(INF, INF))

func add_rect_margins(rect: Rect2, margins: float) -> Rect2:
	return Rect2(
		rect.position - Vector2(margins, margins),
		rect.size + Vector2(2 * margins, 2 * margins)
	)

func add_grid_boundary(boundary: Rect2):
	# TODO: At some point maybe clean up since now grid points will keep expanding?
	grid_boundary = grid_boundary.merge(boundary)

	# Need a way to reproduce the same result every time for random values, position is used since we always know it
	# will be the same for the same generation. This only works because we always set bounds to one terrain chunk at a time.
	rng.seed = hash(boundary.position)

	add_grid_points(boundary)

	var boundary_with_grid_margins = add_rect_margins(boundary, Globals.WORLD_GRID_STEP)
	add_point_edges(boundary_with_grid_margins)

	calculate_weights(boundary_with_grid_margins)

func add_grid_points(boundary: Rect2) -> void:
	var start_pos_x: int = ceil(boundary.position.x / Globals.WORLD_GRID_STEP) * Globals.WORLD_GRID_STEP
	var start_pos_z: int = ceil(boundary.position.y / Globals.WORLD_GRID_STEP) * Globals.WORLD_GRID_STEP

	for grid_point_x in range(start_pos_x, boundary.position.x + boundary.size.x, Globals.WORLD_GRID_STEP):
		for grid_point_z in range(start_pos_z, boundary.position.y + boundary.size.y, Globals.WORLD_GRID_STEP):
			var height = world_state.terrain_height_noise.get_height_at(grid_point_x, grid_point_z)
			var rand_value_x = (-Globals.WORLD_GRID_STEP / 4.0 + rng.randf_range(0.0, Globals.WORLD_GRID_STEP / 2.0))
			var rand_value_z = (-Globals.WORLD_GRID_STEP / 4.0 + rng.randf_range(0.0, Globals.WORLD_GRID_STEP / 2.0))
			var point = Vector3(grid_point_x + rand_value_x, height, grid_point_z + rand_value_z)
			var current_point = PointWithEdges.new(point)

			var point_too_steep = MathFunctions.get_terrain_angle_at_position(point, world_state.space_state) > Globals.MAX_GRID_STEEPNESS
			if point_too_steep:
				continue

			grid_point_edges.insert({"position": Vector2(grid_point_x, grid_point_z), "data": current_point})

# Also removes points without neightbors
func add_point_edges(boundary: Rect2) -> void:
	var to_be_removed = []
	var points_to_add_edges = grid_point_edges.query(boundary)
	for grid_point_data in points_to_add_edges:
		var grid_point = grid_point_data["data"]
		var grid_point_position = grid_point_data["position"]
		for point_around: Vector2i in POINTS_AROUND:
			var neighbor: Vector2i = Vector2i(grid_point_position) + point_around
			var edge_too_steep = _edge_too_steep(grid_point.point, neighbor)
			if not edge_too_steep:
				grid_point.edges.append(GridPointEdge.new(neighbor))
		if grid_point.edges.size() == 0:
			to_be_removed.append(grid_point)

	for grid_point in to_be_removed:
		grid_point_edges.remove(grid_point)

	# Remove edges whose destination does not exist
	var points_to_remove_edges = grid_point_edges.query(boundary)
	for grid_point_data in points_to_remove_edges:
		var edges_to_be_removed = []
		var grid_point = grid_point_data["data"]
		for edge in grid_point.edges:
			if not grid_point_edges.get_item(edge.grid_point):
				edges_to_be_removed.append(edge)
		for edge in edges_to_be_removed:
			grid_point.edges.erase(edge)

func remove_points_and_edges(_boundary: Rect2):
	pass

func calculate_weights(boundary: Rect2):
	for grid_point_data in grid_point_edges.query(boundary):
		var grid_point = grid_point_data["data"]
		for edge in grid_point.edges:
			var neighbor = grid_point_edges.get_item(edge.grid_point)
			if not neighbor:
				continue
			var edge_angle = MathFunctions.calculate_angle_between_points(grid_point.point, neighbor.point)
			var from = grid_point.point
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

func _edge_too_steep(point: Vector3, neighbor: Vector2i) -> bool:
	if not grid_point_edges.get_item(neighbor):
		return true
	var grid_point_edge = grid_point_edges.get_item(neighbor)
	if not grid_point_edge:
		return INF
	var edge_angle = MathFunctions.calculate_angle_between_points(point, grid_point_edge.point)
	return edge_angle > Globals.MAX_GRID_STEEPNESS

# Uncomment to render grid. Tanks performance.
# func _process(_delta):
# 	render_grid()

# func render_grid():
# 	for grid_point in grid_point_edges.query_all():
# 		var point_with_edges = grid_point["data"]
# 		var point_height = world_state.terrain_height_noise.get_height_at(point_with_edges.point.x, point_with_edges.point.z)
# 		DebugDraw3D.draw_sphere(Vector3(point_with_edges.point.x, point_height + 0.5, point_with_edges.point.z))
# 		for edge in point_with_edges.edges:
# 			var neighbor = grid_point_edges.get_item(edge.grid_point)
# 			if not neighbor:
# 				continue
# 			# Color lines by their weight
# 			var red = edge.weight / max_weight
# 			var color = Color(red, 0.0, 0.0, 1.0)
# 			var neighbor_height = world_state.terrain_height_noise.get_height_at(neighbor.point.x, neighbor.point.z)
# 			DebugDraw3D.draw_line(
# 				Vector3(point_with_edges.point.x, point_height + 0.5, point_with_edges.point.z),
# 				Vector3(neighbor.point.x, neighbor_height + 0.5, neighbor.point.z), color
# 			)
