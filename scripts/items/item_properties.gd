extends Node

class_name ItemProperties

const axe_scene = preload("res://scenes/items/axe.tscn")
const berry_scene = preload("res://scenes/items/berry.tscn")
const wood_scene = preload("res://scenes/items/wood.tscn")

enum Item { NO_ITEM, AXE, BERRY, WOOD }

static var ITEMS: Dictionary[Item, ItemProperties] = {
	Item.NO_ITEM: ItemProperties.new("No item", "No item", null),
	Item.AXE: ItemProperties.new("Axe", "Axes", axe_scene),
	Item.BERRY: ItemProperties.new("Berry", "Berries", berry_scene),
	Item.WOOD: ItemProperties.new("Wood", "Wood", wood_scene),
}

var name_singular: String
var name_plural: String	
var resource: PackedScene

func _init(_name_singular: String, _name_plural: String, _resource: PackedScene):
	name_singular = _name_singular
	name_plural = _name_plural
	resource = _resource

func eq(other: ItemProperties) -> bool:
	return name_singular == other.name_singular
