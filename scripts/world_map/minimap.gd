class_name Minimap extends TerrainMap

const UPDATE_DISTANCE: float = 5.0  # distance between full texture rebuilds

var _last_player_pos: Vector3 = Vector3.INF

func update_map(player_pos: Vector3, player_facing_rad: float = 0.0) -> void:
	if _last_player_pos.distance_to(player_pos) > UPDATE_DISTANCE:
		_last_player_pos = player_pos
		super.update_map(player_pos, player_facing_rad)
	else:
		# Alwauys update player facing, otherwise we get "jaggy" behavior
		_overlay.queue_redraw()
		_last_facing = player_facing_rad
