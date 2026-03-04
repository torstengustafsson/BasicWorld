# Extend Node3D to be able to draw debug meshes
class_name  WorldGrid extends Node3D

class GridPointEdge:
	var grid_point: Vector2i
	var weight: float

	func _init(_grid_point: Vector2i, _weight: float = 0.0) -> void:
		grid_point = _grid_point
		weight = _weight

class PointWithEdges:
	var point: Vector3
	var edges: Array[GridPointEdge] = []
	func _init(_point: Vector3):
		point = _point

var POINTS_AROUND: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1),
]

var WORLD_SIZE: int
const WORLD_GRID_STEP: int = 10
var ROAD_WIDTH: float
var grid_point_edges: Dictionary[Vector2i, PointWithEdges] = {}

var world_start_pos: Vector2
var world_end_pos: Vector2

var grid_size: int = 0

var max_weight: float = -1.0

func _init(_world_start_pos: Vector2, _world_end_pos: Vector2, road_width: float) -> void:
	world_start_pos = _world_start_pos
	world_end_pos = _world_end_pos
	WORLD_SIZE = abs(world_start_pos.x - world_end_pos.x)
	grid_size = WORLD_SIZE / WORLD_GRID_STEP
	if WORLD_SIZE != abs(world_start_pos.y - world_end_pos.y):
		print("Not Square world! Exiting.")
		get_tree().quit()
	ROAD_WIDTH = road_width
	create_points_and_edges()

func create_points_and_edges() -> Dictionary[Vector2i, PointWithEdges]:
	grid_point_edges.clear()

	for x: int in grid_size:
		for z: int in grid_size:
			var pos_x = world_start_pos.x + x * WORLD_GRID_STEP
			var pos_z = world_start_pos.y + z * WORLD_GRID_STEP
			var rand_value_x = (-WORLD_GRID_STEP / 4.0 + randf_range(0.0, WORLD_GRID_STEP / 2.0))
			var rand_value_z = (-WORLD_GRID_STEP / 4.0 + randf_range(0.0, WORLD_GRID_STEP / 2.0))
			var point = Vector3(pos_x + rand_value_x, 0.0, pos_z + rand_value_z)
			var current_point = PointWithEdges.new(point)
			for point_around: Vector2i in POINTS_AROUND:
				var neighbor: Vector2i = Vector2i(x + point_around.x, z + point_around.y)
				var weight = 0.0
				if neighbor.x < 0 or neighbor.x >= grid_size or neighbor.y < 0 or neighbor.y >= grid_size:
					continue
				current_point.edges.append(GridPointEdge.new(neighbor, weight))
			grid_point_edges[Vector2i(x, z)] = current_point
	return grid_point_edges

# TODO: This can be optimized by only checking objects that are close to the edge (e.g. using a quadtree)
func calculate_weights(qt: Quadtree):
	for grid_point in grid_point_edges:
		var point_with_edges = grid_point_edges[grid_point]
		for edge in point_with_edges.edges:
			var neighbor = grid_point_edges.get(edge.grid_point, null)
			if not neighbor:
				continue
			var from = point_with_edges.point
			var to = neighbor.point

			var query_rect = Rect2(min(from.x, to.x) - ROAD_WIDTH, min(from.z, to.z) - ROAD_WIDTH, abs(from.x - to.x) + 2 * ROAD_WIDTH, abs(from.z - to.z) + 2 * ROAD_WIDTH)
			var objects: Array[Dictionary]
			qt.query(query_rect, objects)
			var num_obstacles = get_num_objects_in_edge(from, to, objects, ROAD_WIDTH)
			var distance = (from - to).length()
			var weight = num_obstacles * 10.0 + distance
			if max_weight < weight:
				max_weight = weight
			edge.weight = weight


func get_num_objects_in_edge(from: Vector3, to: Vector3, objects: Array[Dictionary], width_to_check: float) -> int:
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


# func _process(_delta):
# 	render_grid()

func render_grid():
	for grid_point in grid_point_edges:
		var point_with_edges = grid_point_edges[grid_point]
		DebugDraw3D.draw_sphere(Vector3(point_with_edges.point.x, 0.5, point_with_edges.point.z))
		for edge in point_with_edges.edges:
			var neighbor = grid_point_edges.get(edge.grid_point, null)
			if not neighbor:
				continue
			var red = edge.weight / max_weight
			var color = Color(red, 0.0, 0.0, 1.0)
			DebugDraw3D.draw_line(Vector3(point_with_edges.point.x, 0.5, point_with_edges.point.z), Vector3(neighbor.point.x, 0.5, neighbor.point.z), color)
