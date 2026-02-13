extends Node

var berrybush_full = preload("res://assets/models/berrybush-full.glb")
var berrybush_empty = preload("res://assets/models/berrybush-empty.glb")

const BERRYBUSH_FULL_SECS = 30

class BerryBush:
	static var berrybush_scene = preload("res://berrybush.tscn")

	var instance: Node3D
	var collider: CollisionShape3D
	var berries_fill_secs: float
	var is_filled: bool = false

	func _init(pos: Vector3, scale: float):
		instance = berrybush_scene.instantiate()
		berries_fill_secs = randf_range(0.0, BERRYBUSH_FULL_SECS)
		instance.position = pos
		instance.scale = Vector3(scale, scale, scale)

var berrybushes: Dictionary[Vector2, BerryBush] = {}

func create_berrybushes(size_x, size_z, step):
	var start_pos_x = size_x / 2 - size_x
	var start_pos_z = size_z / 2 - size_z

	for x in size_x / step:
		for z in size_z / step:
			# generate random value between [-step/2, step/2], in x and z direction, for psudo-random placement
			var rand_value_x = -step / 2 + randf_range(0.0, step) 
			var rand_value_z = -step / 2 + randf_range(0.0, step) 
			var position = Vector3(start_pos_x + x * step + rand_value_x, 0.0, start_pos_z + z * step + rand_value_z)
			var scale = randf_range(1.0, 1.25)
			var berrybush = BerryBush.new(position, scale)

			berrybushes[Vector2(x, z)] = berrybush

			add_child(berrybush.instance)

var filled = 0

func _process(delta):
	for berrybush_index in berrybushes:
		var berrybush = berrybushes[berrybush_index]
		if berrybush.is_filled == true:
			continue
		if berrybush.berries_fill_secs >= BERRYBUSH_FULL_SECS:
			berrybush.is_filled = true
			var object = berrybush.instance.get_node("berrybush")
			berrybush.instance.remove_child(object)
			object = berrybush_full.instantiate()
			berrybush.instance.add_child(object)
			filled += 1
			continue
		berrybush.berries_fill_secs += delta
