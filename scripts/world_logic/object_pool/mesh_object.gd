class_name MeshObject

var id: int
var mesh: Node3D # .glb mesh
var object_id: WorldObject.ObjectId
var process_mode: Node.ProcessMode
var position: Vector3
var rotation: Vector3
var scale: Vector3
func _init(
	_id: int,
	_mesh: Node3D = null,
	_object_id: WorldObject.ObjectId = WorldObject.ObjectId.NO_OBJECT,
	_process_mode: Node.ProcessMode = Node.PROCESS_MODE_PAUSABLE,
	_position: Vector3 = Globals.OUT_OF_SIGHT,
	_rotation: Vector3 = Vector3(0.0, 0.0, 0.0),
	_scale: Vector3 = Vector3(1.0, 1.0, 1.0)
):
	id = _id
	mesh = _mesh
	object_id = _object_id
	position = _position
	rotation = _rotation
	scale = _scale

func reset() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	position = Globals.OUT_OF_SIGHT
	rotation = Vector3(0.0, 0.0, 0.0)
	scale = Vector3(1.0, 1.0, 1.0)

func copy() -> MeshObject:
	return MeshObject.new(id, mesh.duplicate(), object_id, process_mode, position, rotation, scale)
