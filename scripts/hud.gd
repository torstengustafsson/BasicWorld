extends Node

var time_played = 0.0
var last_whole_second: int = 0

var top_left: Node
var mobile_controls: Node2D


func _ready():
	top_left = get_node("TopLeftArea")
	top_left.get_node("CurrentPlayTime").text = str(last_whole_second)
	top_left.get_node("CurrentFPS").text = str(0.0)
	top_left.get_node("CurrentScreenSize").text = str(get_viewport().get_visible_rect().size)

	mobile_controls = get_node("MobileControls")
	if true or OS.get_name() == "Web" and DisplayServer.is_touchscreen_available():
		create_mobile_controls()

	# TODO: Pause not handled. Game hangs forever.
	#bottom_left.get_node("Inventory").button_down.connect(_trigger_event_pressed.bind("open_inventory"))
	#bottom_left.get_node("Inventory").button_up.connect(_trigger_event_released.bind("open_inventory"))

func _process(delta: float):
	time_played += delta
	if floor(time_played) > last_whole_second:
		last_whole_second = floor(time_played)
		top_left.get_node("CurrentPlayTime").text = str(last_whole_second)

	top_left.get_node("CurrentFPS").text = str(snapped(1 / delta, 0.01))

func create_mobile_controls():
		var screen = get_viewport().get_visible_rect().size
		_create_label(Vector2(65, screen.y - 90), "Move")
		_create_button(Vector2(70, screen.y - 130), "", "ui_up")
		_create_button(Vector2(70, screen.y - 60), "", "ui_down")
		_create_button(Vector2(10, screen.y - 100), "", "ui_left")
		_create_button(Vector2(130, screen.y - 100), "", "ui_right")

		_create_button(Vector2(200, screen.y - 100), "Interact", "interact")
		_create_button(Vector2(300, screen.y - 100), "Equipped Use", "use_item")
		_create_button(Vector2(450, screen.y - 100), "Equipped Put Away", "put_away_item")
		_create_button(Vector2(650, screen.y - 100), "Equip 1", "hotkey_1")
		_create_button(Vector2(725, screen.y - 100), "Equip 2", "hotkey_2")
		_create_button(Vector2(800, screen.y - 100), "Equip 3", "hotkey_3")

		# TODO: Need to handle pause game. Currently hangs forever
		# _create_button(Vector2(130, screen.y - 100), "inventory")

func _create_label(position: Vector2, text: String):
	var label: Label = Label.new()
	label.position = position
	label.add_theme_font_size_override("font_size", 24)
	label.text = text
	add_child(label)

func _create_button(position: Vector2, text: String, event: String):
	var button: Button = Button.new()
	button.position = position
	button.size = Vector2(50, 50)
	button.text = text
	button.button_down.connect(_trigger_event_pressed.bind(event))
	button.button_up.connect(_trigger_event_released.bind(event))
	add_child(button)

func _trigger_event_pressed(event: String):
	var triggered_event = InputEventAction.new()
	triggered_event.action = event
	triggered_event.pressed = true
	Input.parse_input_event(triggered_event)

func _trigger_event_released(event: String):
	var triggered_event = InputEventAction.new()
	triggered_event.action = event
	triggered_event.pressed = false
	Input.parse_input_event(triggered_event)
