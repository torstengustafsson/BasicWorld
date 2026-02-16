extends Node

class_name NPCS

var human = preload("res://scenes/human.tscn")

class NPC:
	static var sounds: Array[Resource] = [
		load("res://assets/sounds/aoe2-1-yes.mp3"),
		load("res://assets/sounds/aoe2-11-herb-laugh_8YtTxD5.mp3"),
		load("res://assets/sounds/aoe2-en-taunt-02-no.mp3"),
		load("res://assets/sounds/aoe2-en-taunt-03-food-please.mp3"),
		load("res://assets/sounds/aoe2-en-taunt-04-wood-please.mp3"),
		load("res://assets/sounds/aoe2-en-taunt-06-stone-please.mp3"),
		load("res://assets/sounds/aoe2-en-taunt-22-quit-touchin-me.mp3")
	]

	var object: Node3D
	var audio_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()

	func _init(scene: PackedScene, pos: Vector3, rot: Vector3):
		object = scene.instantiate()
		object.position = pos
		object.rotation = rot
		var rand_scale = randf_range(1.0, 1.2)
		object.scale = Vector3(rand_scale, rand_scale, rand_scale)
		
		var sound_choice: int = randi() % sounds.size()
		audio_player.stream = sounds[sound_choice]

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
