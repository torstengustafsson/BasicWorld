extends Inventory

class_name HotkeyedInventory

func _init() -> void:
	inventory_size = Vector2i(8, 1)
	columns = inventory_size.x
	position = Vector2(350, 450)
	size = Vector2(450, 50)
	add_theme_constant_override("h_separation", 10)
	add_theme_constant_override("v_separation", 10)

	for i in range(inventory_size.x * inventory_size.y):
		inventory_items.append(InventoryItem.new(ItemProperties.Item.NO_ITEM))
		add_child(inventory_items[i])
