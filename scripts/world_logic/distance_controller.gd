extends Node

class_name DistanceController

var player: Node3D # Only used for position
var static_objects_qt: Quadtree
var terrainGenerator: TerrainGenerator
var lod_last_player_pos: Vector3
var terrain_last_player_index: Vector2i

var update_time = 0
const FORCE_UPDATE_INTERVAL_SECONDS = 1.0

func _init(_player, _static_objects_qt: Quadtree, _terrainGenerator: TerrainGenerator):
	player = _player
	static_objects_qt = _static_objects_qt
	terrainGenerator = _terrainGenerator
	lod_last_player_pos = player.position
	terrain_last_player_index = Vector2i(0, 0)

func _process(_delta: float) -> void:
	if (player.position - lod_last_player_pos).length() > Globals.LOD_UPDATE_DISTANCE:
		update_lods()
		lod_last_player_pos = player.position

	var player_chunk_index = terrainGenerator.get_player_chunk_index(player.position)
	if player_chunk_index != terrain_last_player_index:
		terrainGenerator.update_chunks_around_player(player.position, 3)
		terrain_last_player_index = player_chunk_index

	if update_time > FORCE_UPDATE_INTERVAL_SECONDS:
		add_nearby_children_full()
		update_time = 0
	update_time += _delta

func update_lods():
	add_no_collider_children_batched()
	remove_faraway_children_batched()
	add_nearby_children_full()

func add_nearby_children_full():
	var objects_full = static_objects_qt.query_circle(Vector2(player.position.x, player.position.z), Globals.LOD_DISTANCE_FULL)
	for index in objects_full.size():
		var object: WorldObject = objects_full[index]["data"]
		if object.collider.disabled:
			object.collider.disabled = false
			if object.glb_mesh_no_collider.get_parent() == self:
				remove_child(object.glb_mesh_no_collider)
			add_child(object.instance)

func add_no_collider_children_batched(batch_size: int = 500):
	const INNER_RADIUS = Globals.LOD_DISTANCE_FULL
	const OUTER_RADIUS = Globals.LOD_DISTANCE_NO_COLLIDER
	var objects_no_collider = static_objects_qt.query_circle_holed(Vector2(player.position.x, player.position.z), INNER_RADIUS, OUTER_RADIUS)
	var i = 0
	while i < objects_no_collider.size():
		for j in min(batch_size, objects_no_collider.size() - i):
			var object: WorldObject = objects_no_collider[i + j]["data"]
			# Need to verify distance again because batched updating means player may have moved since this loop started
			var distance = object.instance.position.distance_to(player.position)
			if distance > INNER_RADIUS and distance <= OUTER_RADIUS:
				object.collider.disabled = true
				if object.instance.get_parent() == self:
					remove_child(object.instance)
				if object.glb_mesh_no_collider.get_parent() != self:
					add_child(object.glb_mesh_no_collider)
		i += batch_size
		await get_tree().process_frame

func remove_faraway_children_batched(batch_size: int = 500):
	const MARGIN = 5.0 # Add a small extra margin to ensure no outer radius-objects are missed
	const INNER_RADIUS = Globals.LOD_DISTANCE_NO_COLLIDER
	const OUTER_RADIUS = Globals.LOD_DISTANCE_NO_COLLIDER + Globals.LOD_UPDATE_DISTANCE + MARGIN
	var faraway_objects = static_objects_qt.query_circle_holed(Vector2(player.position.x, player.position.z), INNER_RADIUS, OUTER_RADIUS)
	var i = 0
	while i < faraway_objects.size():
		for j in min(batch_size, faraway_objects.size() - i):
			var object: WorldObject = faraway_objects[i + j]["data"]
			# Need to verify distance again because batched updating means player may have moved since this loop started
			# Outer radius is not checked because anything further away should still be removed
			var distance = object.instance.position.distance_to(player.position)
			if distance > INNER_RADIUS:
				if object.glb_mesh_no_collider.get_parent() == self:
					remove_child(object.glb_mesh_no_collider)
				if object.instance.get_parent() == self:
					remove_child(object.instance)
		i += batch_size
		await get_tree().process_frame
