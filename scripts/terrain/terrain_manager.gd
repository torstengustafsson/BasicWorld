extends Node

class_name TerrainManager

# Terrain angles are pre-calculated and stored at all relevant positions
# When the angle for a new position is requested for the first time, it will be queued and later (next frame) actually added.
# So the requester will need to make its request again until it gets a value.
# _angle_positions_to_be_added functions like a queue, that will be added to on new requests, and removed from on actual update.
static var mutex: Mutex = Mutex.new()
static var _added_angle_positions: Dictionary[Vector2, float] = {}
static var _angle_positions_to_be_added: Array[Vector2] = []

# This function is safe to call from a thread
static func get_terrain_angle_at_position(position: Vector3) -> float:
	var position_xz = Vector2(position.x, position.z)
	mutex.lock()
	var existing_value = _added_angle_positions.get(position_xz)
	if existing_value:
		mutex.unlock()
		return existing_value
	_angle_positions_to_be_added.append(position_xz)
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		# Special case, main thread get to update and access it directly
		update_angle_positions()
		existing_value = _added_angle_positions.get(position_xz)
		mutex.unlock()
		if existing_value:
			return existing_value
	mutex.unlock()
	return Globals.NOT_A_NUMBER

# This must be called from the main thread
static func update_angle_positions() -> void:
	mutex.lock()
	var positions_to_be_added = _angle_positions_to_be_added.duplicate()
	_angle_positions_to_be_added.clear()
	mutex.unlock()

	while positions_to_be_added.size() > 0:
		var position_xz = positions_to_be_added.pop_back()
		var origin = Vector3(position_xz.x, 10000.0, position_xz.y)
		var end = Vector3(position_xz.x, -10000.0, position_xz.y)

		var query = PhysicsRayQueryParameters3D.create(origin, end)
		query.collide_with_areas = true
		var result = WorldState.state.space_state.intersect_ray(query)

		# Check if the ray hit the terrain
		if not result or result["collider"].get_parent() is not TerrainChunk:
			continue

		var calculate_slope_angle = func(_normal: Vector3) -> float:
			var dot_product: float = _normal.dot(Vector3.UP)
			dot_product = clamp(dot_product, -1.0, 1.0)  # Avoid floating-point errors
			var angle_rad: float = acos(dot_product)
			var angle_deg: float = rad_to_deg(angle_rad)
			return angle_deg

		var normal: Vector3 = result["normal"]
		var angle: float = calculate_slope_angle.call(normal)
		mutex.lock()
		_added_angle_positions[position_xz] = angle
		mutex.unlock()
