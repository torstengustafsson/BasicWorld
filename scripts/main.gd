extends Node3D

@onready var pause_menu = $PauseMenu
@onready var ground = $Ground/PlaneMesh

const Trees = preload("res://scripts/trees.gd")
const Bushes = preload("res://scripts/bushes.gd")

func _ready() -> void:
	pause_menu.node = self

	var size_x = ground.get_aabb().size.x
	var size_z = ground.get_aabb().size.z
	var step_trees = 10
	var step_berrybushes = 15

	var trees = Trees.new()
	trees.create_trees(size_x, size_z, step_trees)
	add_child(trees)

	var bushes = Bushes.new()
	bushes.create_berrybushes(size_x, size_z, step_berrybushes)
	add_child(bushes)
