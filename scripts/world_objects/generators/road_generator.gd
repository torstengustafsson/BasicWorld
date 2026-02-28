extends Node

class_name RoadGenerator

const NO_GRID_POINT = Vector2i(INF, INF)

class RoadEdge:
	var from: Vector3
	var to: Vector3
	func _init(_from: Vector3, _to: Vector3) -> void:
		from = _from
		to = _to

# Treated as constants. Are vars due to gdscript.
var ROAD_WIDTH: float
var world_grid: WorldGrid

var road_edges: Array[RoadEdge] = []

func _init(_world_grid: WorldGrid, _road_width: float) -> void:
	ROAD_WIDTH = _road_width
	world_grid = _world_grid

func generate_roads(settlement_data: Array[SettlementGenerator.SettlementData]) -> Array:
	if settlement_data.size() <= 1:
		return []
	var result: Array = []
	for settlement in settlement_data:
		var num_available_roads: int = max(1, min(min(3, settlement_data.size() - 1), ceil(settlement.num_houses / 2.0)))
		var closest_settlements = get_closest_settlements(settlement, settlement_data, num_available_roads)

		for other_index in closest_settlements.size():
			var other_settlement = closest_settlements[other_index]
			var new_roads = generate_road_segments(settlement.grid_position, other_settlement.grid_position)
			result.append_array(new_roads)

	road_edges.append_array(result)
	return result

# Return weighted closest settlements, where large settlements are more attrative, and are prioritized a bit further away
func get_closest_settlements(settlement: SettlementGenerator.SettlementData, settlements: Array[SettlementGenerator.SettlementData], amount: int):
	var pq: PriorityQueue = PriorityQueue.new()
	for other_index in settlements.size():
		var other_settlement = settlements[other_index]
		if other_settlement == settlement:
			continue
		var a = Vector2(settlement.position.x, settlement.position.z)
		var b = Vector2(other_settlement.position.x, other_settlement.position.z)
		var distance = (a - b).length()
		var weight = distance - other_settlement.num_houses * 20.0
		pq.push(other_settlement, weight)
	var result = []
	for i in amount:
		result.append(pq.pop())
	return result


func heuristic(a: Vector2i, b: Vector2i):
	return (a - b).length()

# Uses A* to find shortest weighted path to destination
func generate_road_segments(grid_from: Vector2i, grid_destination: Vector2i) -> Array:
	var result = []
	var pq: PriorityQueue = PriorityQueue.new()
	pq.push(grid_from, 0.0)
	var came_from: Dictionary[Vector2i, Vector2i] = { grid_from: NO_GRID_POINT }
	var cost_so_far: Dictionary[Vector2i, float] = { grid_from: 0.0 }
	while not pq.is_empty():
		var current = pq.pop()
		if current == grid_destination:
			break
		for next in world_grid.grid_point_edges[current].edges:
			var new_cost = cost_so_far[current] + next.weight
			if (not cost_so_far.has(next.grid_point)) or new_cost < cost_so_far[next.grid_point]:
				cost_so_far[next.grid_point] = new_cost
				#var priority = heuristic(next.grid_point, grid_destination)
				pq.push(next.grid_point, new_cost)
				came_from[next.grid_point] = current

	var current = grid_destination
	var i = 0
	while current != grid_from:
		if i > 100:
			print("No road found between " + str(grid_from) + " and " + str(grid_destination))
			break
		i += 1
		var previous = came_from[current]
		var a = world_grid.grid_point_edges[previous].point
		var b = world_grid.grid_point_edges[current].point
		var new_road = RoadEdge.new(a, b)
		result.append(new_road)
		current = previous

	return result

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
