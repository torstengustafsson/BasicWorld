extends Node3D

@onready var ground = $Ground
@onready var player = $Player



@onready var game_world: GameWorld = GameWorld.new(ground)

@onready var player_controls: PlayerControls = PlayerControls.new(
	get_world_3d().direct_space_state,
	$PauseMenu/InventoryMenu/Inventory,
	player.get_node("Head/Camera3D"),
	game_world,
)

func _ready() -> void:
	add_child(game_world)
	add_child(player_controls)
