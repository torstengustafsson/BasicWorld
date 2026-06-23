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
var object_id: ObjectId = ObjectId.NO_OBJECT
var glb_mesh: Node3D # Reference to a mesh managed by a MeshPool

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
	glb_mesh.scale = scale

func set_rotation(rotation: Vector3):
	collider_body.rotation = rotation
	glb_mesh.rotation = rotation

func initialize_object(_object_id: ObjectId, _glb_mesh: Node3D) -> void:
	match _object_id:
		ObjectId.HOUSE:
			set_to_house(_glb_mesh)
		ObjectId.CHEST:
			set_to_chest(_glb_mesh)
		ObjectId.TREE:
			set_to_tree(_glb_mesh)
		ObjectId.ROCK:
			set_to_rock(_glb_mesh)
		ObjectId.BERRYBUSH_EMPTY:
			set_to_berrybush(_glb_mesh, ObjectId.BERRYBUSH_EMPTY)
		ObjectId.BERRYBUSH_FULL:
			set_to_berrybush(_glb_mesh, ObjectId.BERRYBUSH_FULL)
		ObjectId.NPC:
			set_to_npc(_glb_mesh)
	set_scale(_glb_mesh.scale)
	set_rotation(glb_mesh.rotation)
	collider_body.position = glb_mesh.position


func set_to_house(_glb_mesh: Node3D) -> void:
	collider.shape = BoxShape3D.new()
	collider.shape.size = Vector3(4.5, 3.6, 6.0)
	object_id = ObjectId.HOUSE
	glb_mesh = _glb_mesh
	collider_body.position = _glb_mesh.position
	collider_body.rotation = glb_mesh.rotation
	set_scale(glb_mesh.scale)

func set_to_chest(_glb_mesh: Node3D) -> void:
	collider.shape = BoxShape3D.new()
	collider.shape.size = Vector3(1.0, 1.0, 1.55)
	object_id = ObjectId.CHEST
	glb_mesh = _glb_mesh
	collider_body.position = _glb_mesh.position
	collider_body.rotation = glb_mesh.rotation
	set_scale(glb_mesh.scale)

func set_to_tree(_glb_mesh: Node3D) -> void:
	collider.shape = CylinderShape3D.new()
	collider.shape.height = 4.0
	collider.shape.radius = 0.5
	object_id = ObjectId.TREE
	glb_mesh = _glb_mesh
	collider_body.position = _glb_mesh.position
	collider_body.rotation = glb_mesh.rotation
	set_scale(glb_mesh.scale)
	max_health = round(glb_mesh.scale.y * 2.0)
	health = max_health

func set_to_rock(_glb_mesh: Node3D) -> void:
	collider.shape = SphereShape3D.new()
	collider.shape.radius = 0.7
	object_id = ObjectId.ROCK
	glb_mesh = _glb_mesh
	collider_body.position = _glb_mesh.position
	collider_body.rotation = glb_mesh.rotation
	set_scale(glb_mesh.scale)
	max_health = round(glb_mesh.scale.x + glb_mesh.scale.y + glb_mesh.scale.z)
	health = max_health

func set_to_berrybush(_glb_mesh: Node3D, _object_id: ObjectId) -> void:
	collider.shape = SphereShape3D.new()
	collider.shape.radius = 0.7
	object_id = _object_id
	glb_mesh = _glb_mesh
	collider_body.position = _glb_mesh.position
	collider_body.rotation = glb_mesh.rotation
	set_scale(glb_mesh.scale)
	berrybush = Berrybush.new(self)

func set_to_npc(_glb_mesh: Node3D) -> void:
	collider.shape = CylinderShape3D.new()
	collider.shape.height = 4.0 # TODO: Verify why it need to be so large. Should be 1.8
	collider.shape.radius = 0.5
	object_id = ObjectId.NPC
	glb_mesh = _glb_mesh
	collider_body.position = _glb_mesh.position
	collider_body.rotation = glb_mesh.rotation
	set_scale(glb_mesh.scale)
	max_health = 4
	health = max_health
	npc = NPC.new(glb_mesh)

func reset_object():
	collider.shape = null
	object_id = ObjectId.NO_OBJECT
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
		var position = parent.glb_mesh.position
		var scale = parent.glb_mesh.scale
		WorldState.state.pool_manager.remove_mesh(parent.glb_mesh)
		var filled_mesh = WorldState.state.pool_manager.get_mesh(WorldObject.ObjectId.BERRYBUSH_FULL, position, scale)
		parent.glb_mesh = filled_mesh

	func reset():
		is_filled = false
		berries_fill_secs = 0.0
		var position = parent.glb_mesh.position
		var scale = parent.glb_mesh.scale
		WorldState.state.pool_manager.remove_mesh(parent.glb_mesh)
		var empty_mesh = WorldState.state.pool_manager.get_mesh(WorldObject.ObjectId.BERRYBUSH_EMPTY, position, scale)
		parent.glb_mesh = empty_mesh
