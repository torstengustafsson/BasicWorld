class_name WorldObject

class ForestTree extends WorldObject:
	var health = 3


static var house_scene = preload("res://scenes/house.tscn")
static var chest_scene = preload("res://scenes/chest.tscn")
static var tree_scene = preload("res://scenes/tree.tscn")

var instance: Node3D

func _init(pos: Vector3, rot: Vector3, scale: float, scene: PackedScene):
	instance = scene.instantiate()
	instance.position = pos
	instance.rotation = rot
	instance.scale = Vector3(scale, scale, scale)

static func add_house(pos: Vector3, rot: Vector3) -> WorldObject:
	var scale = 1.0
	return WorldObject.new(pos, rot, scale, house_scene)

static func add_chest(pos: Vector3, rot: Vector3) -> WorldObject:
	var scale = 1.0
	return WorldObject.new(pos, rot, scale, chest_scene)

static func add_tree(pos: Vector3, scale: float) -> WorldObject:
	var rot = Vector3(0.0, 0.0, 0.0)
	return ForestTree.new(pos, rot, scale, tree_scene)
