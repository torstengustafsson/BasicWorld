extends Node

class_name NPCS

enum WantsOptions { FOOD, WOOD, NONE }

var human = preload("res://scenes/human.tscn")

enum Response { YES, NO }

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
	var model: MeshInstance3D
	var model_material: StandardMaterial3D
	var default_color: Color

	var audio_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	var default_sound_index: int = randi() % sounds.size()
	var default_sound: AudioStream = sounds[default_sound_index]
	var wants: WantsOptions = WantsOptions.NONE
	var has_what_it_wants: bool = false
	var health = 3
	const DAMAGE_TAKEN_SECS = 0.5

	func _init(scene: PackedScene, pos: Vector3, rot: Vector3, scale: float):
		object = scene.instantiate()
		object.position = pos
		object.rotation = rot
		object.scale = Vector3(scale, scale, scale)
		model = object.get_node("animated_human").get_node("Armature").get_node("Skeleton3D").get_node("Human")
		
		# Need to make copy of material to avoid changing on all NPCs
		model_material = model.get_active_material(0).duplicate()
		model.set_surface_override_material(0, model_material)
		default_color = model_material.albedo_color

		# Start jogging animation
		var animationplayer: AnimationPlayer = object.get_node("animated_human").get_node("AnimationPlayer")
		animationplayer.get_animation("Armature|Armature|ArmatureAction").loop_mode = Animation.LOOP_LINEAR
		animationplayer.play("Armature|Armature|ArmatureAction")

		audio_player.stream = default_sound
		audio_player.finished.connect(_on_sound_finished)

		if default_sound.resource_path == "res://assets/sounds/aoe2-en-taunt-03-food-please.mp3":
			wants = WantsOptions.FOOD
		if default_sound.resource_path == "res://assets/sounds/aoe2-en-taunt-04-wood-please.mp3":
			wants = WantsOptions.WOOD

	func play_sound(response: Response):
		audio_player.stream = sounds_responses[response]
		audio_player.play()

	# Retrun true if died
	func take_damage() -> bool:
		health -= 1
		if health <= 0:
			object.queue_free()
			return true
		play_sound(Response.NO)
		var blink_cycle = 0.1
		var loops = int(DAMAGE_TAKEN_SECS / (blink_cycle * 2))
		var tween = model.create_tween().set_loops(loops)
		tween.tween_property(model_material, "albedo_color", Color.RED, 0.1)
		tween.tween_property(model_material, "albedo_color", default_color, 0.1)
		return false

	func _on_sound_finished():
		audio_player.stream = default_sound

var npcs: Array[NPC] = []

func _init() -> void:
	add_to_group("Persist")


func create_npcs(start_pos_x, start_pos_z, end_pos_x, end_pos_z, amount):
	for i in amount:
		var position = Vector3(randf_range(start_pos_x, end_pos_x), 0.0, randf_range(start_pos_z, end_pos_z))
		var rotation = Vector3(0.0, randf() * 2 * PI, 0.0)
		var rand_scale = randf_range(1.0, 1.2)
		add_npc(position, rotation, rand_scale)


func add_npc(position: Vector3, rotation: Vector3, scale: float) -> NPC:
		var npc: NPC = NPC.new(human, position, rotation, scale)
		npcs.append(npc)
		add_child(npc.object)
		add_child(npc.audio_player)	
		return npc

func interact(collider):
	for npc in npcs:
		if npc.object == collider:
				npc.audio_player.play()


# Return true if NPC took item
func interact_equipped_item(collider, player_equipped_item: WorldItem) -> bool:
	for npc in npcs:
		if npc.object == collider:
			if npc.wants == WantsOptions.FOOD and player_equipped_item.item_id == ItemProperties.Item.BERRY:
				npc.play_sound(Response.YES)
				return true
			if npc.wants == WantsOptions.WOOD and player_equipped_item.item_id == ItemProperties.Item.WOOD:
				npc.play_sound(Response.YES)
				return true
			else:
				npc.audio_player.play()
				return false
	return false


func handle_chop(collider):
	for i in npcs.size():
		var npc: NPC = npcs[i]
		if npc.object == collider:
			var died = npc.take_damage()
			if died:
				npcs.remove_at(i)
			return


func save() -> Dictionary:
	var result: Dictionary = {}
	var npc_data: Array = []
	for npc in npcs:
		var data: Dictionary = {}
		data["pos_x"] = snapped(npc.object.position.x, 0.01)
		data["pos_y"] = snapped(npc.object.position.y, 0.01)
		data["pos_z"] = snapped(npc.object.position.z, 0.01)
		data["rot_x"] = snapped(npc.object.rotation.x, 0.01)
		data["rot_y"] = snapped(npc.object.rotation.y, 0.01)
		data["rot_z"] = snapped(npc.object.rotation.z, 0.01)
		data["scale"] = snapped(npc.object.scale.x, 0.01) # Uniform scale
		data["health"] = snapped(npc.health, 0.01)
		data["sound_index"] = npc.default_sound_index
		npc_data.append(data)
	result[SaveLoadState.StateType.NPCS] = npc_data
	return result


func load(data: Dictionary):
	for npc in npcs:
		npc.object.queue_free()
	npcs.clear()

	for npc_data in data[str(SaveLoadState.StateType.NPCS)]:
		var position = Vector3(npc_data["pos_x"], npc_data["pos_y"], npc_data["pos_z"])
		var rotation = Vector3(npc_data["rot_x"], npc_data["rot_y"], npc_data["rot_z"])
		var scale = npc_data["scale"]
		var npc = add_npc(position, rotation, scale)
		npc.health = npc_data["health"]
		npc.default_sound_index = npc_data["sound_index"]
		npc.default_sound = NPC.sounds[npc.default_sound_index]
