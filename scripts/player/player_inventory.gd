extends Node2D

class_name PlayerInventory

const NO_EQUIPPED_ITEM = -1

var inventory: Inventory
var hotkey_inventory: HotkeyItems
var player_camera: Node3D

var equipped_item: EquippedItem = EquippedItem.new()
var item_in_hand: bool = false

var held_item = null

func _init(_inventory: Inventory, hotkey_menu: HotkeyItems, _player_camera: Node3D):
	add_to_group("Persist")
	inventory = _inventory
	hotkey_inventory = hotkey_menu
	player_camera = _player_camera
	inventory.add_child(hotkey_inventory)
	hotkey_inventory.position = Vector2(25.0, 255.0)

func _ready() -> void:
	equipped_item.set_item(ItemProperties.Item.NO_ITEM)
	player_camera.add_child(equipped_item)
	equipped_item.hide()


# func item_in_hotkeys(item: ItemProperties.Item):
# 	for hotkey_index in hotkey_assignments:
# 		var hotkey_item = hotkey_assignments[hotkey_index]
# 		if hotkey_item == item:
# 			return true
# 	return false


func add_item(item: ItemProperties.Item, amount: int = 1):
	var hotkeys_full = hotkey_inventory.add_item(item, amount)
	if hotkeys_full:
		var inventory_full = inventory.add_item(item, amount)
		# TODO: Display message that inventory is full
		print("Inventory full")
	update_inventory()


func remove_item(item: ItemProperties.Item, amount: int = 1):
	var last_removed_hotkey_item = hotkey_inventory.remove_item(item, amount)
	if last_removed_hotkey_item:
		var inventory_full = inventory.remove_item(item, amount)
	update_inventory()

func equip_item_index(index: int):
	if index > hotkey_inventory.inventory_size.x * hotkey_inventory.inventory_size.y:
		print("Error: Tried to equip hotkey index " + str(index) + " but hotkey inventory only has " + str(hotkey_inventory.inventory_size.x * hotkey_inventory.inventory_size.y) + " slots.")
		return
	hotkey_inventory.set_equipped_item_index(index)

	var item = hotkey_inventory.inventory_grid.get_child(index).item
	equipped_item.item_id = item

	if item != ItemProperties.Item.NO_ITEM:
		equipped_item.set_item(item)
		player_camera.add_child(equipped_item)
		if item_in_hand:
			equipped_item.show()
		else:
			equipped_item.hide()

# Return true if equipped item is already in hand
func use_equipped_item() -> bool:
	if item_in_hand:
		equipped_item.use()
		return true
	elif equipped_item.item_id != ItemProperties.Item.NO_ITEM:
		item_in_hand = true
		equipped_item.show()
	return false

func put_away_equipped_item():
	item_in_hand = false
	if equipped_item.item_id != ItemProperties.Item.NO_ITEM:
		equipped_item.hide()

func delete_equipped_item():
	if hotkey_inventory.equipped_item_index != NO_EQUIPPED_ITEM and hotkey_inventory.get_equipped_item_slot().amount <= 1:
		put_away_equipped_item()
		hotkey_inventory.remove_equipped_item()
		equipped_item.set_item(ItemProperties.Item.NO_ITEM)
		hotkey_inventory.set_equipped_item_index(NO_EQUIPPED_ITEM)
	remove_item(equipped_item.item_id, 1)

func update_inventory():
	for slot in inventory.inventory_grid.get_children():
		slot.gui_input.connect(slot_gui_input.bind(slot))
	for slot in hotkey_inventory.inventory_grid.get_children():
		slot.gui_input.connect(slot_gui_input.bind(slot))

# TODO: Handle equipped item
func slot_gui_input(event: InputEvent, slot: InventorySlot) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
		if held_item == null:
			slot.set_picked_up()
			held_item = slot
			print("Picked up item " + str(ItemProperties.ITEMS[slot.item].name_singular) + " with amount " + str(slot.amount))
		else:
			slot.set_item(held_item.item, held_item.amount)
			slot.set_placed_down()
			if held_item != slot:
				held_item.set_empty()
			held_item = null
			print("Placed item " + str(ItemProperties.ITEMS[slot.item].name_singular) + " with amount " + str(slot.amount))

func _input(event: InputEvent) -> void:
	if held_item:
		held_item.icon.position = get_global_mouse_position()

func save() -> Dictionary:
	return {}
# 	var items = inventory_menu._save()
# 	var result: Dictionary = {}
# 	var items_dict: Dictionary = {}
# 	items_dict["items"] = items
# 	items_dict["equipped_item"] = equipped_item.item_id
# 	items_dict["item_in_hand"] = item_in_hand
# 	items_dict["hotkeys"] = hotkey_assignments
# 	result[SaveLoadState.StateType.PlayerInventory] =  items_dict
# 	return result

func load(data: Dictionary):
	pass
# 	var item_data = data[str(SaveLoadState.StateType.PlayerInventory)]
# 	inventory_menu._load(item_data["items"])
# 	item_in_hand = item_data["item_in_hand"]
# 	equip_item(item_data["equipped_item"])
# 	hotkey_assignments = item_data["hotkeys"]
# 	hotkey_counter = hotkey_assignments.size()
