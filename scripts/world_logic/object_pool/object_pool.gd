extends Node

class_name ObjectPool

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
		set_object_disabled(object)
		call_deferred("add_child", object.collider_body)

func get_object(mesh_object: MeshObject) -> WorldObject:
	var existing_object = used_objects.get(mesh_object.position)
	if existing_object:
		existing_object.initialize_object(mesh_object)
		return existing_object
	if used_objects.size() >= growth_threshold_value:
		_grow_pool()
	var object = unused_objects.pop_back()
	if not object:
		return null
	object.initialize_object(mesh_object)
	object.collider_body.call_deferred("set_process_mode", Node.PROCESS_MODE_PAUSABLE)
	used_objects[mesh_object.position] = object
	if not used_objects_by_type.get(mesh_object.object_id):
		used_objects_by_type[mesh_object.object_id] = []
	used_objects_by_type[mesh_object.object_id].append(object)
	used_objects_quadtree.insert({"position": Vector2(mesh_object.position.x, mesh_object.position.z), "data": object})
	return object

func set_object_disabled(object: WorldObject) -> void:
	used_objects_quadtree.remove(object)
	used_objects.erase(object.mesh_object.position)
	used_objects_by_type.get(object.mesh_object.object_id, []).erase(object)
	object.reset_object()
	object.collider_body.call_deferred("set_process_mode", Node.PROCESS_MODE_DISABLED)
	object.collider_body.call_deferred("set_position", Globals.OUT_OF_SIGHT)
	unused_objects.append(object)

func get_object_at_position(object_id: WorldObject.ObjectId, position: Vector3) -> WorldObject:
	var object: WorldObject = used_objects.get(position)
	if object and object.mesh_object.object_id == object_id:
		return object
	return null

func get_all_active_objects() -> Array[WorldObject]:
	return used_objects.values()

func get_active_objects_of_type(type: WorldObject.ObjectId) -> Array:
	return used_objects_by_type.get(type, [])

func remove_objects_outside_bounds(boundary: Rect2) -> void:
	var to_be_removed: Array[WorldObject]
	for position in used_objects.keys():
		if not boundary.has_point(Vector2(position.x, position.z)):
			if not used_objects.get(position):
				print("Error: Tried to remove ", position, " but was no longer in the scene. This should not happen.")
				continue
			to_be_removed.append(used_objects[position])
	for object in to_be_removed:
		set_object_disabled(object)

func _grow_pool() -> void:
	var total_pool_objects: int = unused_objects.size() + used_objects.size()
	var new_objects: int = min(floor(total_pool_objects * growth_factor_percent), 1000)
	growth_threshold_value = floor((total_pool_objects + new_objects) * growth_threshold_percent)
	for _i in new_objects:
		var object: WorldObject = WorldObject.new()
		set_object_disabled(object)
		call_deferred("add_child", object.collider_body)
