extends MeshInstance3D

class_name TerrainChunk

class ShaderParameters:
	# Array[Dictionary[Vector2, SettlementGenerator.SettlementData]]
	var settlement_data: Array = []
	var road_edges: Array[RoadGenerator.RoadEdge] = []

# Add this number of subdivisions to each side of the chunk. Will not be rendered.
# Used to avoid visible seams between terrain chunks
# TODO: Fix seams between chunks of different resolutions
const MARGIN: int = 1

# Input values
var x_index : int
var z_index : int
var x_pos : float
var z_pos : float
var chunk_size : int
var chunk_res : float
var terrain_material : ShaderMaterial
var terrain_noise

# Calculated values
var subdivisions: int
var chunk_size_with_margins: float # Chunk size + margins

func _init(_x_pos, _z_pos, _chunk_size, _chunk_res, _terrain_noise):
	x_index = int(_x_pos / _chunk_size)
	z_index = int(_z_pos / _chunk_size)
	x_pos = _x_pos
	z_pos = _z_pos
	chunk_size = _chunk_size
	chunk_res = _chunk_res
	terrain_material = ShaderMaterial.new()
	terrain_noise = _terrain_noise
	generate_chunk()
	translate(Vector3(x_pos, 0, z_pos))

func generate_chunk():
	var plane_mesh = PlaneMesh.new()
	# NOTE: Subdivisions is number of cuts in plane. So 1 subdivision means 4 total cells, 2 means 9 total cells, etc.
	subdivisions = floor((chunk_size * chunk_res) + 2 * MARGIN)
	var cell_size = 1.0 / (subdivisions - 1) * chunk_size
	chunk_size_with_margins = chunk_size + 2 * cell_size
	plane_mesh.size = Vector2(chunk_size_with_margins, chunk_size_with_margins)
	plane_mesh.subdivide_depth = subdivisions
	plane_mesh.subdivide_width = subdivisions

	var surface_tool = SurfaceTool.new()
	var data_tool = MeshDataTool.new()
	surface_tool.create_from(plane_mesh, 0)
	var array_plane = surface_tool.commit()
	var _error = data_tool.create_from_surface(array_plane, 0)

	for i in range(data_tool.get_vertex_count()):
		var vertex = data_tool.get_vertex(i)
		vertex.y = terrain_noise.get_height_at(vertex.x + x_pos, vertex.z + z_pos)
		data_tool.set_vertex(i, vertex)

	for i in range(array_plane.get_surface_count()):
		array_plane.surface_remove(i)

	data_tool.commit_to_surface(array_plane)
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.create_from(array_plane, 0)
	surface_tool.generate_normals()

	mesh = surface_tool.commit()
	create_trimesh_collision()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	mesh.surface_set_material(0, terrain_material)

func set_shader_data(params: ShaderParameters):
	terrain_material.shader = load("res://shaders/ground.gdshader")
	terrain_material.set_shader_parameter("chunk_size", Vector2(Globals.TERRAIN_CHUNK_SIZE, Globals.TERRAIN_CHUNK_SIZE))
	terrain_material.set_shader_parameter("chunk_position", Vector2(x_pos, z_pos))

	if MARGIN > 0:
		var uv_scale: float = chunk_size_with_margins / chunk_size
		var uv_offset: float = 1.0 / (subdivisions + 1)
		terrain_material.set_shader_parameter("uv_scale", Vector2(uv_scale, uv_scale))
		terrain_material.set_shader_parameter("uv_offset", Vector2(uv_offset, uv_offset))

	terrain_material.set_shader_parameter("grass_albedo_texture", Color(0.25, 0.5, 0.25, 1.0))
	terrain_material.set_shader_parameter("road_albedo_texture", Color(0.5, 0.5, 0.2, 1.0))
	terrain_material.set_shader_parameter("cliff_albedo_texture", Color(0.35, 0.35, 0.35, 1.0))
	terrain_material.set_shader_parameter("barren_albedo_texture", Color(0.35, 0.3, 0.2, 1.0))
	terrain_material.set_shader_parameter("snow_albedo_texture", Color(0.9, 0.9, 0.9, 1.0))
	terrain_material.set_shader_parameter("settlement_count", params.settlement_data.size())
	var shader_settlement_data: Array[Vector3] = []
	for settlement in params.settlement_data:
		var settlement_data = settlement["data"]
		shader_settlement_data.append(Vector3(settlement_data.position.x, settlement_data.position.z, settlement_data.radius))
	terrain_material.set_shader_parameter("settlement_data", shader_settlement_data)
	terrain_material.set_shader_parameter("road_width", Globals.ROAD_WIDTH)
	terrain_material.set_shader_parameter("road_edge_count", params.road_edges.size())

	# TODO: Only give the road edges that are in each chunk, instead of all to everyone.
	var shader_road_edges_data: Array[Vector4] = []
	for edge in params.road_edges:
		shader_road_edges_data.append(Vector4(edge.from.x, edge.from.z, edge.to.x, edge.to.z))
	terrain_material.set_shader_parameter("road_edges", shader_road_edges_data)
