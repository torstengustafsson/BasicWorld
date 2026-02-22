extends Node

# Base class for all character inventorys.
# Player inventory, NPC inventory, etc.
class_name Inventory

class ItemData:
	var amount: int

# Dictionary of item properties and amount
var inventory: Dictionary[ItemProperties.Item, ItemData]

func _add_item(item: ItemProperties.Item, amount: int = 1):
	print("add item " + str(item))
	if not inventory.has(item):
		inventory[item] = ItemData.new()
	inventory[item].amount += amount
	print(inventory.keys())

# Returns true if last item was removed
func _remove_item(item: ItemProperties.Item, amount: int = 1) -> bool:
	if inventory.has(item):
		var inventory_item: ItemData = inventory[item]
		inventory_item.amount -= amount
		if inventory_item.amount <= 0:
			inventory.erase(item)
			return true
	return false

func _save() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in inventory:
		var item_container = inventory[item]
		var data: Dictionary = {}
		data["id"] = item
		data["amount"] = item_container.amount
		result.append(data)
	return result


func _load(data: Array): # Cant be typed due to gdscript. Should be: Array[Dictionary]
	print("inventory before load: " + str(inventory.size()))
	inventory.clear()
	for item in data:
		var item_id: ItemProperties.Item = item["id"]
		inventory.get_or_add(item_id, ItemData.new())
		inventory[item["id"]].amount = item["amount"]
	print("inventory after load: " + str(inventory.size()))
