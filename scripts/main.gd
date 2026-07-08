extends Node3D

@onready var player = $Player
@onready var dialogue_menu = $DialogueMenu

@onready var hotkey_menu = preload("res://scenes/inventory/hotkey_items.tscn").instantiate()


@onready var game_world: GameWorld = GameWorld.new(player)

@onready var player_controls: PlayerControls = PlayerControls.new(
	player.get_node("Head/Camera3D"),
	$PauseMenu,
	hotkey_menu,
	dialogue_menu,
	game_world,
)

func _ready() -> void:
	dialogue_menu.player = player
	dialogue_menu.player_controls = player_controls
	add_child(game_world)
	add_child(player_controls)
	$PauseMenu.unpausable_nodes.append(player_controls)
