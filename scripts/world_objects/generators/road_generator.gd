extends Node

class_name RoadGenerator

class Edge:
	var from: Vector2
	var to: Vector2
	var weight: float

	func _init(_from: Vector2, _to: Vector2, _weight: float = 0.0) -> void:
		from = _from
		to = _to
		weight = _weight

# Treated as constants. Are vars due to gdscript.
var ROAD_WIDTH: float
var WORLD_GRID: Array[Vector2]

var road_edges: Array[Edge] = []

func _init(world_grid: Array[Vector2], road_width: float, _mat: ShaderMaterial) -> void:
	ROAD_WIDTH = road_width
	WORLD_GRID = world_grid

func generate_roads(settlement_data: Array[SettlementGenerator.SettlementData]) -> Array[Edge]:
	if settlement_data.size() <= 1:
		return []

	var result: Array[Edge] = []

	for settlement_index in settlement_data.size() - 1:
		var from = settlement_data[settlement_index].position
		var to = settlement_data[settlement_index + 1].position
		result.append_array(generate_road(from, to))

	road_edges.append_array(result)
	return result

func generate_road(from: Vector3, to: Vector3) -> Array[Edge]:
	var weight: float = 0.0
	return [Edge.new(Vector2(from.x, from.z), Vector2(to.x, to.z), weight)]

func remove_objects_from_roads(objects, callback: Callable):
	var to_be_removed: Array[int] = []
	for index in objects.size():
		var object: Node3D = objects[index].instance
		var object_pos = Vector2(object.position.x, object.position.z)
		for edge in road_edges:
			var a = edge.from
			var b = edge.to
			var ab: Vector2 = b - a;
			var ap: Vector2 = object_pos - a;
			var t: float = clamp(ap.dot(ab) / ab.dot(ab), 0.0, 1.0);
			var closest: Vector2 = a + t * ab;
			var road_dist: float = (object_pos - closest).length()
			if road_dist < ROAD_WIDTH:
				to_be_removed.append(index)
	to_be_removed.sort()
	to_be_removed.reverse()
	for index in to_be_removed:
		callback.call(index)
