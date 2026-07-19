class_name WorldMap extends TerrainMap

const MARGIN = 50.0

var player: CharacterBody3D # Reference

func _ready() -> void:
	super._ready()
	var window_size: Vector2 = get_viewport().get_visible_rect().size
	var min_size = min(window_size.x, window_size.y)
	update_size(min(window_size.x, window_size.y) - MARGIN)

	# I dont understand anchors... This puts the map on the center of the screen
	var pos_x = MARGIN / 2 if window_size.x == min_size else window_size.x / 2 - window_size.y / 2 + MARGIN / 2
	var pos_y = MARGIN / 2 if window_size.y == min_size else window_size.y / 2 - window_size.x / 2 + MARGIN / 2
	position = Vector2(pos_x, pos_y)

	style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.0, 0.0, 0.0, 0.0) # No background, we only want the border
	style_box.border_color = Color(0.3, 0.3, 0.3)
	style_box.border_width_left = 5
	style_box.border_width_right = 5
	style_box.border_width_top = 5
	style_box.border_width_bottom = 5

func set_player(_player: Node3D) -> void:
	player = _player

func open() -> void:
	update_map(player.position, -player.rotation.y)
	update_overlay_data(WorldState.state.settlement_manager.settlements.query_all(), WorldState.state.road_manager.road_segments.query_all())

func scroll(amount: float):
	world_view_size += amount
	update_map(player.position, -player.rotation.y)
	update_overlay_data(WorldState.state.settlement_manager.settlements.query_all(), WorldState.state.road_manager.road_segments.query_all())
