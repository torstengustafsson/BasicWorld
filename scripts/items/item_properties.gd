extends Node

class_name ItemProperties

const axe_scene = preload("res://scenes/items/axe.tscn")
const pickaxe_scene = preload("res://scenes/items/pickaxe.tscn")
const berry_scene = preload("res://scenes/items/berry.tscn")
const wood_scene = preload("res://scenes/items/wood.tscn")
const stone_scene = preload("res://scenes/items/stone.tscn")

const axe_glb = preload("res://assets/models/items/axe_item.glb")
const pickaxe_glb = preload("res://assets/models/items/pickaxe_item.glb")
const berry_glb = preload("res://assets/models/items/berry_item.glb")
const wood_glb = preload("res://assets/models/items/wood_item.glb")
const stone_glb = preload("res://assets/models/items/stone_item.glb")


const axe_icon = preload("res://assets/icons/items/axe_icon.png")
const pickaxe_icon = preload("res://assets/icons/items/pickaxe_icon.png")
const berry_icon = preload("res://assets/icons/items/berries_icon.png")
const wood_icon = preload("res://assets/icons/items/wood_icon.png")
const stone_icon = preload("res://assets/icons/items/stone_icon.png")

enum Item { NO_ITEM, AXE, PICKAXE, BERRY, WOOD, STONE }

static var ITEMS: Dictionary[Item, ItemProperties] = {
	Item.NO_ITEM: ItemProperties.new("No item", "No item", 0, null, null, null),
	Item.AXE: ItemProperties.new("Axe", "Axes", 1, axe_icon, axe_scene, axe_glb),
	Item.PICKAXE: ItemProperties.new("Pickaxe", "Pickaxes", 1, pickaxe_icon, pickaxe_scene, pickaxe_glb),
	Item.BERRY: ItemProperties.new("Berry", "Berries", 10, berry_icon, berry_scene, berry_glb),
	Item.WOOD: ItemProperties.new("Wood", "Wood", 10, wood_icon, wood_scene, wood_glb),
	Item.STONE: ItemProperties.new("Stone", "Stones", 10, stone_icon, stone_scene, stone_glb),
}

var name_singular: String
var name_plural: String
var max_stack_size = 1
var icon: Texture2D
var resource: PackedScene
var glb: PackedScene

func _init(_name_singular: String, _name_plural: String, _max_stack_size: int, _icon: Texture2D, _resource: PackedScene, _glb: PackedScene):
	name_singular = _name_singular
	name_plural = _name_plural
	max_stack_size = _max_stack_size
	icon = _icon
	resource = _resource
	glb = _glb

func eq(other: ItemProperties) -> bool:
	return name_singular == other.name_singular
