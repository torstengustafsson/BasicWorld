extends ThreadWorker

class_name ThreadAddRoads

func _init() -> void:
	super._init()
	player_pos = WorldState.state.player.position
	thread.start(Callable(self, "_thread_add_roads"))

func _thread_add_roads():
	while true:
		if (player_pos - last_player_pos).length() > Globals.LOD_UPDATE_DISTANCE:
			last_player_pos = player_pos
			var boundary: Rect2 = Rect2(
				Vector2(player_pos.x - Globals.LOD_DISTANCE_NO_COLLIDER, player_pos.z - Globals.LOD_DISTANCE_NO_COLLIDER),
				Vector2(Globals.LOD_DISTANCE_NO_COLLIDER * 2, Globals.LOD_DISTANCE_NO_COLLIDER * 2)
			)
			WorldState.state.road_generator.generate_roads(boundary)
