extends Node

class_name WorldItem

var object: RigidBody3D
var item_id: ItemProperties.Item

func _init(item: ItemProperties.Item):
	item_id = item
	var resource = ItemProperties.ITEMS[item].resource
	if resource:
		object = resource.instantiate()

static func create_item(item: ItemProperties.Item) -> WorldItem:
	return WorldItem.new(item)
