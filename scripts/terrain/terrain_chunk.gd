extends MeshInstance3D

class_name TerrainChunk

var x_pos : int
var z_pos : int
var chunk_size : int
var chunk_res : float
var terrain_mat : ShaderMaterial
var terrain_noise

func _init(_x_pos, _z_pos, _chunk_size, _chunk_res, _terrain_mat, _terrain_noise):
	x_pos = _x_pos
	z_pos = _z_pos
	chunk_size = _chunk_size
	chunk_res = _chunk_res
	terrain_mat = _terrain_mat
	terrain_noise = _terrain_noise

func _ready():
	generate_chunk()
	translate(Vector3(x_pos, 0, z_pos))

func generate_chunk():
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(chunk_size, chunk_size)
	plane_mesh.subdivide_depth = chunk_size * chunk_res
	plane_mesh.subdivide_width = chunk_size * chunk_res

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

	mesh.surface_set_material(0, terrain_mat)
