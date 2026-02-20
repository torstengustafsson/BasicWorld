extends Node

class_name Trees


class ForestTree:
	var tree_scene = preload("res://scenes/tree.tscn")
	var instance: Node3D
	var collider: CollisionShape3D
	var health = 3

	func _init(pos: Vector3, scale: float):
		instance = tree_scene.instantiate()
		instance.position = pos
		instance.scale = Vector3(scale, scale, scale)

var trees: Dictionary[Vector2, ForestTree] = {}
var shaking_tree: Node3D = null
const TREE_SHAKE_SECS = 0.3
var shake_timer = INF # INF means not shaking
var shake_direction: Vector3 = Vector3(0.0, 0.0, 0.0)

var world_items: WorldItems

func _init(_world_items: WorldItems):
	world_items = _world_items

func create_trees(start_pos_x, start_pos_z, size_x, size_z, step):
	for x in size_x / step:
		for z in size_z / step:
			var rand_value_x = -step / 2 + randf_range(0.0, step) 
			var rand_value_z = -step / 2 + randf_range(0.0, step) 
			var position = Vector3(start_pos_x + x * step + rand_value_x, 0.0, start_pos_z + z * step + rand_value_z)

			# Skip if out-of-bounds
			if position.x < start_pos_x || position.z < start_pos_z || position.x > start_pos_x + size_x || position.z > start_pos_z + size_z:
				continue

			var rand_scale = randf_range(1.0, 2.0)
			var tree = ForestTree.new(position, rand_scale)
			trees[Vector2(x, z)] = tree

			add_child(tree.instance)

func handle_chop(collider, direction: Vector3):
	for tree_index in trees:
		var tree = trees[tree_index]
		if tree.instance == collider:
			tree.health -= 1
			if tree.health <= 0:
				world_items.spawn_item(tree.instance.position + Vector3(0.0, 1.0, 0.0), ItemProperties.WOOD_ITEM)
				tree.instance.queue_free()
				trees.erase(tree_index)
				return
			shaking_tree = tree.instance
			shake_timer = 0.0
			shake_direction = direction
			return

func _process(delta):
	if shaking_tree and shake_timer < INF:
		shaking_tree.rotation = Vector3(PI * (sin(shake_timer * 40.0) * 0.05), 0.0, 0.0)
		if shake_timer > TREE_SHAKE_SECS:
			shaking_tree.rotation = Vector3(0.0, 0.0, 0.0)
			shaking_tree = null
			shake_timer = INF
		shake_timer += delta
