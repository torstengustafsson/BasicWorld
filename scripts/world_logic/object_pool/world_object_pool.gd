class_name WorldObjectPool extends ObjectPool

class PendingObject:
	var object: WorldObject
	var mesh_object: MeshObject
	var add_new: bool
	func _init(_object, _mesh_object, _add_new = true) -> void:
		object = _object
		mesh_object = _mesh_object
		add_new = _add_new
var pending_object_updates: Array[PendingObject] = [] # Queues node updates, to avoid calling call_deferred too much
var pending_updates_mutex: Mutex = Mutex.new()

var unused_objects: Array[WorldObject] = []
var unused_objects_mutex: Mutex = Mutex.new()

func _init(_initial_pool_size: int = 10):
	for _i in _initial_pool_size:
		_create_new_object()

func _create_new_object() -> void:
	var object: WorldObject = WorldObject.new()
	unused_objects_mutex.lock()
	unused_objects.append(object)
	unused_objects_mutex.unlock()
	total_objects += 1

func add_object(mesh_object: MeshObject) -> WorldObject:
	if unused_objects.is_empty():
		_grow_pool()
	if not mesh_object:
		print("Error: Mesh object is null")
	unused_objects_mutex.lock()
	var object = unused_objects.pop_back()
	unused_objects_mutex.unlock()
	object.mesh_object = mesh_object
	pending_updates_mutex.lock()
	pending_object_updates.append(PendingObject.new(object, mesh_object))
	pending_updates_mutex.unlock()
	return object

func remove_object(object: WorldObject) -> void:
	unused_objects_mutex.lock()
	unused_objects.append(object)
	unused_objects_mutex.unlock()
	pending_updates_mutex.lock()
	pending_object_updates.append(PendingObject.new(object, null, false))
	pending_updates_mutex.unlock()

# Must be called from the main thread
func apply_updates():
	pending_updates_mutex.lock()
	var updates: Array[PendingObject] = pending_object_updates.duplicate()
	pending_object_updates.clear()
	pending_updates_mutex.unlock()
	for update in updates:
		if update.add_new:
			update.object.initialize_object(update.mesh_object)
			add_child(update.object.collider_body)
		else:
			update.object.reset_object()
			remove_child(update.object.collider_body)
