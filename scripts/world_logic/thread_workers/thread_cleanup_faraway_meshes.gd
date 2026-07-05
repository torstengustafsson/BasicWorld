extends ThreadWorker

class_name ThreadCleanupFarawayMeshes

func _init() -> void:
	super._init()
	player_pos = WorldState.state.player.position
	thread.start(Callable(self, "_thread_cleanup_faraway_meshes"))

func _thread_cleanup_faraway_meshes():
	const OUTER_BOUNDS = Globals.LOD_DISTANCE_NO_COLLIDER * Globals.LOD_REMOVE_DISTANCE_MULTIPLIER
	while true:
		if (player_pos - last_player_pos).length() > Globals.LOD_UPDATE_DISTANCE * 5:
			last_player_pos = player_pos
			var boundary_to_keep: Rect2 = Rect2(
				Vector2(player_pos.x - OUTER_BOUNDS, player_pos.z - OUTER_BOUNDS),
				Vector2(OUTER_BOUNDS * 2, OUTER_BOUNDS * 2)
			)
			WorldState.state.pool_manager.remove_faraway_meshes(boundary_to_keep)
