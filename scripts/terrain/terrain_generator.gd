# Baserat på https://www.youtube.com/watch?v=rWeQ30h25Yg
# Thread verkar ha ändrats sedan godot 3..

extends Node

class_name TerrainGenerator

const NUM_CHUNKS_FULL_RES = 2

# Contains a Dictionary holding the chunks for each resolution size
var chunks: Dictionary[int, Dictionary] = {}

var terrain_mat : ShaderMaterial
var terrain_noise

func _init(_terrain_mat, _terrain_noise):
	terrain_mat = _terrain_mat
	terrain_noise = _terrain_noise

	for res in range(Globals.NUM_CHUNK_RESOLUTIONS):
		chunks[res] = {}


func add_chunks_around_player(player_pos: Vector3):
	var num_chunks_lowest_res = NUM_CHUNKS_FULL_RES * pow(2, Globals.NUM_CHUNK_RESOLUTIONS - 1)

	var num_chunks = num_chunks_lowest_res
	for x in range(0, num_chunks):
		for z in range(0, num_chunks):
			for resolution in range(Globals.NUM_CHUNK_RESOLUTIONS):
				var player_fit_x = floor(player_pos.x) - (int(floor(player_pos.x)) % Globals.TERRAIN_CHUNK_SIZE)
				var player_fit_z = floor(player_pos.z) - (int(floor(player_pos.z)) % Globals.TERRAIN_CHUNK_SIZE)
				var chunk_x = player_fit_x + (-num_chunks / 2 + x) * Globals.TERRAIN_CHUNK_SIZE + float(Globals.TERRAIN_CHUNK_SIZE) / 2
				var chunk_z = player_fit_z + (-num_chunks / 2 + z) * Globals.TERRAIN_CHUNK_SIZE + float(Globals.TERRAIN_CHUNK_SIZE) / 2
				var key = chunk_x * 1000000000 + chunk_z
				if chunks[resolution].has(key):
					if chunks[resolution].get(key).process_mode == Node.PROCESS_MODE_DISABLED:
						hide_chunks_at(key)
						chunks[resolution].get(key).process_mode = Node.PROCESS_MODE_INHERIT
						add_child(chunks[resolution].get(key))
					continue

				var res_bounds = NUM_CHUNKS_FULL_RES * pow(2, resolution) / 2
				var res_check = num_chunks_lowest_res / 2 - res_bounds
				if x >= res_check and x < num_chunks - res_check and z >= res_check and z < num_chunks - res_check:
					hide_chunks_at(key)
					var chunk_resolution = 1 / (float(resolution) + 1) / 2
					var chunk = TerrainChunk.new(chunk_x, chunk_z, Globals.TERRAIN_CHUNK_SIZE, chunk_resolution, terrain_mat, terrain_noise)
					chunks[resolution][key] = chunk
					add_child(chunk)

func cleanup_chunks(player_pos: Vector3):
	for i in range(chunks.size()):
		var current_res = NUM_CHUNKS_FULL_RES * pow(2, i)
		var chunk_map = chunks[i]
		for key in chunk_map.keys():
			var distance_vector = Vector2(chunk_map[key].position.x, chunk_map[key].position.z) - Vector2(player_pos.x, player_pos.z)
			if distance_vector.length() > Globals.TERRAIN_CHUNK_SIZE * current_res * 1.2:
				remove_chunk(chunk_map, key)

func remove_chunk(chunk_map,key):
	if chunk_map.get(key):
		remove_child(chunk_map.get(key))
		chunk_map.get(key).queue_free()
		chunk_map.erase(key)

func hide_chunks_at(key):
	for chunk_map in chunks.values():
		if chunk_map.has(key):
			chunk_map.get(key).process_mode = Node.PROCESS_MODE_DISABLED


func get_num_chunks():
	var result = 0
	for chunk_map in chunks.values():
		result += chunk_map.size()
	return result
