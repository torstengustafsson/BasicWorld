extends Node

class_name BushGenerator

const BERRYBUSH_FULL_SECS = 30

class BerryBush extends WorldObject:
	static var berrybush_scene = preload("res://scenes/berrybush.tscn")
	static var berrybush_empty = preload("res://assets/models/berrybush-empty.glb")
	static var berrybush_full = preload("res://assets/models/berrybush-full.glb")
	const BERRYBUSH_NAME = "berrybush"

	var berries_fill_secs: float
	var is_filled: bool = false

	func _init(pos: Vector3, scale: float):
		var rot = Vector3(0.0, 0.0, 0.0)
		super._init(pos, rot, scale, berrybush_scene)
		instance = berrybush_scene.instantiate()
		berries_fill_secs = randf_range(0.0, BERRYBUSH_FULL_SECS)
		instance.position = pos
		instance.scale = Vector3(scale, scale, scale)

	func fill():
		is_filled = true
		var object = instance.get_node(BERRYBUSH_NAME)
		instance.remove_child(object)
		object.queue_free()
		object = berrybush_full.instantiate()
		object.name = BERRYBUSH_NAME
		instance.add_child(object)

	func reset():
		is_filled = false
		berries_fill_secs = 0.0
		var object = instance.get_node(BERRYBUSH_NAME)
		instance.remove_child(object)
		object.queue_free()
		object = berrybush_empty.instantiate()
		object.name = BERRYBUSH_NAME
		instance.add_child(object)

var berrybushes: Array[WorldObject] = []

func _init():
	add_to_group("Persist")

func create_berrybushes(start_pos_x, start_pos_z, end_pos_x, end_pos_z, step, seed) -> Array[WorldObject]:
	# Bushes and trees uses same seed
	var noise_trees = FastNoiseLite.new()
	noise_trees.frequency = 0.1
	noise_trees.fractal_octaves = 3
	noise_trees.fractal_lacunarity = 2.0
	noise_trees.fractal_gain = 0.4
	noise_trees.seed = seed

	for x in (end_pos_x - start_pos_x) / step:
		for z in (end_pos_z - start_pos_z) / step:
			var noise_val = (noise_trees.get_noise_2d(x, z) + 1) / 2.0 * 100.0 # Random noise between 0.0-100.0
			var rand_value_x = -step / 2 + randf_range(0.0, step)
			var rand_value_z = -step / 2 + randf_range(0.0, step)
			var position = Vector3(start_pos_x + x * step + rand_value_x, 0.0, start_pos_z + z * step + rand_value_z)

			# Skip if out-of-bounds
			if position.x < start_pos_x || position.z < start_pos_z || position.x > end_pos_x || position.z > end_pos_z:
				continue

			if randf_range(30.0, 50.0) < noise_val:
				continue

			var scale = randf_range(1.0, 1.25)
			add_bush(position, scale)
	return berrybushes

func add_bush(position: Vector3, scale: float) -> BerryBush:
	var berrybush = BerryBush.new(position, scale)
	berrybushes.append(berrybush)
	add_child(berrybush.instance)
	return berrybush

func _process(delta):
	for berrybush in berrybushes:
		if berrybush.is_filled == true:
			continue
		if berrybush.berries_fill_secs >= BERRYBUSH_FULL_SECS:
			berrybush.fill()
			continue
		berrybush.berries_fill_secs += delta

func remove_at(index: int):
	berrybushes[index].instance.queue_free()
	berrybushes.remove_at(index)

# Returns amount of berries gained
func interact(collider) -> int:
	for berrybush in berrybushes:
		if berrybush.instance == collider && berrybush.is_filled:
			berrybush.reset()
			return 1
	return 0

func save() -> Dictionary:
	var result: Dictionary = {}
	var bush_data: Array = []
	for berrybush in berrybushes:
		var data: Dictionary = {}
		data["pos_x"] = snapped(berrybush.instance.position.x, 0.01)
		data["pos_y"] = snapped(berrybush.instance.position.y, 0.01)
		data["pos_z"] = snapped(berrybush.instance.position.z, 0.01)
		data["scale"] = snapped(berrybush.instance.scale.x, 0.01) # Uniform scale
		data["is_filled"] = berrybush.is_filled
		bush_data.append(data)
	result[SaveLoadState.StateType.Bushes] = bush_data
	return result

func load(data: Dictionary):
	for berrybush in berrybushes:
		berrybush.instance.queue_free()
	berrybushes.clear()

	for berrybush in data[str(SaveLoadState.StateType.Bushes)]:
		var position = Vector3(berrybush["pos_x"], berrybush["pos_y"], berrybush["pos_z"])
		var scale = berrybush["scale"]
		var bush = add_bush(position, scale)
		if berrybush["is_filled"]:
			bush.fill()
