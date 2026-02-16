extends Node

class_name PlayerInventory

var world_items: WorldItems

class ItemContainer:
	var item: ItemProperties
	var amount: int


# Dictionary of item properties and amount
var inventory: Dictionary[String, ItemContainer]
var hotkey_assignments: Dictionary[int, ItemProperties]
var hotkey_counter: int = 0

var inventoryText: Label
var player_camera: Node3D

const EQUIPPED_ITEM_DEFAULT_POSITION: Vector3 = Vector3(-0.5, -0.4, -0.6)
const EQUIPPED_ITEM_DEFAULT_ROTATION: Vector3 = Vector3(0.0, 1.4 * PI, 0.2 * PI)
var EQUIPPED_ITEM_POSITION: Vector3 = EQUIPPED_ITEM_DEFAULT_POSITION
var EQUIPPED_ITEM_ROTATION: Vector3 = EQUIPPED_ITEM_DEFAULT_ROTATION
const ITEM_SWING_ANIMATION_SECS: float = 0.3
var item_swinging_timer: float = INF # INF means not currently swinging


const ITEM_NOT_EQUIPPED: String = "Not Equipped"
var equipped_item: WorldItem = WorldItem.new(ITEM_NOT_EQUIPPED, ITEM_NOT_EQUIPPED, null)
var item_in_hand: bool = false

func _init(_inventoryText: Label, _player_camera: Node3D, _world_items: WorldItems):
	inventoryText = _inventoryText
	player_camera = _player_camera
	world_items = _world_items
	update_inventory_text()

func item_in_hotkeys(item: ItemProperties):
	for hotkey_index in hotkey_assignments:
		var hotkey_item = hotkey_assignments[hotkey_index]
		if hotkey_item.name_singular == item.name_singular:
			return true
	return false

func add_item(item: ItemProperties):
	inventory.get_or_add(item.name_singular, ItemContainer.new())
	inventory[item.name_singular].item = item
	inventory[item.name_singular].amount += 1
	if not item_in_hotkeys(item):
		hotkey_assignments[hotkey_counter] = item
		hotkey_counter += 1
	if equipped_item.properties.name_singular == ITEM_NOT_EQUIPPED:
		equip_item(item)
	update_inventory_text()


func update_inventory_text():
	var text: String = "YOUR ITEMS\n"
	for item_name in inventory:
		var item = inventory[item_name].item
		var amount = inventory[item_name].amount
		text += item.name_plural
		text += ": " 
		text += str(amount)
		text += "\n"
	text += "EQUIPPED ITEM: "
	text += equipped_item.properties.name_singular
	text += "\n"
	inventoryText.text = text


func equip_item(item: ItemProperties):
	if equipped_item.object != null:
		equipped_item.object.queue_free()
		player_camera.remove_child(equipped_item.object)

	equipped_item.properties = item
	# TODO: Should only swap out the model instead of whole object
	equipped_item.object = item.resource.instantiate()
	equipped_item.object.gravity_scale = 0.0
	equipped_item.object.collision_layer = 0
	equipped_item.object.collision_mask = 0

	if item_in_hand:
		equipped_item.object.show()
	else:
		equipped_item.object.hide()
	player_camera.add_child(equipped_item.object)
	update_inventory_text()


func equip_item_index(index: int):
	if hotkey_assignments.size() > index:
		equip_item(hotkey_assignments[index])


func use_equipped_item():
	if item_in_hand:
		item_swinging_timer = 0.0
		return
	else:
		if equipped_item.properties.name_singular != ITEM_NOT_EQUIPPED:
			item_in_hand = true
			equipped_item.object.show()


func put_away_equipped_item():
	item_in_hand = false
	if equipped_item.properties.name_singular != ITEM_NOT_EQUIPPED:
		equipped_item.object.hide()


func delete_equipped_item():
	inventory[equipped_item.properties.name_singular].amount -= 1
	if inventory[equipped_item.properties.name_singular].amount == 0:
		item_in_hand = false
		inventory.erase(equipped_item.properties.name_singular)
		player_camera.remove_child(equipped_item.object)
		equipped_item.object.queue_free()
		equipped_item = WorldItem.new(ITEM_NOT_EQUIPPED, ITEM_NOT_EQUIPPED, null)
	update_inventory_text()


# TODO: Figure out if it is possible to inherit camera position and rotation instead
func _process(delta):
	if item_swinging_timer < INF:
		var transform = Transform3D.IDENTITY.rotated(Vector3.RIGHT, PI / 6 * item_swinging_timer)
		item_swinging_timer += delta
		EQUIPPED_ITEM_ROTATION = transform * EQUIPPED_ITEM_DEFAULT_ROTATION
		if item_swinging_timer >= ITEM_SWING_ANIMATION_SECS:
			item_swinging_timer = INF
			EQUIPPED_ITEM_ROTATION = EQUIPPED_ITEM_DEFAULT_ROTATION
	if item_in_hand:
		equipped_item.object.position = EQUIPPED_ITEM_POSITION
		equipped_item.object.rotation = EQUIPPED_ITEM_ROTATION
