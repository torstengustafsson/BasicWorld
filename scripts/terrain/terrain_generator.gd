# Based on https://www.youtube.com/watch?v=rWeQ30h25Yg

extends Node
class_name TerrainGenerator

var shader_parameters: TerrainChunk.ShaderParameters = TerrainChunk.ShaderParameters.new()

const NUM_CHUNKS_FULL_RES = 3 # 3 Mean 3x3 chunks around player at full res, with player expected to be in the middle chunk
const GRID_SIZE = NUM_CHUNKS_FULL_RES + 2 * (Globals.NUM_CHUNK_RESOLUTIONS - 1)
var HALF_GRID_SIZE: int = floor(GRID_SIZE / floor(2)) # Make constant to avoid handling the integer division warning each time

# Contains a Dictionary holding the chunks for each resolution size
# resolution=1 means highest resolution, 2 means half of that, and so on.
# The value is also a dictionary, of type Dictorionary[Vector2i, TerrainChunk], where the int key is its hashed x and z position.
var chunks: Dictionary[int, Dictionary] = {}

var terrain_noise

func _init(_terrain_noise):
	terrain_noise = _terrain_noise

	for res in range(Globals.NUM_CHUNK_RESOLUTIONS):
		chunks[res] = {}

# settlement_data: Array[SettlementManager.SettlementData]
func update_shader_data(settlement_data: Array, road_segments: Array):
	shader_parameters.settlement_data = settlement_data.duplicate()
	shader_parameters.road_segments = road_segments.duplicate()

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
	for chunk_index in get_grid_loop_order():
		_add_chunk(chunk_index.x, chunk_index.y, player_pos)
		i += 1
		if i > batch_size:
			i = 0
			await get_tree().process_frame

func _add_chunk(grid_x_index: int, grid_z_index: int, player_pos: Vector3) -> TerrainChunk:
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
		return chunks[resolution_index].get(key)

	# else, new chunk
	hide_other_resolutions_at_index(resolution_index, key)
	var chunk = TerrainChunk.new(chunk_x_pos, chunk_z_pos, Globals.TERRAIN_CHUNK_SIZE, resolution_index, terrain_noise)
	chunk.set_shader_data(shader_parameters)
	chunks[resolution_index][key] = chunk
	add_child(chunk)
	return chunk

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

# Return 0 for center chunk, and increases by 1 for each step outward
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

# Returns an array that starts from the middle and expands outwards from there
func get_grid_loop_order() -> Array[Vector2i]:
	var center = Vector2i(HALF_GRID_SIZE, HALF_GRID_SIZE)
	var queue: Array[Vector2i] = [center]
	var result: Array[Vector2i] = []
	var visited = {}

	# Directions: up, down, left, right
	var directions = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

	# Process cells in BFS order
	while queue.size() > 0:
		var current = queue.pop_front()
		if current in visited:
			continue
		visited[current] = true

		result.append(current)

		# Add neighbors to the queue
		for dir in directions:
			var neighbor = current + dir
			if (neighbor.x >= 0 and neighbor.x < GRID_SIZE and
				neighbor.y >= 0 and neighbor.y < GRID_SIZE and
				not neighbor in visited):
				queue.append(neighbor)

	return result

func get_terrain_size() -> Rect2:
	var min_x = INF
	var max_x = -INF
	var min_z = INF
	var max_z = -INF
	for chunk_res in chunks:
		var chunks_for_res = chunks[chunk_res]
		for key in chunks_for_res:
			var chunk: TerrainChunk = chunks_for_res[key]
			min_x = min(min_x, chunk.x_pos - Globals.TERRAIN_CHUNK_SIZE / 2.0)
			max_x = max(max_x, chunk.x_pos + Globals.TERRAIN_CHUNK_SIZE / 2.0)
			min_z = min(min_z, chunk.z_pos - Globals.TERRAIN_CHUNK_SIZE / 2.0)
			max_z = max(max_z, chunk.z_pos + Globals.TERRAIN_CHUNK_SIZE / 2.0)
	return Rect2(min_x, min_z, max_x - min_x, max_z - min_z)

func get_chunk_boundary(chunk) -> Rect2:
	return Rect2(chunk.x_pos - Globals.TERRAIN_CHUNK_SIZE / 2.0, chunk.z_pos - Globals.TERRAIN_CHUNK_SIZE / 2.0, Globals.TERRAIN_CHUNK_SIZE, Globals.TERRAIN_CHUNK_SIZE)

# Uncomment to render terrain chunk boundaries
# func _process(_delta):
# 	render_chunk_boundaries()

# func render_chunk_boundaries():

# 	for chunk_res in chunks:
# 		var chunks_for_res = chunks[chunk_res]
# 		for key in chunks_for_res:
# 			var chunk: TerrainChunk = chunks_for_res[key]
# 			if chunk.get_parent() != self:
# 				continue
# 			var boundary = get_chunk_boundary(chunk)

# 			var northwest_point = Vector3(boundary.position.x + 0.25, 10.0, boundary.position.y + 0.25)
# 			var northeast_point = Vector3(boundary.position.x + boundary.size.x, 10.0, boundary.position.y + 0.25)
# 			var southwest_point = Vector3(boundary.position.x + 0.25, 10.0, boundary.position.y + boundary.size.y)
# 			var southeast_point = Vector3(boundary.position.x + boundary.size.x, 10.0, boundary.position.y + boundary.size.y)

# 			var color = Color(chunk.resolution_index == 0, chunk.resolution_index == 1, chunk.resolution_index == 2, 0.5)

# 			DebugDraw3D.draw_line(northwest_point, northeast_point, color)
# 			DebugDraw3D.draw_line(northwest_point, southwest_point, color)
# 			DebugDraw3D.draw_line(southwest_point, southeast_point, color)
# 			DebugDraw3D.draw_line(northeast_point, southeast_point, color)
