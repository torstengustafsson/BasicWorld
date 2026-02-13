extends Node

var tree = preload("res://tree.tscn")

var trees: Dictionary[Vector2, Node] = {}

func create_trees(size_x, size_z, step):
	var start_pos_x = size_x / 2 - size_x
	var start_pos_z = size_z / 2 - size_z

	for x in size_x / step:
		for z in size_z / step:
			var instance = tree.instantiate()

			# generate random value between [-step/2, step/2]
			var rand_value_x = -step / 2 + randf_range(0.0, step) 
			var rand_value_z = -step / 2 + randf_range(0.0, step) 
			instance.position = Vector3(start_pos_x + x * step + rand_value_x, 0.0, start_pos_z + z * step + rand_value_z)

			var rand_scale = randf_range(1.0, 2.0)
			instance.scale = Vector3(rand_scale, rand_scale, rand_scale)
			trees[Vector2(x, z)] = instance


			add_child(instance)
