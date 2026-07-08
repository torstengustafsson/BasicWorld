# Based on: https://www.youtube.com/watch?v=FHYb63ppHmk&list=PLY1jY0hbmKxBvcEHa0k5Aw8_MKoB6jrRU
class_name Inventory extends Node2D

@onready var inventory_grid: GridContainer = $InventoryGrid

# When player is moving items in the inventory, this is the item that is being held.
# Only one item can be held at a time. Need to handle moving between multiple inventories
static var held_item: InventorySlot = null

var slot_scene = preload("res://scenes/inventory/inventory_slot.tscn")
var inventory_size: Vector2i = Vector2i(8, 4)
var total_items_amount: Dictionary[ItemProperties.Item, int] = {}

func _ready() -> void:
	inventory_grid.columns = inventory_size.x
	for i in range(inventory_size.x * inventory_size.y):
		var slot = slot_scene.instantiate()
		inventory_grid.add_child(slot)

func clear_inventory():
	for i in inventory_grid.get_child_count():
		var slot: InventorySlot = inventory_grid.get_child(i)
		slot.item = ItemProperties.Item.NO_ITEM
		slot.amount = 0
	total_items_amount.clear()
	for slot in inventory_grid.get_children():
		slot.set_empty()

func add_item(item: ItemProperties.Item, amount_to_add: int) -> bool:
	total_items_amount[item] = total_items_amount.get(item, 0) + amount_to_add

	# Start by adding to existing stacks
	for i in inventory_grid.get_child_count():
		var slot: InventorySlot = inventory_grid.get_child(i)
		if slot.item == item and slot.amount < slot.max_stack_size():
			var leftover = slot.add_amount(amount_to_add)
			if leftover <= 0:
				return false
			amount_to_add = leftover

	# If there are still items left to add, add them to empty slots
	for slot in inventory_grid.get_child_count():
		var inventory_item: InventorySlot = inventory_grid.get_child(slot)
		if inventory_item.item == ItemProperties.Item.NO_ITEM:
			inventory_item.item = item
			inventory_item.set_item(item)
			var leftover = inventory_item.add_amount(amount_to_add)
			if leftover <= 0:
				return false
			amount_to_add = leftover

	# Inventory is full
	return true

# Returns true if last item was removed
func remove_item(item: ItemProperties.Item, amount_to_remove: int = 1) -> bool:
	total_items_amount[item] = max(total_items_amount.get(item, 0) - amount_to_remove, 0)
	for i in range(inventory_grid.get_children().size() - 1, -1, -1):
		var slot: InventorySlot = inventory_grid.get_children()[i]
		if slot.item == item:
			var leftover = slot.remove_amount(amount_to_remove)
			if leftover <= 0:
				break
			amount_to_remove = leftover
	return total_items_amount[item] == 0

func update_grid():
	for i in inventory_size.x:
		for j in inventory_size.y:
			var index = i * inventory_size.y + j
			if index < inventory_grid.get_children().size():
				var item = inventory_grid.get_children()[index]
				if item.item != ItemProperties.Item.NO_ITEM:
					# Update the UI for this item, e.g. show the item icon and amount
					pass

func _input(_event: InputEvent) -> void:
	if held_item:
		held_item.icon.position = get_global_mouse_position() - held_item.global_position - held_item.size / 2
		held_item.amount_label.position = get_global_mouse_position() - held_item.global_position - held_item.size / 2 + InventorySlot.AMOUNT_TEXT_POSITION

# Return true if inventory state was changed
static func slot_gui_input(event: InputEvent, slot: InventorySlot) -> bool:
	# Held item should show amount
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MouseButton.MOUSE_BUTTON_LEFT):
		return false
	if not held_item: # Pick up item
		if slot.item == ItemProperties.Item.NO_ITEM:
			return false
		slot.set_picked_up()
		held_item = slot
		return true
	else: # Put held item back on a slot
		if slot.item == ItemProperties.Item.NO_ITEM: # Free slot, simply place it there
			slot.set_item(held_item.item, held_item.amount)
			slot.set_placed_down()
			held_item.set_empty()
			_reset_held_item()
			return true
		else: # Item is put back on occupied slot
			if held_item == slot: # Same slot it was picked up from, simply place it back
				slot.set_item(held_item.item, held_item.amount)
				slot.set_placed_down()
				_reset_held_item()
				return false
			if slot.item == held_item.item: # Same item type, can add to stack
				var leftover = slot.add_amount(held_item.amount)
				held_item.amount = leftover
				if leftover <= 0:
					slot.item = held_item.item
					slot.set_placed_down()
					held_item.set_empty()
					_reset_held_item()
				return true
		return false # Otherwise, slot contains another item type, in which case nothing happens

static func _reset_held_item():
	held_item.icon.position = Vector2.ZERO
	held_item.set_placed_down()
	held_item = null

func _save() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(inventory_grid.get_children().size()):
		var slot: InventorySlot = inventory_grid.get_children()[i]
		var data: Dictionary = {}
		data["id"] = slot.item
		data["amount"] = slot.amount
		result.append(data)
	return result


func _load(data: Array): # Cant be typed due to gdscript. Should be: Array[Dictionary]
	clear_inventory()
	for item in data:
		var item_id: ItemProperties.Item = item["id"]
		var slot: InventorySlot = slot_scene.instantiate()
		slot.item = item_id
		slot.amount = item["amount"]
		inventory_grid.add_child(slot)
