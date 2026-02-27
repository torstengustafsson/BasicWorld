class_name  WorldGrid extends Node3D

class GridPointEdge:
	var grid_point: Vector2i
	var weight: float

	func _init(_grid_point: Vector2i, _weight: float = 0.0) -> void:
		grid_point = _grid_point
		weight = _weight

class PointWithEdges:
	var point: Vector2
	var edges: Array[GridPointEdge] = []
	func _init(_point: Vector2):
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

var WORLD_SIZE: float
const WORLD_GRID_STEP: int = 10
var ROAD_WIDTH: float
var points: Array[Vector2]
var edges: Dictionary[Vector2i, PointWithEdges] = {}

var world_start_pos: Vector2
var world_end_pos: Vector2

func _init(_world_start_pos: Vector2, _world_end_pos: Vector2, road_width: float) -> void:
	world_start_pos = _world_start_pos
	world_end_pos = _world_end_pos
	WORLD_SIZE = abs(world_start_pos.x - world_end_pos.x)
	if WORLD_SIZE != abs(world_start_pos.y - world_end_pos.y):
		print("Not Square world! Exiting.")
		get_tree().quit()
	ROAD_WIDTH = road_width
	create_points_and_edges()

func create_points_and_edges() -> Dictionary[Vector2i, PointWithEdges]:
	edges.clear()
	for x: int in WORLD_SIZE / WORLD_GRID_STEP:
		for z: int in WORLD_SIZE / WORLD_GRID_STEP:
			var pos_x = world_start_pos.x + x * WORLD_GRID_STEP
			var pos_z = world_start_pos.y + z * WORLD_GRID_STEP
			var rand_value_x = (-WORLD_GRID_STEP / 4.0 + randf_range(0.0, WORLD_GRID_STEP / 2.0))
			var rand_value_z = (-WORLD_GRID_STEP / 4.0 + randf_range(0.0, WORLD_GRID_STEP / 2.0))
			var point = Vector2(pos_x + rand_value_x, pos_z + rand_value_z)
			var current_point = PointWithEdges.new(point)
			for point_around: Vector2i in POINTS_AROUND:
				var neighbor: Vector2i = Vector2i(x + point_around.x, z + point_around.y)
				var weight = 0.0
				if neighbor.x < world_start_pos.x or neighbor.x > world_end_pos.x or neighbor.y < world_start_pos.y or neighbor.y > world_end_pos.y:
					continue
				current_point.edges.append(GridPointEdge.new(neighbor, weight))
			edges[Vector2i(x, z)] = current_point
	return edges

func calculate_weights(objects: Array[WorldObject]):
	for grid_point in edges:
		var point_with_edges = edges[grid_point]
		for edge in point_with_edges.edges:
			var neighbor = edges.get(edge.grid_point, null)
			if not neighbor:
				continue
			var from = point_with_edges.point
			var to = neighbor.point
			var num_obstacles = get_num_objects_in_edge(from, to, objects, ROAD_WIDTH)
			var distance = (from - to).length()
			var weight = num_obstacles * 10.0 + distance
			edge.weight = weight


func get_num_objects_in_edge(from: Vector2, to: Vector2, objects: Array[WorldObject], width_to_check: float) -> int:
	var result: int = 0
	var a = from
	var b = to
	var ab: Vector2 = b - a;
	for index in objects.size():
		var object: Node3D = objects[index].instance
		var object_pos = Vector2(object.position.x, object.position.z)
		var ap: Vector2 = object_pos - a;
		var t: float = clamp(ap.dot(ab) / ab.dot(ab), 0.0, 1.0);
		var closest: Vector2 = a + t * ab;
		var road_dist: float = (object_pos - closest).length()
		if road_dist < width_to_check:
			result += 1
	return result


# func _process(_delta):
# 	render_grid()

func render_grid():
	for grid_point in edges:
		var point_with_edges = edges[grid_point]
		DebugDraw3D.draw_sphere(Vector3(point_with_edges.point.x, 0.5, point_with_edges.point.y))
		for edge in point_with_edges.edges:
			var neighbor = edges.get(edge.grid_point, null)
			if not neighbor:
				continue
			var red = edge.weight / 500.0
			var color = Color(red, 0.0, 0.0, 1.0)
			DebugDraw3D.draw_line(Vector3(point_with_edges.point.x, 0.5, point_with_edges.point.y), Vector3(neighbor.point.x, 0.5, neighbor.point.y), color)
