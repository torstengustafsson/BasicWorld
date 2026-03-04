extends Node

class_name RockGenerator

enum ChopResults { StillStanding, ChoppedDown }

class ChopResult:
	var result: ChopResults
	var position: Vector3
	var amount_gained: int

	func _init(_result: ChopResults, _position: Vector3 = Vector3.ZERO, _amount_gained: int = 0):
		result =_result
		position = _position
		amount_gained = _amount_gained

var rocks: Array[WorldObject] = []
var static_objects_qt: Quadtree

func _init(qt: Quadtree):
	static_objects_qt = qt
	add_to_group("Persist")

func create_rocks(start_pos_x, start_pos_z, end_pos_x, end_pos_z, step, rocks_noise) -> Array[WorldObject]:
	for x in (end_pos_x - start_pos_x) / step:
		for z in (end_pos_z - start_pos_z) / step:
			var rand_value_x = -step / 2 + randf_range(0.0, step)
			var rand_value_z = -step / 2 + randf_range(0.0, step)
			var position = Vector3(start_pos_x + x * step + rand_value_x, 0.0, start_pos_z + z * step + rand_value_z)

			# Skip if out-of-bounds
			if position.x < start_pos_x || position.z < start_pos_z || position.x > end_pos_x || position.z > end_pos_z:
				continue

			if rocks_noise.above_threshold(position):
				continue

			var rand_scale = Vector3(randf_range(1.0, 3.0), randf_range(1.2, 4.0), randf_range(1.0, 3.0))
			add_rock(position, rand_scale)
	return rocks

func add_rock(position: Vector3, scale: Vector3):
	var rock = WorldObject.add_rock(position, scale)
	rocks.append(rock)
	static_objects_qt.insert({"position": Vector2(position.x, position.z), "data": rock})
	add_child(rock.instance)

func remove_at(index: int):
	rocks[index].instance.queue_free()
	rocks.remove_at(index)
	static_objects_qt.remove({"position": Vector2(rocks[index].instance.position.x, rocks[index].instance.position.z), "data": rocks[index]})


func handle_chop(collider) -> ChopResult:
	for rock_index in rocks.size() - 1:
		var rock = rocks[rock_index]
		if rock.instance == collider:
			rock.health -= 1
			if rock.health <= 0:
				remove_at(rock_index)
				var amount_gained = floor(rock.max_health / 3)
				return ChopResult.new(ChopResults.ChoppedDown, rock.instance.position + Vector3(0.0, 1.0, 0.0), amount_gained)
			return ChopResult.new(ChopResults.StillStanding)
	return ChopResult.new(ChopResults.StillStanding)

func save() -> Dictionary:
	var result: Dictionary = {}
	var rock_data: Array = []
	for rock in rocks:
		var data: Dictionary = {}
		data["pos_x"] = snapped(rock.instance.position.x, 0.01)
		data["pos_y"] = snapped(rock.instance.position.y, 0.01)
		data["pos_z"] = snapped(rock.instance.position.z, 0.01)
		data["scale_x"] = snapped(rock.instance.scale.x, 0.01)
		data["scale_y"] = snapped(rock.instance.scale.y, 0.01)
		data["scale_z"] = snapped(rock.instance.scale.z, 0.01)
		rock_data.append(data)
	result[SaveLoadState.StateType.Rocks] = rock_data
	return result

func load(data: Dictionary):
	for rock in rocks:
		rock.instance.queue_free()
	rocks.clear()

	for rock in data[str(SaveLoadState.StateType.Rocks)]:
		var position = Vector3(rock["pos_x"], rock["pos_y"], rock["pos_z"])
		var scale = Vector3(rock["scale_x"], rock["scale_y"], rock["scale_z"])
		add_rock(position, scale)
