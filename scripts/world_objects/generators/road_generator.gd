extends Node

class_name RoadGenerator

class RoadEdge:
	var from: Vector3
	var to: Vector3
	var weight: float
	func _init(_from: Vector3, _to: Vector3, _weight: float = 0.0) -> void:
		from = _from
		to = _to
		weight = _weight

# Treated as constants. Are vars due to gdscript.
var ROAD_WIDTH: float
var world_grid: WorldGrid

var road_edges: Array[RoadEdge] = []

func _init(_world_grid: WorldGrid, _road_width: float) -> void:
	ROAD_WIDTH = _road_width
	world_grid = _world_grid

func generate_roads(settlement_data: Array[SettlementGenerator.SettlementData], objects: Array[WorldObject]) -> Array[RoadEdge]:
	if settlement_data.size() <= 1:
		return []
	var result: Array[RoadEdge] = []
	for settlement in settlement_data:
		var num_available_roads: int = max(1, min(min(3, settlement_data.size() - 1), ceil(settlement.num_houses / 2.0)))
		var roads: Array[RoadEdge] = []
		for other_index in settlement_data.size():
			var other_settlement = settlement_data[other_index]
			if other_settlement == settlement:
				continue
			var a = Vector2(settlement.position.x, settlement.position.z)
			var b = Vector2(other_settlement.position.x, other_settlement.position.z)
			var distance = (a - b).length()
			var weight = distance - other_settlement.num_houses * 20.0
			var new_road = RoadEdge.new(Vector3(a.x, 0.0, a.y), Vector3(b.x, 0.0, b.y), weight)
			roads.append(new_road)
		roads.sort_custom(func(a, b): return a.weight < b.weight)
		for i in num_available_roads:
			# TODO: Check if there is already a good road that can be used.
			# If there is, skip new one. Requires world grid graph.
			result.append_array(generate_road(roads[i].from, roads[i].to, objects))

	road_edges.append_array(result)
	return result

func generate_road(from: Vector3, to: Vector3, objects: Array[WorldObject]) -> Array[RoadEdge]:
	var num_obstacles: float = world_grid.get_num_objects_in_edge(from, to, objects, ROAD_WIDTH)
	var distance = (from - to).length()
	var weight = num_obstacles * 10.0 + distance
	return [RoadEdge.new(from, to, weight)]

# NOTE: Does not use get_objects_in_road due to performance reasons
# (it is more efficient to loop objects first and then roads)
func remove_objects_from_roads(objects: Array[WorldObject], callback: Callable):
	var to_be_removed: Array[int] = []
	for index in objects.size():
		var object: Node3D = objects[index].instance
		var object_pos = Vector2(object.position.x, object.position.z)
		for edge in road_edges:
			var a = Vector2(edge.from.x, edge.from.z)
			var b = Vector2(edge.to.x, edge.to.z)
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
