extends Node

class_name BushGenerator

const MAX_ALLOWED_HEIGHT = 50.0

var space_state: PhysicsDirectSpaceState3D

var static_objects_qt: Quadtree
var berrybushes: Array[WorldObject] = []

func _init(qt: Quadtree, _space_state: PhysicsDirectSpaceState3D):
	static_objects_qt = qt
	space_state = _space_state
	add_to_group("Persist")

func create_berrybushes(start_pos_x, start_pos_z, end_pos_x, end_pos_z, step, forest_noise, terrain_height_noise):
	for x in (end_pos_x - start_pos_x) / step:
		for z in (end_pos_z - start_pos_z) / step:
			var rand_value_x = -step / 2 + randf_range(0.0, step)
			var rand_value_z = -step / 2 + randf_range(0.0, step)
			var pos_x = start_pos_x + x * step + rand_value_x
			var pos_z = start_pos_z + z * step + rand_value_z
			var height = min(terrain_height_noise.get_height_at(pos_x, pos_z), MAX_ALLOWED_HEIGHT)
			var position = Vector3(pos_x, height, pos_z)

			# Skip if out-of-bounds
			if position.x < start_pos_x || position.z < start_pos_z || position.x > end_pos_x || position.z > end_pos_z:
				continue

			# Skip if outside of noise function threshold
			if forest_noise.above_threshold(position):
				continue

			# Skip if terrain is too steep
			var terrain_angle = MathFunctions.get_terrain_angle_at_position(position, space_state)
			if terrain_angle > Globals.MAX_OBJECT_STEEPNESS or terrain_angle == INF:
				continue

			# Skip if at too high elevation (use some randomness to reduce chance closer to max)
			var height_value = MathFunctions.taper(height / MAX_ALLOWED_HEIGHT, 0.5)
			if height_value < randf_range(0.0, 0.5):
				continue

			var scale = randf_range(1.0, 1.25)
			add_bush(position, scale)

func add_bush(position: Vector3, scale: float) -> WorldObject.BerryBushObject:
	var berrybush = WorldObject.add_berrybush(position, scale)
	berrybushes.append(berrybush)
	static_objects_qt.insert({"position": Vector2(position.x, position.z), "data": berrybush})
	return berrybush

func _process(delta):
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


# Returns amount of berries gained
func interact(collider) -> int:
	for berrybush in berrybushes:
		if berrybush.instance == collider && berrybush.is_filled:
			berrybush.reset()
			return 1
	return 0

func save() -> Dictionary:
	return {}
	# var result: Dictionary = {}
	# var bush_data: Array = []
	# for berrybush in berrybushes:
	# 	var data: Dictionary = {}
	# 	data["pos_x"] = snapped(berrybush.instance.position.x, 0.01)
	# 	data["pos_y"] = snapped(berrybush.instance.position.y, 0.01)
	# 	data["pos_z"] = snapped(berrybush.instance.position.z, 0.01)
	# 	data["scale"] = snapped(berrybush.instance.scale.x, 0.01) # Uniform scale
	# 	data["is_filled"] = berrybush.is_filled
	# 	bush_data.append(data)
	# result[SaveLoadState.StateType.Bushes] = bush_data
	# return result

func load(data: Dictionary):
	pass
	# for berrybush in berrybushes:
	# 	berrybush.instance.queue_free()
	# berrybushes.clear()

	# for berrybush in data[str(SaveLoadState.StateType.Bushes)]:
	# 	var position = Vector3(berrybush["pos_x"], berrybush["pos_y"], berrybush["pos_z"])
	# 	var scale = berrybush["scale"]
	# 	var bush = add_bush(position, scale)
	# 	if berrybush["is_filled"]:
	# 		bush.fill()
