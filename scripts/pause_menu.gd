extends CanvasLayer

var settings_menu_open: bool = false
var inventory_open: bool = false

@onready var inventory = $Inventory
@onready var settings_menu = $SettingsMenu
@onready var settings_controls_button = $SettingsMenu/ControlsButton
@onready var settings_resumegame_button = $SettingsMenu/ResumeButton
@onready var settings_exitgame_button = $SettingsMenu/ExitGameButton
@onready var controls_submenu = $SettingsMenu/ControlsSubmenu
@onready var controls_back_button = $SettingsMenu/ControlsSubmenu/BackButton

func _ready() -> void:
	# This node and its subnodes is the only ones that is not paused on pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	inventory.hide()

	settings_controls_button.connect("pressed", _open_controls_menu.bind())
	settings_resumegame_button.connect("pressed", _resume_game.bind())
	settings_exitgame_button.connect("pressed", _exit_game.bind())
	controls_back_button.connect("pressed", _open_settings_menu.bind())


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("open_settings"):
		if settings_menu_open || inventory_open:
			_resume_game()
		else:
			_open_settings_menu()

	if !settings_menu_open && Input.is_action_just_pressed("open_inventory"):
		if inventory_open:
			_resume_game()
		else:
			_open_inventory()

# Close all menus and unpause the game
func _resume_game() -> void:
	hide()
	inventory.hide()
	settings_menu_open = false
	inventory_open = false
	get_tree().paused = false

func _open_settings_menu() -> void:
	show()
	settings_menu.show()
	settings_controls_button.show()
	settings_resumegame_button.show()
	settings_exitgame_button.show()
	controls_submenu.hide()
	inventory.hide()
	settings_menu_open = true
	get_tree().paused = true

func _open_inventory() -> void:
	show()
	settings_menu.hide()
	inventory.show()
	inventory_open = true
	get_tree().paused = true

func _open_controls_menu() -> void:
	controls_submenu.show()
	settings_controls_button.hide()
	settings_resumegame_button.hide()
	settings_exitgame_button.hide()

func _exit_game():
	get_tree().quit()
