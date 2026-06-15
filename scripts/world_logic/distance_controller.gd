extends Node3D

class_name DistanceController

var world_state: WorldState
var world_generator: WorldGenerator

var lod_last_player_pos: Vector3
var terrain_last_player_index: Vector2i

var update_close_objects_time = 0
const FORCE_UPDATE_CLOSE_OBJECTS_INTERVAL_SECONDS = 2.0

var cleanup_faraway_objects_time = 0
const FORCE_CLEANUP_FARAWAY_OBJECTS_INTERVAL_SECONDS = 10.0


func _init(_world_state: WorldState):
	world_generator = WorldGenerator.new(_world_state)
	world_state = _world_state
	lod_last_player_pos = world_state.player.position
	terrain_last_player_index = Vector2i(0, 0)

func _ready() -> void:
	# CREATE TERRAIN

	world_state.terrain_generator.add_chunks_around_player(world_state.player.position, world_generator.generate_world)

	# TODO: Find out why we need to wait here.
	# Without the wait, ground collisions will not be available at start outside of player immediate area.
	# This make below ground-based calculations like removing trees on steep terrain not possible.
	await get_tree().process_frame

	var terrain_boundary = world_state.terrain_generator.get_terrain_size()

	world_generator.generate_starting_items(terrain_boundary)

	update_lods()

func _process(_delta: float) -> void:
	var player_chunk_index = world_state.terrain_generator.get_player_chunk_index(world_state.player.position)
	if player_chunk_index != terrain_last_player_index:
		world_state.terrain_generator.update_chunks_around_player(world_state.player.position, world_generator.generate_world, 3)
		terrain_last_player_index = player_chunk_index

	if (world_state.player.position - lod_last_player_pos).length() > Globals.LOD_UPDATE_DISTANCE:
		update_lods()
		lod_last_player_pos = world_state.player.position
		update_close_objects_time = 0

	if update_close_objects_time > FORCE_UPDATE_CLOSE_OBJECTS_INTERVAL_SECONDS:
		add_nearby_children_full()
		update_close_objects_time = 0
	update_close_objects_time += _delta

	if cleanup_faraway_objects_time > FORCE_CLEANUP_FARAWAY_OBJECTS_INTERVAL_SECONDS:
		# remove_all_faraway_children_batched()
		cleanup_faraway_objects_time = 0
	cleanup_faraway_objects_time += _delta


func update_lods():
	add_no_collider_children_batched()
	remove_faraway_children_batched()
	add_nearby_children_full()

func add_nearby_children_full():
	var objects_full = world_state.static_objects_qt.query_circle(Vector2(world_state.player.position.x, world_state.player.position.z), Globals.LOD_DISTANCE_FULL)
	for object in objects_full:
		object = object["data"]
		if object.collider.disabled:
			object.collider.disabled = false
			if object.glb_mesh_no_collider.get_parent() == self:
				remove_child(object.glb_mesh_no_collider)
			add_child(object.instance)

func add_no_collider_children_batched(batch_size: int = 500):
	const INNER_RADIUS = Globals.LOD_DISTANCE_FULL
	const OUTER_RADIUS = Globals.LOD_DISTANCE_NO_COLLIDER
	var objects_no_collider = world_state.static_objects_qt.query_circle_holed(Vector2(world_state.player.position.x, world_state.player.position.z), INNER_RADIUS, OUTER_RADIUS)
	var i = 0
	while i < objects_no_collider.size():
		for j in min(batch_size, objects_no_collider.size() - i):
			var object: WorldObject = objects_no_collider[i + j]["data"]
			if object == null or object.instance == null:
				continue
			# Need to verify distance again because batched updating means player may have moved since this loop started
			var distance = object.instance.position.distance_to(world_state.player.position)
			if distance > INNER_RADIUS and distance <= OUTER_RADIUS:
				object.collider.disabled = true
				if object.instance.get_parent() == self:
					remove_child(object.instance)
				if object.glb_mesh_no_collider.get_parent() != self:
					add_child(object.glb_mesh_no_collider)
		i += batch_size
		await get_tree().process_frame

func remove_faraway_children_batched(batch_size: int = 500):
	const MARGIN = 10.0 # Add a small extra margin to ensure no outer radius-objects are missed
	const INNER_RADIUS = Globals.LOD_DISTANCE_NO_COLLIDER
	const OUTER_RADIUS = Globals.LOD_DISTANCE_NO_COLLIDER + Globals.LOD_UPDATE_DISTANCE + MARGIN
	var faraway_objects = world_state.static_objects_qt.query_circle_holed(Vector2(world_state.player.position.x, world_state.player.position.z), INNER_RADIUS, OUTER_RADIUS)
	var i = 0
	while i < faraway_objects.size():
		for j in min(batch_size, faraway_objects.size() - i):
			var object: WorldObject = faraway_objects[i + j]["data"]
			if object == null or object.instance == null:
				continue
			# Need to verify distance again because batched updating means player may have moved since this loop started
			# Outer radius is not checked because anything further away should still be removed
			var distance = object.instance.position.distance_to(world_state.player.position)
			if distance > INNER_RADIUS:
				if object.glb_mesh_no_collider.get_parent() == self:
					remove_child(object.glb_mesh_no_collider)
				if object.instance.get_parent() == self:
					remove_child(object.instance)
		i += batch_size
		await get_tree().process_frame

func remove_all_faraway_children_batched(batch_size: int = 500):
	const INNER_RADIUS = Globals.LOD_DISTANCE_NO_COLLIDER * 1.5
	var all_faraway_objects = world_state.static_objects_qt.query_circle_holed(Vector2(world_state.player.position.x, world_state.player.position.z), INNER_RADIUS, INF)
	var i = 0
	while i < all_faraway_objects.size():
		for j in min(batch_size, all_faraway_objects.size() - i):
			var object: WorldObject = all_faraway_objects[i + j]["data"]
			if object == null or object.instance == null:
				continue
			# Need to verify distance again because batched updating means player may have moved since this loop started
			# Outer radius is not checked because anything further away should still be removed
			var distance = object.instance.position.distance_to(world_state.player.position)
			if distance > INNER_RADIUS:
				if object.glb_mesh_no_collider.get_parent() == self:
					remove_child(object.glb_mesh_no_collider)
				if object.instance.get_parent() == self:
					remove_child(object.instance)
		i += batch_size
		await get_tree().process_frame
