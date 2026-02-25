extends Node

class_name SettlementGenerator

class SettlementData:
	var position: Vector3
	var radius: float
	var num_houses: int
	func _init(_position, _radius, _num_houses) -> void:
		position = _position
		radius = _radius
		num_houses = _num_houses


var houses: Array[House] = []

func _init():
	add_to_group("Persist")

# Returns x- and y-coordinates of each settlement position as well as its radius as a Vector3
func create_settlements(start_pos_x, start_pos_z, end_pos_x, end_pos_z, step) -> Array[SettlementData]:
	var result: Array[SettlementData] = []
	for x in (end_pos_x - start_pos_x) / step:
		for z in (end_pos_z - start_pos_z) / step:
			var rand_value_x = -step / 3 + randf_range(0.0, step / 3 * 2)
			var rand_value_z = -step / 3 + randf_range(0.0, step / 3 * 2)
			var position = Vector3(start_pos_x + x * step + rand_value_x, 0.0, start_pos_z + z * step + rand_value_z)

			# Skip if out-of-bounds
			if position.x < start_pos_x + 16.0 || position.z < start_pos_z + 16.0 || position.x > end_pos_x - 16.0 || position.z > end_pos_z - 16.0:
				continue

			var settlement_data = add_settlement(position)
			result.append(settlement_data)
	return result

# Returns radius of settlement
func add_settlement(position: Vector3) -> SettlementData:
	const MAX_NUM_HOUSES = 5
	var num_houses = randi_range(2, MAX_NUM_HOUSES)
	var start_rotation: float = randf() * 2 * PI
	var house_spread_angle_multiplier: float = (MAX_NUM_HOUSES * 2 - num_houses)
	var last_angle: float = start_rotation
	var largest_radius: float = 0.0
	for house_angle in num_houses:
		var angle = last_angle + PI / 3 * randf_range(0.2, 0.3) * house_spread_angle_multiplier
		last_angle = angle
		var distance_from_town_center = randf_range(10.0, 16.0) * (MAX_NUM_HOUSES + num_houses) / 10.0
		largest_radius = distance_from_town_center
		var rotated = Basis(Vector3.UP,  angle) * Vector3(1, 0, 0) * distance_from_town_center
		add_house(position + rotated, Vector3(0.0, angle + PI, 0.0))

	var settlement_radius = largest_radius + 5.0
	return SettlementData.new(position, settlement_radius, num_houses)

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
