extends Node2D

class_name Inventory

@onready var inventory_grid: GridContainer = $InventoryGrid

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
