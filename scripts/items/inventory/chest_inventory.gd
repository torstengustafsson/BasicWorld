class_name ChestInventory extends Inventory

var rare_items: Dictionary[int, ItemProperties.Item] = {
	0: ItemProperties.Item.AXE,
	1: ItemProperties.Item.PICKAXE,
}

var common_items: Dictionary[int, ItemProperties.Item] = {
	0: ItemProperties.Item.BERRY,
	1: ItemProperties.Item.STONE,
	2: ItemProperties.Item.WOOD,
}
const NO_CHEST_OPEN: int = 9223372036854775807 # INT MAX
var currently_opened_chest: int = NO_CHEST_OPEN
var opened_chests: Dictionary[int, Dictionary] = {} # Dictionary[int, Dictionary[ItemProperties.Item, int]]

const MIN_CHEST_OPEN_TIME = 0.1
var chest_opened_time: int

func _init() -> void:
	inventory_size = Vector2i(3, 3)

func _ready() -> void:
	inventory_grid.columns = inventory_size.x
	for i in range(inventory_size.x * inventory_size.y):
		var slot = slot_scene.instantiate()
		inventory_grid.add_child(slot)
	for slot in inventory_grid.get_children():
		if not slot.is_connected("gui_input", Callable(self, "chest_slot_gui_input")):
			slot.gui_input.connect(chest_slot_gui_input.bind(slot))
	hide()

func open_chest(chest_id: int) -> void:
	currently_opened_chest = chest_id
	var chest_items = opened_chests.get(chest_id)
	if chest_items == null:
		var rare = _add_rare_items()
		var common = _add_common_items()
		chest_items = {}
		chest_items.merge(rare)
		chest_items.merge(common)
		opened_chests[chest_id] = chest_items
	_add_chest_inventory(chest_items)
	chest_opened_time = Time.get_ticks_msec()
	show()

func close_chest() -> void:
	currently_opened_chest = NO_CHEST_OPEN
	clear_inventory()
	hide()

func is_open() -> bool:
	var elapsed = (Time.get_ticks_msec() - chest_opened_time) / 1000.0
	return visible and elapsed > MIN_CHEST_OPEN_TIME

func _add_rare_items() -> Dictionary[ItemProperties.Item, int]:
	var result: Dictionary[ItemProperties.Item, int] = {}
	var num_items = 0 if randi_range(0, 10) < 8 else 1 # 20% chance to get a rare item
	for item in num_items:
		var rand_num = randi_range(0, rare_items.size() - 1)
		var item_type = rare_items.get(rand_num)
		if not item_type:
			print("Error: Bad rare item index for chest: ", rand_num)
			continue
		if result.has(item_type):
			result[item_type] += 1
		else:
			result[item_type] = 1
	return result

func _add_common_items() -> Dictionary[ItemProperties.Item, int]:
	var result: Dictionary[ItemProperties.Item, int] = {}
	var num_items = randi_range(2, 8)
	for item in num_items:
		var rand_num = randi_range(0, common_items.size() - 1)
		var item_type = common_items.get(rand_num)
		if not item_type:
			print("Error: Bad common item index for chest: ", rand_num)
			continue
		result[item_type] = result.get(item_type, 0) + 1
	return result

func _add_chest_inventory(items: Dictionary):
	for item in items:
		var amount = items[item]
		add_item(item, amount)

# This function is neccessary to store the modifications to the chest inventory for future openings of the chest
func chest_slot_gui_input(event: InputEvent, slot: InventorySlot) -> void:
	# TODO: It would be nice to also handle right click to instantly move items between inventory and chest
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MouseButton.MOUSE_BUTTON_LEFT):
		return
	var dropped_item: ItemProperties.Item = ItemProperties.Item.NO_ITEM
	var dropped_amount = 0
	if held_item:
		dropped_item = held_item.item
		dropped_amount = held_item.amount

	var update_happened = super.slot_gui_input(event, slot)
	if not update_happened:
		return

	var chest_items: Dictionary = opened_chests[currently_opened_chest]
	if not held_item: # If dropped, add the held item amount to the chest
		chest_items[dropped_item] = chest_items.get(dropped_item, 0) + dropped_amount
	else: # If item was lifted, remove that amount from the chest
		chest_items.erase(slot.item)
