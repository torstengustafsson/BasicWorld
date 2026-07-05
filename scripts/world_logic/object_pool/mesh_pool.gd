class_name MeshPool
extends ObjectPool

class PendingObject:
	var mesh_object: MeshObject
	var add_new: bool
	func _init(_mesh_object, _add_new = true) -> void:
		mesh_object = _mesh_object
		add_new = _add_new
var pending_updates: Array[PendingObject] = [] # Queues node updates, to avoid calling call_deferred too much
var pending_updates_mutex: Mutex = Mutex.new()

# Each mesh pool manages a single mesh with its corresponding object_id
var mesh_scene: PackedScene
var object_id: WorldObject.ObjectId

var unused_meshes: Array[MeshObject] = []
var unused_meshes_mutex: Mutex = Mutex.new()

func _init(_mesh_scene, _object_id, _initial_pool_size := 10):
	mesh_scene = _mesh_scene
	object_id = _object_id
	for _i in _initial_pool_size:
		_create_new_object()

func _create_new_object() -> void:
	var mesh_object = MeshObject.new(
		_allocate_id(),
		mesh_scene.instantiate(),
		object_id,
		Node.PROCESS_MODE_DISABLED
	)
	unused_meshes_mutex.lock()
	unused_meshes.append(mesh_object)
	unused_meshes_mutex.unlock()
	total_objects += 1

func add_mesh(position: Vector3, scale: Vector3, rotation: Vector3) -> MeshObject:
	if unused_meshes.is_empty():
		_grow_pool()
	unused_meshes_mutex.lock()
	var mesh_object = unused_meshes.pop_back()
	mesh_object.process_mode = Node.PROCESS_MODE_PAUSABLE
	mesh_object.position = position
	mesh_object.scale = scale
	mesh_object.rotation = rotation
	unused_meshes_mutex.unlock()
	pending_updates_mutex.lock()
	pending_updates.append(PendingObject.new(mesh_object))
	pending_updates_mutex.unlock()
	return mesh_object

func remove_mesh(mesh_object: MeshObject) -> void:
	mesh_object.reset()
	pending_updates_mutex.lock()
	pending_updates.append(PendingObject.new(mesh_object, false))
	pending_updates_mutex.unlock()
	unused_meshes_mutex.lock()
	unused_meshes.append(mesh_object)
	unused_meshes_mutex.unlock()

func apply_updates():
	pending_updates_mutex.lock()
	var updates = pending_updates.duplicate()
	pending_updates.clear()
	pending_updates_mutex.unlock()
	for update in updates:
		var mesh = update.mesh_object.mesh
		if not is_instance_valid(mesh):
			continue
		mesh.process_mode = update.mesh_object.process_mode
		mesh.position = update.mesh_object.position
		mesh.scale = update.mesh_object.scale
		mesh.rotation = update.mesh_object.rotation
		if update.add_new:
			if mesh.get_parent() == self:
				print("Error add_Child already child id=", update.mesh_object.id)
			else:
				add_child(mesh)
		else:
			if mesh.get_parent() != self:
				print("Error remove_Child not a child id=", update.mesh_object.id, ", ", update.mesh_object.object_id, ", ", update.mesh_object.position)
			else:
				remove_child(mesh)
