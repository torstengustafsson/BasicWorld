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

var grid_point_edges: Dictionary[Vector2i, PointWithEdges] = {}

var world_start_pos: Vector2
var world_end_pos: Vector2

var terrain_height_noise: TerrainNoise

var grid_size: int = 0

var max_weight: float = -1.0

func _init(_world_start_pos: Vector2, _world_end_pos: Vector2, _terrain_height_noise) -> void:
	world_start_pos = _world_start_pos
	world_end_pos = _world_end_pos
	terrain_height_noise = _terrain_height_noise
	var world_size = abs(world_start_pos.x - world_end_pos.x)
	grid_size = int(world_size / Globals.WORLD_GRID_STEP)
	if world_size != abs(world_start_pos.y - world_end_pos.y):
		print("Not Square world! Exiting.")
		get_tree().quit()
	create_points_and_edges()

func create_points_and_edges() -> Dictionary[Vector2i, PointWithEdges]:
	grid_point_edges.clear()

	# Add grid points
	for x: int in grid_size:
		for z: int in grid_size:
			var pos_x = world_start_pos.x + x * Globals.WORLD_GRID_STEP
			var pos_z = world_start_pos.y + z * Globals.WORLD_GRID_STEP
			var height = terrain_height_noise.get_height_at(pos_x, pos_z)
			var rand_value_x = (-Globals.WORLD_GRID_STEP / 4.0 + randf_range(0.0, Globals.WORLD_GRID_STEP / 2.0))
			var rand_value_z = (-Globals.WORLD_GRID_STEP / 4.0 + randf_range(0.0, Globals.WORLD_GRID_STEP / 2.0))
			var point = Vector3(pos_x + rand_value_x, height, pos_z + rand_value_z)
			var current_point = PointWithEdges.new(point)
			grid_point_edges[Vector2i(x, z)] = current_point

	# Add grid edges
	var to_be_removed = []
	for grid_point in grid_point_edges:
		var grid_point_edge = grid_point_edges[grid_point]
		for point_around: Vector2i in POINTS_AROUND:
			var neighbor: Vector2i = grid_point + point_around
			var out_of_bounds: bool = neighbor.x < 0 or neighbor.x >= grid_size or neighbor.y < 0 or neighbor.y >= grid_size
			var too_steep = false
			if grid_point_edges.has(neighbor):
				too_steep = abs(MathFunctions.calculate_angle_between_points(grid_point_edge.point, grid_point_edges[neighbor].point)) > Globals.MAX_GRID_STEEPNESS
			if not out_of_bounds and not too_steep:
				grid_point_edge.edges.append(GridPointEdge.new(neighbor))
		if grid_point_edge.edges.size() == 0:
			to_be_removed.append(grid_point)
	for grid_point in to_be_removed:
		grid_point_edges.erase(grid_point)
	return grid_point_edges

func calculate_weights(qt: Quadtree):
	for grid_point in grid_point_edges:
		var point_with_edges = grid_point_edges[grid_point]
		for edge in point_with_edges.edges:
			var neighbor = grid_point_edges.get(edge.grid_point, null)
			if not neighbor:
				continue
			var from = point_with_edges.point
			var to = neighbor.point
			var query_rect = Rect2(
				min(from.x, to.x) - Globals.ROAD_WIDTH,
				min(from.z, to.z) - Globals.ROAD_WIDTH,
				abs(from.x - to.x) + 2 * Globals.ROAD_WIDTH,
				abs(from.z - to.z) + 2 * Globals.ROAD_WIDTH)
			var objects = qt.query(query_rect)
			var num_obstacles = get_num_objects_in_edge(from, to, objects, Globals.ROAD_WIDTH)
			var distance = (from - to).length()
			var weight = num_obstacles * 10.0 + distance
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


# Uncomment to render grid. Tanks performance.
# func _process(_delta):
# 	render_grid()

# func render_grid():
# 	for grid_point in grid_point_edges:
# 		var point_with_edges = grid_point_edges[grid_point]
# 		var point_height = terrain_height_noise.get_height_at(point_with_edges.point.x, point_with_edges.point.z)
# 		DebugDraw3D.draw_sphere(Vector3(point_with_edges.point.x, point_height + 0.5, point_with_edges.point.z))
# 		for edge in point_with_edges.edges:
# 			var neighbor = grid_point_edges.get(edge.grid_point, null)
# 			if not neighbor:
# 				continue
# 			var red = edge.weight / max_weight
# 			var color = Color(red, 0.0, 0.0, 1.0)
# 			var neighbor_height = terrain_height_noise.get_height_at(neighbor.point.x, neighbor.point.z)
# 			DebugDraw3D.draw_line(
# 				Vector3(point_with_edges.point.x, point_height + 0.5, point_with_edges.point.z),
# 				Vector3(neighbor.point.x, neighbor_height + 0.5, neighbor.point.z), color
# 			)
