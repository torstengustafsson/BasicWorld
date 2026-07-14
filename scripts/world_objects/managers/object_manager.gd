class_name ObjectManager extends Node

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

var forest_noise: NoiseFunctions
var rocks_noise: NoiseFunctions

var shaking_tree: WorldObject = null
const TREE_SHAKE_SECS = 0.3
var shake_timer: float = INF # INF means not shaking
var shake_direction: Vector3 = Vector3(0.0, 0.0, 0.0)

func _init(_rng: RandomNumberGenerator):
	forest_noise = NoiseFunctions.create_forest_noise(_rng)
	rocks_noise = NoiseFunctions.create_rocks_noise(_rng)

func _add_meshes_from_pool(multimesh_chunk: MultiMeshChunk, step: int, noise_function: NoiseFunctions, object_id: WorldObject.ObjectId):
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var boundary = multimesh_chunk.chunk_boundary

	var start_pos_x: int = int(floor(boundary.position.x / step)) * step
	var start_pos_z: int = int(floor(boundary.position.y / step)) * step
	var end_pos_x: int = int(ceil((boundary.position.x + boundary.size.x) / step)) * step
	var end_pos_z: int = int(ceil((boundary.position.y + boundary.size.y) / step)) * step

	var spread = step / floor(2)
	for x in range(start_pos_x, end_pos_x, step):
		for z in range(start_pos_z, end_pos_z, step):
			# Adjust x and z by the boundary's position to ensure uniqueness. Otherwise adjacent
			# multimesh chunk boundaries will get the same values at the edges, leading to duplicates.
			var unique_x: int = x + int(boundary.position.x) % step
			var unique_z: int = z + int(boundary.position.y) % step

			var position_index := Vector2i(unique_x, unique_z)
			rng.seed = hash(position_index) + hash(object_id) # Used to reproduce the same result every time for random values
			var rand_value_x = rng.randf_range(-spread, spread)
			var rand_value_z = rng.randf_range(-spread, spread)
			var rand_value_max_height = rng.randf_range(0.0, 0.5)
			var pos_x = unique_x + rand_value_x
			var pos_z = unique_z + rand_value_z
			var height = min(WorldState.state.terrain_height_noise.get_height_at(pos_x, pos_z), MAX_ALLOWED_HEIGHT)
			var position = Vector3(pos_x, height, pos_z)

			# Skip if outside of noise function threshold
			if noise_function.above_threshold(position):
				continue

			# Skip if terrain is too steep
			var terrain_angle = TerrainManager.get_terrain_angle_at_position(position)
			if terrain_angle > Globals.MAX_OBJECT_STEEPNESS:
				continue

			# Skip if at too high elevation (use some randomness to reduce chance closer to max)
			var height_value = MathFunctions.taper(height / MAX_ALLOWED_HEIGHT, 0.5)
			if height_value < rand_value_max_height:
				continue

			# # Skip if road is in the way
			if WorldState.state.road_manager.is_in_road(position):
				continue

			# Skip if inside a settlement
			if WorldState.state.settlement_manager.is_inside_settlement(position, object_id):
				continue

			# Add object to scene
			# TODO: Due to object random spread, objects may sometimes be placed right outside of its multimesh
			# chunk boundary, which will lead to these objects not being properly indexed at boundary checks.
			var object = WorldObject.create_object(object_id, position)
			multimesh_chunk.place(object)

func add_world_objects(multimesh_chunk: MultiMeshChunk, object_id: WorldObject.ObjectId) -> void:
	match object_id:
		WorldObject.ObjectId.TREE:
			_add_meshes_from_pool(multimesh_chunk, Globals.STEP_TREES, forest_noise, WorldObject.ObjectId.TREE)
		WorldObject.ObjectId.ROCK:
			_add_meshes_from_pool(multimesh_chunk, Globals.STEP_ROCKS, rocks_noise, WorldObject.ObjectId.ROCK)
		WorldObject.ObjectId.BERRYBUSH:
			_add_meshes_from_pool(multimesh_chunk, Globals.STEP_BERRYBUSHES, forest_noise, WorldObject.ObjectId.BERRYBUSH)

func handle_tree_chop(collision_position: Vector3) -> ChopResult:
	var tree = WorldState.state.multimesh_manager.get_object_at_position(WorldObject.ObjectId.TREE, collision_position)
	if not tree:
		return ChopResult.new(ChopResults.NoHit)
	tree.health -= 1
	if tree.health <= 0:
		WorldState.state.multimesh_manager.delete_object(tree)
		var amount_gained = floor(tree.max_health / 3)
		return ChopResult.new(ChopResults.ChoppedDown, tree.position + Vector3(0.0, 1.0, 0.0), amount_gained)
	shaking_tree = tree
	shake_timer = 0.0
	return ChopResult.new(ChopResults.StillStanding)

func handle_rock_chop(collision_position: Vector3) -> ChopResult:
	var rock = WorldState.state.multimesh_manager.get_object_at_position(WorldObject.ObjectId.ROCK, collision_position)
	if not rock:
		return ChopResult.new(ChopResults.NoHit)
	rock.health -= 1
	if rock.health <= 0:
		WorldState.state.multimesh_manager.delete_object(rock)
		var amount_gained = floor(rock.max_health / 3)
		return ChopResult.new(ChopResults.ChoppedDown, rock.position + Vector3(0.0, 1.0, 0.0), amount_gained)
	return ChopResult.new(ChopResults.StillStanding)

# Returns amount of berries gained
func interact(collision_position: Vector3) -> int:
	var object = WorldState.state.multimesh_manager.get_object_at_position(WorldObject.ObjectId.BERRYBUSH_FULL, collision_position)
	if not object:
		object = WorldState.state.multimesh_manager.get_object_at_position(WorldObject.ObjectId.BERRYBUSH, collision_position)
	if object and object.berrybush and object.berrybush.is_filled:
		object.berrybush.reset()
		return 1
	return 0

func _process(delta):
	# Handle trees
	if shaking_tree and shake_timer < INF:
		shaking_tree.set_instance_rotation(Vector3(PI * (sin(shake_timer * 40.0) * 0.05), 0.0, 0.0))
		if shake_timer > TREE_SHAKE_SECS:
			shaking_tree.rotation = Vector3(0.0, 0.0, 0.0)
			shaking_tree = null
			shake_timer = INF
		shake_timer += delta

	# Handle berrybushes
	const INNER_BOUNDS = Globals.LOD_DISTANCE_FULL
	var player_position = WorldState.state.player.position
	var boundary: Rect2 = Rect2(
		Vector2(player_position.x - INNER_BOUNDS, player_position.z - INNER_BOUNDS),
		Vector2(INNER_BOUNDS * 2, INNER_BOUNDS * 2)
	)
	var objects: Array = \
		WorldState.state.multimesh_manager.get_objects_of_type_in_boundary(WorldObject.ObjectId.BERRYBUSH, boundary) + \
		WorldState.state.multimesh_manager.get_objects_of_type_in_boundary(WorldObject.ObjectId.BERRYBUSH_FULL, boundary)
	for object in objects:
		if object.berrybush:
			object.berrybush.update(delta)

func destroy():
	forest_noise = null
	rocks_noise = null
