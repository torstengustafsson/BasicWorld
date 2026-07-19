class_name TerrainMap extends Control

@export var world_view_size: float = 800.0 # how many world units across the map shows
@export var sample_resolution: int = 72    # NxN noise samples per rebuild
@export var slope_sample_dist: float = 2.0  # world units used to estimate slope

# References
var terrain_noise: TerrainNoise
var forest_noise: NoiseFunctions
var settlement_data: Array = []
var road_segments: Array = []

var style_box: StyleBoxFlat # Optional

var _texture_rect: TextureRect # Background terrain color texture
var _overlay: Control # Things on top, settlements, roads, player marker
var _map_origin: Vector2 = Vector2.ZERO # world-space top-left corner currently represented by the texture

var _last_facing: float = 0.0

func _ready():
	size.x = size.y # Ensure square dimensions
	custom_minimum_size = size
	clip_contents = true

	_texture_rect = TextureRect.new()
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_texture_rect.custom_minimum_size = size
	_texture_rect.size = size
	_texture_rect.texture_filter = TextureRect.TEXTURE_FILTER_LINEAR
	add_child(_texture_rect)

	_overlay = Control.new()
	_overlay.size = size
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.draw.connect(_on_overlay_draw)

func update_size(new_size: float) -> void:
	size = Vector2(new_size, new_size)
	_texture_rect.size = size
	_overlay.size = size

func setup(_terrain_noise, _forest_noise) -> void:
	terrain_noise = _terrain_noise
	forest_noise = _forest_noise

func update_overlay_data(_settlement_data: Array, _road_segments: Array) -> void:
	settlement_data = _settlement_data
	road_segments = _road_segments
	_overlay.queue_redraw()

func update_map(player_pos: Vector3, player_facing_rad: float = 0.0) -> void:
	_rebuild_texture(player_pos)
	_overlay.queue_redraw()
	_last_facing = player_facing_rad

func _rebuild_texture(player_pos: Vector3) -> void:
	if terrain_noise == null or forest_noise == null:
		return

	var half_view = world_view_size / 2.0
	_map_origin = Vector2(player_pos.x - half_view, player_pos.z - half_view)

	var img = Image.create(sample_resolution, sample_resolution, false, Image.FORMAT_RGB8)
	var step = world_view_size / float(sample_resolution)

	for py in range(sample_resolution):
		var wz = _map_origin.y + py * step
		for px in range(sample_resolution):
			var wx = _map_origin.x + px * step
			img.set_pixel(px, py, _sample_color(wx, wz))

	var tex = ImageTexture.create_from_image(img)
	_texture_rect.texture = tex

func _sample_color(wx: float, wz: float) -> Color:
	var h = terrain_noise.get_height_at(wx, wz)
	var hx = terrain_noise.get_height_at(wx + slope_sample_dist, wz)
	var hz = terrain_noise.get_height_at(wx, wz + slope_sample_dist)
	var slope: float = Vector2((hx - h) / slope_sample_dist, (hz - h) / slope_sample_dist).length()
	var is_forest = not forest_noise.above_threshold(Vector2(wx, wz))

	if slope > TerrainConstants.CLIFF_SLOPE_THRESHOLD:
		return TerrainConstants.COLOR_CLIFF
	elif h > TerrainConstants.HEIGHT_SNOW + TerrainConstants.BLEND_MARGIN:
		return TerrainConstants.COLOR_SNOW
	elif h > TerrainConstants.HEIGHT_BARREN + TerrainConstants.BLEND_MARGIN:
		return TerrainConstants.COLOR_BARREN
	elif is_forest:
		return TerrainConstants.COLOR_FOREST
	else:
		return TerrainConstants.COLOR_GRASS

# World-space position -> pixel position on the overlay control
func _world_to_map_px(world_xz: Vector2) -> Vector2:
	var rel = (world_xz - _map_origin) / world_view_size
	return rel * float(size.x)

func _on_overlay_draw() -> void:
	if style_box:
		_overlay.draw_style_box(style_box, Rect2(Vector2.ZERO, size))

	# Roads
	for segment in road_segments:
		var a = _world_to_map_px(Vector2(segment.from.x, segment.from.y))
		var b = _world_to_map_px(Vector2(segment.to.x, segment.to.y))
		_overlay.draw_line(a, b, TerrainConstants.COLOR_ROAD, 2.0)

	# Settlements
	for settlement in settlement_data:
		var p = _world_to_map_px(Vector2(settlement.position.x, settlement.position.z))
		_overlay.draw_circle(p, 6.0, TerrainConstants.COLOR_SETTLEMENT)

	# Player marker (as an arrow, always centered since the map scrolls under the player)
	var center = size / 2.0
	var forward = Vector2(sin(_last_facing), -cos(_last_facing))
	var right = forward.orthogonal()
	var tip = center + forward * 8.0
	var back_left = center - forward * 6.0 + right * 5.0
	var back_right = center - forward * 6.0 - right * 5.0
	_overlay.draw_colored_polygon(PackedVector2Array([tip, back_left, back_right]), TerrainConstants.COLOR_PLAYER)
