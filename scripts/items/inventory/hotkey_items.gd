extends Inventory

class_name HotkeyItems

const NO_EQUIPPED_ITEM = -1
var equipped_item_index: int = NO_EQUIPPED_ITEM

func _ready() -> void:
	inventory_size = Vector2i(8, 1)
	inventory_grid.columns = inventory_size.x
	for i in range(inventory_size.x * inventory_size.y):
		var slot = slot_scene.instantiate()
		inventory_grid.add_child(slot)

func set_equipped_item_index(item_index: int) -> void:
	if item_index >= inventory_size.x * inventory_size.y or item_index < 0:
		for slot in inventory_grid.get_children():
			slot.set_unequipped()
		equipped_item_index = NO_EQUIPPED_ITEM
		return
	if equipped_item_index != NO_EQUIPPED_ITEM:
		inventory_grid.get_child(equipped_item_index).set_unequipped()
	equipped_item_index = item_index
	inventory_grid.get_child(equipped_item_index).set_equipped()

func remove_equipped_item(amount: int = 1):
	if equipped_item_index != NO_EQUIPPED_ITEM:
		var slot: InventorySlot = inventory_grid.get_children()[equipped_item_index]
		var leftover = slot.remove_amount(amount)
		if leftover <= 0:
			equipped_item_index = NO_EQUIPPED_ITEM
			slot.set_unequipped()

func get_equipped_item_slot() -> InventorySlot:
	if equipped_item_index == NO_EQUIPPED_ITEM:
		return null
	return inventory_grid.get_child(equipped_item_index)
