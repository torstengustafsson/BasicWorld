extends Node3D

var save_load_state: SaveLoadState
@onready var player = $Player
@onready var dialogue_menu = $DialogueMenu
@onready var world_map = $PauseMenu/WorldMap
@onready var minimap = $HUD/Minimap
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
	save_load_state = SaveLoadState.new(game_world, player_controls.player_inventory)
	dialogue_menu.player = player
	dialogue_menu.player_controls = player_controls
	add_child(game_world)
	add_child(player_controls)
	$PauseMenu.unpausable_nodes.append(player_controls)
	$PauseMenu._add_save_load_state(save_load_state)
	world_map.set_player(player)
	world_map.setup(WorldState.state.terrain_height_noise, WorldState.state.object_manager.forest_noise)
	minimap.setup(WorldState.state.terrain_height_noise, WorldState.state.object_manager.forest_noise)

func _process(_delta: float) -> void:
	minimap.update_map(player.position, -player.rotation.y)
	minimap.update_overlay_data(WorldState.state.settlement_manager.settlements.query_all(), WorldState.state.road_manager.road_segments.query_all())
