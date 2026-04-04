extends Node

class_name NpcGenerator


var npcs: Array[NPC] = []
var static_objects_qt: Quadtree

func _init(qt: Quadtree) -> void:
	static_objects_qt = qt
	add_to_group("Persist")


func create_npcs(start_pos_x, start_pos_z, end_pos_x, end_pos_z, amount, terrain_height_noise):
	for i in amount:
		var pos_x = randf_range(start_pos_x, end_pos_x)
		var pos_z = randf_range(start_pos_z, end_pos_z)
		var height = terrain_height_noise.get_height_at(pos_x, pos_z)
		var position = Vector3(pos_x, height, pos_z)
		var rotation = Vector3(0.0, randf() * 2 * PI, 0.0)
		var rand_scale = randf_range(1.0, 1.2)
		add_npc(position, rotation, rand_scale)

func create_npc_children(start_pos_x, start_pos_z, end_pos_x, end_pos_z, amount):
	for i in amount:
		var position = Vector3(randf_range(start_pos_x, end_pos_x), 0.0, randf_range(start_pos_z, end_pos_z))
		var rotation = Vector3(0.0, randf() * 2 * PI, 0.0)
		var rand_scale = randf_range(0.5, 0.6)
		add_npc(position, rotation, rand_scale)


func add_npc(position: Vector3, rotation: Vector3, scale: float) -> NPC:
		var npc: NPC = NPC.new(position, rotation, scale)
		npcs.append(npc)
		static_objects_qt.insert({"position": Vector2(position.x, position.z), "data": npc})
		return npc

func interact(collider):
	for npc in npcs:
		if npc.instance == collider:
			npc.instance.add_child(npc.audio_player)
			npc.audio_player.play()


func interact_equipped_item(collider, item: ItemProperties.Item = ItemProperties.Item.NO_ITEM) -> bool:
	for npc in npcs:
		if npc.instance == collider:
			return npc.interact_item(item)
	return false


func handle_chop(collider):
	for i in npcs.size():
		var npc: NPC = npcs[i]
		if npc.instance == collider:
			var died = npc.take_damage()
			if died:
				static_objects_qt.remove({"position": Vector2(npc.instance.position.x, npc.instance.position.z), "data": npc})
				npcs.remove_at(i)
			return


func save() -> Dictionary:
	var result: Dictionary = {}
	var npc_data: Array = []
	for npc in npcs:
		var data: Dictionary = {}
		data["pos_x"] = snapped(npc.instance.position.x, 0.01)
		data["pos_y"] = snapped(npc.instance.position.y, 0.01)
		data["pos_z"] = snapped(npc.instance.position.z, 0.01)
		data["rot_x"] = snapped(npc.instance.rotation.x, 0.01)
		data["rot_y"] = snapped(npc.instance.rotation.y, 0.01)
		data["rot_z"] = snapped(npc.instance.rotation.z, 0.01)
		data["scale"] = snapped(npc.instance.scale.x, 0.01) # Uniform scale
		data["health"] = snapped(npc.health, 0.01)
		data["sound_index"] = npc.default_sound_index
		npc_data.append(data)
	result[SaveLoadState.StateType.NPCS] = npc_data
	return result


func load(data: Dictionary):
	for npc in npcs:
		npc.instance.queue_free()
	npcs.clear()

	for npc_data in data[str(SaveLoadState.StateType.NPCS)]:
		var position = Vector3(npc_data["pos_x"], npc_data["pos_y"], npc_data["pos_z"])
		var rotation = Vector3(npc_data["rot_x"], npc_data["rot_y"], npc_data["rot_z"])
		var scale = npc_data["scale"]
		var npc = add_npc(position, rotation, scale)
		npc.health = npc_data["health"]
		npc.default_sound_index = npc_data["sound_index"]
		npc.default_sound = NPC.sounds[npc.default_sound_index]
