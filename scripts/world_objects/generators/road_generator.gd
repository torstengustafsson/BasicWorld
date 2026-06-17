extends Node

class_name RoadGenerator

const NO_GRID_POINT = Vector2i(INF, INF)

class RoadEdge:
	var from: Vector3
	var to: Vector3
	func _init(_from: Vector3, _to: Vector3) -> void:
		from = _from
		to = _to

var added_boundaries: Dictionary[Rect2, bool] = {}

var world_state: WorldState
var settlement_generator: SettlementGenerator
var road_edges: Array[RoadEdge] = []
var connected_settlements: Dictionary = {}  # Tracks which settlement pairs are already connected

func _init(_world_state: WorldState, _settlement_generator: SettlementGenerator) -> void:
	world_state = _world_state
	settlement_generator = _settlement_generator

func generate_roads(boundary: Rect2) -> Array[RoadEdge]:
	if added_boundaries.has(boundary):
		return road_edges
	added_boundaries[boundary] = true

	boundary.position -= Vector2(Globals.TERRAIN_CHUNK_SIZE, Globals.TERRAIN_CHUNK_SIZE)
	boundary.size += Vector2(2 * Globals.TERRAIN_CHUNK_SIZE, 2 * Globals.TERRAIN_CHUNK_SIZE)
	var settlements = settlement_generator.settlements.query(boundary)
	var result: Array[RoadEdge] = []
	for settlement in settlements:
		var settlement_data = settlement["data"]
		var num_available_roads: int = max(1, min(min(3, settlements.size() - 1), ceil(settlement_data.num_houses / 2.0)))
		var closest_settlements = get_closest_settlements(settlement_data, boundary, num_available_roads)

		for other_settlement in closest_settlements:
			if connection_exists_between_settlements(settlement_data, other_settlement):
				continue
			var max_distance = Globals.MAX_SETTLEMENT_DISTANCE_FOR_ROAD + settlement_data.num_houses * Globals.MAX_SETTLEMENT_DISTANCE_FOR_ROAD * 0.1
			var new_roads = generate_road_segments(settlement_data.grid_position, other_settlement.grid_position, max_distance)
			if new_roads.size() > 0:
				add_connection_between_settlements(settlement_data, other_settlement)
			result.append_array(new_roads)

	road_edges.append_array(result)
	return result


func get_settlement_connection_key(pos_a: Vector2i, pos_b: Vector2i) -> String:
		# Sort positions to ensure A→B and B→A produce the same key
		if pos_a < pos_b:
			return str(pos_a) + "|" + str(pos_b)
		else:
			return str(pos_b) + "|" + str(pos_a)

func connection_exists_between_settlements(settlement: SettlementGenerator.SettlementData, other_settlement: SettlementGenerator.SettlementData) -> bool:
	var connection_key = get_settlement_connection_key(settlement.grid_position, other_settlement.grid_position)
	return connection_key in connected_settlements

func add_connection_between_settlements(settlement: SettlementGenerator.SettlementData, other_settlement: SettlementGenerator.SettlementData):
	var connection_key = get_settlement_connection_key(settlement.grid_position, other_settlement.grid_position)
	connected_settlements[connection_key] = true


# Return weighted closest settlements, where large settlements are more attrative, and are prioritized a bit further away
func get_closest_settlements(settlement: SettlementGenerator.SettlementData, boundary: Rect2, amount: int):
	var pq: PriorityQueue = PriorityQueue.new()
	for other_settlement_data in settlement_generator.settlements.query(boundary):
		var other_settlement = other_settlement_data["data"]
		if not other_settlement:
			continue
		if not boundary.has_point(Vector2(settlement.position.x, settlement.position.z)) or other_settlement == settlement:
			continue
		var a = Vector2(settlement.position.x, settlement.position.z)
		var b = Vector2(other_settlement.position.x, other_settlement.position.z)
		var distance = (a - b).length()
		var weight = distance - other_settlement.num_houses * 20.0
		pq.push(other_settlement, weight)
	var result = []
	for i in amount:
		var next = pq.pop()
		if next:
			result.append(next)
	return result


# Uses A* to find shortest weighted path to destination
func generate_road_segments(grid_from: Vector2i, grid_destination: Vector2i, max_distance: float) -> Array:
	var pq: PriorityQueue = PriorityQueue.new()
	pq.push(grid_from, 0.0)
	var came_from: Dictionary[Vector2i, Vector2i] = { grid_from: NO_GRID_POINT }
	var cost_so_far: Dictionary[Vector2i, float] = { grid_from: 0.0 }
	while not pq.is_empty():
		var current = pq.pop()
		if current == grid_destination:
			break
		var current_grid_point = world_state.world_grid.grid_point_edges.get_item(current)
		if not current_grid_point:
			continue
		for next in current_grid_point.edges:
			var new_cost = cost_so_far[current] + next.weight
			if (not cost_so_far.has(next.grid_point)) or new_cost < cost_so_far[next.grid_point]:
				cost_so_far[next.grid_point] = new_cost
				pq.push(next.grid_point, new_cost)
				came_from[next.grid_point] = current

	if not cost_so_far.has(grid_destination):
		# No path found
		return []

	if cost_so_far[grid_destination] > max_distance:
		# Shortest path is too long
		return []

	# Step backwards to find the shortest path
	var result = []
	var current_step = grid_destination
	var max_iterations = 0
	while current_step != grid_from:
		if max_iterations > 100:
			print("No road found between " + str(grid_from) + " and " + str(grid_destination))
			break
		max_iterations += 1
		var previous_step = came_from[current_step]
		var a = world_state.world_grid.grid_point_edges.get_item(previous_step)
		var b = world_state.world_grid.grid_point_edges.get_item(current_step)
		if not (a or b):
			continue
		var new_road = RoadEdge.new(a.point, b.point)
		result.append(new_road)
		current_step = previous_step

	return result

# NOTE: Does not use get_objects_in_road due to performance reasons
# (it is more efficient to loop objects first and then roads)
func remove_objects_from_roads(roads: Array[RoadEdge], remove_callback: Callable):
	for edge in roads:
		var query_rect = Rect2(
			min(edge.from.x, edge.to.x) - Globals.ROAD_WIDTH,
			min(edge.from.z, edge.to.z) - Globals.ROAD_WIDTH,
			abs(edge.from.x -edge.to.x) + 2 * Globals.ROAD_WIDTH,
			abs(edge.from.z -edge.to.z) + 2 * Globals.ROAD_WIDTH)
		var objects = world_state.static_objects_qt.query(query_rect)
		for index in objects.size():
			var object: WorldObject = objects[index]["data"]
			var object_pos = Vector2(object.instance.position.x, object.instance.position.z)
			var a = Vector2(edge.from.x, edge.from.z)
			var b = Vector2(edge.to.x, edge.to.z)
			var ab: Vector2 = b - a;
			var ap: Vector2 = object_pos - a;
			var t: float = clamp(ap.dot(ab) / ab.dot(ab), 0.0, 1.0);
			var closest: Vector2 = a + t * ab;
			var road_dist: float = (object_pos - closest).length()
			if road_dist < Globals.ROAD_WIDTH + 0.1:
				remove_callback.call(object)
