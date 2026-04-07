extends Node

class_name DistanceController

var static_objects_qt: Quadtree
var player: Node3D # Only used for position
var last_player_pos: Vector3

var update_time = 0
const FORCE_UPDATE_INTERVAL_SECONDS = 1.0

func _init(_player, _static_objects_qt: Quadtree):
	static_objects_qt = _static_objects_qt
	player = _player
	last_player_pos = player.position

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
				add_child(object.glb_mesh_no_collider)
		i += batch_size
		await get_tree().process_frame

func remove_faraway_children_batched(batch_size: int = 500):
	const INNER_RADIUS = Globals.LOD_DISTANCE_NO_COLLIDER
	const OUTER_RADIUS = Globals.LOD_DISTANCE_NO_COLLIDER + Globals.LOD_UPDATE_DISTANCE * 2
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

func _process(_delta: float) -> void:
	if (player.position - last_player_pos).length() > Globals.LOD_UPDATE_DISTANCE:
		update_lods()
		last_player_pos = player.position
	if update_time > FORCE_UPDATE_INTERVAL_SECONDS:
		add_nearby_children_full()
		update_time = 0
	update_time += _delta
