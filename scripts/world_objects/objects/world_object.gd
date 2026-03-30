class_name WorldObject

enum ObjectId {
	HOUSE,
	CHEST,
	TREE,
	ROCK,
	HUMAN,
	BERRYBUSH
}

class BreakableObject extends WorldObject:
	var max_health: int = 1
	var health: int = 1


static var house_scene = preload("res://scenes/house.tscn")
static var chest_scene = preload("res://scenes/chest.tscn")
static var tree_scene = preload("res://scenes/tree.tscn")
static var rock_scene = preload("res://scenes/rock.tscn")
static var human_scene = preload("res://scenes/human.tscn")

var instance: Node3D
var id: ObjectId
var in_scene = false
var collider_enabled = false

func _init(pos: Vector3, rot: Vector3, scale: Vector3, scene: PackedScene, _id: ObjectId):
	id = _id
	instance = scene.instantiate()
	instance.position = pos
	instance.rotation = rot
	if scale.x == scale.y and scale.y == scale.z:
		instance.scale = scale
	else:
		# Jolt physics engine does not allow non-uniform scale of colliders.
		# So we only scale the model, and the collider get a uniform average of the scale values.
		var max_val = max(scale.x, scale.x, scale.x)
		var min_val = min(scale.x, scale.x, scale.x)
		var scale_val = min_val + max_val - min_val / 2.0
		var averaged_scale = Vector3(scale_val, scale_val, scale_val) * 0.8
		for collider in find_colliders(instance):
			collider.scale = averaged_scale
		for mesh in find_meshes(instance):
			mesh.scale = scale

static func add_house(pos: Vector3, rot: Vector3) -> WorldObject:
	var scale = Vector3(1.0, 1.0, 1.0)
	return WorldObject.new(pos, rot, scale, house_scene, ObjectId.HOUSE)

static func add_chest(pos: Vector3, rot: Vector3) -> WorldObject:
	var scale = Vector3(1.0, 1.0, 1.0)
	return WorldObject.new(pos, rot, scale, chest_scene, ObjectId.CHEST)

static func add_tree(pos: Vector3, scale: float) -> WorldObject:
	var rot = Vector3(0.0, 0.0, 0.0)
	var tree = BreakableObject.new(pos, rot, Vector3(scale, scale, scale), tree_scene, ObjectId.TREE)
	tree.max_health = round(scale * 2.0)
	tree.health = tree.max_health
	return tree

static func add_rock(pos: Vector3, scale: Vector3) -> WorldObject:
	var rot = Vector3(0.0, randf_range(0.0, 2 * PI), 0.0)
	var rock = BreakableObject.new(pos, rot, scale, rock_scene, ObjectId.ROCK)
	rock.max_health = round(scale.x + scale.y + scale.z)
	rock.health = rock.max_health
	return rock

func enable_colliders():
	collider_enabled = true
	_update_colliders(instance, true)

func disable_colliders():
	collider_enabled = false
	_update_colliders(instance, false)

func _update_colliders(parent_node: Node3D, colliders_enabled: bool):
	var colliders = find_colliders(parent_node)
	for collider in colliders:
		collider.disabled = !colliders_enabled

func find_colliders(parent_node: Node) -> Array:
	var colliders = []
	for child in parent_node.get_children():
		if child is CollisionShape3D or child is CollisionPolygon3D:
			colliders.append(child)
		# Recursively check children of children
		colliders += find_colliders(child)
	return colliders

func find_meshes(parent_node: Node) -> Array:
	var meshes = []
	for child in parent_node.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
		# Recursively check children of children
		meshes += find_meshes(child)
	return meshes
