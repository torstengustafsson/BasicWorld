extends Node

# Base class for all character inventorys.
# Player inventory, NPC inventory, etc.
class_name Inventory

class _ItemContainer:
	var item: ItemProperties
	var amount: int

# Dictionary of item properties and amount
var inventory: Dictionary[String, _ItemContainer]

func _add_item(item: ItemProperties, amount: int = 1):
	inventory.get_or_add(item.name_singular, _ItemContainer.new())
	inventory[item.name_singular].item = item
	inventory[item.name_singular].amount += 1

# Returns true if last item was removed
func _remove_item(item: ItemProperties, amount: int = 1) -> bool:
	if inventory.has(item.name_singular):
		var inventory_item: _ItemContainer = inventory[item.name_singular]
		inventory_item.amount -= amount
		if inventory_item.amount <= 0:
			inventory.erase(inventory_item.item.name_singular)
			return true
	return false
