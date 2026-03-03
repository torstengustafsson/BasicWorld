extends Inventory

class_name HotkeyedInventory

func _ready() -> void:
	inventory_size = Vector2i(8, 1)
	grid_container.columns = inventory_size.x
	position = Vector2(350, 455)
	for i in range(inventory_size.x * inventory_size.y):
		var slot = slot_scene.instantiate()
		grid_container.add_child(slot)
