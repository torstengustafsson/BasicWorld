extends Node

class_name WorldItems

# Contains all items in the world
var world_items: Array[WorldItem]

func spawn_item(pos: Vector3, properties: ItemProperties):
	var item = WorldItem.create_item(properties)
	item.object.position = pos
	item.object.rotation = Vector3(randf_range(0.0, PI / 4), randf_range(0.0, PI / 4), randf_range(0.0, PI / 4))
	
	add_item_to_world(item)

func add_item_to_world(item: WorldItem):
	world_items.append(item)
	add_child(item.object)

func get_world_item(properties: ItemProperties) -> WorldItem:
	for item in world_items:
		if item.properties == properties:
			return item
	return null

func interact(collider) -> ItemProperties:
	for item in world_items:
		if item.object.get_node("PickableArea") == collider:
			var properties = item.properties
			item.object.queue_free()
			world_items.erase(item)
			return properties
	return null
