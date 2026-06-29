extends ThreadWorker

class_name ThreadCleanupFarawayObjects

func _init() -> void:
	super._init()
	player_pos = WorldState.state.player.position
	thread.start(Callable(self, "_thread_cleanup_faraway_objects"))

func _thread_cleanup_faraway_objects():
	const INNER_BOUNDS = Globals.LOD_DISTANCE_FULL * Globals.LOD_REMOVE_DISTANCE_MULTIPLIER
	while true:
		if (player_pos - last_player_pos).length() > Globals.LOD_UPDATE_DISTANCE:
			last_player_pos = player_pos
			var boundary_to_keep: Rect2 = Rect2(
				Vector2(player_pos.x - INNER_BOUNDS, player_pos.z - INNER_BOUNDS),
				Vector2(INNER_BOUNDS * 2, INNER_BOUNDS * 2)
			)
			WorldState.state.pool_manager.remove_faraway_world_objects(boundary_to_keep)
