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

func interact(collider) -> ItemProperties:
	for item in world_items:
		if item.object.get_node("PickableArea") == collider:
			var properties = item.properties
			item.object.queue_free()
			world_items.erase(item)
			return properties
	return null
