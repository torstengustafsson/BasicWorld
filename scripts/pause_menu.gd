extends CanvasLayer

# Container for the parent node
var node: Node

# Keeps track of whether the pause menu can be resumed
# This is set to true, when ESC has been released after being
# pressed in the parent node
# If we didn't do this, the pause menu would immediately resume
# because both instances recognize the ESC key is down
var is_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Start by ensuring the pause menu is hidden
	hide()

func _process(_delta: float) -> void:
	# If the ESC button has been released since being pressed in the parent
	# node (can_resume), and ESC is now pressed again, we resume the game
	if Input.is_action_just_pressed("ui_cancel"):
		if is_paused:
			resume()
		else:
			pause()


# Resume the game by hiding the pause menu and unpausing the parent node's tree
func resume() -> void:
	hide()
	is_paused = false
	node.get_tree().paused = false

# Pause game by showing the menu and pausing the parent node's tree
func pause() -> void:
	show()
	is_paused = true
	node.get_tree().paused = true
