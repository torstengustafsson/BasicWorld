extends ThreadWorker

class_name ThreadAddMeshes

var initialization_completed: bool = false

var extra_worker_threads: Array[Thread]

func _init() -> void:
	super._init()
	player_pos = WorldState.state.player.position
	thread.start(Callable(self, "_thread_add_meshes"))

func _thread_add_meshes():
	while true:
		if (player_pos - last_player_pos).length() > Globals.LOD_UPDATE_DISTANCE:
			last_player_pos = player_pos
			# Add objects in increments to make meshes close to player spawn first
			# It will keep adding objects until it reaches distance of Globals.LOD_DISTANCE_NO_COLLIDER from player
			var outer_increment = int(ceil(Globals.LOD_DISTANCE_NO_COLLIDER / 4))
			var reset_loop: bool = false
			for i in 4:
				var outer_bounds = (i + 1) * outer_increment
				var outer_boundary: Rect2 = Rect2(
					Vector2(floor(player_pos).x - outer_bounds, floor(player_pos.z) - outer_bounds),
					Vector2(outer_bounds * 2, outer_bounds * 2)
				)
				var inner_bounds = i * outer_increment
				var inner_boundary: Rect2 = Rect2(
					Vector2(floor(player_pos.x) - inner_bounds, floor(player_pos.z) - inner_bounds),
					Vector2(inner_bounds * 2, inner_bounds * 2)
				)
				var boundaries = MathFunctions.get_holed_rect(outer_boundary, inner_boundary)
				for boundary in boundaries:
					WorldState.state.object_manager.request_terrain_angles(boundary)
				wait_for_next_main_frame()
				for boundary in boundaries:
					WorldState.state.object_manager.add_world_meshes(boundary)
					if (player_pos - last_player_pos).length() > Globals.LOD_UPDATE_DISTANCE:
						# Early exit if player has moved to new area
						reset_loop = true
						break
				if reset_loop:
					break
			initialization_completed = true
