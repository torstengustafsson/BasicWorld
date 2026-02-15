extends Node

class_name WorldItem

var object: RigidBody3D
var properties: ItemProperties

func _init(_name_singular: String, _name_plural: String, _resource: PackedScene):
	properties = ItemProperties.new(_name_singular, _name_plural, _resource)
	if _resource:
		object = _resource.instantiate()

static func create_item(item: ItemProperties) -> WorldItem:
	return WorldItem.new(item.name_singular, item.name_plural, item.resource)
