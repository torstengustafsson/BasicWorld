extends Node

class_name PlayerInventory

var world_items: WorldItems

# Dictionary of item properties and amount
var inventory: Dictionary[ItemProperties, int]

var inventoryText: Label
var player_camera: Node3D

const EQUIPPED_ITEM_POSITION = Vector3(-0.5, -0.4, -0.6)
const EQUIPPED_ITEM_ROTATION = Vector3(0.0, 1.4 * PI, 0.2 * PI)


var equipped_item: WorldItem
var ITEM_NOT_EQUIPPED: WorldItem = WorldItem.new("Not Equipped", "Not Equipped", null)
var item_in_hand: bool = false

func _init(_inventoryText: Label, _player_camera: Node3D, _world_items: WorldItems):
	inventoryText = _inventoryText
	player_camera = _player_camera
	world_items = _world_items
	equipped_item = ITEM_NOT_EQUIPPED
	update_inventory()

func add_item(item: ItemProperties):
	inventory.get_or_add(item, 0)
	inventory[item] += 1
	if equipped_item == ITEM_NOT_EQUIPPED:
		equip_item(item)
	update_inventory()


func update_inventory():
	var text: String = "YOUR ITEMS\n"
	for item in inventory:
		var amount = inventory[item]
		text += item.name_plural
		text += ": " 
		text += str(amount)
		text += "\n"
	text += "EQUIPPED ITEM: "
	text += equipped_item.properties.name_singular
	text += "\n"
	inventoryText.text = text


func equip_item(item):
	equipped_item = WorldItem.create_item(item)
	equipped_item.object.position = EQUIPPED_ITEM_POSITION
	equipped_item.object.rotation = EQUIPPED_ITEM_ROTATION
	equipped_item.object.gravity_scale = 0.0
	equipped_item.object.collision_layer = 0
	equipped_item.object.collision_mask = 0
	player_camera.add_child(equipped_item.object)

	if item_in_hand:
		equipped_item.object.show()
	else:
		equipped_item.object.hide()

# TODO: Figure out if it is possible to inherit camera position and rotation instead
func _process(delta):
	if item_in_hand:
		equipped_item.object.position = EQUIPPED_ITEM_POSITION
		equipped_item.object.rotation = EQUIPPED_ITEM_ROTATION
		pass

func use_equipped_item():
	if item_in_hand:
		print("Using equipped item " + equipped_item.properties.name_singular)
		return
	else:
		if equipped_item != ITEM_NOT_EQUIPPED:
			item_in_hand = true
			equipped_item.object.show()

		pass

func put_away_equipped_item():
	item_in_hand = false
	if equipped_item != ITEM_NOT_EQUIPPED:
		equipped_item.object.hide()
