extends ThreadWorker

class_name ThreadAddSettlements

var initialization_completed: bool = false

func _init() -> void:
	super._init()
	player_pos = WorldState.state.player.position
	thread.start(Callable(self, "_thread_add_settlements_and_update_shader_data"))

func _thread_add_settlements_and_update_shader_data():
	while true:
		if (player_pos - last_player_pos).length() > Globals.LOD_UPDATE_DISTANCE:
			last_player_pos = player_pos
			var boundary: Rect2 = Rect2(
				Vector2(player_pos.x - Globals.LOD_DISTANCE_NO_COLLIDER, player_pos.z - Globals.LOD_DISTANCE_NO_COLLIDER),
				Vector2(Globals.LOD_DISTANCE_NO_COLLIDER * 2, Globals.LOD_DISTANCE_NO_COLLIDER * 2)
			)
			# Update possible default settlement position terrain angles
			WorldState.state.settlement_manager.request_terrain_angles(boundary)
			wait_for_next_main_frame()
			# Then update possible edge settlement position terrain angles (Will also create all valid first-step settlements, which is no problem here)
			WorldState.state.settlement_manager.create_settlements(boundary)
			wait_for_next_main_frame()
			# Now all possible settlement positions have got their terrain angles set
			var nearby_settlements: Array[SettlementManager.SettlementData] = WorldState.state.settlement_manager.create_settlements(boundary)
			WorldState.state.npc_manager.create_npc_meshes_in_settlements(nearby_settlements)
			var nearby_road_segments = WorldState.state.road_generator.get_roads_in_area(boundary)
			WorldState.state.terrain_generator.update_shader_data(nearby_settlements, nearby_road_segments)
			initialization_completed = true
