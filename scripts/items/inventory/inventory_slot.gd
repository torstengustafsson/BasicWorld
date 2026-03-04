extends Panel

class_name InventorySlot



var amount: int
var item: ItemProperties.Item
func max_stack_size() -> int:
	if item == ItemProperties.Item.NO_ITEM:
		return 0
	return ItemProperties.ITEMS[item].max_stack_size


@onready var icon = $TextureRect
@onready var amount_label = $AmountLabel

func _ready() -> void:
	set_item(ItemProperties.Item.NO_ITEM)
	custom_minimum_size = Vector2(50, 50)

func set_item(new_item: ItemProperties.Item, _amount: int = 0):
	icon.texture = ItemProperties.ITEMS[new_item].icon
	item = new_item
	amount = _amount
	amount_label.text = ""
	if amount > 0 and max_stack_size() > 1:
		amount_label.text = str(amount)

func add_amount(amount_to_add: int) -> int:
	if item == ItemProperties.Item.NO_ITEM or amount_to_add <= 0:
		return 0
	var leftover = amount_to_add - (max_stack_size() - amount)
	amount = min(amount + amount_to_add, max_stack_size())
	if max_stack_size() > 1:
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
		icon.texture = null
		amount_label.text = ""
	return max(-leftover, 0)

func set_empty():
	item = ItemProperties.Item.NO_ITEM
	amount = 0
	icon.texture = null
	amount_label.text = ""

func set_picked_up():
	icon.modulate = Color(0.5, 0.5, 0.5, 1.0)

func set_placed_down():
	icon.modulate = Color(1.0, 1.0, 1.0, 1.0)


func set_equipped():
	var style = StyleBoxTexture.new()
	style.texture = preload("res://assets/icons/items/slot_equipped.png")
	add_theme_stylebox_override("panel", style)

func set_unequipped():
	var style = StyleBoxTexture.new()
	style.texture = preload("res://assets/icons/items/slot.png")
	add_theme_stylebox_override("panel", style)
