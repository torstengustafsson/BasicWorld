# Actual Pool-classes inherit from this class

class_name ObjectPool extends Node

const GROWTH_THRESHOLD_PERCENT: float = 0.8 # A value of 0.8 means grow when used objects are >= 80% of pool size.
const GROWTH_FACTOR_PERCENT: float = 0.5 # A value of 0.5 means grow by 50% each time.
var total_objects: int = 0

static var _id_counter: int = 0
static var _id_mutex: Mutex = Mutex.new()

static func _allocate_id() -> int:
	# Godot int is 64 bits, so this should last for a full playthrough
	_id_mutex.lock()
	_id_counter += 1
	var id = _id_counter
	_id_mutex.unlock()
	return id

func _grow_pool() -> void:
	var new_objects: int = min(floor(total_objects * GROWTH_FACTOR_PERCENT), 1000)
	for _i in new_objects:
		_create_new_object()

# Subclasses overload this function for actual object generation
func _create_new_object():
	pass

# NOTE: Add and remove methods may take different inputs, so they are harder to create generic interface for.
# For now, they need to implement their own logic as well as the methods.
