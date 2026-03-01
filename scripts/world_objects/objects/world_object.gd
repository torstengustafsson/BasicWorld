class_name WorldObject

class BreakableObject extends WorldObject:
	var max_health: int = 1
	var health: int = 1


static var house_scene = preload("res://scenes/house.tscn")
static var chest_scene = preload("res://scenes/chest.tscn")
static var tree_scene = preload("res://scenes/tree.tscn")
static var rock_scene = preload("res://scenes/rock.tscn")

var instance: Node3D

func _init(pos: Vector3, rot: Vector3, scale: Vector3, scene: PackedScene):
	instance = scene.instantiate()
	instance.position = pos
	instance.rotation = rot
	instance.scale = scale

static func add_house(pos: Vector3, rot: Vector3) -> WorldObject:
	var scale = Vector3(1.0, 1.0, 1.0)
	return WorldObject.new(pos, rot, scale, house_scene)

static func add_chest(pos: Vector3, rot: Vector3) -> WorldObject:
	var scale = Vector3(1.0, 1.0, 1.0)
	return WorldObject.new(pos, rot, scale, chest_scene)

static func add_tree(pos: Vector3, scale: float) -> WorldObject:
	var rot = Vector3(0.0, 0.0, 0.0)
	var tree = BreakableObject.new(pos, rot, Vector3(scale, scale, scale), tree_scene)
	tree.max_health = round(scale * 2.0)
	tree.health = tree.max_health
	return tree

static func add_rock(pos: Vector3, scale: Vector3) -> WorldObject:
	var rot = Vector3(0.0, randf_range(0.0, 2 * PI), 0.0)
	var rock = BreakableObject.new(pos, rot, scale, rock_scene)
	rock.max_health = round(scale.x + scale.y + scale.z)
	rock.health = rock.max_health
	return rock
