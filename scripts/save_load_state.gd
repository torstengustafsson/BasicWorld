extends Node

class_name SaveLoadState

enum StateType { Trees, Bushes, Rocks, WorldItems, NPCS, PlayerInventory }

func save_game():
	var save_file = FileAccess.open("user://basicworld.save", FileAccess.WRITE)
	print(save_file.get_path())
	var save_nodes = get_tree().get_nodes_in_group("Persist")
	var result: Dictionary = {}
	for node in save_nodes:
		if !node.has_method("save"):
			print("node '%s' is missing a save() function, skipped" % node.name)
			continue

		var node_state = node.save()
		result.merge(node_state)

	var json_string = JSON.stringify(result)
	save_file.store_line(json_string)

func load_game():
	if not FileAccess.file_exists("user://basicworld.save"):
		return # Error! We don't have a save to load.

	var save_file = FileAccess.open("user://basicworld.save", FileAccess.READ)
	while save_file.get_position() < save_file.get_length():
		var json_string = save_file.get_line()
		var json = JSON.new()

		if json.parse(json_string) != OK:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			continue

		# Get the data from the JSON object.
		var node_data = json.data

		var load_nodes = get_tree().get_nodes_in_group("Persist")

		for node in load_nodes:
			if !node.has_method("load"):
				print("node '%s' is missing a load() function, skipped" % node.name)
				continue

			node.load(node_data)
