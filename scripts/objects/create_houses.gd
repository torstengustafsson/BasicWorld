extends Node

class_name Houses

var houses: Array[House] = []

func _init():
	add_to_group("Persist")

func create_settlements(start_pos_x, start_pos_z, end_pos_x, end_pos_z, step):
	for x in (end_pos_x - start_pos_x) / step:
		for z in (end_pos_z - start_pos_z) / step:
			var rand_value_x = -step / 3 + randf_range(0.0, step / 3 * 2)
			var rand_value_z = -step / 3 + randf_range(0.0, step / 3 * 2)
			var position = Vector3(start_pos_x + x * step + rand_value_x, 0.0, start_pos_z + z * step + rand_value_z)

			# Skip if out-of-bounds
			if position.x < start_pos_x + 16.0 || position.z < start_pos_z + 16.0 || position.x > end_pos_x - 16.0 || position.z > end_pos_z - 16.0:
				continue

			add_settlement(position)

func add_settlement(position: Vector3):
	const MAX_NUM_HOUSES = 5
	var num_houses = randi_range(2, MAX_NUM_HOUSES)
	var start_rotation = randf() * 2 * PI
	var house_spread_angle_multiplier = (MAX_NUM_HOUSES * 2 - num_houses)
	var last_angle = start_rotation
	for house_angle in num_houses:
		var angle = last_angle + PI / 3 * randf_range(0.2, 0.3) * house_spread_angle_multiplier
		last_angle = angle
		var distance_from_town_center = randf_range(10.0, 16.0) * (MAX_NUM_HOUSES + num_houses) / 10.0
		var rotated = Basis(Vector3.UP,  angle) * Vector3(1, 0, 0) * distance_from_town_center
		var house = add_house(position + rotated, Vector3(0.0, angle + PI, 0.0))

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
