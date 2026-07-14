# Based on https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html
class_name SaveLoadState extends RefCounted

const SAVE_LOCATION: String = "user://basicworld.save"

var game_world: GameWorld # Reference
var player_inventory: PlayerInventory # Reference

func _init(_game_world: GameWorld, _player_inventory: PlayerInventory) -> void:
	game_world = _game_world
	player_inventory = _player_inventory

func save_game():
	var save_file = FileAccess.open(SAVE_LOCATION, FileAccess.WRITE)
	print("Saving game to path ", save_file.get_path_absolute())

	var result: Dictionary = {}
	result["game_world"] = game_world.save()
	result["player_inventory"] = player_inventory.save()
	var json_string = JSON.stringify(result)
	save_file.store_line(json_string)

func load_game():
	if not FileAccess.file_exists(SAVE_LOCATION):
		return # Error! We don't have a save to load.

	var save_file = FileAccess.open(SAVE_LOCATION, FileAccess.READ)
	while save_file.get_position() < save_file.get_length():
		var json_string = save_file.get_line()
		var json = JSON.new()
		if json.parse(json_string) != OK:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			continue
		var node_data = json.data
		if node_data["game_world"] == null:
			print("Error: Required field missing: game_world")
			return
		game_world.load(node_data["game_world"])
		if node_data["player_inventory"] == null:
			print("Error: Required field missing: player_inventory")
			return
		player_inventory.load(node_data["player_inventory"])
