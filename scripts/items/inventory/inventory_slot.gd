extends Panel

class_name InventorySlot

var amount: int
var max_stack_size: int
var item: ItemProperties.Item

@onready var icon = $TextureRect
@onready var amount_label = $AmountLabel

func _ready() -> void:
	set_item(ItemProperties.Item.NO_ITEM)
	custom_minimum_size = Vector2(50, 50)

func set_item(new_item: ItemProperties.Item):
	if new_item == ItemProperties.Item.NO_ITEM:
		icon.texture = null
		amount = 0
		max_stack_size = 1
	else:
		if ItemProperties.ITEMS[new_item].icon == null:
			print("No icon!")
			return

		icon.texture = ItemProperties.ITEMS[new_item].icon
		max_stack_size = ItemProperties.ITEMS[new_item].max_stack_size

func add_amount(amount_to_add: int) -> int:
	if item == ItemProperties.Item.NO_ITEM or amount_to_add <= 0:
		return 0
	var leftover = amount_to_add - (max_stack_size - amount)
	amount = min(amount + amount_to_add, max_stack_size)
	if max_stack_size > 1:
		amount_label.text = str(amount)
	return leftover

func remove_amount(amount_to_remove: int) -> int:
	if item == ItemProperties.Item.NO_ITEM or amount <= 0:
		return amount_to_remove
	var leftover = max(-(amount - amount_to_remove), 0)
	amount = max(amount - amount_to_remove, 0)
	amount_label.text = str(amount)
	if amount == 0:
		item = ItemProperties.Item.NO_ITEM
		amount_label.text = ""
	return max(-leftover, 0)
