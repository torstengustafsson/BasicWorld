class_name MultiMeshManager extends Node

static var house_mesh: PackedScene = preload("res://assets/models/house.glb")
static var chest_mesh: PackedScene = preload("res://assets/models/chest.glb")
static var tree_mesh: PackedScene = preload("res://assets/models/tree.glb")
static var rock_mesh: PackedScene = preload("res://assets/models/rock.glb")
static var berrybush_mesh: PackedScene = preload("res://assets/models/berrybush-empty.glb")
static var berrybush_full_mesh: PackedScene = preload("res://assets/models/berrybush-full.glb")

# Multimesh chunks are added in a grid pattern, starting at (0.0, 0.0)
const GRID_ORIGIN: Vector2 = Vector2(0.0, 0.0)
const CELL_SIZE: Vector2 = Vector2(Globals.MULTIMESH_CHUNK_SIZE, Globals.MULTIMESH_CHUNK_SIZE)

var MULTIMESH_MESH_ID_MAPPINGS: Dictionary[WorldObject.ObjectId, PackedScene] = {
	WorldObject.ObjectId.HOUSE: house_mesh,
	WorldObject.ObjectId.CHEST: chest_mesh,
	WorldObject.ObjectId.TREE: tree_mesh,
	WorldObject.ObjectId.ROCK: rock_mesh,
	WorldObject.ObjectId.BERRYBUSH: berrybush_mesh,
	WorldObject.ObjectId.BERRYBUSH_FULL: berrybush_full_mesh,
}

# Contains all multimesh chunks that are currently added to the scene
var active_multimesh_chunks: Dictionary[Rect2, Dictionary] = {} # Dictionary[Rect2, Dictionary[WorldObject.ObjectId, MultiMeshChunk]]

# Contains all fully active objects, meaning they have both their mesh and collider added to the scene
# (Faraway objects only have the mesh, collider is added when player gets close)
var active_objects: Quadtree = Quadtree.new()

# All objects that have been removed from the game will be stored here, to ensure they are not placed again on later re-generation
var deleted_objects: Quadtree = Quadtree.new()

static func _get_grid_cells_touching(boundary: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []

	var local_pos: Vector2 = boundary.position - GRID_ORIGIN

	# Lowest cell index touched on each axis.
	var min_cell: Vector2i = Vector2i(
		floori(local_pos.x / CELL_SIZE.x),
		floori(local_pos.y / CELL_SIZE.y)
	)

	var end_pos: Vector2 = local_pos + boundary.size
	var max_cell: Vector2i = Vector2i(
		ceili(end_pos.x / CELL_SIZE.x) - 1,
		ceili(end_pos.y / CELL_SIZE.y) - 1
	)

	for grid_y in range(min_cell.y, max_cell.y + 1):
		for grid_x in range(min_cell.x, max_cell.x + 1):
			var cell_pos: Vector2 = GRID_ORIGIN + Vector2(grid_x * CELL_SIZE.x, grid_y * CELL_SIZE.y)
			result.append(Rect2(cell_pos, CELL_SIZE))

	return result

func _init(initial_deleted_objects: Array[Vector2]) -> void:
	for position_xz in initial_deleted_objects:
		deleted_objects.insert({"position": position_xz, "data": true})

# Will add the objects without their colliders. Colliders must be activated separately per object instance.
func add_multimesh_chunks(boundary: Rect2, batch_size: int = 3):
	var i = 0
	var multimesh_chunk_boundaries = _get_grid_cells_touching(boundary)
	for chunk_boundary in multimesh_chunk_boundaries:
		for object_id in MULTIMESH_MESH_ID_MAPPINGS.keys():
			if not active_multimesh_chunks.has(chunk_boundary):
				active_multimesh_chunks[chunk_boundary] = {}
			if active_multimesh_chunks[chunk_boundary].has(object_id):
				# TODO: If multimesh chunk is added before roads for an area, then objects will
				# currently not be removed from the road, with this solution.
				continue
			var mesh_scene = MULTIMESH_MESH_ID_MAPPINGS[object_id]
			var multimesh_chunk = MultiMeshChunk.new(chunk_boundary, active_objects, deleted_objects, mesh_scene)
			active_multimesh_chunks[chunk_boundary][object_id] = multimesh_chunk
			add_child(multimesh_chunk)
			WorldState.state.settlement_manager.add_settlement_objects(multimesh_chunk, object_id)
			WorldState.state.object_manager.add_world_objects(multimesh_chunk, object_id)
			i += 1
			if i > batch_size:
				i = 0
				await get_tree().process_frame

func add_colliders(boundary: Rect2):
	for multimesh_chunks_at_boundary in active_multimesh_chunks.values():
		for multimesh_chunk in multimesh_chunks_at_boundary.values():
			multimesh_chunk.add_colliders(boundary)

func remove_multimesh_chunks(boundary_to_keep: Rect2):
	var chunks_to_be_removed: Array[MultiMeshChunk] = []
	var boundaries_to_be_removed: Array[Rect2] = []
	for chunk_boundary in active_multimesh_chunks:
		if not chunk_boundary.intersects(boundary_to_keep):
			boundaries_to_be_removed.append(chunk_boundary)
			for multimesh_chunk in active_multimesh_chunks[chunk_boundary].values():
				chunks_to_be_removed.append(multimesh_chunk)
	for multimesh_chunk in chunks_to_be_removed:
		multimesh_chunk.destroy()
	for boundary in boundaries_to_be_removed:
		active_multimesh_chunks.erase(boundary)

func remove_faraway_colliders(boundary_to_keep: Rect2):
	const LARGE_VALUE = 100000.0
	var LARGE_BOUNDS = Rect2(
		Vector2(boundary_to_keep.position.x - LARGE_VALUE, boundary_to_keep.position.y - LARGE_VALUE),
		Vector2(2 * LARGE_VALUE, 2 * LARGE_VALUE)
	)
	var boundaries = MathFunctions.get_holed_rect(LARGE_BOUNDS, boundary_to_keep)
	for boundary in boundaries:
		for object_data in active_objects.query(boundary):
			object_data["multimesh_chunk"].remove_collider(object_data["object"])

func get_object_at_position(object_id: WorldObject.ObjectId, position: Vector3) -> WorldObject:
	var object: WorldObject
	var object_data = active_objects.get_item(Vector2(position.x, position.z))
	if object_data and object_data.has("object"):
		object = object_data["object"]
	else:
		object = active_objects.get_item(Vector2(position.x, position.z))

	if not object or object.object_id != object_id:
		return null
	return object_data["object"]

func get_objects_of_type_in_boundary(object_id: WorldObject.ObjectId, boundary: Rect2) -> Array[WorldObject]:
	var result: Array[WorldObject] = []
	for chunk_boundary in active_multimesh_chunks:
		if not chunk_boundary.intersects(boundary) or not active_multimesh_chunks[chunk_boundary].has(object_id):
			continue
		var multimesh_chunk = active_multimesh_chunks[chunk_boundary][object_id]
		result.append_array(multimesh_chunk.added_objects.query(boundary))
	return result

func get_all_objects_in_boundary(boundary: Rect2) -> Array[WorldObject]:
	var result: Array[WorldObject] = []
	for chunk_boundary in active_multimesh_chunks:
		if not chunk_boundary.intersects(boundary):
			continue
		for multimesh_chunk in active_multimesh_chunks[chunk_boundary].values():
			result.append_array(multimesh_chunk.added_objects.query(boundary))
	return result

func remove_object(object: WorldObject) -> bool:
	var multimesh_chunk = object.multimesh_parent
	if not active_multimesh_chunks.has(multimesh_chunk.chunk_boundary) or not active_multimesh_chunks[multimesh_chunk.chunk_boundary].has(object.object_id):
		return false
	multimesh_chunk.remove(object)
	return true

func add_object(object_id: WorldObject.ObjectId, position: Vector3, rotation: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> WorldObject:
	for multimesh_chunks_at_boundary in active_multimesh_chunks.values():
		if multimesh_chunks_at_boundary.has(object_id):
			var multimesh_chunk = multimesh_chunks_at_boundary[object_id]
			var object = WorldObject.create_object(object_id, position, rotation, scale)
			return multimesh_chunk.place(object)
	return null

func add_object_with_collider(object_id: WorldObject.ObjectId, position: Vector3, rotation: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> WorldObject:
	for chunk_boundary in active_multimesh_chunks:
		if chunk_boundary.has_point(Vector2(position.x, position.z)) and active_multimesh_chunks[chunk_boundary].has(object_id):
			var multimesh_chunk = active_multimesh_chunks[chunk_boundary][object_id]
			var object = WorldObject.create_object(object_id, position, rotation, scale)
			var placed_object = multimesh_chunk.place(object)
			if placed_object:
				multimesh_chunk.add_collider(placed_object)
	return null

func delete_object(object: WorldObject) -> bool:
	var removed = remove_object(object)
	if removed:
		deleted_objects.insert({"position": Vector2(object.position.x, object.position.z), "data": true})
	return removed

func destroy():
	for multimesh_chunks_at_boundary in active_multimesh_chunks.values():
		for multimesh_chunk in multimesh_chunks_at_boundary.values():
			multimesh_chunk.destroy()
	active_multimesh_chunks.clear()
	active_objects.clear()
	deleted_objects.clear()

func save() -> Dictionary:
	var result: Dictionary = {}
	var deleted_object_data: Array = []
	for position_xz in deleted_objects.query_all_positions():
		deleted_object_data.append([position_xz.x, position_xz.y])
	result["deleted_objects"] = deleted_object_data
	return result

static func load(data: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for position_xz in data["deleted_objects"]:
		result.append(Vector2(position_xz[0], position_xz[1]))
	return result
