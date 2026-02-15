extends Node

class_name ItemProperties

const axe_scene = preload("res://scenes/items/axe.tscn")
const berry_scene = preload("res://scenes/items/berry.tscn")
const wood_scene = preload("res://scenes/items/wood.tscn")

static var AXE_ITEM: ItemProperties =  ItemProperties.new("Axe", "Axes", axe_scene)
static var BERRY_ITEM: ItemProperties =  ItemProperties.new("Berry", "Berries", berry_scene)
static var WOOD_ITEM: ItemProperties =  ItemProperties.new("Wood", "Wood", wood_scene)

var name_singular: String
var name_plural: String	
var resource: PackedScene

func _init(_name_singular: String, _name_plural: String, _resource: PackedScene):
	name_singular = _name_singular
	name_plural = _name_plural
	resource = _resource
