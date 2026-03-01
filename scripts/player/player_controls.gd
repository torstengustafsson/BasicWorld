extends Node

class_name PlayerControls

var space_state: PhysicsDirectSpaceState3D
var player_camera: Camera3D
var player_inventory: PlayerInventory
var game_world: GameWorld

func _init(
	_space_state: PhysicsDirectSpaceState3D,
	inventory: Node2D,
	_player_camera: Camera3D,
	_game_world: GameWorld,
):
	space_state = _space_state
	player_camera = _player_camera
	player_inventory = PlayerInventory.new(inventory, player_camera)
	game_world = _game_world
	add_child(player_inventory)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		handle_interaction()
	if event.is_action_pressed("use_item"):
		var item_already_in_hand = player_inventory.use_equipped_item()
		if item_already_in_hand:
			handle_use_item()
	if event.is_action_pressed("put_away_item"):
			player_inventory.put_away_equipped_item()
	if event.is_action_pressed("hotkey_1"):
			player_inventory.equip_item_index(0)
	if event.is_action_pressed("hotkey_2"):
			player_inventory.equip_item_index(1)
	if event.is_action_pressed("hotkey_3"):
			player_inventory.equip_item_index(2)


func handle_interaction():
	const RAY_LENGTH = 1.8
	var mousepos = get_viewport().get_mouse_position()
	var origin = player_camera.project_ray_origin(mousepos)
	var end = origin + player_camera.project_ray_normal(mousepos) * RAY_LENGTH
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true

	var result = space_state.intersect_ray(query)
	if not result:
		return

	var interact_result: GameWorld.InteractResult = game_world.interact(result.collider, player_inventory.equipped_item.item_id)
	match interact_result.result:
		GameWorld.InteractResults.GainItem:
			player_inventory.add_item(interact_result.item)
		GameWorld.InteractResults.DeleteEquippedItem:
			player_inventory.delete_equipped_item()


func handle_use_item():
	const RAY_LENGTH = 1.8
	var mousepos = get_viewport().get_mouse_position()
	var origin = player_camera.project_ray_origin(mousepos)
	var end = origin + player_camera.project_ray_normal(mousepos) * RAY_LENGTH
	var query = PhysicsRayQueryParameters3D.create(origin, end)

	var result = space_state.intersect_ray(query)
	if not result:
		return

	game_world.handle_use_item(result.collider, player_inventory.equipped_item.item_id)
