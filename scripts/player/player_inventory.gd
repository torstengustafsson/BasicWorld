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
	process_mode = Node.PROCESS_MODE_ALWAYS
	equipped_item.set_item(ItemProperties.Item.NO_ITEM)
	player_camera.add_child(equipped_item)
	equipped_item.hide()


func add_item(item: ItemProperties.Item, amount: int = 1):
	var hotkeys_full = hotkey_inventory.add_item(item, amount)
	if hotkeys_full:
		var inventory_full = inventory.add_item(item, amount)
		if inventory_full:
			print_text_to_screen("Inventory full")
	update_inventory_bindings()

func remove_item(item: ItemProperties.Item, amount: int = 1):
	var last_removed_hotkey_item = hotkey_inventory.remove_item(item, amount)
	if last_removed_hotkey_item:
		inventory.remove_item(item, amount)
	update_inventory_bindings()


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


func update_inventory_bindings():
	for slot in inventory.inventory_grid.get_children():
		slot.gui_input.connect(slot_gui_input.bind(slot))
	for slot in hotkey_inventory.inventory_grid.get_children():
		slot.gui_input.connect(slot_gui_input.bind(slot))


func print_text_to_screen(text: String):
	# Create a CanvasLayer so UI renders on top of everything
	var canvas = CanvasLayer.new()
	add_child(canvas)

	# Create the label
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 48)

	# Anchor to center of screen
	label.anchor_left = 0.5
	label.anchor_top = 0.5
	label.anchor_right = 0.5
	label.anchor_bottom = 0.5
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.offset_left = -200
	label.offset_right = 200
	label.offset_top = -30
	label.offset_bottom = 30
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	canvas.add_child(label)

	# Remove after 2 seconds
	await get_tree().create_timer(2.0).timeout
	canvas.queue_free()


# TODO: Handle equipped item
func slot_gui_input(event: InputEvent, slot: InventorySlot) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
		if held_item == null:
			if slot.item == ItemProperties.Item.NO_ITEM:
				return
			slot.set_picked_up()
			held_item = slot
		else:
			held_item.icon.position = Vector2.ZERO
			held_item.set_placed_down()
			slot.set_item(held_item.item, held_item.amount)
			slot.set_placed_down()
			if held_item != slot:
				held_item.set_empty()
			held_item = null


# TODO: This node gets paused when inventory is up
func _input(_event: InputEvent) -> void:
	if held_item:
		held_item.icon.position = get_global_mouse_position() - held_item.global_position - held_item.size / 2


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
