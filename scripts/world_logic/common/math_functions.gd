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

# Godots built-in modulus function does not work as expected for negative values
static func mod(n: int, m: int) -> int:
	return ((n % m) + m) % m;

static func resize_rect(rect: Rect2, scale: float) -> Rect2:
	var center = rect.get_center()
	var new_size = rect.size * scale
	return Rect2(
		center.x - new_size.x / 2,
		center.y - new_size.y / 2,
		new_size.x,
		new_size.y
	)

static func get_holed_rect(outer: Rect2, hole: Rect2) -> Array[Rect2]:
	var top := Rect2(
		outer.position.x,
		outer.position.y,
		outer.size.x,
		hole.position.y - outer.position.y
	)
	var bottom := Rect2(
		outer.position.x,
		hole.end.y,
		outer.size.x,
		outer.end.y - hole.end.y
	)
	var left := Rect2(
		outer.position.x,
		hole.position.y,
		hole.position.x - outer.position.x,
		hole.size.y
	)
	var right := Rect2(
		hole.end.x,
		hole.position.y,
		outer.end.x - hole.end.x,
		hole.size.y
	)
	return [top, bottom, left, right]

static func get_middle_point_vec2(a: Vector2, b: Vector2):
	return (a + b) * 0.5

static func get_middle_point_vec3(a: Vector3, b: Vector3):
	return (a + b) * 0.5

static func transform_to_array(t: Transform3D) -> Array:
	return [
		t.basis.x.x, t.basis.x.y, t.basis.x.z,
		t.basis.y.x, t.basis.y.y, t.basis.y.z,
		t.basis.z.x, t.basis.z.y, t.basis.z.z,
		t.origin.x, t.origin.y, t.origin.z
	]

static func array_to_transform(arr: Array) -> Transform3D:
	var basis := Basis(
		Vector3(arr[0], arr[1], arr[2]),
		Vector3(arr[3], arr[4], arr[5]),
		Vector3(arr[6], arr[7], arr[8])
	)
	var origin := Vector3(arr[9], arr[10], arr[11])
	return Transform3D(basis, origin)