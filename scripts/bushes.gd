extends Node


const BERRYBUSH_FULL_SECS = 30

class BerryBush:
	static var berrybush_scene = preload("res://berrybush.tscn")
	static var berrybush_empty = preload("res://assets/models/berrybush-empty.glb")
	static var berrybush_full = preload("res://assets/models/berrybush-full.glb")
	const BERRYBUSH_NAME = "berrybush"

	var instance: Node3D
	var collider: CollisionShape3D
	var berries_fill_secs: float
	var is_filled: bool = false

	func _init(pos: Vector3, scale: float):
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

var berrybushes: Dictionary[Vector2, BerryBush] = {}

func create_berrybushes(size_x, size_z, margin, step):
	var start_pos_x = size_x / 2 - size_x + margin
	var start_pos_z = size_z / 2 - size_z + margin

	for x in (size_x - 2 * margin) / step:
		for z in (size_z - 2 * margin) / step:
			var rand_value_x = -step / 2 + randf_range(0.0, step) 
			var rand_value_z = -step / 2 + randf_range(0.0, step) 
			var position = Vector3(start_pos_x + x * step + rand_value_x, 0.0, start_pos_z + z * step + rand_value_z)

			# Skip if out-of-bounds
			if position.x < - size_x / 2 + margin || position.z < -size_z / 2 + margin || position.x > size_x / 2 - margin || position.z > size_z / 2 - margin:
				continue

			var scale = randf_range(1.0, 1.25)
			var berrybush = BerryBush.new(position, scale)

			berrybushes[Vector2(x, z)] = berrybush

			add_child(berrybush.instance)

func _process(delta):
	for berrybush_index in berrybushes:
		var berrybush = berrybushes[berrybush_index]
		if berrybush.is_filled == true:
			continue
		if berrybush.berries_fill_secs >= BERRYBUSH_FULL_SECS:
			berrybush.fill()
			continue
		berrybush.berries_fill_secs += delta

func interact(collider):
	for berrybush_index in berrybushes:
		var berrybush = berrybushes[berrybush_index]
		if berrybush.instance == collider && berrybush.is_filled:
			berrybush.reset()
