extends Node

const axe_scene = preload("res://scenes/items/axe.tscn")

# Contains all items in the world
var items: Dictionary[int, Item]
var item_counter: int = 0

class Item:
	var object: Node3D
	var name: String
	var is_axe: bool = false

	func _init(_name, _object):
		name = _name
		object = _object

func spawn_axe(pos: Vector3) -> Node3D:
	var axe_object = axe_scene.instantiate()
	var axe = Item.new("Axe", axe_object)
	axe.object.position = pos
	axe.is_axe = true
	items[item_counter] = axe
	return axe.object

# Returns name of item picked
func interact(collider) -> String:
	for item_index in items:
		var item = items[item_index]
		if item.object.get_node("PickableArea") == collider:
			var name = item.name
			item.object.queue_free()
			items.erase(item_index)
			return name
	return ""
