extends Node3D

@onready var pause_menu = $PauseMenu
@onready var ground = $Ground/PlaneMesh
@onready var player = $Player

const Trees = preload("res://scripts/trees.gd")
const Bushes = preload("res://scripts/bushes.gd")
const ItemScript = preload("res://scripts/item.gd")
const Inventory = preload("res://scripts/inventory.gd")

var trees_script = Trees.new()
var bushes_script = Bushes.new()
var item_script = ItemScript.new()
@onready var player_inventory = Inventory.new($PauseMenu/Inventory/DisplayText)

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
	var axe = item_script.spawn_axe(axe_position)
	add_child(axe)



func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		interact_pressed()


func interact_pressed():
	const RAY_LENGTH = 1.5
	
	var space_state = get_world_3d().direct_space_state
	var cam = player.get_node("Head/Camera3D")
	var mousepos = get_viewport().get_mouse_position()

	var origin = cam.project_ray_origin(mousepos)
	var end = origin + cam.project_ray_normal(mousepos) * RAY_LENGTH
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true

	var result = space_state.intersect_ray(query)
	if not result:
		return

	var berries_picked = bushes_script.interact(result.collider)
	if berries_picked > 0:
		player_inventory.add_item("Berries")
		return

	var item_picked = item_script.interact(result.collider)
	if item_picked != "":
		player_inventory.add_item(item_picked)
