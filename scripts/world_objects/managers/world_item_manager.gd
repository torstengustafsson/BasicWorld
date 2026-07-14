class_name WorldItemManager extends Node

# Contains all items in the world
var world_items: Array[WorldItem]

var rng: RandomNumberGenerator

func _init(_rng: RandomNumberGenerator, initial_world_items: Array[Vector4]) -> void:
	rng = _rng
	for item_data in initial_world_items:
		# Need to move items up since they may otherwise clip through the ground
		spawn_item(Vector3(item_data.x, item_data.y + 0.5, item_data.z), int(item_data.w))

func generate_starting_items(boundary: Rect2, amount: int):
	var get_random_position = func() -> Vector3:
		var pos_x = rng.randf_range(boundary.position.x, boundary.end.x)
		var pos_z = rng.randf_range(boundary.position.y, boundary.end.y)
		return Vector3(
			pos_x,
			WorldState.state.terrain_height_noise.get_height_at(pos_x, pos_z) + 0.5,
			pos_z)

	for berry in floor(amount / 3.0):
		var berry_position = get_random_position.call()
		spawn_item(berry_position, ItemProperties.Item.BERRY)

	for wood in floor(amount / 3.0):
		var wood_position = get_random_position.call()
		spawn_item(wood_position, ItemProperties.Item.WOOD)

	for stone in floor(amount / 3.0):
		var stone_position = get_random_position.call()
		spawn_item(stone_position, ItemProperties.Item.STONE)

	var axe_position = WorldState.state.player.position + Vector3(-1.0, 2.0, -4.0)
	spawn_item(axe_position, ItemProperties.Item.AXE)
	var pickaxe_position = WorldState.state.player.position + Vector3(1.0, 2.0, -4.0)
	spawn_item(pickaxe_position, ItemProperties.Item.PICKAXE)

func spawn_item(pos: Vector3, item_id: ItemProperties.Item) -> WorldItem:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(pos)
	var item = WorldItem.create_item(item_id)
	item.object.position = pos
	item.object.rotation = Vector3(
		rng.randf_range(0.0, PI / 4),
		rng.randf_range(0.0, PI / 4),
		rng.randf_range(0.0, PI / 4))
	_add_item_to_world(item)
	return item

func _add_item_to_world(item: WorldItem):
	world_items.append(item)
	var particle_effect = create_item_particle_effect()
	item.object.add_child(particle_effect)
	add_child(item.object)

func get_world_item(properties: ItemProperties) -> WorldItem:
	for item in world_items:
		if item.properties == properties:
			return item
	return null

func create_item_particle_effect() -> GPUParticles3D:
	var particles = GPUParticles3D.new()
	particles.amount = 32
	particles.amount_ratio = 0.8
	particles.lifetime = 0.75
	particles.speed_scale = 0.3
	particles.randomness = 0.1
	var process_material = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.spread = 180.0
	process_material.initial_velocity_min = 1.0
	process_material.initial_velocity_max = 1.0
	process_material.gravity = Vector3(0.0, 2.0, 0.0)
	var curve_texture: CurveTexture = CurveTexture.new()
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.72, 0.92))
	curve.add_point(Vector2(1.0, 0.0))
	curve_texture.curve = curve
	process_material.scale_curve = curve_texture
	particles.process_material = process_material
	var particle: QuadMesh = QuadMesh.new()
	particle.size = Vector2(0.05, 0.05)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 1.0, 0.4, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 0.4, 1.0)
	mat.emission_energy_multiplier = 2.0
	particle.material = mat
	particles.draw_pass_1 = particle
	return particles

func interact(collision_position: Vector3) -> ItemProperties.Item:
	var item_index = 0
	for item in world_items:
		if item.object.position == collision_position:
			WorldState.state.audio_manager.play_sound(AudioManager.SoundID.PICK_UP_ITEM, item.object.position)
			item.object.queue_free()
			world_items.remove_at(item_index)
			return item.item_id
		item_index += 1
	return ItemProperties.Item.NO_ITEM

func destroy():
	for item in world_items:
		item.object.queue_free()
	world_items.clear()

func save() -> Dictionary:
	var result: Dictionary = {}
	var item_data: Array = []
	for item in world_items:
		var data: Array = [item.object.position.x, item.object.position.y, item.object.position.z, item.item_id]
		item_data.append(data)
	result["world_items"] = item_data
	return result

static func load(data: Dictionary) -> Array[Vector4]:
	var result: Array[Vector4] = []
	for item_data in data[str("world_items")]:
		result.append(Vector4(item_data[0], item_data[1], item_data[2], item_data[3]))
	return result
