class_name WorldObject

enum ObjectId {
	HOUSE,
	CHEST,
	TREE,
	ROCK,
	HUMAN,
	BERRYBUSH
}

static var house_mesh = preload("res://assets/models/house.glb")
static var chest_mesh = preload("res://assets/models/chest.glb")
static var tree_mesh = preload("res://assets/models/tree.glb")
static var rock_mesh = preload("res://assets/models/rock.glb")
static var human_mesh = preload("res://assets/models/animated_human.glb")
static var berrybush_empty_mesh = preload("res://assets/models/berrybush-empty.glb")
static var berrybush_full_mesh = preload("res://assets/models/berrybush-full.glb")

static var object_rng = RandomNumberGenerator.new()


var instance: StaticBody3D
var glb_mesh: Node3D # Imported glb scenes are Node3D and not MeshInstance3D
var collider = CollisionShape3D
var glb_mesh_no_collider: Node3D # TODO

var object_id: ObjectId

func _init(pos: Vector3, rot: Vector3, scale: Vector3, glb_mesh_scene: PackedScene, _collider: CollisionShape3D, _id: ObjectId):
	object_id = _id
	instance = StaticBody3D.new()
	glb_mesh = glb_mesh_scene.instantiate()
	collider = _collider
	collider.disabled = true # By default all collisions are disabled. They will be later re-added on distance calculations from player
	instance.add_child(glb_mesh)
	instance.add_child(collider)

	instance.position = pos
	instance.rotation = rot
	glb_mesh.scale = scale
	var uniform_scale: bool = scale.x == scale.y and scale.y == scale.z
	if uniform_scale:
		collider.scale = scale
	else:
		# Jolt physics engine does not allow non-uniform scale of colliders.
		# So the collider instead get a uniform average of the scale values.
		var max_val = max(scale.x, scale.x, scale.x)
		var min_val = min(scale.x, scale.x, scale.x)
		var scale_val = min_val + max_val - min_val / 2.0
		var averaged_scale = Vector3(scale_val, scale_val, scale_val) * 0.8
		collider.scale = averaged_scale

	glb_mesh_no_collider = glb_mesh_scene.instantiate()
	glb_mesh_no_collider.position = pos
	glb_mesh_no_collider.rotation = rot
	glb_mesh_no_collider.scale = scale

func delete():
	instance.queue_free()
	glb_mesh.queue_free()
	collider.queue_free()
	glb_mesh_no_collider.queue_free()

static func object_exists_at_position(position: Vector3, objects: Quadtree, objectId: WorldObject.ObjectId) -> bool:
	var nearby_objects = objects.query_circle(Vector2(position.x, position.z), 0.1)
	for object in nearby_objects:
		if object["data"].object_id == objectId:
			return true
	return false

static func add_house(pos: Vector3, rot: Vector3, objects: Quadtree) -> WorldObject:
	if object_exists_at_position(pos, objects, WorldObject.ObjectId.HOUSE):
		return
	var scale = Vector3(1.0, 1.0, 1.0)
	var col = CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = Vector3(4.5, 3.6, 6.0)
	var house = WorldObject.new(pos, rot, scale, house_mesh, col, ObjectId.HOUSE)
	objects.insert({"position": Vector2(pos.x, pos.z), "data": house})
	return house

static func add_chest(pos: Vector3, rot: Vector3, objects: Quadtree) -> WorldObject:
	if object_exists_at_position(pos, objects, WorldObject.ObjectId.CHEST):
		return
	var scale = Vector3(1.0, 1.0, 1.0)
	var col = CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = Vector3(1.0, 1.0, 1.55)
	var chest = WorldObject.new(pos, rot, scale, chest_mesh, col, ObjectId.CHEST)
	objects.insert({"position": Vector2(pos.x, pos.z), "data": chest})
	return chest

static func add_tree(pos: Vector3, objects: Quadtree) -> WorldObject:
	if object_exists_at_position(pos, objects, WorldObject.ObjectId.TREE):
		return
	object_rng.seed = hash(pos)
	var scale = object_rng.randf_range(1.0, 2.0)
	var rot = Vector3(0.0, 0.0, 0.0)
	var col = CollisionShape3D.new()
	col.shape = CylinderShape3D.new()
	col.shape.height = 2.0
	col.shape.radius = 0.5
	var tree = BreakableObject.new(pos, rot, Vector3(scale, scale, scale), tree_mesh, col, ObjectId.TREE)
	tree.max_health = round(scale * 2.0)
	tree.health = tree.max_health
	objects.insert({"position": Vector2(pos.x, pos.z), "data": tree})
	return tree

static func add_rock(pos: Vector3, objects: Quadtree) -> WorldObject:
	if object_exists_at_position(pos, objects, WorldObject.ObjectId.ROCK):
		return
	object_rng.seed = hash(pos)
	var scale = Vector3(object_rng.randf_range(1.0, 3.0), object_rng.randf_range(1.2, 4.0), object_rng.randf_range(1.0, 3.0))
	var rot = Vector3(0.0, object_rng.randf_range(0.0, 2 * PI), 0.0)
	var col = CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = 1.0
	var rock = BreakableObject.new(pos, rot, scale, rock_mesh, col, ObjectId.ROCK)
	rock.max_health = round(scale.x + scale.y + scale.z)
	rock.health = rock.max_health
	objects.insert({"position": Vector2(pos.x, pos.z), "data": rock})
	return rock

static func add_berrybush(pos: Vector3, objects: Quadtree) -> WorldObject:
	if object_exists_at_position(pos, objects, WorldObject.ObjectId.BERRYBUSH):
		return
	object_rng.seed = hash(pos)
	var scale = object_rng.randf_range(1.0, 1.25)
	var rot = Vector3(0.0, 0.0, 0.0)
	var col = CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = 0.7
	var berrybush = BerryBushObject.new(pos, rot, Vector3(scale, scale, scale), col)
	objects.insert({"position": Vector2(pos.x, pos.z), "data": berrybush})
	return berrybush

static func add_npc(position: Vector3, rotation: Vector3, scale: float, objects: Quadtree) -> WorldObject:
	if object_exists_at_position(position, objects, WorldObject.ObjectId.HUMAN):
		return
	var npc: NPC = NPC.new(position, rotation, scale)
	objects.insert({"position": Vector2(position.x, position.z), "data": npc})
	return npc


class BreakableObject extends WorldObject:
	var max_health: int = 1
	var health: int = 1

class BerryBushObject extends WorldObject:
	const BERRYBUSH_FULL_SECS = 60
	var berries_fill_secs: float
	var is_filled: bool = false
	var full_bush_glb_mesh = berrybush_full_mesh.instantiate()

	func _init(pos: Vector3, rot: Vector3, scale: Vector3, col: CollisionShape3D):
		super._init(pos, rot, scale, berrybush_empty_mesh, col, ObjectId.BERRYBUSH)
		berries_fill_secs = object_rng.randf_range(0.0, BERRYBUSH_FULL_SECS)

	func update(delta: float):
		if is_filled == true:
			return
		if berries_fill_secs >= BERRYBUSH_FULL_SECS:
			fill()
			return
		berries_fill_secs += delta

	func fill():
		is_filled = true
		if self.glb_mesh.get_parent() == instance:
			instance.remove_child(self.glb_mesh)
		instance.add_child(full_bush_glb_mesh)

	func reset():
		is_filled = false
		berries_fill_secs = 0.0
		if full_bush_glb_mesh.get_parent() == instance:
			instance.remove_child(full_bush_glb_mesh)
		instance.add_child(glb_mesh)

	func delete():
		super.delete()
		full_bush_glb_mesh.queue_free()
