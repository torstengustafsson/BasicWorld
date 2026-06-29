extends RefCounted

class_name WorldObject

enum ObjectId {
	NO_OBJECT,
	HOUSE,
	CHEST,
	TREE,
	ROCK,
	BERRYBUSH_EMPTY,
	BERRYBUSH_FULL,
	NPC,
}

# NOTE: Here we are only interested in collider, but Godot requires it to be StaticBody3D to enable physics collisions
var collider_body: StaticBody3D = StaticBody3D.new()
var collider: CollisionShape3D = CollisionShape3D.new()
var mesh_object: MeshObject = MeshObject.new()

var max_health: int = 1
var health: int = 1

# Composition objects
var berrybush: Berrybush = null
var npc: NPC = null

func _init():
	collider_body.add_child(collider)

func set_mesh_object(_mesh_object: MeshObject):
	mesh_object = _mesh_object


func set_scale(scale: Vector3):
	var uniform_scale: bool = scale.x == scale.y and scale.y == scale.z
	if uniform_scale:
		collider_body.scale = scale
	else:
		# Jolt physics engine does not allow non-uniform scale of colliders.
		# So we set the collider to instead get a uniform average of the scale values.
		var max_val = max(scale.x, scale.y, scale.z)
		var min_val = min(scale.x, scale.y, scale.z)
		var scale_val = min_val + max_val - min_val / 2.0
		var averaged_scale = Vector3(scale_val, scale_val, scale_val) * 0.8
		collider_body.scale = averaged_scale
	mesh_object.mesh.scale = scale

func initialize_object(_mesh_object: MeshObject) -> void:
	mesh_object = _mesh_object
	match _mesh_object.object_id:
		ObjectId.HOUSE:
			set_to_house()
		ObjectId.CHEST:
			set_to_chest()
		ObjectId.TREE:
			set_to_tree()
		ObjectId.ROCK:
			set_to_rock()
		ObjectId.BERRYBUSH_EMPTY:
			set_to_berrybush(ObjectId.BERRYBUSH_EMPTY)
		ObjectId.BERRYBUSH_FULL:
			set_to_berrybush(ObjectId.BERRYBUSH_FULL)
		ObjectId.NPC:
			set_to_npc()
	set_scale(mesh_object.scale)
	collider_body.rotation = mesh_object.rotation
	collider_body.position = mesh_object.position


func set_to_house() -> void:
	collider.shape = BoxShape3D.new()
	collider.shape.size = Vector3(4.5, 3.6, 6.0)
	mesh_object.object_id = ObjectId.HOUSE
	collider_body.position = mesh_object.position
	collider_body.rotation = mesh_object.rotation
	set_scale(mesh_object.scale)

func set_to_chest() -> void:
	collider.shape = BoxShape3D.new()
	collider.shape.size = Vector3(1.0, 1.0, 1.55)
	mesh_object.object_id = ObjectId.CHEST
	collider_body.position = mesh_object.position
	collider_body.rotation = mesh_object.rotation
	set_scale(mesh_object.scale)

func set_to_tree() -> void:
	collider.shape = CylinderShape3D.new()
	collider.shape.height = 4.0
	collider.shape.radius = 0.5
	mesh_object.object_id = ObjectId.TREE
	collider_body.position = mesh_object.position
	collider_body.rotation = mesh_object.rotation
	set_scale(mesh_object.scale)
	max_health = round(mesh_object.scale.y * 2.0)
	health = max_health

func set_to_rock() -> void:
	collider.shape = SphereShape3D.new()
	collider.shape.radius = 0.7
	mesh_object.object_id = ObjectId.ROCK
	collider_body.position = mesh_object.position
	collider_body.rotation = mesh_object.rotation
	set_scale(mesh_object.scale)
	max_health = round(mesh_object.scale.x + mesh_object.scale.y + mesh_object.scale.z)
	health = max_health

func set_to_berrybush(_object_id: ObjectId) -> void:
	collider.shape = SphereShape3D.new()
	collider.shape.radius = 0.7
	mesh_object.object_id = _object_id
	collider_body.position = mesh_object.position
	collider_body.rotation = mesh_object.rotation
	set_scale(mesh_object.scale)
	berrybush = Berrybush.new(self)

func set_to_npc() -> void:
	collider.shape = CylinderShape3D.new()
	collider.shape.height = 4.0 # TODO: Verify why it need to be so large. Should be 1.8
	collider.shape.radius = 0.5
	mesh_object.object_id = ObjectId.NPC
	collider_body.position = mesh_object.position
	collider_body.rotation = mesh_object.rotation
	set_scale(mesh_object.scale)
	max_health = 4
	health = max_health
	npc = NPC.new(mesh_object)

func reset_object():
	mesh_object = MeshObject.new()
	collider.call_deferred("set_shape", null)
	berrybush = null
	npc = null

class Berrybush:
	const BERRYBUSH_FULL_SECS: float = 15.0
	var berries_fill_secs: float
	var is_filled: bool = false
	var parent: WorldObject

	func _init(_parent: WorldObject):
		berries_fill_secs = randf_range(BERRYBUSH_FULL_SECS / 5.0, BERRYBUSH_FULL_SECS)
		parent = _parent

	func update(delta: float):
		if is_filled == true:
			return
		if berries_fill_secs >= BERRYBUSH_FULL_SECS:
			fill()
			return
		berries_fill_secs += delta

	func fill():
		is_filled = true
		WorldState.state.pool_manager.remove_mesh(parent.mesh_object)
		parent.mesh_object = WorldState.state.pool_manager.get_mesh(ObjectId.BERRYBUSH_FULL, parent.mesh_object.position, parent.mesh_object.scale)

	func reset():
		is_filled = false
		berries_fill_secs = 0.0
		WorldState.state.pool_manager.remove_mesh(parent.mesh_object)
		parent.mesh_object = WorldState.state.pool_manager.get_mesh(WorldObject.ObjectId.BERRYBUSH_EMPTY, parent.mesh_object.position, parent.mesh_object.scale)
