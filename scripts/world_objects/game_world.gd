extends Node3D

class_name GameWorld

enum InteractResults { NoResult, GainItem, DeleteEquippedItem }

class InteractResult:
	var result: InteractResults
	var item: ItemProperties.Item

	func _init(_result: InteractResults = InteractResults.NoResult, _item: ItemProperties.Item = ItemProperties.Item.NO_ITEM) -> void:
		result = _result
		item = _item

var world_state: WorldState
var distance_controller: DistanceController

func _init(_player: Node3D) -> void:
	world_state = WorldState.new(_player)

func _ready() -> void:
	var start_time = Time.get_ticks_msec()

	world_state.space_state = get_world_3d().direct_space_state
	distance_controller = DistanceController.new(world_state)
	add_child(distance_controller)
	await get_tree().process_frame

	var elapsed = Time.get_ticks_msec() - start_time

	print("")
	print("Total time to generate world = " + str(elapsed / 1000.0) + " seconds")
	print("Number of objects in scene = " + str(count_all_children(self)))
	print("RANDOM SEED = " + str(Globals.RANDOM_SEED))


func count_all_children(node: Node) -> int:
	var count = node.get_child_count()
	for child in node.get_children():
		count += count_all_children(child)
	return count


func interact(collider, item: ItemProperties.Item = ItemProperties.Item.NO_ITEM) -> InteractResult:
	return distance_controller.interact(collider, item)

func handle_use_item(collider, item: ItemProperties.Item) -> void:
	return distance_controller.handle_use_item(collider, item)
