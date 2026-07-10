# Based on https://ezcha.net/news/5-16-26-rendering-a-million-objects-in-godot

class_name MultiMeshChunk extends Node3D

var multimesh_instance: MultiMeshInstance3D
var multimesh: MultiMesh = null
var static_body: StaticBody3D = null
var model: Node3D # Instantiated .glb model

var chunk_boundary: Rect2

var active_objects: Quadtree # Reference to MultiMeshManagers active_objects
var deleted_objects: Quadtree # Reference to MultiMeshManagers deleted_objects
var added_objects: Quadtree = Quadtree.new()
var object_id_pool: PackedInt32Array = []
var mesh_id_pool: PackedInt32Array = []

# Helper function to find the mesh nodes from another Node (Used for .glb imported nodes)
static func find_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(find_meshes(child))
	return result

func _init(_chunk_boundary: Rect2, _active_objects: Quadtree, _deleted_objects: Quadtree, mesh_scene: PackedScene, instance_count: int = 0) -> void:
	active_objects = _active_objects
	deleted_objects = _deleted_objects
	model = mesh_scene.instantiate()
	var meshes = find_meshes(model)
	assert(meshes.size() == 1)
	var mesh: Mesh = meshes[0].mesh

	chunk_boundary = _chunk_boundary
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = instance_count if instance_count != 0 else Globals.MULTIMESH_CHUNK_MAX_INSTANCES
	multimesh.visible_instance_count = 0
	multimesh.mesh = mesh
	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.multimesh = multimesh

	static_body = StaticBody3D.new()

func _ready() -> void:
	add_child(multimesh_instance)
	add_child(static_body)

func count() -> int:
	return added_objects.size()

func place(object: WorldObject) -> WorldObject:
	if (count() >= Globals.MULTIMESH_CHUNK_MAX_INSTANCES):
		push_error("Error: Multimesh chunk has reached its maximum amount of objects. (", Globals.MULTIMESH_CHUNK_MAX_INSTANCES, ")")
		return null
	if deleted_objects.has(Vector2(object.position.x, object.position.z)):
		return null # Object has been deleted, should not be re-added to the scene
	multimesh.visible_instance_count += 1
	object.mesh_instance_id = _recycle_id(object_id_pool, added_objects.size())
	object.initialize_model(model)
	object.multimesh_parent = self
	added_objects.insert({"position": Vector2(object.position.x, object.position.z), "data": object})
	_add_mesh(object)
	return object

func remove(object: WorldObject) -> void:
	if (object.mesh_instance_id > -1):
		object_id_pool.append(object.mesh_instance_id)
		added_objects.remove_item(Vector2(object.position.x, object.position.z))
	_remove_mesh(object)
	_remove_shape(object)
	active_objects.remove_item(Vector2(object.position.x, object.position.z))

func add_colliders(boundary: Rect2):
	for object in added_objects.query(boundary):
		if not object.collision_shape:
			print("ERROR: object at position ", object.position, " lacks collision shape!")
			return
		if not object.collision_shape.get_parent() == static_body:
			active_objects.insert({"position": Vector2(object.position.x, object.position.z), "data": { "object": object, "multimesh_chunk": self } })
			static_body.add_child(object.collision_shape)

func add_collider(object: WorldObject):
	if added_objects.has(Vector2(object.position.x, object.position.z)):
		active_objects.insert({"position": Vector2(object.position.x, object.position.z), "data": { "object": object, "multimesh_chunk": self } })
		static_body.add_child(object.collision_shape)

func remove_collider(object: WorldObject):
	if added_objects.has(Vector2(object.position.x, object.position.z)):
		active_objects.remove_item(Vector2(object.position.x, object.position.z))
		static_body.remove_child(object.collision_shape)

func set_instance_transform(_instance_id: int, _transform: Transform3D) -> void:
	if _instance_id < 0 or _instance_id > multimesh.visible_instance_count:
		return
	multimesh.set_instance_transform(_instance_id, _transform)

func _recycle_id(pool: PackedInt32Array, fallback: int) -> int:
	var pool_size: int = pool.size()
	if (pool_size > 0):
		var last_idx: int = pool_size - 1
		var recycled: int = pool[last_idx]
		pool.resize(last_idx)
		return recycled

	# Assign a fresh ID
	return fallback

func _add_mesh(object: WorldObject) -> void:
	object.mesh_instance_id = _recycle_id(mesh_id_pool, object.mesh_instance_id)
	_update_mesh_transform(object)

func _update_mesh_transform(object: WorldObject) -> void:
	multimesh.set_instance_transform(object.mesh_instance_id, object.get_transform())
	# Repeat textures to match size, pass to shader via custom data
	# var data: Color = Color(object.size.x, object.size.y, object.size.z, 0.0)
	#multimesh.set_instance_custom_data(object.mesh_instance_id, data)

func _remove_mesh(object: WorldObject) -> void:
	if (object.mesh_instance_id < 0): return

	# Hide multi-mesh instance (zero scale)
	multimesh.set_instance_transform(object.mesh_instance_id, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))

	# Prepare to recycle ID
	mesh_id_pool.append(object.mesh_instance_id)
	object.mesh_instance_id = -1

func _update_shape(object: WorldObject) -> void:
	if (object.collision_shape == null): return
	object.collision_shape.shape.size = object.size
	object.collision_shape.transform = Transform3D(Basis.from_euler(object.rotation), object.position)

func _remove_shape(object: WorldObject) -> void:
	if (object.collision_shape == null): return
	object.collision_shape.queue_free()
	object.collision_shape = null

func destroy() -> void:
	multimesh_instance.queue_free()
	static_body.queue_free()
	queue_free()
