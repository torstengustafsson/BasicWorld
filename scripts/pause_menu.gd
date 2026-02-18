extends CanvasLayer

var settings_menu_open: bool = false
var inventory_open: bool = false

@onready var inventory = $Inventory

func _ready() -> void:
	# This node and its subnodes is the only ones that is not paused on pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	inventory.hide()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("open_info"):
		if settings_menu_open || inventory_open:
			resume()
		else:
			open_settings_menu()

	if !settings_menu_open && Input.is_action_just_pressed("open_inventory"):
		if inventory_open:
			resume()
		else:
			open_inventory()

# Close all menus and unpause the game
func resume() -> void:
	hide()
	inventory.hide()
	settings_menu_open = false
	inventory_open = false
	get_tree().paused = false

func open_settings_menu() -> void:
	show()
	settings_menu_open = true
	get_tree().paused = true

func open_inventory() -> void:
	inventory.show()
	inventory_open = true
	get_tree().paused = true
