extends Node

class_name ObjectGenerator

enum ChopResults { StillStanding, ChoppedDown }

class ChopResult:
	var result: ChopResults
	var position: Vector3
	var amount_gained: int

	func _init(_result: ChopResults, _position: Vector3 = Vector3.ZERO, _amount_gained: int = 0):
		result =_result
		position = _position
		amount_gained = _amount_gained

const MAX_ALLOWED_HEIGHT = 100.0

var world_state: WorldState

var added_boundaries: Dictionary[Rect2, bool] = {}

var forest_noise: NoiseFunctions
var rocks_noise: NoiseFunctions

var rocks: Array[WorldObject] = []
var berrybushes: Array[WorldObject] = []
var trees: Array[WorldObject] = []

var shaking_tree: Node3D = null
const TREE_SHAKE_SECS = 0.3
var shake_timer = INF # INF means not shaking
var shake_direction: Vector3 = Vector3(0.0, 0.0, 0.0)


func _init(_world_state: WorldState):
	world_state = _world_state
	forest_noise = NoiseFunctions.create_forest_noise(world_state.rng)
	rocks_noise = NoiseFunctions.create_rocks_noise(world_state.rng)

func reset_noise_seeds():
	for noise in forest_noise.noises:
		noise.noise.seed = noise.random_seed
	for noise in rocks_noise.noises:
		noise.noise.seed = noise.random_seed

func _create_objects(boundary: Rect2, step: int, noise_function: NoiseFunctions, add_callback: Callable):
	for x in boundary.size.x / step:
		for z in boundary.size.y / step:
			@warning_ignore("integer_division")
			var rand_value_x = -step / 2 + world_state.rng.randf_range(0.0, step)
			@warning_ignore("integer_division")
			var rand_value_z = -step / 2 + world_state.rng.randf_range(0.0, step)
			var rand_value_height = world_state.rng.randf_range(0.0, 0.5)
			var pos_x = boundary.position.x + x * step + rand_value_x
			var pos_z = boundary.position.y + z * step + rand_value_z
			var height = min(world_state.terrain_height_noise.get_height_at(pos_x, pos_z), MAX_ALLOWED_HEIGHT)
			var position = Vector3(pos_x, height, pos_z)

			# Skip if out-of-bounds
			if not boundary.has_point(Vector2(pos_x, pos_z)):
				continue

			# Skip if outside of noise function threshold
			if noise_function.above_threshold(position):
				continue

			# Skip if terrain is too steep
			var terrain_angle = MathFunctions.get_terrain_angle_at_position(position, world_state.space_state)
			if terrain_angle > Globals.MAX_OBJECT_STEEPNESS or terrain_angle == INF:
				continue

			# Skip if at too high elevation (use some randomness to reduce chance closer to max)
			var height_value = MathFunctions.taper(height / MAX_ALLOWED_HEIGHT, 0.5)
			if height_value < rand_value_height:
				continue

			add_callback.call(position)

func _add_rock(position: Vector3):
	var rock = WorldObject.add_rock(position, world_state.static_objects_qt)
	rocks.append(rock)

func _add_bush(position: Vector3) -> WorldObject.BerryBushObject:
	var berrybush = WorldObject.add_berrybush(position, world_state.static_objects_qt)
	berrybushes.append(berrybush)
	return berrybush

func _add_tree(position: Vector3):
	var tree = WorldObject.add_tree(position, world_state.static_objects_qt)
	trees.append(tree)

func _remove_object(object: WorldObject, objects: Array):
	world_state.static_objects_qt.remove({"position": Vector2(object.instance.position.x, object.instance.position.z), "data": object})
	object.instance.queue_free()
	objects.erase(object)

func _handle_chop(collider, objects) -> WorldObject:
	for index in objects.size() - 1:
		var object = objects[index]
		if object.instance == collider:
			object.health -= 1
			return object
	return null

func _create_trees(boundary: Rect2):
	var step = Globals.STEP_TREES
	_create_objects(boundary, step, forest_noise, _add_tree)

func _create_berrybushes(boundary: Rect2):
	var step = Globals.STEP_BERRYBUSHES
	_create_objects(boundary, step, forest_noise, _add_bush)

func _create_rocks(boundary: Rect2):
	var step = Globals.STEP_ROCKS
	_create_objects(boundary, step, rocks_noise, _add_rock)

func create_world_objects(boundary: Rect2):
	if added_boundaries.has(boundary):
		return
	added_boundaries[boundary] = true
	_create_rocks(boundary)
	_create_berrybushes(boundary)
	_create_trees(boundary)

func handle_tree_chop(collider) -> ChopResult:
	var tree = _handle_chop(collider, trees)
	if not tree:
		return ChopResult.new(ChopResults.StillStanding)
	if tree.health <= 0:
		_remove_object(tree, trees)
		var amount_gained = 1
		return ChopResult.new(ChopResults.ChoppedDown, tree.instance.position + Vector3(0.0, 1.0, 0.0), amount_gained)
	shaking_tree = tree.instance
	shake_timer = 0.0
	return ChopResult.new(ChopResults.StillStanding)


func handle_rock_chop(collider) -> ChopResult:
	var rock = _handle_chop(collider, rocks)
	if not rock:
		return ChopResult.new(ChopResults.StillStanding)
	if rock.health <= 0:
		_remove_object(rock, rocks)
		var amount_gained = floor(rock.max_health / 3)
		return ChopResult.new(ChopResults.ChoppedDown, rock.instance.position + Vector3(0.0, 1.0, 0.0), amount_gained)
	return ChopResult.new(ChopResults.StillStanding)


# Returns amount of berries gained
func interact(collider) -> int:
	for berrybush in berrybushes:
		if berrybush.instance == collider && berrybush.is_filled:
			berrybush.reset()
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
	var to_be_removed: Array[int] = []
	for index in berrybushes.size():
		var berrybush = berrybushes[index]
		if berrybush.instance == null: # Only happens when bush has been removed by the world state
			to_be_removed.append(index)
			continue
		berrybush.update(delta)


	to_be_removed.sort()
	to_be_removed.reverse()
	for index in to_be_removed:
		berrybushes.remove_at(index)
