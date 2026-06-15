extends Node

class_name WorldGenerator

var world_state: WorldState

var added_boundaries: Dictionary[Rect2, bool] = {}

func _init(_world_state: WorldState):
	world_state = _world_state

func remove_object_callback(object: WorldObject):
	world_state.static_objects_qt.remove({"position": Vector2(object.instance.position.x, object.instance.position.z), "data": object})
	object.delete()
	object = null

# Generates everything on the world, except the terrain
func generate_world(boundary: Rect2):
	if added_boundaries.has(boundary):
		return
	added_boundaries[boundary] = true

	# CREATE STATIC OBJECTS AND ITEMS

	world_state.object_generator.create_world_objects(boundary)

	# UPDATE WORLD GRID

	world_state.world_grid.add_grid_boundary(boundary)

	# CREATE SETTLEMENTS

	world_state.settlements_generator.create_settlements(boundary)

	world_state.npcs_generator.create_npcs_in_settlements(boundary)

	# Create some random NPCs out in the forest as well
	var num_npcs = 25
	world_state.npcs_generator.create_npcs(boundary, num_npcs)

	world_state.settlements_generator.remove_objects_from_settlements(boundary, remove_object_callback)

	# CREATE ROADS

	var road_edges: Array[RoadGenerator.RoadEdge] = []

	# var road_edges: Array[RoadGenerator.RoadEdge] = world_state.road_generator.generate_roads(boundary) # Type: Array[RoadGenerator.RoadEdge]
	# world_state.road_generator.remove_objects_from_roads(remove_object_callback)

	# FINAL TOUCHES

	world_state.terrain_generator.update_shader_data(world_state.settlements_generator.settlements.query_all(), road_edges)

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
