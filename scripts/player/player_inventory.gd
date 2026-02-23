extends Inventory

class_name PlayerInventory

var inventoryText: Label
var player_camera: Node3D

var hotkey_assignments: Dictionary # Cant be typed due to gdscript. Should be: Dictionary[int, ItemProperties.Item]
var hotkey_counter: int = 0

const EQUIPPED_ITEM_DEFAULT_POSITION: Vector3 = Vector3(-0.5, -0.4, -0.6)
const EQUIPPED_ITEM_DEFAULT_ROTATION: Vector3 = Vector3(0.0, 1.4 * PI, 0.2 * PI)
var EQUIPPED_ITEM_POSITION: Vector3 = EQUIPPED_ITEM_DEFAULT_POSITION
var EQUIPPED_ITEM_ROTATION: Vector3 = EQUIPPED_ITEM_DEFAULT_ROTATION
const ITEM_SWING_ANIMATION_SECS: float = 0.3
var item_swinging_timer: float = INF # INF means not currently swinging

var equipped_item: WorldItem = WorldItem.new(ItemProperties.Item.NO_ITEM)
var item_in_hand: bool = false

func _init(_inventoryText: Label, _player_camera: Node3D):
	add_to_group("Persist")
	inventoryText = _inventoryText
	player_camera = _player_camera
	update_inventory_text()


func item_in_hotkeys(item: ItemProperties.Item):
	for hotkey_index in hotkey_assignments:
		var hotkey_item = hotkey_assignments[hotkey_index]
		if hotkey_item == item:
			return true
	return false


func add_item(item: ItemProperties.Item, amount: int = 1):
	super._add_item(item, amount)
	if not item_in_hotkeys(item):
		hotkey_assignments[str(hotkey_counter)] = item
		hotkey_counter += 1
	if equipped_item.item_id == ItemProperties.Item.NO_ITEM:
		equip_item(item)
	update_inventory_text()


func update_inventory_text():
	var text: String = "YOUR ITEMS\n"
	for item in inventory:
		var amount = inventory[item].amount
		text += ItemProperties.ITEMS[item].name_plural
		text += ": "
		text += str(amount)
		text += "\n"
	text += "EQUIPPED ITEM: "
	text += ItemProperties.ITEMS[equipped_item.item_id].name_singular
	text += "\n"
	inventoryText.text = text


func equip_item(item: ItemProperties.Item):
	if equipped_item.object != null:
		equipped_item.object.queue_free()
		player_camera.remove_child(equipped_item.object)

	equipped_item.item_id = item
	# TODO: Should only swap out the model instead of whole object
	if item != ItemProperties.Item.NO_ITEM:
		equipped_item.object = ItemProperties.ITEMS[item].resource.instantiate()
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
	var index_str = str(index)
	if hotkey_assignments.size() > index and inventory.has(hotkey_assignments[index_str]):
		equip_item(hotkey_assignments[index_str])


# Return true if equipped item is already in hand
func use_equipped_item() -> bool:
	if item_in_hand:
		item_swinging_timer = 0.0
		return true
	elif equipped_item.item_id != ItemProperties.Item.NO_ITEM:
		item_in_hand = true
		equipped_item.object.show()
	return false

func put_away_equipped_item():
	item_in_hand = false
	if equipped_item.item_id != ItemProperties.Item.NO_ITEM:
		equipped_item.object.hide()


func delete_equipped_item():
	var last_removed = super._remove_item(equipped_item.item_id)
	if last_removed:
		item_in_hand = false
		player_camera.remove_child(equipped_item.object)
		equipped_item.object.queue_free()
		equipped_item = WorldItem.new(ItemProperties.Item.NO_ITEM)
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

func save() -> Dictionary:
	var items = super._save()
	var result: Dictionary = {}
	var items_dict: Dictionary = {}
	items_dict["items"] = items
	items_dict["equipped_item"] = equipped_item.item_id
	items_dict["item_in_hand"] = item_in_hand
	items_dict["hotkeys"] = hotkey_assignments
	result[SaveLoadState.StateType.PlayerInventory] =  items_dict
	return result

func load(data: Dictionary):
	var item_data = data[str(SaveLoadState.StateType.PlayerInventory)]
	super._load(item_data["items"])
	item_in_hand = item_data["item_in_hand"]
	equip_item(item_data["equipped_item"])
	hotkey_assignments = item_data["hotkeys"]
	hotkey_counter = hotkey_assignments.size()
