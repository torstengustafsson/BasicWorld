extends Node

class_name PoolManager

class DeletedObject:
	var position: Vector3
	var object_id: WorldObject.ObjectId
	func _init(_position, _object_id) -> void:
		position = _position
		object_id = _object_id

static var house_mesh: PackedScene = preload("res://assets/models/house.glb")
static var chest_mesh: PackedScene = preload("res://assets/models/chest.glb")
static var tree_mesh: PackedScene = preload("res://assets/models/tree.glb")
static var rock_mesh: PackedScene = preload("res://assets/models/rock.glb")
static var human_mesh: PackedScene = preload("res://assets/models/human.glb")
static var berrybush_empty_mesh: PackedScene = preload("res://assets/models/berrybush-empty.glb")
static var berrybush_full_mesh: PackedScene = preload("res://assets/models/berrybush-full.glb")

const EXTRA_POOL_MULTIPLIER = 1.2 # Because threads may work at different speeds, objects may be created faster that they are deleted
const TREE_POOL_INITIAL_SIZE: int = int(pow(ceil(Globals.LOD_DISTANCE_NO_COLLIDER * 2 * Globals.LOD_REMOVE_DISTANCE_MULTIPLIER) / Globals.STEP_TREES, 2) * EXTRA_POOL_MULTIPLIER)
const ROCK_POOL_INITIAL_SIZE: int = int(pow(ceil(Globals.LOD_DISTANCE_NO_COLLIDER * 2 * Globals.LOD_REMOVE_DISTANCE_MULTIPLIER) / Globals.STEP_ROCKS, 2) * EXTRA_POOL_MULTIPLIER)
const BERRYBUSH_POOL_INITIAL_SIZE: int = int(pow(ceil(Globals.LOD_DISTANCE_NO_COLLIDER * 2 * Globals.LOD_REMOVE_DISTANCE_MULTIPLIER) / Globals.STEP_BERRYBUSHES, 2) * EXTRA_POOL_MULTIPLIER)
const CLOSE_OBJECTS_INITAL_SIZE = 100

# All currently active meshes are stored here
var meshes_by_id: Dictionary[int, MeshObject] = {}

# All currently active world objects are stored here
var objects_by_id: Dictionary[int, WorldObject] = {}

# Holds references to active WorldObjects sorted by type for easy access
var objects_by_type: Dictionary[WorldObject.ObjectId, Array] = {}

# --- Spatial indexes: store IDs only, never copies of the data ---
var mesh_positions_quadtree: Quadtree = Quadtree.new()   # id -> position lookup helper

var object_positions_quadtree: Quadtree = Quadtree.new()

# All objects that are removed by the player will be stored here, to ensure they are not placed again on later re-generation
var deleted_objects_quadtree: Quadtree = Quadtree.new()
var deleted_objects_quadtree_mutex: Mutex = Mutex.new()

var mesh_mutex: Mutex = Mutex.new()
var object_mutex: Mutex = Mutex.new()

var mesh_pools: Dictionary[WorldObject.ObjectId, MeshPool] = {
	WorldObject.ObjectId.TREE: MeshPool.new(tree_mesh, WorldObject.ObjectId.TREE, TREE_POOL_INITIAL_SIZE),
	WorldObject.ObjectId.ROCK: MeshPool.new(rock_mesh, WorldObject.ObjectId.ROCK,ROCK_POOL_INITIAL_SIZE),
	WorldObject.ObjectId.BERRYBUSH_EMPTY: MeshPool.new(berrybush_empty_mesh, WorldObject.ObjectId.BERRYBUSH_EMPTY, BERRYBUSH_POOL_INITIAL_SIZE),
	WorldObject.ObjectId.BERRYBUSH_FULL: MeshPool.new(berrybush_full_mesh, WorldObject.ObjectId.BERRYBUSH_FULL, BERRYBUSH_POOL_INITIAL_SIZE),
	WorldObject.ObjectId.HOUSE: MeshPool.new(house_mesh, WorldObject.ObjectId.HOUSE, 100),
	WorldObject.ObjectId.CHEST: MeshPool.new(chest_mesh, WorldObject.ObjectId.CHEST, 30),
	WorldObject.ObjectId.NPC: MeshPool.new(human_mesh, WorldObject.ObjectId.NPC, 100),
	WorldObject.ObjectId.TUTORIAL_NPC: MeshPool.new(human_mesh, WorldObject.ObjectId.TUTORIAL_NPC, 1),
}
var world_object_pool: ObjectPool = WorldObjectPool.new(CLOSE_OBJECTS_INITAL_SIZE)

func _init() -> void:
	mesh_positions_quadtree.boundary = Rect2(Vector2(-INF, -INF), Vector2(INF, INF))
	for pool in mesh_pools.values():
		add_child(pool)
	object_positions_quadtree.boundary = Rect2(Vector2(-INF, -INF), Vector2(INF, INF))
	add_child(world_object_pool)

func add_mesh(object_id: WorldObject.ObjectId, position: Vector3, scale: Vector3 = Vector3(1.0, 1.0, 1.0), rotation: Vector3 = Vector3(0.0, 0.0, 0.0)) -> MeshObject:
	if is_deleted(object_id, position):
		return null
	mesh_mutex.lock()
	var existing_id = mesh_positions_quadtree.get_item(Vector2(position.x, position.z))
	if existing_id != null:
		var existing_mesh_object = meshes_by_id.get(int(existing_id))
		mesh_mutex.unlock()
		if not existing_mesh_object:
			print("Error: quadtree had mesh but not meshes_by_id. At: ", position, " object_id=", object_id, " id=", existing_id)
		return existing_mesh_object
	var mesh_object = mesh_pools[object_id].add_mesh(position, scale, rotation)
	meshes_by_id[mesh_object.id] = mesh_object
	mesh_positions_quadtree.insert({"position": Vector2(position.x, position.z), "data": mesh_object.id})
	mesh_mutex.unlock()
	return mesh_object

func get_mesh_at_position(position: Vector3) -> MeshObject:
	mesh_mutex.lock()
	var existing_id = mesh_positions_quadtree.get_item(Vector2(position.x, position.z))
	if existing_id:
		var existing_mesh_object = meshes_by_id.get(int(existing_id))
		mesh_mutex.unlock()
		return existing_mesh_object
	mesh_mutex.unlock()
	return null

func get_meshes_in_range(position: Vector3, radius: float) -> Array[MeshObject]:
	mesh_mutex.lock()
	var ids = mesh_positions_quadtree.query_circle(Vector2(position.x, position.z), radius)
	mesh_mutex.unlock()
	var result: Array[MeshObject] = []
	for id in ids:
		var mesh_object = meshes_by_id.get(id)
		if mesh_object:
			result.append(mesh_object)
	return result

func get_meshes_in_area(area: Rect2) -> Array:
	mesh_mutex.lock()
	var ids = mesh_positions_quadtree.query(area)
	mesh_mutex.unlock()
	var result: Array[MeshObject] = []
	for id in ids:
		var mesh_object = meshes_by_id.get(id)
		if mesh_object:
			result.append(mesh_object)
	return result

func remove_mesh_by_id(id: int) -> void:
	mesh_mutex.lock()
	var mesh_object = meshes_by_id.get(id)
	if mesh_object == null:
		mesh_mutex.unlock()
		return
	mesh_pools[mesh_object.object_id].remove_mesh(mesh_object)
	meshes_by_id.erase(id)
	mesh_positions_quadtree.remove_item(id)
	if meshes_by_id.has(id):
		print("ERROR: meshes_by_id did not remove id!")
	if mesh_positions_quadtree.has(id):
		print("ERROR: mesh_positions_quadtree did not remove id!")
	mesh_mutex.unlock()

func remove_faraway_meshes(boundary_to_keep: Rect2) -> void:
	const LARGE_VALUE = 1000000.0
	var outer_boundaries = MathFunctions.get_holed_rect(
		Rect2(
			Vector2(boundary_to_keep.position.x - LARGE_VALUE, boundary_to_keep.position.y - LARGE_VALUE),
			Vector2((LARGE_VALUE + boundary_to_keep.size.x) * 2, (LARGE_VALUE + boundary_to_keep.size.x) * 2),
		),
		boundary_to_keep
	)
	var ids: Array = []
	mesh_mutex.lock()
	for boundary in outer_boundaries:
		ids.append_array(mesh_positions_quadtree.query(boundary))
	mesh_mutex.unlock()
	for id in ids:
		remove_mesh_by_id(id)

func is_deleted(object_id: WorldObject.ObjectId, position: Vector3) -> bool:
	deleted_objects_quadtree_mutex.lock()
	var deleted_object: DeletedObject = deleted_objects_quadtree.get_item(Vector2(position.x, position.z))
	deleted_objects_quadtree_mutex.unlock()
	return deleted_object and deleted_object.object_id == object_id

func add_object(mesh_object: MeshObject) -> WorldObject:
	if is_deleted(mesh_object.object_id, mesh_object.position):
		return null
	var position_xz = Vector2(mesh_object.position.x, mesh_object.position.z)
	object_mutex.lock()
	var existing_id = object_positions_quadtree.get_item(position_xz)
	if existing_id != null:
		var existing_object = objects_by_id.get(int(existing_id))
		object_mutex.unlock()
		return existing_object
	var object = world_object_pool.add_object(mesh_object)
	objects_by_id[mesh_object.id] = object
	objects_by_type.get_or_add(mesh_object.object_id, [])
	objects_by_type[mesh_object.object_id].append(object)
	object_positions_quadtree.insert({"position": position_xz, "data": mesh_object.id})
	object_mutex.unlock()
	return object

func get_object_at_position(object_id: WorldObject.ObjectId, position: Vector3) -> WorldObject:
	object_mutex.lock()
	var id = object_positions_quadtree.get_item(Vector2(position.x, position.z))
	if not id:
		object_mutex.unlock()
		return null
	var result = objects_by_id.get(id)
	object_mutex.unlock()
	if not result or result.mesh_object.object_id != object_id:
		return null
	return result

func get_active_objects_of_type(object_id: WorldObject.ObjectId) -> Array:
	object_mutex.lock()
	var result = objects_by_type.get(object_id)
	object_mutex.unlock()
	return result if result else []

func remove_object_by_id(id: int) -> void:
	object_mutex.lock()
	var object = objects_by_id.get(id)
	if object == null:
		object_mutex.unlock()
		return
	world_object_pool.remove_object(object)
	objects_by_id.erase(object.mesh_object.id)
	objects_by_type.get_or_add(object.mesh_object.object_id, [])
	objects_by_type[object.mesh_object.object_id].erase(object)
	object_positions_quadtree.remove_item(id)
	object_mutex.unlock()
	remove_mesh_by_id(id)

# Compared to remove_object, this function also makes sure the removed object will stay removed on later re-generation
func delete_object(object: WorldObject) -> void:
	var deleted_object = DeletedObject.new(object.mesh_object.position, object.mesh_object.object_id)
	deleted_objects_quadtree_mutex.lock()
	deleted_objects_quadtree.insert({"position": Vector2(object.mesh_object.position.x, object.mesh_object.position.z), "data": deleted_object})
	deleted_objects_quadtree_mutex.unlock()
	remove_object_by_id(object.mesh_object.id)

func remove_faraway_world_objects(boundary_to_keep: Rect2) -> void:
	const LARGE_VALUE = 1000000.0
	var outer_boundaries = MathFunctions.get_holed_rect(
		Rect2(
			Vector2(boundary_to_keep.position.x - LARGE_VALUE, boundary_to_keep.position.y - LARGE_VALUE),
			Vector2(LARGE_VALUE * 2, LARGE_VALUE * 2),
		),
		boundary_to_keep
	)
	var ids: Array = []
	object_mutex.lock()
	for boundary in outer_boundaries:
		ids.append_array(object_positions_quadtree.query(boundary))
	object_mutex.unlock()
	for id in ids:
		remove_object_by_id(id)

# # Must be called from the main thread
func apply_queued_updates():
	for mesh_pool in mesh_pools.values():
		mesh_pool.apply_updates()
	world_object_pool.apply_updates()
