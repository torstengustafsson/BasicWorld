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
var WORLD_GRID: WorldGrid

var road_edges: Array[Edge] = []

func _init(world_grid: WorldGrid, road_width: float, _mat: ShaderMaterial) -> void:
	ROAD_WIDTH = road_width
	WORLD_GRID = world_grid

func generate_roads(settlement_data: Array[SettlementGenerator.SettlementData], objects: Array[WorldObject]) -> Array[Edge]:
	if settlement_data.size() <= 1:
		return []

	var result: Array[Edge] = []

	for settlement in settlement_data:
		var num_available_roads: int = max(1, min(min(3, settlement_data.size() - 1), ceil(settlement.num_houses / 2.0)))
		var roads: Array[Edge] = []
		for other_index in settlement_data.size():
			var other_settlement = settlement_data[other_index]
			if other_settlement == settlement:
				continue
			var a = Vector2(settlement.position.x, settlement.position.z)
			var b = Vector2(other_settlement.position.x, other_settlement.position.z)
			var distance = (a - b).length()
			var weight = distance - other_settlement.num_houses * 20.0
			var new_road = Edge.new(a, b, weight)
			roads.append(new_road)
		roads.sort_custom(func(a, b):
			return a.weight < b.weight
		)
		for i in num_available_roads:
			# TODO: Check if there is already a good road that can be used.
			# If there is, skip new one. Requires world grid graph.
			result.append_array(generate_road(roads[i].from, roads[i].to, objects))

	road_edges.append_array(result)
	return result

func generate_road(from: Vector2, to: Vector2, objects: Array[WorldObject]) -> Array[Edge]:
	var num_obstacles: float = WORLD_GRID.get_num_objects_in_edge(from, to, objects, ROAD_WIDTH)
	var distance = (from - to).length()
	var weight = num_obstacles * 10.0 + distance
	return [Edge.new(from, to, weight)]

# NOTE: Does not use get_objects_in_road due to performance reasons
# (it is more efficient to loop objects first and then roads)
func remove_objects_from_roads(objects: Array[WorldObject], callback: Callable):
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
			if road_dist < ROAD_WIDTH + 0.1:
				to_be_removed.append(index)
	to_be_removed.sort()
	to_be_removed.reverse()
	for index in to_be_removed:
		callback.call(index)
