extends Node

class_name WorldGenerator

var world_state: WorldState

# Uncomment "generation_times" lines below to debug wich parts takes most time to generate
# var generation_times: Dictionary[String, float] = {}

func _init(_world_state: WorldState):
	world_state = _world_state

func remove_object_callback(object: WorldObject):
	world_state.static_objects_qt.remove(object)
	object.delete()
	object = null

# Generates everything on the world, except the terrain
func generate_world(boundary: Rect2):
	# Uncomment timer lines to debug generation times
	# var start_time = Time.get_ticks_msec()

	# CREATE STATIC OBJECTS AND ITEMS
	# var objects_start_time = Time.get_ticks_msec()

	world_state.object_generator.create_world_objects(boundary)

	# generation_times["Objects"] = generation_times.get("Objects", 0.0) + Time.get_ticks_msec() - objects_start_time

	# CREATE SETTLEMENTS
	# var settlements_start_time = Time.get_ticks_msec()

	var new_settlements = world_state.settlements_generator.create_settlements(boundary)

	world_state.npcs_generator.create_npcs_in_settlements(new_settlements)

	# Create some random NPCs out in the forest as well
	var num_npcs = 5
	world_state.npcs_generator.create_npcs(boundary, num_npcs)

	world_state.settlements_generator.remove_objects_from_settlements(new_settlements, remove_object_callback)

	# generation_times["Settlements"] = generation_times.get("Settlements", 0.0) + Time.get_ticks_msec() - settlements_start_time

	# CREATE ROADS
	# var roads_start_time = Time.get_ticks_msec()

	var new_roads = world_state.road_generator.generate_roads(boundary)
	world_state.road_generator.remove_objects_from_roads(new_roads, remove_object_callback)

	# generation_times["Roads"] = generation_times.get("Roads", 0.0) + Time.get_ticks_msec() - roads_start_time

	# FINAL TOUCHES

	var closest_settlements = world_state.settlements_generator.settlements.query_circle(Vector2(world_state.player.position.x, world_state.player.position.z), Globals.TERRAIN_CHUNK_SIZE * 2)
	world_state.terrain_generator.update_shader_data(closest_settlements, world_state.road_generator.road_edges)

	# generation_times["Total"] = generation_times.get("Total", 0.0) + Time.get_ticks_msec() - start_time

	# print("Generate world")
	# for time in generation_times.keys():
	# 	print("Total generation time for ", time, " = ", generation_times[time] / 1000.0)

func generate_starting_items(boundary):
	var axe_position = Vector3(-1.0, 2.0, -4.0)
	if boundary.has_point(Vector2(axe_position.x, axe_position.z)):
		world_state.item_generator.spawn_item(axe_position, ItemProperties.Item.AXE)

	var pickaxe_position = Vector3(1.0, 2.0, -4.0)
	if boundary.has_point(Vector2(pickaxe_position.x, pickaxe_position.z)):
		world_state.item_generator.spawn_item(pickaxe_position, ItemProperties.Item.PICKAXE)

	var get_random_position = func() -> Vector3:
		return Vector3(
			world_state.rng.randf_range(boundary.position.x, boundary.end.x),
			5.0,
			world_state.rng.randf_range(boundary.position.y, boundary.end.y))

	for berry in 40:
		var berry_position = get_random_position.call()
		world_state.item_generator.spawn_item(berry_position, ItemProperties.Item.BERRY)

	for wood in 40:
		var wood_position = get_random_position.call()
		world_state.item_generator.spawn_item(wood_position, ItemProperties.Item.WOOD)

	for stone in 40:
		var stone_position = get_random_position.call()
		world_state.item_generator.spawn_item(stone_position, ItemProperties.Item.STONE)
