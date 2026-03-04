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


func _init(rect: Rect2, p_capacity: int = MAX_CAPACITY, p_depth: int = 0) -> void:
	boundary = rect
	capacity = p_capacity
	depth = p_depth


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


# Query all items whose position falls within the given Rect2.
func query(area: Rect2, result: Array = []) -> Array:
	if not boundary.intersects(area):
		return result

	for item in items:
		if area.has_point(item["position"]):
			result.append(item)

	if divided:
		northwest.query(area, result)
		northeast.query(area, result)
		southwest.query(area, result)
		southeast.query(area, result)

	return result


# Query all items within a circular area (center + radius).
func query_circle(center: Vector2, radius: float, result: Array = []) -> Array:
	# Broad-phase: skip if circle doesn't intersect this boundary at all
	var closest := Vector2(
		clamp(center.x, boundary.position.x, boundary.end.x),
		clamp(center.y, boundary.position.y, boundary.end.y)
	)
	if closest.distance_squared_to(center) > radius * radius:
		return result

	var r2 := radius * radius
	for item in items:
		if item["position"].distance_squared_to(center) <= r2:
			result.append(item)

	if divided:
		northwest.query_circle(center, radius, result)
		northeast.query_circle(center, radius, result)
		southwest.query_circle(center, radius, result)
		southeast.query_circle(center, radius, result)

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