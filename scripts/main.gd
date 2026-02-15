extends Node3D

@onready var pause_menu = $PauseMenu
@onready var ground = $Ground/PlaneMesh
@onready var player = $Player

var trees_script = preload("res://scripts/trees.gd").new()
var bushes_script = preload("res://scripts/bushes.gd").new()
var world_items = preload("res://scripts/world_items.gd").new()
@onready var player_controls = preload("res://scripts/player_controls.gd").new(
	get_world_3d().direct_space_state,
	$PauseMenu/Inventory/DisplayText,
	player.get_node("Head/Camera3D"),
	world_items,
	bushes_script)

var trees
var berrybushes

func _ready() -> void:
	var size_x = ground.get_aabb().size.x
	var size_z = ground.get_aabb().size.z
	var margin = 5.0
	var step_trees = 5
	var step_berrybushes = 15

	var start_pos_x = size_x / 2 - size_x + margin
	var start_pos_z = size_z / 2 - size_z + margin
	var size_x_margin = size_x - 2 * margin
	var size_z_margin = size_z - 2 * margin

	trees_script.create_trees(start_pos_x, start_pos_z, size_x_margin, size_z_margin, step_trees)
	add_child(trees_script)

	bushes_script.create_berrybushes(start_pos_x, start_pos_z, size_x_margin, size_z_margin, step_berrybushes)
	add_child(bushes_script)

	#var axe_position = Vector3(randf_range(start_pos_x, start_pos_x + size_x_margin), 5.0, randf_range(start_pos_z, start_pos_z + size_z_margin))
	var axe_position = Vector3(0.0, 5.0, -3.0)
	world_items.spawn_item(axe_position, ItemProperties.AXE_ITEM)

	var berry_position = Vector3(0.0, 10.0, -4.0)
	world_items.spawn_item(berry_position, ItemProperties.BERRY_ITEM)

	var wood_position = Vector3(2.0, 5.0, -4.0)
	world_items.spawn_item(wood_position, ItemProperties.WOOD_ITEM)

	add_child(world_items)

	add_child(player_controls)
