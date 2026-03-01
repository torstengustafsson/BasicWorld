extends GridContainer

class_name Inventory

var inventory_size: Vector2i = Vector2i(8, 5)

var inventory_items: Array[InventoryItem] = []
var total_items_amount: Dictionary[ItemProperties.Item, int] = {}

func _init() -> void:
	columns = inventory_size.x
	position = Vector2(350, 125)
	size = Vector2(450, 275)
	add_theme_constant_override("h_separation", 10)
	add_theme_constant_override("v_separation", 10)

	for i in range(inventory_size.x * inventory_size.y):
		inventory_items.append(InventoryItem.new(ItemProperties.Item.NO_ITEM))
		add_child(inventory_items[i])

func _add_item(item: ItemProperties.Item, amount: int):
	total_items_amount[item] = total_items_amount.get(item, 0) + amount
	for i in range(inventory_items.size()):
		var inventory_item: InventoryItem = inventory_items[i]
		if inventory_item.item == item and inventory_item.amount < inventory_item.max_stack_size:
			var leftover = inventory_item.add_amount(amount)
			if leftover <= 0:
				return
			amount = leftover
		if inventory_item.item == ItemProperties.Item.NO_ITEM:
			inventory_item.item = item
			var leftover = inventory_item.add_amount(amount)
			if leftover <= 0:
				return
			amount = leftover

# Returns true if last item was removed
func _remove_item(item: ItemProperties.Item, amount: int = 1) -> bool:
	total_items_amount[item] = max(total_items_amount.get(item, 0) - amount, 0)
	for i in range(inventory_items.size() - 1, -1, -1):
		var inventory_item: InventoryItem = inventory_items[i]
		if inventory_item.item == item:
			inventory_item.amount -= amount
			if inventory_item.amount <= 0:
				inventory_items[i] = InventoryItem.new(ItemProperties.Item.NO_ITEM)
	return total_items_amount[item] <= 0

func update_grid():
	for i in inventory_size.x:
		for j in inventory_size.y:
			var index = i * inventory_size.y + j
			if index < inventory_items.size():
				var item = inventory_items[index]
				if item.item != ItemProperties.Item.NO_ITEM:
					# Update the UI for this item, e.g. show the item icon and amount
					pass

func _save() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in inventory_items:
		var item_container = item
		var data: Dictionary = {}
		data["id"] = item_container.item
		data["amount"] = item_container.amount
		result.append(data)
	return result


func _load(data: Array): # Cant be typed due to gdscript. Should be: Array[Dictionary]
	inventory_items.clear()
	for item in data:
		var item_id: ItemProperties.Item = item["id"]
		var new_item: InventoryItem = InventoryItem.new(item_id)
		new_item.amount = item["amount"]
		inventory_items.append(new_item)
