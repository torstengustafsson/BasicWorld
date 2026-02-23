extends Node3D

@onready var ground = $Ground/PlaneMesh
@onready var player = $Player

var world_item_generator = WorldItemGenerator.new()
var tree_generator = TreeGenerator.new()
var bush_generator = BushGenerator.new()
var settlement_generator = SettlementGenerator.new()
var npcs_generator = NpcGenerator.new()


@onready var game_world: GameWorld = GameWorld.new(
	ground,
	world_item_generator,
	bush_generator,
	tree_generator,
	npcs_generator,
	settlement_generator,
)

@onready var player_controls: PlayerControls = PlayerControls.new(
	get_world_3d().direct_space_state,
	$PauseMenu/InventoryMenu/InventoryText,
	player.get_node("Head/Camera3D"),
	game_world,
)

func _ready() -> void:
	add_child(game_world)
	add_child(player_controls)
