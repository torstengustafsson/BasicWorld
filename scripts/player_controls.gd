extends Node

var space_state: PhysicsDirectSpaceState3D
var player_camera: Camera3D
var player_inventory: PlayerInventory
var world_items: WorldItems
var bushes_script: Bushes

func _init(_space_state, _inventory_text, _player_camera, _world_items, _bushes_script):
	space_state = _space_state
	player_camera = _player_camera
	player_inventory = preload("res://scripts/player_inventory.gd").new(_inventory_text, player_camera, world_items)
	world_items = _world_items
	bushes_script = _bushes_script
	add_child(player_inventory)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		interact_pressed()
	if event.is_action_pressed("use_item"):
		player_inventory.use_equipped_item()
	if event.is_action_pressed("put_away_item"):
			player_inventory.put_away_equipped_item()


func interact_pressed():
	const RAY_LENGTH = 1.8
	
	var mousepos = get_viewport().get_mouse_position()

	var origin = player_camera.project_ray_origin(mousepos)
	var end = origin + player_camera.project_ray_normal(mousepos) * RAY_LENGTH
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true

	var result = space_state.intersect_ray(query)
	if not result:
		return

	var berries_picked = bushes_script.interact(result.collider)
	if berries_picked > 0:
		player_inventory.add_item(ItemProperties.BERRY_ITEM)
		return

	var item_picked = world_items.interact(result.collider)
	if item_picked:
		player_inventory.add_item(item_picked)
