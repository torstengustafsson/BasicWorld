extends Node

class_name PoolManager

static var house_mesh: PackedScene = preload("res://assets/models/house.glb")
static var chest_mesh: PackedScene = preload("res://assets/models/chest.glb")
static var tree_mesh: PackedScene = preload("res://assets/models/tree.glb")
static var rock_mesh: PackedScene = preload("res://assets/models/rock.glb")
static var human_mesh: PackedScene = preload("res://assets/models/animated_human.glb")
static var berrybush_empty_mesh: PackedScene = preload("res://assets/models/berrybush-empty.glb")
static var berrybush_full_mesh: PackedScene = preload("res://assets/models/berrybush-full.glb")

const TREE_POOL_INITIAL_SIZE: int = int(pow(ceil(Globals.LOD_DISTANCE_NO_COLLIDER * 2 * Globals.LOD_REMOVE_DISTANCE_MULTIPLIER) / Globals.STEP_TREES, 2))
const ROCK_POOL_INITIAL_SIZE: int = int(pow(ceil(Globals.LOD_DISTANCE_NO_COLLIDER * 2 * Globals.LOD_REMOVE_DISTANCE_MULTIPLIER) / Globals.STEP_ROCKS, 2))
const BERRYBUSH_POOL_INITIAL_SIZE: int = int(pow(ceil(Globals.LOD_DISTANCE_NO_COLLIDER * 2 * Globals.LOD_REMOVE_DISTANCE_MULTIPLIER) / Globals.STEP_BERRYBUSHES, 2))
const CLOSE_OBJECT_INITAL_SIZE = 100

# Contains all meshes added to scene by the object pools for easy access.
# Only meshes are added first for performance reasons. The full objects are only added when player gets close.
var used_meshes_quadtree: Quadtree = Quadtree.new()
var mesh_pools: Dictionary[WorldObject.ObjectId, MeshPool] = {
	WorldObject.ObjectId.TREE: MeshPool.new(tree_mesh, WorldObject.ObjectId.TREE, used_meshes_quadtree, TREE_POOL_INITIAL_SIZE),
	WorldObject.ObjectId.ROCK: MeshPool.new(rock_mesh, WorldObject.ObjectId.ROCK, used_meshes_quadtree, ROCK_POOL_INITIAL_SIZE),
	WorldObject.ObjectId.BERRYBUSH_EMPTY: MeshPool.new(berrybush_empty_mesh, WorldObject.ObjectId.BERRYBUSH_EMPTY, used_meshes_quadtree, BERRYBUSH_POOL_INITIAL_SIZE),
	WorldObject.ObjectId.BERRYBUSH_FULL: MeshPool.new(berrybush_full_mesh, WorldObject.ObjectId.BERRYBUSH_FULL, used_meshes_quadtree, BERRYBUSH_POOL_INITIAL_SIZE),
	WorldObject.ObjectId.HOUSE: MeshPool.new(house_mesh, WorldObject.ObjectId.HOUSE, used_meshes_quadtree, 100),
	WorldObject.ObjectId.CHEST: MeshPool.new(chest_mesh, WorldObject.ObjectId.CHEST, used_meshes_quadtree, 30),
	WorldObject.ObjectId.NPC: MeshPool.new(human_mesh, WorldObject.ObjectId.NPC, used_meshes_quadtree, 100),
}
# Contains the full objects, with colliders and custom behavior. Each object correspond to one mesh in the scene. It
# contains a reference to its corresponding mesh, that is managed by the MeshPools.
var used_objects_quadtree: Quadtree = Quadtree.new()
var object_pool: ObjectPool = ObjectPool.new(used_objects_quadtree, CLOSE_OBJECT_INITAL_SIZE)

func _init() -> void:
	used_meshes_quadtree.boundary = Rect2(Vector2(-INF, -INF), Vector2(INF, INF))
	for pool in mesh_pools.values():
		add_child(pool)
	used_objects_quadtree.boundary = Rect2(Vector2(-INF, -INF), Vector2(INF, INF))
	add_child(object_pool)

func get_mesh(type: WorldObject.ObjectId, position: Vector3, scale: Vector3) -> Node3D:
	return mesh_pools[type].get_mesh(position, scale)

func get_mesh_at_position(type: WorldObject.ObjectId, position: Vector3) -> Node3D:
	return mesh_pools[type].get_mesh_at_position(position)

func get_meshes_in_range(position: Vector3, radius: float) -> Array:
	return used_meshes_quadtree.query_circle(Vector2(position.x, position.z), radius)

func remove_faraway_world_meshes(boundary_to_keep: Rect2):
	for pool in mesh_pools.values():
		pool.remove_meshes_outside_bounds(boundary_to_keep)

func remove_mesh(mesh: Node3D) -> void:
	var type = mesh.get_meta("object_id")
	mesh_pools[type]._set_mesh_disabled(mesh)

func remove_mesh_with_id(mesh: Node3D, object_id: WorldObject.ObjectId) -> void:
	mesh_pools[object_id]._set_mesh_disabled(mesh)


func get_object(glb_mesh: Node3D) -> WorldObject:
	return object_pool.get_object(glb_mesh)

func get_object_at_position(type: WorldObject.ObjectId, position: Vector3) -> WorldObject:
	return object_pool.get_object_at_position(type, position)

func get_active_objects_of_type(type: WorldObject.ObjectId) -> Array:
	return object_pool.get_active_objects_of_type(type)

func remove_faraway_world_objects(boundary_to_keep: Rect2) -> void:
	object_pool.remove_objects_outside_bounds(boundary_to_keep)

func remove_object(object: WorldObject) -> void:
	mesh_pools[object.object_id]._set_mesh_disabled(object.glb_mesh)
	object_pool._set_object_disabled(object)

# TODO
# func get_collider(shape: CollisionShape3D, position: Vector3, scale: Vector3) -> CollisionObject3D:
# 	return null
