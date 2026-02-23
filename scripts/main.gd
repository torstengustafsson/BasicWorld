extends Node3D

@onready var ground = $Ground/PlaneMesh
@onready var player = $Player

var world_items = preload("res://scripts/items/world_items.gd").new()
var trees_script = preload("res://scripts/objects/create_trees.gd").new(world_items)
var bushes_script = preload("res://scripts/objects/create_bushes.gd").new()
var houses_script = preload("res://scripts/objects/create_houses.gd").new()
var npcs_script = preload("res://scripts/objects/npcs.gd").new()
@onready var player_controls = preload("res://scripts/player/player_controls.gd").new(
	get_world_3d().direct_space_state,
	$PauseMenu/InventoryMenu/InventoryText,
	player.get_node("Head/Camera3D"),
	world_items,
	bushes_script,
	trees_script,
	npcs_script)

var trees
var berrybushes

func _ready() -> void:
	var size_x = ground.get_aabb().size.x
	var size_z = ground.get_aabb().size.z
	var margin = 5.0
	var step_trees = 5
	var step_berrybushes = 15
	var step_houses = 75

	var start_pos_x = size_x / 2 - size_x + margin
	var start_pos_z = size_z / 2 - size_z + margin
	var end_pos_x = size_x / 2 - margin
	var end_pos_z = size_z / 2 - margin

	trees_script.create_trees(start_pos_x, start_pos_z, end_pos_x, end_pos_z, step_trees)
	add_child(trees_script)

	bushes_script.create_berrybushes(start_pos_x, start_pos_z, end_pos_x, end_pos_z, step_berrybushes)
	add_child(bushes_script)

	houses_script.create_settlements(start_pos_x, start_pos_z, end_pos_x, end_pos_z, step_houses)
	add_child(houses_script)

	var num_npcs = 25
	npcs_script.create_npcs(start_pos_x, start_pos_z, end_pos_x, end_pos_z, num_npcs)
	add_child(npcs_script)

	#var axe_position = Vector3(randf_range(start_pos_x, start_pos_x + size_x_margin), 5.0, randf_range(start_pos_z, start_pos_z + size_z_margin))
	var axe_position = Vector3(0.0, 2.0, -4.0)
	world_items.spawn_item(axe_position, ItemProperties.Item.AXE)

	for berry in 5:
		var berry_position = Vector3(randf_range(start_pos_x, end_pos_z), 5.0, randf_range(start_pos_z, end_pos_z))
		world_items.spawn_item(berry_position, ItemProperties.Item.BERRY)

	for wood in 5:
		var wood_position = Vector3(randf_range(start_pos_x, end_pos_x), 5.0, randf_range(start_pos_z, end_pos_z))
		world_items.spawn_item(wood_position, ItemProperties.Item.WOOD)

	add_child(world_items)

	add_child(player_controls)
