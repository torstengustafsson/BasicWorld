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
	TUTORIAL_NPC,
}

# NOTE: Here we are only interested in collider, but Godot requires it to be StaticBody3D to enable physics collisions
var collider_body: StaticBody3D = StaticBody3D.new()
var collider: CollisionShape3D = CollisionShape3D.new()
var mesh_object: MeshObject = null # Should be treated as constant reference

var max_health: int = 1
var health: int = 1

# Composition objects
var berrybush: Berrybush = null
var npc: NPC = null

func _init():
	collider_body.add_child(collider)

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
	if mesh_object:
		mesh_object.mesh.scale = scale # Scale is considered safe to modify

func initialize_object(_mesh_object: MeshObject = null) -> void:
	if _mesh_object != null: # If set to null, we assume its own mesh_object is already initialized with correct values
		mesh_object = _mesh_object
	match mesh_object.object_id:
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
		ObjectId.TUTORIAL_NPC:
			set_to_tutorial_npc()
	set_scale(mesh_object.scale)
	collider_body.rotation = mesh_object.rotation
	collider_body.position = mesh_object.position


func set_to_house() -> void:
	collider.shape = BoxShape3D.new()
	collider.shape.size = Vector3(4.5, 3.6, 6.0)

func set_to_chest() -> void:
	collider.shape = BoxShape3D.new()
	collider.shape.size = Vector3(1.0, 1.0, 1.55)

func set_to_tree() -> void:
	collider.shape = CylinderShape3D.new()
	collider.shape.height = 4.0
	collider.shape.radius = 0.5
	max_health = round(mesh_object.scale.y * 2.0)
	health = max_health

func set_to_rock() -> void:
	collider.shape = SphereShape3D.new()
	collider.shape.radius = 0.7
	max_health = round(mesh_object.scale.x + mesh_object.scale.y + mesh_object.scale.z)
	health = max_health

func set_to_berrybush(_object_id: ObjectId) -> void:
	collider.shape = SphereShape3D.new()
	collider.shape.radius = 0.7
	berrybush = Berrybush.new(self)

func set_to_npc() -> void:
	collider.shape = CylinderShape3D.new()
	collider.shape.height = 4.0 # TODO: Verify why it need to be so large. Should be 1.8
	collider.shape.radius = 0.5
	max_health = 4
	health = max_health
	npc = NPC.new(mesh_object)

func set_to_tutorial_npc() -> void:
	collider.shape = CylinderShape3D.new()
	collider.shape.height = 4.0 # TODO: Verify why it need to be so large. Should be 1.8
	collider.shape.radius = 0.5
	max_health = 4
	health = max_health
	npc = NPC.new(mesh_object)
	npc.default_sound = AudioManager.SoundID.ROGGAN

func reset_object():
	mesh_object = null
	collider.shape = null
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
		var position = parent.mesh_object.position
		var scale = parent.mesh_object.scale
		WorldState.state.pool_manager.remove_mesh_by_id(parent.mesh_object.id)
		parent.mesh_object = WorldState.state.pool_manager.add_mesh(ObjectId.BERRYBUSH_FULL, position, scale)

	func reset():
		is_filled = false
		berries_fill_secs = 0.0
		var position = parent.mesh_object.position
		var scale = parent.mesh_object.scale
		WorldState.state.pool_manager.remove_mesh_by_id(parent.mesh_object.id)
		parent.mesh_object = WorldState.state.pool_manager.add_mesh(WorldObject.ObjectId.BERRYBUSH_EMPTY, position, scale)
