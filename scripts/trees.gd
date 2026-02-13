extends Node

var tree = preload("res://tree.tscn")

var trees: Dictionary[Vector2, Node] = {}

func create_trees(size_x, size_z, margin, step):
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

			var instance = tree.instantiate()
			instance.position = position

			var rand_scale = randf_range(1.0, 2.0)
			instance.scale = Vector3(rand_scale, rand_scale, rand_scale)
			trees[Vector2(x, z)] = instance


			add_child(instance)
