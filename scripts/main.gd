extends Node3D

@onready var pause_menu = $PauseMenu
@onready var ground = $Ground/PlaneMesh
@onready var player = $Player

const TreesScript = preload("res://scripts/trees.gd")
const BushesScript = preload("res://scripts/bushes.gd")

var trees_script = TreesScript.new()
var bushes_script = BushesScript.new()

var trees
var berrybushes

func _ready() -> void:
	pause_menu.node = self

	var size_x = ground.get_aabb().size.x
	var size_z = ground.get_aabb().size.z
	var margin = 5.0
	var step_trees = 5
	var step_berrybushes = 15

	trees_script.create_trees(size_x, size_z, margin, step_trees)
	add_child(trees_script)

	bushes_script.create_berrybushes(size_x, size_z, margin, step_berrybushes)
	add_child(bushes_script)

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
	# TODO: How to access berry bush from here?
	print(result)
	bushes_script.interact(result.collider)
