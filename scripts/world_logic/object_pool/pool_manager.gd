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
static var human_walking_mesh: PackedScene = preload("res://assets/models/human_walking.glb")
static var human_waving_mesh: PackedScene = preload("res://assets/models/human_waving.glb")
static var berrybush_empty_mesh: PackedScene = preload("res://assets/models/berrybush-empty.glb")
static var berrybush_full_mesh: PackedScene = preload("res://assets/models/berrybush-full.glb")

const EXTRA_POOL_MULTIPLIER = 1.2 # Because threads may work at different speeds, objects may be created faster that they are deleted
const TREE_POOL_INITIAL_SIZE: int = int(pow(ceil(Globals.LOD_DISTANCE_NO_COLLIDER * 2 * Globals.LOD_REMOVE_DISTANCE_MULTIPLIER) / Globals.STEP_TREES, 2) * EXTRA_POOL_MULTIPLIER)
const ROCK_POOL_INITIAL_SIZE: int = int(pow(ceil(Globals.LOD_DISTANCE_NO_COLLIDER * 2 * Globals.LOD_REMOVE_DISTANCE_MULTIPLIER) / Globals.STEP_ROCKS, 2) * EXTRA_POOL_MULTIPLIER)
const BERRYBUSH_POOL_INITIAL_SIZE: int = int(pow(ceil(Globals.LOD_DISTANCE_NO_COLLIDER * 2 * Globals.LOD_REMOVE_DISTANCE_MULTIPLIER) / Globals.STEP_BERRYBUSHES, 2) * EXTRA_POOL_MULTIPLIER)
const CLOSE_OBJECT_INITAL_SIZE = 100

var mesh_mutex: Mutex = Mutex.new()
var object_mutex: Mutex = Mutex.new()

# Contains all meshes added to scene by the object pools for easy access.
# Only meshes are added first for performance reasons. The full objects are only added when player gets close.
var used_meshes_quadtree: Quadtree = Quadtree.new()

# Contains the full objects, with colliders and custom behavior. Each object correspond to one mesh in the scene. It
# contains a reference to its corresponding mesh, that is managed by the MeshPools.
var used_objects_quadtree: Quadtree = Quadtree.new()

# All objects that are removed by the player will be stored here, to ensure they are not placed again on later re-generation
var deleted_objects_quadtree: Quadtree = Quadtree.new()

var mesh_pools: Dictionary[WorldObject.ObjectId, MeshPool] = {
	WorldObject.ObjectId.TREE: MeshPool.new(tree_mesh, WorldObject.ObjectId.TREE, TREE_POOL_INITIAL_SIZE),
	WorldObject.ObjectId.ROCK: MeshPool.new(rock_mesh, WorldObject.ObjectId.ROCK, ROCK_POOL_INITIAL_SIZE),
	WorldObject.ObjectId.BERRYBUSH_EMPTY: MeshPool.new(berrybush_empty_mesh, WorldObject.ObjectId.BERRYBUSH_EMPTY, BERRYBUSH_POOL_INITIAL_SIZE),
	WorldObject.ObjectId.BERRYBUSH_FULL: MeshPool.new(berrybush_full_mesh, WorldObject.ObjectId.BERRYBUSH_FULL, BERRYBUSH_POOL_INITIAL_SIZE),
	WorldObject.ObjectId.HOUSE: MeshPool.new(house_mesh, WorldObject.ObjectId.HOUSE, 100),
	WorldObject.ObjectId.CHEST: MeshPool.new(chest_mesh, WorldObject.ObjectId.CHEST, 30),
	WorldObject.ObjectId.NPC: MeshPool.new(human_walking_mesh, WorldObject.ObjectId.NPC, 100),
}
var object_pool: ObjectPool = ObjectPool.new(used_objects_quadtree, CLOSE_OBJECT_INITAL_SIZE)

func _init() -> void:
	used_meshes_quadtree.boundary = Rect2(Vector2(-INF, -INF), Vector2(INF, INF))
	for pool in mesh_pools.values():
		add_child(pool)
	used_objects_quadtree.boundary = Rect2(Vector2(-INF, -INF), Vector2(INF, INF))
	add_child(object_pool)

func get_mesh(object_id: WorldObject.ObjectId, position: Vector3, scale: Vector3 = Vector3(1.0, 1.0, 1.0)) -> MeshObject:
	mesh_mutex.lock()
	if is_deleted(object_id, position):
		mesh_mutex.unlock()
		return null
	var mesh_object = mesh_pools[object_id].get_mesh(position, scale)
	mesh_mutex.unlock()
	return mesh_object

func get_mesh_at_position(type: WorldObject.ObjectId, position: Vector3) -> MeshObject:
	return mesh_pools[type].get_mesh_at_position(position)

func get_meshes_in_area(area: Rect2) -> Array:
	mesh_mutex.lock()
	var result = used_meshes_quadtree.query(area)
	mesh_mutex.unlock()
	return result

func get_meshes_in_range(position: Vector3, radius: float) -> Array:
	mesh_mutex.lock()
	var result = used_meshes_quadtree.query_circle(Vector2(position.x, position.z), radius)
	mesh_mutex.unlock()
	return result

func remove_faraway_world_meshes(boundary_to_keep: Rect2):
	mesh_mutex.lock()
	for pool in mesh_pools.values():
		pool.remove_meshes_outside_bounds(boundary_to_keep)
	mesh_mutex.unlock()

func remove_mesh(mesh_object: MeshObject) -> void:
	mesh_mutex.lock()
	mesh_pools[mesh_object.object_id].set_mesh_disabled(mesh_object)
	mesh_mutex.unlock()

# Must be called from the main thread
func apply_mesh_updates():
	for mesh_pool in mesh_pools.values():
		mesh_pool.apply_mesh_updates()

func is_deleted(object_id: WorldObject.ObjectId, position: Vector3) -> bool:
	object_mutex.lock()
	var deleted_object = deleted_objects_quadtree.get_item(Vector2(position.x, position.z))
	object_mutex.unlock()
	return deleted_object and deleted_object.object_id == object_id

func get_object(mesh_object: MeshObject) -> WorldObject:
	object_mutex.lock()
	if is_deleted(mesh_object.object_id, mesh_object.position):
		object_mutex.unlock()
		return null
	var object = object_pool.get_object(mesh_object)
	object_mutex.unlock()
	return object

func get_object_at_position(object_id: WorldObject.ObjectId, position: Vector3) -> WorldObject:
	return object_pool.get_object_at_position(object_id, position)

func get_active_objects_of_type(object_id: WorldObject.ObjectId) -> Array:
	return object_pool.get_active_objects_of_type(object_id)

func remove_faraway_world_objects(boundary_to_keep: Rect2) -> void:
	object_mutex.lock()
	object_pool.remove_objects_outside_bounds(boundary_to_keep)
	object_mutex.unlock()

func remove_object(object: WorldObject) -> void:
	mesh_mutex.lock()
	mesh_pools[object.mesh_object.object_id].set_mesh_disabled(object.mesh_object)
	mesh_mutex.unlock()
	object_mutex.lock()
	object_pool.set_object_disabled(object)
	object_mutex.unlock()

# Compared to remove_object, this function also makes sure the removed object will stay removed on later re-generation
func delete_object(object: WorldObject) -> void:
	object_mutex.lock()
	var deleted_object = DeletedObject.new(object.mesh_object.position, object.mesh_object.object_id)
	deleted_objects_quadtree.insert({"position": Vector2(object.mesh_object.position.x, object.mesh_object.position.z), "data": deleted_object})
	object_mutex.unlock()
	remove_object(object)
