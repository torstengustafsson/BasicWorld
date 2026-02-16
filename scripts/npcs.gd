extends Node

class_name NPCS

enum WantsOptions { FOOD, WOOD, NONE }

var human = preload("res://scenes/human.tscn")

class NPC:
	static var sounds_responses: Array[Resource] = [
		load("res://assets/sounds/aoe2-1-yes.mp3"),
		load("res://assets/sounds/aoe2-en-taunt-02-no.mp3"),
	]

	static var sounds: Array[Resource] = [
		load("res://assets/sounds/aoe2-en-taunt-03-food-please.mp3"),
		load("res://assets/sounds/aoe2-en-taunt-04-wood-please.mp3"),
		load("res://assets/sounds/aoe2-11-herb-laugh_8YtTxD5.mp3"),
		load("res://assets/sounds/aoe2-en-taunt-06-stone-please.mp3"),
		load("res://assets/sounds/aoe2-en-taunt-08-all-hail_a8ltBrY.mp3"),
		load("res://assets/sounds/aoe2-en-taunt-22-quit-touchin-me.mp3"),
	]

	var object: Node3D
	var audio_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	var wants: WantsOptions = WantsOptions.NONE
	var has_what_it_wants: bool = false

	func _init(scene: PackedScene, pos: Vector3, rot: Vector3):
		object = scene.instantiate()
		object.position = pos
		object.rotation = rot
		var rand_scale = randf_range(1.0, 1.2)
		object.scale = Vector3(rand_scale, rand_scale, rand_scale)

		var sound_choice: int = randi() % sounds.size()
		audio_player.stream = sounds[sound_choice]

		if sound_choice == 0:
			wants = WantsOptions.FOOD
		if sound_choice == 1:
			wants = WantsOptions.WOOD

var npcs: Array[NPC] = []

func create_npcs(start_pos_x, start_pos_z, size_x, size_z, amount):
	for i in amount:
		var position = Vector3(randf_range(start_pos_x, size_x), 0.0, randf_range(start_pos_z, size_z))
		var rotation = Vector3(0.0, randf() * 2 * PI, 0.0)

		# Skip if out-of-bounds
		if position.x < start_pos_x || position.z < start_pos_z || position.x > start_pos_x + size_x || position.z > start_pos_z + size_z:
			continue

		var npc: NPC = NPC.new(human, position, rotation)
		npcs.append(npc)
		add_child(npc.object)
		add_child(npc.audio_player)

func interact(collider):
	for npc in npcs:
		if npc.object == collider:
				npc.audio_player.play()


# Return true if NPC took item
func interact_equipped_item(collider, player_equipped_item: WorldItem) -> bool:
	for npc in npcs:
		if npc.object == collider:
			if npc.wants == WantsOptions.FOOD and player_equipped_item.properties.name_singular == "Berry":
				var audio_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
				audio_player.position = npc.audio_player.position
				audio_player.stream = npc.sounds_responses[0]
				add_child(audio_player)
				audio_player.play()
				return true
			if npc.wants == WantsOptions.WOOD and player_equipped_item.properties.name_singular == "Wood":
				var audio_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
				audio_player.position = npc.audio_player.position
				audio_player.stream = npc.sounds_responses[0]
				add_child(audio_player)
				audio_player.play()
				return true
			else:
				npc.audio_player.play()
				return false
	return false
