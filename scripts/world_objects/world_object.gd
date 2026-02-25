extends Node3D

class_name WorldObject

static var house_scene = preload("res://scenes/house.tscn")
static var chest_scene = preload("res://scenes/chest.tscn")

var instance: Node3D

func _init(pos: Vector3, rot: Vector3, scene: PackedScene):
	instance = scene.instantiate()
	instance.position = pos
	instance.rotation = rot

static func add_house(pos: Vector3, rot: Vector3) -> WorldObject:
	return WorldObject.new(pos, rot, house_scene)

static func add_chest(pos: Vector3, rot: Vector3) -> WorldObject:
	return WorldObject.new(pos, rot, chest_scene)
