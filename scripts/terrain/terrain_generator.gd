# Based on https://www.youtube.com/watch?v=rWeQ30h25Yg

extends Node
class_name TerrainGenerator

var shader_parameters: TerrainChunk.ShaderParameters = TerrainChunk.ShaderParameters.new()

const NUM_CHUNKS_FULL_RES = 3 # 3 Mean 3x3 chunks around player at full res, with player expected to be in the middle chunk
const GRID_SIZE = NUM_CHUNKS_FULL_RES + 2 * (Globals.NUM_CHUNK_RESOLUTIONS - 1)
@warning_ignore("integer_division")
var HALF_GRID_SIZE: int = floor(GRID_SIZE / 2) # Make constant to avoid handling the integer division warning each time

# Contains a Dictionary holding the chunks for each resolution size
# resolution=1 means highest resolution, 2 means half of that, and so on.
# The value is also a dictionary, of type Dictorionary[Vector2i, TerrainChunk], where the int key is its hashed x and z position.
var chunks: Dictionary[int, Dictionary] = {}

var terrain_noise

func _init(_terrain_noise):
	terrain_noise = _terrain_noise

	for res in range(Globals.NUM_CHUNK_RESOLUTIONS):
		chunks[res] = {}

func update_shader_data(settlement_data: Array[SettlementGenerator.SettlementData], road_edges: Array[RoadGenerator.RoadEdge]):
	shader_parameters.settlement_data = settlement_data.duplicate()
	shader_parameters.road_edges = road_edges.duplicate()

	for chunk_res in chunks:
		var chunks_for_res = chunks[chunk_res]
		for key in chunks_for_res:
			var chunk: TerrainChunk = chunks_for_res[key]
			chunk.set_shader_data(shader_parameters)

func update_chunks_around_player(player_pos: Vector3, batch_size = 1000):
	cleanup_chunks(player_pos)
	add_chunks_around_player(player_pos, batch_size)

func add_chunks_around_player(player_pos: Vector3, batch_size = 1000):
	var i = 0
	for x in range(0, GRID_SIZE):
		for z in range(0, GRID_SIZE):
			_add_chunk(x, z, player_pos)
			i += 1
			if i > batch_size:
				i = 0
				await get_tree().process_frame

func _add_chunk(grid_x_index: int, grid_z_index: int, player_pos: Vector3):
	var x_index: int = floor(player_pos.x / Globals.TERRAIN_CHUNK_SIZE) + grid_x_index - HALF_GRID_SIZE
	var z_index: int = floor(player_pos.z / Globals.TERRAIN_CHUNK_SIZE) + grid_z_index - HALF_GRID_SIZE
	var chunk_x_pos: float = x_index * Globals.TERRAIN_CHUNK_SIZE
	var chunk_z_pos: float = z_index * Globals.TERRAIN_CHUNK_SIZE
	var key = Vector2i(x_index, z_index)
	var resolution_index = calculate_resolution(grid_x_index, grid_z_index)

	# First check if chunk has already been added
	if chunks[resolution_index].has(key):
		if chunks[resolution_index].get(key).get_parent() != self:
			hide_other_resolutions_at_index(resolution_index, key)
			add_child(chunks[resolution_index].get(key))
		return

	# else, new chunk
	hide_other_resolutions_at_index(resolution_index, key)
	var chunk_resolution = 1.0 / pow(2.0, resolution_index) * Globals.TERRAIN_RESOLUTION_MULTIPLIER
	var chunk = TerrainChunk.new(chunk_x_pos, chunk_z_pos, Globals.TERRAIN_CHUNK_SIZE, chunk_resolution, terrain_noise)
	chunk.set_shader_data(shader_parameters)
	chunks[resolution_index][key] = chunk
	add_child(chunk)

func get_player_chunk_index(player_pos: Vector3) -> Vector2i:
	var player_fit_x = floor(player_pos.x) - (int(floor(player_pos.x)) % Globals.TERRAIN_CHUNK_SIZE)
	var player_fit_z = floor(player_pos.z) - (int(floor(player_pos.z)) % Globals.TERRAIN_CHUNK_SIZE)
	var x_index = HALF_GRID_SIZE + player_fit_x / Globals.TERRAIN_CHUNK_SIZE - HALF_GRID_SIZE
	var z_index = HALF_GRID_SIZE + player_fit_z / Globals.TERRAIN_CHUNK_SIZE - HALF_GRID_SIZE
	return Vector2i(x_index, z_index)

func cleanup_chunks(player_pos: Vector3):
	var to_be_removed = []
	for chunk_res in range(chunks.size()):
		var chunks_for_res = chunks[chunk_res]
		for key in chunks_for_res:
			var chunk = chunks_for_res[key]
			var player_chunk_index: Vector2i = get_player_chunk_index(player_pos)
			var distance_x: int = abs(player_chunk_index.x - chunk.x_index)
			var distance_z: int = abs(player_chunk_index.y - chunk.z_index)
			if distance_x > HALF_GRID_SIZE + 2 or distance_z > HALF_GRID_SIZE + 2:
				to_be_removed.append({"chunks_for_res": chunks_for_res, "key": key})
	for item in to_be_removed:
		remove_chunk(item["chunks_for_res"], item["key"])

func calculate_resolution(x_index: int, z_index: int) -> int:
	var center = (GRID_SIZE - 1) / 2.0
	var distance_from_center_x = abs(x_index - center)
	var distance_from_center_z = abs(z_index - center)
	var max_distance_from_center = max(distance_from_center_x, distance_from_center_z)
	var full_res_margin = floor(NUM_CHUNKS_FULL_RES / 2.0)
	return max(max_distance_from_center - full_res_margin, 0)

func hide_other_resolutions_at_index(resolution: int, key: Vector2i) -> void:
	for chunk_resolution in chunks:
		var chunks_for_resolution = chunks[chunk_resolution]
		if chunks_for_resolution.has(key) and chunk_resolution != resolution and chunks_for_resolution.get(key).get_parent() == self:
			remove_child(chunks_for_resolution.get(key))

func remove_chunk(chunks_for_resolution: Dictionary, key: Vector2i) -> void:
	if chunks_for_resolution.get(key):
		if chunks_for_resolution.get(key).get_parent() == self:
			remove_child(chunks_for_resolution.get(key))
		chunks_for_resolution.get(key).queue_free()
		chunks_for_resolution.erase(key)

func get_num_chunks() -> int:
	var result = 0
	for chunks_for_resolution in chunks.values():
		result += chunks_for_resolution.size()
	return result

func get_chunks() -> Array[TerrainChunk]:
	var result: Array[TerrainChunk] = []
	for chunks_for_resolution in chunks.values():
		for chunk: TerrainChunk in chunks_for_resolution.values():
			result.append(chunk)
	return result
