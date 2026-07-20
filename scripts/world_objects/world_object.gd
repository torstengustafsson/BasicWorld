class_name WorldObject extends Object

enum ObjectId {
	NO_OBJECT,
	HOUSE,
	CHEST,
	TREE,
	ROCK,
	BERRYBUSH,
	BERRYBUSH_FULL,
	NPC,
	TUTORIAL_NPC,
}

# If this WorldObject was placed via a MultiMeshChunk, a reference to it is stored for each WorldObject
# This is to allow easy access to it for removal and such.
var multimesh_parent: MultiMeshChunk
var mesh_instance_id: int # Used for world objects that are controlled by multimeshes
var model: Node3D # Instantiated .glb model
var collision_shape: CollisionShape3D = CollisionShape3D.new()

var object_id: WorldObject.ObjectId
var position: Vector3
var rotation: Vector3
var scale: Vector3

var max_health: int = 1
var health: int = 1

# Composition objects
var berrybush: Berrybush = null
var npc: NPC = null

func _init(
	_object_id: WorldObject.ObjectId = WorldObject.ObjectId.NO_OBJECT,
	_position: Vector3 = Globals.OUT_OF_SIGHT,
	_rotation: Vector3 = Vector3(0.0, 0.0, 0.0),
	_scale: Vector3 = Vector3(1.0, 1.0, 1.0),
	_mesh_instance_id: int = Globals.MAX_INT,
):
	object_id = _object_id
	position = _position
	rotation = _rotation
	set_scale(_scale)
	mesh_instance_id = _mesh_instance_id
	collision_shape.position = _position
	collision_shape.rotation = _rotation

# Returns a color multiplier of the object. Returns white (no change) for object types that do not use random color multipliers.
func initialize_model(_model: Node3D) -> Color:
	model = _model
	model.transform = get_transform()

	var rng = RandomNumberGenerator.new()
	rng.seed = hash(position)
	if npc:
		npc.initialize(self, rng)

	if object_id == ObjectId.TREE:
		model.get_node("Tree").get_active_material(0).vertex_color_use_as_albedo = true
		return Color(randf_range(1.0, 3.0), randf_range(0.8, 1.0), 1.0)
	return Color.WHITE

func get_transform() -> Transform3D:
	return Transform3D(
		Basis.from_euler(rotation).scaled_local(scale),
		position
	)

func set_instance_rotation(_rotation: Vector3) -> void:
	rotation = _rotation
	multimesh_parent.set_instance_transform(mesh_instance_id, get_transform())

func set_scale(_scale: Vector3):
	scale = _scale
	var uniform_scale: bool = scale.x == scale.y and scale.y == scale.z
	if uniform_scale:
		collision_shape.scale = scale
	else:
		# Jolt physics engine does not allow non-uniform scale of collision_shapes.
		# So we set the collision_shape to instead get a uniform average of the scale values.
		var max_val = max(scale.x, scale.x, scale.z)
		var min_val = min(scale.x, scale.x, scale.z)
		var scale_val = min_val + max_val - min_val / 2.0
		var averaged_scale = Vector3(scale_val, scale_val, scale_val) * 0.8
		collision_shape.scale = averaged_scale

static func create_object(_object_id: ObjectId, _position: Vector3, _rotation: Vector3 = Vector3.ZERO, _scale: Vector3 = Vector3.ONE) -> WorldObject:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(_position)
	var object: WorldObject = WorldObject.new(_object_id, _position, _rotation, _scale)
	match _object_id:
		ObjectId.HOUSE:
			object.set_to_house(rng)
		ObjectId.CHEST:
			object.set_to_chest(rng)
		ObjectId.TREE:
			object.set_to_tree(rng)
		ObjectId.ROCK:
			object.set_to_rock(rng)
		ObjectId.BERRYBUSH:
			object.set_to_berrybush(rng, false)
		ObjectId.BERRYBUSH_FULL:
			object.set_to_berrybush(rng, true)
		ObjectId.NPC:
			object.set_to_npc(rng)
		ObjectId.TUTORIAL_NPC:
			object.set_to_tutorial_npc(rng)
	return object

func set_to_house(_rng: RandomNumberGenerator) -> void:
	collision_shape.shape = BoxShape3D.new()
	collision_shape.shape.size = Vector3(4.5, 3.6, 6.0)

func set_to_chest(_rng: RandomNumberGenerator) -> void:
	collision_shape.shape = BoxShape3D.new()
	collision_shape.shape.size = Vector3(1.0, 1.0, 1.55)

func set_to_tree(rng: RandomNumberGenerator) -> void:
	var scale_dim = rng.randf_range(2.5, 5.0)
	set_scale(Vector3(scale_dim, scale_dim, scale_dim))
	collision_shape.shape = CylinderShape3D.new()
	collision_shape.shape.height = 4.0
	collision_shape.shape.radius = 0.25
	max_health = round(scale.y * 2.0)
	health = max_health

func set_to_rock(rng: RandomNumberGenerator) -> void:
	set_scale(Vector3(rng.randf_range(1.0, 4.0), rng.randf_range(1.2, 6.0), rng.randf_range(1.0, 4.0)))
	if rotation == Vector3.ZERO:
		rotation = Vector3(0.0, rng.randf_range(0.0, 2 * PI), 0.0)
	collision_shape.shape = CapsuleShape3D.new()
	collision_shape.shape.height = scale.y * 0.7
	collision_shape.shape.radius = 0.7
	max_health = round(scale.x + scale.y + scale.z)
	health = max_health

func set_to_berrybush(rng: RandomNumberGenerator, is_filled: bool) -> void:
	var scale_dim = rng.randf_range(1.0, 1.25)
	set_scale(Vector3(scale_dim, scale_dim, scale_dim))
	if rotation == Vector3.ZERO:
		rotation = Vector3(0.0, rng.randf_range(0.0, 2 * PI), 0.0)
	collision_shape.shape = SphereShape3D.new()
	collision_shape.shape.radius = 1.0
	berrybush = Berrybush.new(self)
	berrybush.is_filled = is_filled

func set_to_npc(rng: RandomNumberGenerator) -> void:
	var scale_dim = rng.randf_range(0.85, 1.15)
	set_scale(Vector3(scale_dim, scale_dim, scale_dim))
	collision_shape.shape = CapsuleShape3D.new()
	collision_shape.shape.height = 4.0
	collision_shape.shape.radius = 0.5
	max_health = 4
	health = max_health
	npc = NPC.new()

func set_to_tutorial_npc(_rng: RandomNumberGenerator) -> void:
	collision_shape.shape = CapsuleShape3D.new()
	collision_shape.shape.height = 4.0
	collision_shape.shape.radius = 0.5
	max_health = 4
	health = max_health
	npc = NPC.new()
	npc.default_sound = AudioManager.SoundID.ROGGAN

func reset_object():
	collision_shape.shape = null
	berrybush = null
	npc = null

class Berrybush extends Object:
	const BERRYBUSH_FULL_SECS: float = 15.0
	var berries_fill_secs: float
	var is_filled: bool = false
	var parent: WorldObject

	func _init(_parent: WorldObject):
		berries_fill_secs = randf_range(0, BERRYBUSH_FULL_SECS / 3.0)
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
		var position = parent.position
		var rotation = parent.rotation
		var scale = parent.scale
		var removed = WorldState.state.multimesh_manager.remove_object(parent)
		if removed:
			WorldState.state.multimesh_manager.add_object_with_collider(ObjectId.BERRYBUSH_FULL, position, rotation, scale)
			parent.free()

	func reset():
		is_filled = false
		berries_fill_secs = 0.0
		var position = parent.position
		var rotation = parent.rotation
		var scale = parent.scale
		var removed = WorldState.state.multimesh_manager.remove_object(parent)
		if removed:
			WorldState.state.multimesh_manager.add_object_with_collider(ObjectId.BERRYBUSH, position, rotation, scale)
			parent.free()
