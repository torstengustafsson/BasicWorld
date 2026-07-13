extends CanvasLayer

class_name DialogueMenu

enum DialogueAction { YouTalk, TheOtherOneTalk, Exit }

class Dialogue:
	var text: String
	var response_options: Array = []
	var action = DialogueAction.YouTalk
	func _init(_text: String, _action: DialogueAction) -> void:
		text = _text
		action = _action

var player: CharacterBody3D
var player_controls: PlayerControls

var response_buttons: Array[Button] = [Button.new(), Button.new(), Button.new()]

func _ready() -> void:
	# This node and its subnodes is the only ones that is not paused on pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

func open_dialogue(dialogue: Dialogue):
	player.set_process_unhandled_input(false)
	player_controls.set_process_input(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_show_dialogue(dialogue)
	show()

func close_dialogue():
	player.set_process_unhandled_input(true)
	player_controls.set_process_input(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	hide()

func _show_dialogue(dialogue: Dialogue):
	_reset_buttons(dialogue.response_options.size())
	$Background/TextArea/Label.text = dialogue.text
	for i in dialogue.response_options.size():
		var response = dialogue.response_options[i]
		if i >= response_buttons.size():
			return
		response_buttons[i].text = response.text
		response_buttons[i].pressed.connect(_on_response_button_pressed.bind(response))

func _on_response_button_pressed(dialogue: Dialogue) -> void:
	if dialogue.action == DialogueAction.YouTalk:
		if not dialogue.response_options.size() == 1:
			print("Error: NPC response does not have exactly one response (responses=", dialogue.response_options.size(), "):")
			for response in dialogue.response_options:
				print("  ", response.text)
			return
		_show_dialogue(dialogue.response_options[0])
	if dialogue.action == DialogueAction.Exit:
		close_dialogue()

func _reset_buttons(num_buttons: int):
	for i in response_buttons.size():
		if response_buttons[i].pressed.is_connected(_on_response_button_pressed):
			response_buttons[i].pressed.disconnect(_on_response_button_pressed)
		if response_buttons[i].get_parent() == $Background:
			$Background.remove_child(response_buttons[i])
	for i in min(num_buttons, response_buttons.size()):
		var button = response_buttons[i]
		button.position = Vector2(0, 0)
		button.size = Vector2(300, 32)
		button.anchor_left = 0.5
		button.position.x -= button.size.x / 2.0
		button.anchor_top = 0.52
		button.position.y += i * (button.size.y + 5)

		$Background.add_child(button)
