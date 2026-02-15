extends Node

# Dictionay of item name and amount
var inventory: Dictionary[String, int]

var inventoryText

func _init(_inventoryText):
	inventoryText = _inventoryText
	update_inventory()

func add_item(item_name: String):
	inventory.get_or_add(item_name, 0)
	inventory[item_name] += 1
	update_inventory()

func update_inventory():
	var text: String = "YOUR ITEMS\n"
	for item_name in inventory:
		text += item_name
		text += ": " 
		text += str(inventory[item_name])
		text += "\n"
	inventoryText.text = text
