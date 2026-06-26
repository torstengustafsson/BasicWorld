extends Node

class_name MeshPool

const OUT_OF_SIGHT = Vector3(-1000000.0, -1000000.0, -1000000.0)

# Pool configuration
var mesh_scene: PackedScene # Used to instantiate the pools Node3D objects
var object_id: WorldObject.ObjectId
var initial_pool_size: int # Size of pool at creation. Pool may later grow beyond this, but a good initial value may save some initialization time.
var growth_threshold_percent: float # A value of 0.8 means grow when used objects are >= 80% of pool size.
var growth_threshold_value: int # Actual threshold value in number of objects required before pool growth.
var growth_factor_percent: float # A value of 0.5 means grow by 50% each time.

var unused_meshes: Array[Node3D] = [] # These are available meshes to be added to the scene. Pre-added as children to scene for performance.
var used_meshes: Dictionary[Vector3, Node3D] = {} # Takes meshes from unused_meshes and places them on their position in the scene. Maps mesh position to mesh.

# Reference to PoolManager:s meshes quadtree
var used_meshes_quadtree: Quadtree

func _init(_mesh_scene: PackedScene, _object_id: WorldObject.ObjectId, _used_meshes_quadtree: Quadtree, _initial_pool_size: int = 10, _growth_threshold_percent: float = 0.8, _growth_factor_percent: float = 0.5):
	mesh_scene = _mesh_scene
	object_id = _object_id
	used_meshes_quadtree = _used_meshes_quadtree
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
		var mesh: Node3D = mesh_scene.instantiate()
		mesh.set_meta("object_id", object_id)
		_set_mesh_disabled(mesh)
		add_child(mesh)

func get_mesh(position: Vector3, scale: Vector3) -> Node3D:
	var existing_mesh = used_meshes.get(position)
	if existing_mesh:
		return existing_mesh
	if used_meshes.size() >= growth_threshold_value:
		_grow_pool()
	var mesh = unused_meshes.pop_back()
	if not mesh:
		return null
	mesh.process_mode = Node.PROCESS_MODE_PAUSABLE
	mesh.position = position
	mesh.scale = scale
	used_meshes[position] = mesh
	used_meshes_quadtree.insert({"position": Vector2(position.x, position.z), "data": mesh})
	return mesh

func _set_mesh_disabled(mesh: Node3D) -> void:
	used_meshes_quadtree.remove(mesh)
	used_meshes.erase(mesh.position)
	mesh.process_mode = Node.PROCESS_MODE_DISABLED
	mesh.position = OUT_OF_SIGHT
	unused_meshes.append(mesh)

func get_mesh_at_position(position: Vector3) -> Node3D:
	return used_meshes.get(position)

func get_all_active_meshes() -> Array[Node3D]:
	return used_meshes.values()

func remove_meshes_outside_bounds(boundary: Rect2) -> void:
	for position in used_meshes.keys():
		if not boundary.has_point(Vector2(position.x, position.z)):
			_set_mesh_disabled(used_meshes[position])

func _grow_pool() -> void:
	var total_pool_objects: int = unused_meshes.size() + used_meshes.size()
	var new_objects: int = floor(total_pool_objects * growth_factor_percent)
	growth_threshold_value = floor((total_pool_objects + new_objects) * growth_threshold_percent)
	for _i in new_objects:
		var mesh: Node3D = mesh_scene.instantiate()
		mesh.set_meta("object_id", object_id)
		_set_mesh_disabled(mesh)
		add_child(mesh)
