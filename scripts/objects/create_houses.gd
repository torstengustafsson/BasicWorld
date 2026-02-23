extends Node

class_name Houses

var houses: Array[House] = []

func _init():
	add_to_group("Persist")

func create_houses(start_pos_x, start_pos_z, end_pos_x, end_pos_z, step):
	for x in (end_pos_x - start_pos_x) / step:
		for z in (end_pos_z - start_pos_z) / step:
			var rand_value_x = -step / 2 + randf_range(0.0, step) 
			var rand_value_z = -step / 2 + randf_range(0.0, step) 
			var position = Vector3(start_pos_x + x * step + rand_value_x, 0.0, start_pos_z + z * step + rand_value_z)
			var rotation = Vector3(0.0, randf() * 2 * PI, 0.0)

			# Skip if out-of-bounds
			if position.x < start_pos_x || position.z < start_pos_z || position.x > end_pos_x || position.z > end_pos_z:
				continue

			add_house(position, rotation)

func add_house(position: Vector3, rotation: Vector3) -> House:
	var house = House.new(position, rotation)
	houses.append(house)
	add_child(house.instance)
	return house


func save() -> Dictionary:
	#TODO
	return {}

func load(data: Dictionary):
	#TODO
	pass
