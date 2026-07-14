class_name RoadManager extends Node

const NO_GRID_POINT = Vector2i(INF, INF)

class RoadSegment:
	var from: Vector2
	var to: Vector2
	func _init(_from: Vector2, _to: Vector2) -> void:
		from = _from
		to = _to

static var mutex: Mutex = Mutex.new()
var _added_road_positions: Dictionary[Vector3, bool] = {}

var connected_settlements: Dictionary = {}  # Tracks which settlement pairs are already connected

# Contains all road segments that have will ever be generated during a playthrough.
# Will thus keep expanding forever.
var road_segments: Quadtree = Quadtree.new()

func generate_roads(boundary: Rect2) -> void:
	var neighbor_max_distance = Globals.WORLD_GRID_STEP * (Globals.SETTLEMENT_GRID_STEP + 2 * Globals.SETTLEMENT_GRID_SPREAD)
	boundary.position -= Vector2(neighbor_max_distance / 2, neighbor_max_distance/ 2)
	boundary.size += Vector2(2 * neighbor_max_distance/ 2, 2 * neighbor_max_distance/ 2)
	var settlements = WorldState.state.settlement_manager.settlements.query(boundary)
	for settlement in settlements:
		var num_available_roads: int = max(1, min(3, settlements.size() - 1, ceil(settlement.get_num_houses() / 2.0)))
		for other_settlement in get_closest_settlements(settlement, boundary, num_available_roads):
			var max_distance = Globals.MAX_SETTLEMENT_DISTANCE_FOR_ROAD + settlement.get_num_houses() * Globals.MAX_SETTLEMENT_DISTANCE_FOR_ROAD * 0.1
			if _connection_exists_between_settlements(settlement, other_settlement) or (settlement.position - other_settlement.position).length() > max_distance:
				continue
			var road_generated = try_generate_road_segments(settlement.grid_index, other_settlement.grid_index, max_distance)
			if road_generated:
				_add_connection_between_settlements(settlement, other_settlement)

# Return weighted closest settlements, where large settlements are more attrative, and are prioritized a bit further away
func get_closest_settlements(settlement: SettlementManager.SettlementData, boundary: Rect2, amount: int) -> Array[SettlementManager.SettlementData]:
	var pq: PriorityQueue = PriorityQueue.new()
	for other_settlement in WorldState.state.settlement_manager.settlements.query(boundary):
		if not other_settlement or other_settlement == settlement:
			continue
		var a = Vector2(settlement.position.x, settlement.position.z)
		var b = Vector2(other_settlement.position.x, other_settlement.position.z)
		var distance = (a - b).length()
		var weight = distance - other_settlement.get_num_houses() * 20.0
		pq.push(other_settlement, weight)
	var result: Array[SettlementManager.SettlementData] = []
	for i in amount:
		var next = pq.pop()
		if next:
			result.append(next)
	return result


# Uses A* to find shortest weighted path to destination
func try_generate_road_segments(grid_from: Vector2i, grid_destination: Vector2i, max_distance: float) -> bool:
	var points = WorldState.state.world_grid.generate_shortest_distance_between_grid_points(grid_from, grid_destination, max_distance)
	if points.size() == 0:
		return false
	for i in range(1, points.size()):
		var from = Vector2(points[i-1].x, points[i-1].z)
		var to = Vector2(points[i].x, points[i].z)
		# NOTE: Using middle point as indexer may in rare cases prohibit a road from generating, if it interects another
		# road so they would get the same middle point. Chance is still very low of that happening since we use floating point numbers.
		var middle_point = MathFunctions.get_middle_point_vec2(from, to)
		if not road_segments.get_item(middle_point):
			var new_road = RoadSegment.new(from ,to)
			mutex.lock()
			road_segments.insert({"position": middle_point, "data": new_road})
			mutex.unlock()
	return true

func is_in_road(position: Vector3) -> bool:
	mutex.lock()
	var existing_value = _added_road_positions.get(position)
	if existing_value:
		mutex.unlock()
		return existing_value
	var result = false
	for road_segment in road_segments.query_circle(Vector2(position.x, position.z), Globals.WORLD_GRID_STEP):
		result = is_in_road_segment(position, road_segment)
		if result:
			break
	_added_road_positions[position] = result
	mutex.unlock()
	return result

# Genrated by mistral (AI)
func is_in_road_segment(position: Vector3, road_segment: RoadSegment) -> bool:
	var object_pos = Vector2(position.x, position.z)
	var a = Vector2(road_segment.from.x, road_segment.from.y)
	var b = Vector2(road_segment.to.x, road_segment.to.y)
	var ab: Vector2 = b - a;
	var ap: Vector2 = object_pos - a;
	var t: float = clamp(ap.dot(ab) / ab.dot(ab), 0.0, 1.0);
	var closest: Vector2 = a + t * ab;
	var road_dist: float = (object_pos - closest).length()
	if road_dist < Globals.ROAD_WIDTH + Globals.ROAD_MARGIN:
		return true
	return false

func get_roads_in_area(area: Rect2) -> Array:
	mutex.lock()
	var result = road_segments.query(area)
	mutex.unlock()
	return result

func _get_settlement_connection_key(pos_a: Vector2i, pos_b: Vector2i) -> String:
		# Sort positions to ensure A→B and B→A produce the same key
		if pos_a < pos_b:
			return str(pos_a) + "|" + str(pos_b)
		else:
			return str(pos_b) + "|" + str(pos_a)

func _connection_exists_between_settlements(settlement: SettlementManager.SettlementData, other_settlement: SettlementManager.SettlementData) -> bool:
	var connection_key = _get_settlement_connection_key(settlement.grid_index, other_settlement.grid_index)
	return connection_key in connected_settlements

func _add_connection_between_settlements(settlement: SettlementManager.SettlementData, other_settlement: SettlementManager.SettlementData):
	var connection_key = _get_settlement_connection_key(settlement.grid_index, other_settlement.grid_index)
	connected_settlements[connection_key] = true

func destroy():
	_added_road_positions.clear()
	connected_settlements.clear()
	road_segments = Quadtree.new()

# Can be used for debugging road generation
# func _generate_road(from: Vector2i, to: Vector2i) -> void:
# 	var road_generated = try_generate_road_segments(from, to, Globals.MAX_SETTLEMENT_DISTANCE_FOR_ROAD * 2.0)
# 	if not road_generated:
# 		print("_generate_road error: No road possible")
