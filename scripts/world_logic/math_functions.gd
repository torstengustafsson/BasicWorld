class_name MathFunctions

# This game uses strings as the seed, since it is easier to memorize specific values
static func generate_random_seed() -> String:
	var length = 20
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	var result = ""
	for i in range(length):
		var random_index = randi() % chars.length()
		result += chars[random_index]
	return result


# Expects x to be between 0.0 and 1.0. Returns value between 0.0 and 1.0.
# Return 1.0 when x is 0.0, and tapers down to 0.0, with threshold being the falloff point (x=threshold return 0.5).
# Sharpness of 10 and threshold of 0.5 means x=1.0 return ~0.0. Lower sharpness means hight value at 1.0, and
# higher sharpness means 0.0 falloff is earlier.
static func taper(x, threshold, sharpness = 10):
	return 1 / (1 + exp(sharpness * (x - threshold)))

# Expects x to be between 0.0 and 1.0. Returns value between 0.0 and 1.0.
# Returns high values when x is close to center. Tapers of to 0.0 at the edges. Taper down strength is determined ny width.
static func hill(x, center, width):
	return exp(-pow(x - center, 2) / (2 * width * width))

# Return the angle in degrees between two points.
# Angle is the steepness as in the steepness of a hill from the bottom to the top.
static func calculate_angle_between_points(point_a: Vector3, point_b: Vector3) -> float:
	var direction: Vector3 = point_b - point_a
	direction = direction.normalized()
	var dot_product: float = direction.dot(Vector3.UP)
	dot_product = clamp(dot_product, -1.0, 1.0)
	var angle_rad: float = acos(dot_product)
	var angle_deg: float = rad_to_deg(angle_rad)
	# Angle between flat ground and the UP vector is 90 degrees, so subtract
	# that amount to get 0 for flat ground.
	return angle_deg - 90.0

static func get_terrain_angle_at_position(position: Vector3, space_state: PhysicsDirectSpaceState3D) -> float:
	var origin = position + Vector3(0.0, 10000.0, 0.0)
	var end = position - Vector3(0.0, 10000.0, 0.0)

	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true

	var result = space_state.intersect_ray(query)

	# Check if the ray hit the terrain
	if not result or result["collider"].get_parent() is not TerrainChunk:
		return INF

	var calculate_slope_angle = func(_normal: Vector3) -> float:
		var dot_product: float = _normal.dot(Vector3.UP)
		dot_product = clamp(dot_product, -1.0, 1.0)  # Avoid floating-point errors
		var angle_rad: float = acos(dot_product)
		var angle_deg: float = rad_to_deg(angle_rad)
		return angle_deg

	var normal: Vector3 = result["normal"]
	var angle: float = calculate_slope_angle.call(normal)
	return angle
