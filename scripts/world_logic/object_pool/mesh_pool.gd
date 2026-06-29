extends Node

class_name MeshPool

# Pool configuration
var mesh_scene: PackedScene # Used to instantiate the pools Node3D objects
var object_id: WorldObject.ObjectId
var initial_pool_size: int # Size of pool at creation. Pool may later grow beyond this, but a good initial value may save some initialization time.
var growth_threshold_percent: float # A value of 0.8 means grow when used objects are >= 80% of pool size.
var growth_threshold_value: int # Actual threshold value in number of objects required before pool growth.
var growth_factor_percent: float # A value of 0.5 means grow by 50% each time.

var unused_meshes: Array[MeshObject] = [] # These are available meshes to be added to the scene. Pre-added as children to scene for performance.
var used_meshes: Dictionary[Vector3, MeshObject] = {} # Takes meshes from unused_meshes and places them in the scene at the correct position, scale and so on. Maps mesh position to mesh.
var pending_mesh_updates: Array[MeshObject] = [] # Queues node updates, to avoid calling call_deferred too much
var pending_updates_mutex: Mutex = Mutex.new()

func _init(_mesh_scene: PackedScene, _object_id: WorldObject.ObjectId, _initial_pool_size: int = 10, _growth_threshold_percent: float = 0.8, _growth_factor_percent: float = 0.5):
	mesh_scene = _mesh_scene
	object_id = _object_id
	initial_pool_size = _initial_pool_size
	growth_threshold_percent = _growth_threshold_percent
	growth_threshold_value = floor(growth_threshold_percent * initial_pool_size)
	growth_factor_percent = _growth_factor_percent

func _ready() -> void:
	# growth_threshold is a percentage of when to increase the pool. Must be between 0.0 and 1.0
	assert(growth_threshold_percent > 0.0 and growth_threshold_percent < 1.0)
	# We make this assumption on pool recalculation, so generate an error if this ever changes to avoid debugging headaches
	_initialize_pool()

func _initialize_pool() -> void:
	unused_meshes.clear()
	for _i in range(initial_pool_size):
		var mesh_object = MeshObject.new(mesh_scene.instantiate(), object_id, Globals.OUT_OF_SIGHT)
		set_mesh_disabled(mesh_object)
		call_deferred("add_child", mesh_object.mesh)

func get_mesh(position: Vector3, scale: Vector3 = Vector3(1.0, 1.0, 1.0)) -> MeshObject:
	var existing_mesh = used_meshes.get(position)
	if existing_mesh:
		return existing_mesh
	if used_meshes.size() >= growth_threshold_value:
		_grow_pool()
	var mesh_object = unused_meshes.pop_back()
	if not mesh_object:
		return null
	mesh_object.process_mode = Node.PROCESS_MODE_PAUSABLE
	mesh_object.position = position
	mesh_object.rotation = Vector3(0.0, 0.0, 0.0)
	mesh_object.scale = scale
	pending_updates_mutex.lock()
	pending_mesh_updates.append(mesh_object)
	pending_updates_mutex.unlock()
	used_meshes[position] = mesh_object
	WorldState.state.pool_manager.used_meshes_quadtree.insert({"position": Vector2(position.x, position.z), "data": mesh_object})
	return mesh_object

func set_mesh_disabled(mesh_object: MeshObject) -> void:
	if mesh_object.object_id == WorldObject.ObjectId.CHEST:
		pass
	used_meshes.erase(mesh_object.position)
	mesh_object.mesh.call_deferred("set_process_mode", Node.PROCESS_MODE_DISABLED)
	mesh_object.mesh.call_deferred("set_position", Globals.OUT_OF_SIGHT)
	mesh_object.process_mode = Node.PROCESS_MODE_DISABLED
	mesh_object.position = Globals.OUT_OF_SIGHT
	pending_updates_mutex.lock()
	pending_mesh_updates.append(mesh_object)
	pending_updates_mutex.unlock()
	unused_meshes.append(mesh_object)
	WorldState.state.pool_manager.used_meshes_quadtree.remove(mesh_object)

func get_mesh_at_position(position: Vector3) -> MeshObject:
	var result = used_meshes.get(position)
	return result

func get_all_active_meshes() -> Array[Node3D]:
	var result = used_meshes.values().duplicate()
	return result

func remove_meshes_outside_bounds(boundary: Rect2) -> void:
	for position in used_meshes.keys():
		if not boundary.has_point(Vector2(position.x, position.z)):
			if used_meshes.get(position):
				set_mesh_disabled(used_meshes[position])

# Must be called from the main thread
func apply_mesh_updates():
	pending_updates_mutex.lock()
	var updates: Array[MeshObject] = pending_mesh_updates.duplicate()
	pending_mesh_updates.clear()
	pending_updates_mutex.unlock()
	for mesh_object in updates:
		if not is_instance_valid(mesh_object.mesh):
			continue
		mesh_object.mesh.process_mode = mesh_object.process_mode
		mesh_object.mesh.position = mesh_object.position
		mesh_object.mesh.scale = mesh_object.scale


func _grow_pool() -> void:
	var total_pool_objects: int = unused_meshes.size() + used_meshes.size()
	var new_objects: int = min(floor(total_pool_objects * growth_factor_percent), 1000)
	growth_threshold_value = floor((total_pool_objects + new_objects) * growth_threshold_percent)
	for _i in new_objects:
		var mesh_object = MeshObject.new(mesh_scene.instantiate(), object_id, Globals.OUT_OF_SIGHT)
		set_mesh_disabled(mesh_object)
		call_deferred("add_child", mesh_object.mesh)
