## Quadtree - Spatial partitioning data structure for GDScript
## Usage: var qt = Quadtree.new(Rect2(0, 0, 1024, 1024))
##        qt.insert({"position": Vector2(100, 200), "data": my_node})
##        var found = qt.query(Rect2(50, 150, 200, 200))

class_name Quadtree

const MAX_CAPACITY := 4   # Max items per node before subdividing
const MAX_DEPTH    := 8   # Max recursion depth

var boundary: Rect2
var capacity: int
var depth: int

var items: Array = []       # Array of {position: Vector2, data: Variant}
var divided: bool = false

var northwest: Quadtree
var northeast: Quadtree
var southwest: Quadtree
var southeast: Quadtree


func _init(rect: Rect2 = Rect2(0.0, 0.0, 0.0, 0.0), p_capacity: int = MAX_CAPACITY, p_depth: int = 0) -> void:
	boundary = rect
	capacity = p_capacity
	depth = p_depth

# TODO: It would be good to be able to dynamically update the boundary, but it would require updating all the items
# in the subdivisions as well. For now, there is no solution for that, so we are limited to a set boundary at start.
# Below is an attempt to add dynamic boundary, but since it does not handle updating the items in the subdivisions,
# it will break the whole tree.
# func add_to_boundary(new_boundary: Rect2) -> void:
# 	if boundary.encloses(new_boundary):
# 		return

# 	var x_min = min(boundary.position.x, new_boundary.position.x)
# 	var y_min = min(boundary.position.y, new_boundary.position.y)
# 	var x_max = max(boundary.end.x, new_boundary.end.x)
# 	var y_max = max(boundary.end.y, new_boundary.end.y)
# 	boundary = Rect2(Vector2(x_min, y_min), Vector2(x_max - x_min, y_max - y_min))

# 	if divided:
# 		var x  := boundary.position.x
# 		var y  := boundary.position.y
# 		var hw := boundary.size.x * 0.5
# 		var hh := boundary.size.y * 0.5

# 		northwest._update_boundary(Rect2(x,      y,      hw, hh))
# 		northeast._update_boundary(Rect2(x + hw, y,      hw, hh))
# 		southwest._update_boundary(Rect2(x,      y + hh, hw, hh))
# 		southeast._update_boundary(Rect2(x + hw, y + hh, hw, hh))

# func _update_boundary(new_boundary: Rect2) -> void:
# 	boundary = new_boundary
# 	if divided:
# 		var x  := boundary.position.x
# 		var y  := boundary.position.y
# 		var hw := boundary.size.x * 0.5
# 		var hh := boundary.size.y * 0.5

# 		northwest._update_boundary(Rect2(x,      y,      hw, hh))
# 		northeast._update_boundary(Rect2(x + hw, y,      hw, hh))
# 		southwest._update_boundary(Rect2(x,      y + hh, hw, hh))
# 		southeast._update_boundary(Rect2(x + hw, y + hh, hw, hh))

# Insert an item dict with at least a "position" key (Vector2).
# Returns true if inserted successfully.
func insert(item: Dictionary) -> bool:
	assert("position" in item, "Item must have a 'position' key (Vector2).")

	if not boundary.has_point(item["position"]):
		return false

	if items.size() < capacity or depth >= MAX_DEPTH:
		items.append(item)
		return true

	if not divided:
		_subdivide()

	return (northwest.insert(item)
		or northeast.insert(item)
		or southwest.insert(item)
		or southeast.insert(item))


# Query all items
func query_all(result: Array = []) -> Array:
	for item in items:
		result.append(item)

	if divided:
		northwest.query_all(result)
		northeast.query_all(result)
		southwest.query_all(result)
		southeast.query_all(result)

	return result


func query(area: Rect2) -> Array:
	var result: Array = []
	return _query(area, result)

# Query all items whose position falls within the given Rect2.
func _query(area: Rect2, result: Array = []) -> Array:
	if not boundary.intersects(area):
		return result

	for item in items:
		if area.has_point(item["position"]):
			result.append(item)

	if divided:
		northwest._query(area, result)
		northeast._query(area, result)
		southwest._query(area, result)
		southeast._query(area, result)

	return result

func query_circle(center: Vector2, radius: float) -> Array:
	var result: Array = []
	return _query_circle(center, radius, result)

# Query all items within a circular area (center + radius).
func _query_circle(center: Vector2, radius: float, result: Array = []) -> Array:
	# Broad-phase: skip if circle doesn't intersect this boundary at all
	var closest := Vector2(
		clamp(center.x, boundary.position.x, boundary.end.x),
		clamp(center.y, boundary.position.y, boundary.end.y)
	)

	var r2 := radius * radius

	if closest.distance_squared_to(center) > r2:
		return result

	for item in items:
		if item["position"].distance_squared_to(center) <= r2:
			result.append(item)

	if divided:
		northwest._query_circle(center, radius, result)
		northeast._query_circle(center, radius, result)
		southwest._query_circle(center, radius, result)
		southeast._query_circle(center, radius, result)

	return result

func query_circle_holed(center: Vector2, inner_radius, outer_radius: float) -> Array:
	var result: Array = []
	return _query_circle_holed(center, inner_radius, outer_radius, result)

# Query all items within a circular area (center + radius), ignoring an inner circular area (center + inner_radius).
func _query_circle_holed(center: Vector2, inner_radius: float, outer_radius: float, result: Array = []) -> Array:
	# Broad-phase: skip if circle doesn't intersect this boundary at all
	var closest := Vector2(
		clamp(center.x, boundary.position.x, boundary.end.x),
		clamp(center.y, boundary.position.y, boundary.end.y)
	)

	var outer_r2 := outer_radius * outer_radius
	var inner_r2 := inner_radius * inner_radius

	if closest.distance_squared_to(center) > outer_r2:
		return result

	for item in items:
		var dist = item["position"].distance_squared_to(center)
		if dist <= outer_r2 and dist > inner_r2:
			result.append(item)

	if divided:
		northwest._query_circle_holed(center, inner_radius, outer_radius, result)
		northeast._query_circle_holed(center, inner_radius, outer_radius, result)
		southwest._query_circle_holed(center, inner_radius, outer_radius, result)
		southeast._query_circle_holed(center, inner_radius, outer_radius, result)

	return result


# Remove a specific item by reference equality of its "data" field.
# Returns true if the item was found and removed.
func remove(item: Dictionary) -> bool:
	if not boundary.has_point(item["position"]):
		return false

	for i in items.size():
		if items[i] == item:
			items.remove_at(i)
			return true

	if divided:
		return (northwest.remove(item)
			or northeast.remove(item)
			or southwest.remove(item)
			or southeast.remove(item))

	return false


# Clear all items and collapse subdivisions.
func clear() -> void:
	items.clear()
	divided = false
	northwest = null
	northeast = null
	southwest = null
	southeast = null


# Returns total item count across the whole tree.
func count() -> int:
	var total := items.size()
	if divided:
		total += northwest.count()
		total += northeast.count()
		total += southwest.count()
		total += southeast.count()
	return total


# Draw the quadtree grid using a CanvasItem node (pass your Node2D/Control).
# Call this inside a _draw() override.
func debug_draw(canvas: CanvasItem, color: Color = Color.GREEN, width: float = 1.0) -> void:
	canvas.draw_rect(boundary, color, false, width)
	if divided:
		northwest.debug_draw(canvas, color, width)
		northeast.debug_draw(canvas, color, width)
		southwest.debug_draw(canvas, color, width)
		southeast.debug_draw(canvas, color, width)


# ── Private ──────────────────────────────────────────────────────────────────

func _subdivide() -> void:
	var x  := boundary.position.x
	var y  := boundary.position.y
	var hw := boundary.size.x * 0.5
	var hh := boundary.size.y * 0.5

	var next_depth := depth + 1
	northwest = Quadtree.new(Rect2(x,      y,      hw, hh), capacity, next_depth)
	northeast = Quadtree.new(Rect2(x + hw, y,      hw, hh), capacity, next_depth)
	southwest = Quadtree.new(Rect2(x,      y + hh, hw, hh), capacity, next_depth)
	southeast = Quadtree.new(Rect2(x + hw, y + hh, hw, hh), capacity, next_depth)
	divided = true

	# Re-distribute existing items into children
	var old_items := items.duplicate()
	items.clear()
	for item in old_items:
		if not (northwest.insert(item)
			or northeast.insert(item)
			or southwest.insert(item)
			or southeast.insert(item)):
			# Shouldn't happen, but keep at this level as fallback
			items.append(item)
