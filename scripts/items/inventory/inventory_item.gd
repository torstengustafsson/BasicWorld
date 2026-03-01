extends Panel

class_name InventoryItem

var amount: int
var max_stack_size: int
var item: ItemProperties.Item

func _init(_item: ItemProperties.Item) -> void:
	item = _item
	amount = 0
	max_stack_size = 1
	custom_minimum_size = Vector2(50, 50)

func add_amount(amount_to_add: int) -> int:
	if amount_to_add <= 0:
		return 0
	var leftover = amount_to_add - (max_stack_size - amount)
	amount = min(amount + amount_to_add, max_stack_size)
	return leftover
