extends Node

var tree = preload("res://scenes/tree.tscn")

var trees: Dictionary[Vector2, Node] = {}

func create_trees(start_pos_x, start_pos_z, size_x, size_z, step):
	for x in size_x / step:
		for z in size_z / step:
			var rand_value_x = -step / 2 + randf_range(0.0, step) 
			var rand_value_z = -step / 2 + randf_range(0.0, step) 
			var position = Vector3(start_pos_x + x * step + rand_value_x, 0.0, start_pos_z + z * step + rand_value_z)

			# Skip if out-of-bounds
			if position.x < start_pos_x || position.z < start_pos_z || position.x > start_pos_x + size_x || position.z > start_pos_z + size_z:
				continue

			var instance = tree.instantiate()
			instance.position = position

			var rand_scale = randf_range(1.0, 2.0)
			instance.scale = Vector3(rand_scale, rand_scale, rand_scale)
			trees[Vector2(x, z)] = instance


			add_child(instance)
