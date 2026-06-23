extends Node

class_name ObjectPool

const OUT_OF_SIGHT = Vector3(-1000000.0, -1000000.0, -1000000.0)

# Pool configuration
var initial_pool_size: int # Size of pool at creation. Pool may later grow beyond this, but a good initial value may save some initialization time.
var growth_threshold_percent: float # A value of 0.8 means grow when used objects are >= 80% of pool size.
var growth_threshold_value: int # Actual threshold value in number of objects required before pool growth.
var growth_factor_percent: float # A value of 0.5 means grow by 50% each time.

var unused_objects: Array[WorldObject] = [] # These are available objects to be added to the scene. Pre-added as children to scene for performance.
var used_objects: Dictionary[Vector3, WorldObject] = {} # Takes objects from unused_objects and places them on their position in the scene. Maps object position to object.
var used_objects_by_type: Dictionary[WorldObject.ObjectId, Array] = {} # Same as used_objects, but sorted by object_id

# Reference to PoolManager:s objects quadtree
var used_objects_quadtree: Quadtree

func _init(_used_objects_quadtree: Quadtree, _initial_pool_size: int = 10, _growth_threshold_percent: float = 0.8, _growth_factor_percent: float = 0.5):
	used_objects_quadtree = _used_objects_quadtree
	initial_pool_size = _initial_pool_size
	growth_threshold_percent = _growth_threshold_percent
	growth_threshold_value = floor(growth_threshold_percent * initial_pool_size)
	growth_factor_percent = _growth_factor_percent
	assert(initial_pool_size > 0)
	assert(growth_threshold_percent > 0.0 and growth_threshold_percent < 1.0)
	assert(growth_factor_percent > 0.0 and growth_factor_percent < 1.0)

func _ready() -> void:
	_initialize_pool()

func _initialize_pool() -> void:
	unused_objects.clear()
	for _i in range(initial_pool_size):
		var object: WorldObject = WorldObject.new()
		_set_object_disabled(object)
		add_child(object.collider_body)

func get_object(glb_mesh: Node3D) -> WorldObject:
	var position = glb_mesh.position
	var existing_object = used_objects.get(position)
	if existing_object:
		return existing_object
	if used_objects.size() >= growth_threshold_value:
		_grow_pool()
	var object = unused_objects.pop_back()
	if not object:
		return null
	var object_id = glb_mesh.get_meta("object_id")
	object.initialize_object(object_id, glb_mesh)
	object.collider_body.process_mode = Node.PROCESS_MODE_PAUSABLE
	used_objects[position] = object
	if not used_objects_by_type.get(object.object_id):
		used_objects_by_type[object.object_id] = []
	used_objects_by_type[object.object_id].append(object)
	used_objects_quadtree.insert({"position": Vector2(position.x, position.z), "data": object})
	return object

func _set_object_disabled(object: WorldObject) -> void:
	used_objects_quadtree.remove(object)
	used_objects.erase(object.collider_body.position)
	used_objects_by_type.get(object.object_id, []).erase(object)
	object.reset_object()
	object.collider_body.process_mode = Node.PROCESS_MODE_DISABLED
	object.collider_body.position = OUT_OF_SIGHT
	unused_objects.append(object)

func get_object_at_position(type: WorldObject.ObjectId, position: Vector3) -> WorldObject:
	var object: WorldObject = used_objects.get(position)
	if object and object.object_id == type:
		return object
	return null

func get_all_active_objects() -> Array[WorldObject]:
	return used_objects.values()

func get_active_objects_of_type(type: WorldObject.ObjectId) -> Array:
	return used_objects_by_type.get(type, [])

func remove_objects_outside_bounds(boundary: Rect2) -> void:
	for position in used_objects.keys():
		if not boundary.has_point(Vector2(position.x, position.z)):
			_set_object_disabled(used_objects[position])

func _grow_pool() -> void:
	var total_pool_objects: int = unused_objects.size() + used_objects.size()
	var new_objects: int = floor(total_pool_objects * growth_factor_percent)
	growth_threshold_value = floor((total_pool_objects + new_objects) * growth_threshold_percent)
	for _i in new_objects:
		var object: WorldObject = WorldObject.new()
		_set_object_disabled(object)
		add_child(object.collider_body)
