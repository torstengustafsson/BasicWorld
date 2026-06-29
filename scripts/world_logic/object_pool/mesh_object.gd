class_name MeshObject

var mesh: Node3D # .glb mesh
var object_id: WorldObject.ObjectId
var process_mode: Node.ProcessMode = Node.PROCESS_MODE_PAUSABLE
var position: Vector3
var rotation: Vector3
var scale: Vector3
func _init(
	_mesh = null,
	_object_id = WorldObject.ObjectId.NO_OBJECT,
	_position = Globals.OUT_OF_SIGHT,
	_rotation = Vector3(0.0, 0.0, 0.0),
	_scale = Vector3(1.0, 1.0, 1.0)
):
	mesh = _mesh
	object_id = _object_id
	position = _position
	rotation = _rotation
	scale = _scale

func set_position(_position: Vector3):
	mesh.call_deferred("set_position", _position)
	position = _position

func set_rotation(_rotation: Vector3):
	mesh.call_deferred("set_rotation", _rotation)
	rotation = _rotation

func set_scale(_scale: Vector3):
	mesh.call_deferred("set_scale", _scale)
	scale = _scale
