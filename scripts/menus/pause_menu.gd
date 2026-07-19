class_name PauseMenu extends CanvasLayer

# TODO: This class should probably be refactored into a state machine

var settings_menu_open: bool = false
var inventory_open: bool = false
var world_map_open: bool = false

var save_load_state: SaveLoadState

var unpausable_nodes: Array[Node] = []

@onready var inventory_menu = $InventoryMenu
@onready var chest_inventory_menu = $InventoryMenu/ChestInventory
@onready var world_map = $WorldMap
@onready var settings_menu = $SettingsMenu
@onready var settings_submenu = $SettingsMenu/SettingsSubmenu
@onready var controls_submenu = $SettingsMenu/ControlsSubmenu
@onready var settings_savegame_button = $SettingsMenu/SettingsSubmenu/SaveGameButton
@onready var settings_loadgame_button = $SettingsMenu/SettingsSubmenu/LoadGameButton
@onready var settings_controls_button = $SettingsMenu/SettingsSubmenu/ControlsButton
@onready var settings_resumegame_button = $SettingsMenu/SettingsSubmenu/ResumeButton
@onready var settings_exitgame_button = $SettingsMenu/SettingsSubmenu/ExitGameButton
@onready var controls_back_button = $SettingsMenu/ControlsSubmenu/BackButton

func _ready() -> void:
	# This node and its subnodes is the only ones that is not paused on pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	inventory_menu.hide()
	world_map.hide()

	settings_savegame_button.connect("pressed", _save_game.bind())
	settings_loadgame_button.connect("pressed", _load_game.bind())
	settings_controls_button.connect("pressed", _open_controls_menu.bind())
	settings_resumegame_button.connect("pressed", _resume_game.bind())
	settings_exitgame_button.connect("pressed", _exit_game.bind())
	controls_back_button.connect("pressed", _open_settings_menu.bind())

func _add_save_load_state(_save_load_state: SaveLoadState):
	save_load_state = _save_load_state

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_settings"):
		if settings_menu_open || inventory_open || world_map_open:
			_resume_game()
		else:
			_open_settings_menu()

	if event.is_action_pressed("open_inventory") and !settings_menu_open and !world_map_open:
		if inventory_open:
			_resume_game()
		else:
			_open_inventory()

	if event.is_action_pressed("open_world_map") and !settings_menu_open and !inventory_open:
		if world_map_open:
			_resume_game()
		else:
			_open_world_map()

	if event is InputEventMouseButton and world_map_open:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			world_map.scroll(50.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			world_map.scroll(-50.0)

	if event.is_action_pressed("interact") and chest_inventory_menu.is_open():
		_resume_game()

func pause_game():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	show()
	get_tree().paused = true

func open_chest_inventory(chest_id: int):
	chest_inventory_menu.open_chest(chest_id)
	_open_inventory()

# Close all menus and unpause the game
func _resume_game() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	hide()
	inventory_menu.hide()
	chest_inventory_menu.close_chest()
	settings_menu_open = false
	inventory_open = false
	world_map_open = false
	get_tree().paused = false

func _open_settings_menu() -> void:
	pause_game()
	settings_menu.show()
	settings_submenu.show()
	controls_submenu.hide()
	inventory_menu.hide()
	world_map.hide()
	settings_menu_open = true

func _open_inventory() -> void:
	pause_game()
	settings_menu.hide()
	world_map.hide()
	inventory_menu.show()
	inventory_open = true

func _open_controls_menu() -> void:
	controls_submenu.show()
	settings_submenu.hide()

func _open_world_map() -> void:
	pause_game()
	settings_menu.hide()
	inventory_menu.hide()
	world_map.show()
	world_map.open()
	world_map_open = true

func _save_game():
	save_load_state.save_game()

func _load_game():
	save_load_state.load_game()
	_resume_game()

func _exit_game():
	get_tree().quit()
