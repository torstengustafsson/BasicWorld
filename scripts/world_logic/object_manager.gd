extends Node

class_name ObjectManager

enum ChopResults { NoHit, StillStanding, ChoppedDown }

class ChopResult:
	var result: ChopResults
	var position: Vector3
	var amount_gained: int

	func _init(_result: ChopResults, _position: Vector3 = Vector3.ZERO, _amount_gained: int = 0):
		result =_result
		position = _position
		amount_gained = _amount_gained

const MAX_ALLOWED_HEIGHT = 100.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var forest_noise: NoiseFunctions
var rocks_noise: NoiseFunctions

var shaking_tree: Node3D = null
const TREE_SHAKE_SECS = 0.3
var shake_timer = INF # INF means not shaking
var shake_direction: Vector3 = Vector3(0.0, 0.0, 0.0)

func _init():
	forest_noise = NoiseFunctions.create_forest_noise(WorldState.state.rng)
	rocks_noise = NoiseFunctions.create_rocks_noise(WorldState.state.rng)

func _add_meshes_from_pool(boundary: Rect2, step: int, noise_function: NoiseFunctions, object_type: WorldObject.ObjectId, get_scale: Callable):
	var start_pos_x = floor(boundary.position.x / step) * step
	var start_pos_z = floor(boundary.position.y / step) * step
	var end_pos_x = ceil((boundary.position.x + boundary.size.x) / step) * step
	var end_pos_z = ceil((boundary.position.y + boundary.size.y) / step) * step
	for x in range(start_pos_x, end_pos_x, step):
		for z in range(start_pos_z, end_pos_z, step):
			rng.seed = hash(Vector2(x, z)) + hash(object_type) # Used to reproduce the same result every time for random values
			var spread = step / floor(2)
			var rand_value_x = rng.randf_range(-spread, spread)
			var rand_value_z = rng.randf_range(-spread, spread)
			var rand_value_max_height = rng.randf_range(0.0, 0.5)
			var pos_x = x + rand_value_x
			var pos_z = z + rand_value_z
			var height = min(WorldState.state.terrain_height_noise.get_height_at(pos_x, pos_z), MAX_ALLOWED_HEIGHT)
			var position = Vector3(pos_x, height, pos_z)

			# Skip if another object of same type is already placed there
			if WorldState.state.pool_manager.get_mesh_at_position(object_type, position):
				continue

			# Skip if outside of noise function threshold
			if noise_function.above_threshold(position):
				continue

			# Skip if terrain is too steep
			var terrain_angle = MathFunctions.get_terrain_angle_at_position(position, WorldState.state.space_state)
			if terrain_angle > Globals.MAX_OBJECT_STEEPNESS or terrain_angle == INF:
				continue

			# Skip if at too high elevation (use some randomness to reduce chance closer to max)
			var height_value = MathFunctions.taper(height / MAX_ALLOWED_HEIGHT, 0.5)
			if height_value < rand_value_max_height:
				continue

			# Skip if road is in the way
			if WorldState.state.road_generator.is_in_road(position):
				continue

			# Skip if would overlap another object
			if WorldState.state.pool_manager.get_meshes_in_range(position, 1.0).size() > 0:
				continue

			# Add object to scene
			WorldState.state.pool_manager.get_mesh(object_type, position, get_scale.call())

func add_world_meshes(boundary: Rect2) -> void:
	_add_meshes_from_pool(boundary, Globals.STEP_TREES, forest_noise, WorldObject.ObjectId.TREE, _get_tree_scale)
	_add_meshes_from_pool(boundary, Globals.STEP_ROCKS, rocks_noise, WorldObject.ObjectId.ROCK, _get_rock_scale)
	_add_meshes_from_pool(boundary, Globals.STEP_BERRYBUSHES, forest_noise, WorldObject.ObjectId.BERRYBUSH_EMPTY, _get_berrybush_scale)

func handle_tree_chop(collider) -> ChopResult:
	var tree = WorldState.state.pool_manager.get_object_at_position(WorldObject.ObjectId.TREE, collider.position)
	if not tree:
		return ChopResult.new(ChopResults.NoHit)
	tree.health -= 1
	if tree.health <= 0:
		WorldState.state.pool_manager.remove_object(tree)
		var amount_gained = floor(tree.max_health / 3)
		return ChopResult.new(ChopResults.ChoppedDown, tree.glb_mesh.position + Vector3(0.0, 1.0, 0.0), amount_gained)
	shaking_tree = tree.glb_mesh
	shake_timer = 0.0
	return ChopResult.new(ChopResults.StillStanding)

func handle_rock_chop(collider) -> ChopResult:
	var rock = WorldState.state.pool_manager.get_object_at_position(WorldObject.ObjectId.ROCK, collider.position)
	if not rock:
		return ChopResult.new(ChopResults.NoHit)
	rock.health -= 1
	if rock.health <= 0:
		WorldState.state.pool_manager.remove_object(rock)
		var amount_gained = floor(rock.max_health / 3)
		return ChopResult.new(ChopResults.ChoppedDown, rock.glb_mesh.position + Vector3(0.0, 1.0, 0.0), amount_gained)
	return ChopResult.new(ChopResults.StillStanding)

# Returns amount of berries gained
func interact(collider) -> int:
	var object = WorldState.state.pool_manager.get_object_at_position(WorldObject.ObjectId.BERRYBUSH_FULL, collider.position)
	if not object:
		object = WorldState.state.pool_manager.get_object_at_position(WorldObject.ObjectId.BERRYBUSH_EMPTY, collider.position)
	if object and object.berrybush and object.berrybush.is_filled:
		object.berrybush.reset()
		return 1
	return 0

func _process(delta):
	# Handle trees
	if shaking_tree and shake_timer < INF:
		shaking_tree.rotation = Vector3(PI * (sin(shake_timer * 40.0) * 0.05), 0.0, 0.0)
		if shake_timer > TREE_SHAKE_SECS:
			shaking_tree.rotation = Vector3(0.0, 0.0, 0.0)
			shaking_tree = null
			shake_timer = INF
		shake_timer += delta

	# Handle berrybushes
	var objects: Array = WorldState.state.pool_manager.get_active_objects_of_type(WorldObject.ObjectId.BERRYBUSH_EMPTY) + WorldState.state.pool_manager.get_active_objects_of_type(WorldObject.ObjectId.BERRYBUSH_FULL)
	for object in objects:
		if object.berrybush:
			object.berrybush.update(delta)

func _get_tree_scale() -> Vector3:
	var scale = rng.randf_range(1.5, 4.0)
	return Vector3(scale, scale, scale)

func _get_rock_scale() -> Vector3:
	return Vector3(rng.randf_range(1.0, 4.0), rng.randf_range(1.2, 6.0), rng.randf_range(1.0, 4.0))

func _get_berrybush_scale() -> Vector3:
	var scale = rng.randf_range(1.0, 1.25)
	return Vector3(scale, scale, scale)
