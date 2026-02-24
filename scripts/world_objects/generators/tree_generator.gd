extends Node

class_name TreeGenerator

enum ChopResults { StillStanding, ChoppedDown }

class ChopResult:
	var result: ChopResults
	var position: Vector3

	func _init(_result: ChopResults, _position: Vector3 = Vector3.ZERO):
		result =_result
		position = _position

class ForestTree:
	var tree_scene = preload("res://scenes/tree.tscn")
	var instance: Node3D
	var collider: CollisionShape3D
	var health = 3

	func _init(pos: Vector3, scale: float):
		instance = tree_scene.instantiate()
		instance.position = pos
		instance.scale = Vector3(scale, scale, scale)

var trees: Array[ForestTree] = []
var shaking_tree: Node3D = null
const TREE_SHAKE_SECS = 0.3
var shake_timer = INF # INF means not shaking
var shake_direction: Vector3 = Vector3(0.0, 0.0, 0.0)

func _init():
	add_to_group("Persist")

func create_trees(start_pos_x, start_pos_z, end_pos_x, end_pos_z, step):
	for x in (end_pos_x - start_pos_x) / step:
		for z in (end_pos_z - start_pos_z) / step:
			var rand_value_x = -step / 2 + randf_range(0.0, step)
			var rand_value_z = -step / 2 + randf_range(0.0, step)
			var position = Vector3(start_pos_x + x * step + rand_value_x, 0.0, start_pos_z + z * step + rand_value_z)

			# Skip if out-of-bounds
			if position.x < start_pos_x || position.z < start_pos_z || position.x > end_pos_x || position.z > end_pos_z:
				continue

			var rand_scale = randf_range(1.0, 2.0)
			var tree = ForestTree.new(position, rand_scale)
			trees.append(tree)

			add_child(tree.instance)

func add_tree(position: Vector3, scale: float):
	var tree = ForestTree.new(position, scale)
	trees.append(tree)
	add_child(tree.instance)

func remove_at(index: int):
	trees[index].instance.queue_free()
	trees.remove_at(index)


func handle_chop(collider) -> ChopResult:
	for tree_index in trees.size() - 1:
		var tree = trees[tree_index]
		if tree.instance == collider:
			tree.health -= 1
			if tree.health <= 0:
				remove_at(tree_index)
				return ChopResult.new(ChopResults.ChoppedDown, tree.instance.position + Vector3(0.0, 1.0, 0.0))
			shaking_tree = tree.instance
			shake_timer = 0.0
			return ChopResult.new(ChopResults.StillStanding)
	return ChopResult.new(ChopResults.StillStanding)

func _process(delta):
	if shaking_tree and shake_timer < INF:
		shaking_tree.rotation = Vector3(PI * (sin(shake_timer * 40.0) * 0.05), 0.0, 0.0)
		if shake_timer > TREE_SHAKE_SECS:
			shaking_tree.rotation = Vector3(0.0, 0.0, 0.0)
			shaking_tree = null
			shake_timer = INF
		shake_timer += delta

func save() -> Dictionary:
	var result: Dictionary = {}
	var tree_data: Array = []
	for tree in trees:
		var data: Dictionary = {}
		data["pos_x"] = snapped(tree.instance.position.x, 0.01)
		data["pos_y"] = snapped(tree.instance.position.y, 0.01)
		data["pos_z"] = snapped(tree.instance.position.z, 0.01)
		data["scale"] = snapped(tree.instance.scale.x, 0.01) # Uniform scale
		tree_data.append(data)
	result[SaveLoadState.StateType.Trees] = tree_data
	return result

func load(data: Dictionary):
	for tree in trees:
		tree.instance.queue_free()
	trees.clear()

	for tree in data[str(SaveLoadState.StateType.Trees)]:
		var position = Vector3(tree["pos_x"], tree["pos_y"], tree["pos_z"])
		var scale = tree["scale"]
		add_tree(position, scale)
