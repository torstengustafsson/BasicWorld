class_name NoiseFunctions

# NOTE: This will keep expanding forever
var added_mask_textures: Dictionary[int, ImageTexture] = {}

class NoiseContainer:
	var noise: FastNoiseLite
	var threshold: float # Value between 0.0 and 1.0, 0.4 means keep ~40% of the area, 0.25 means keep ~25% of the area
	var additive: bool
	var random_seed: int
	var edge_width: float

	func _init(_random_seed, frequency, _threshold, _additive=true, _edge_width=0.05):
		random_seed = _random_seed
		threshold = _threshold
		additive = _additive
		edge_width = _edge_width
		noise = FastNoiseLite.new()
		noise.seed = random_seed
		noise.frequency = frequency

var noises: Array[NoiseContainer] = []
var num_additive_noises = 0

func _init(noises_array: Array[NoiseContainer]) -> void:
	noises = noises_array
	for noise in noises:
		num_additive_noises += int(noise.additive)

func above_threshold(position: Vector2) -> bool:
	return get_density(position) > 0.5

# Used to get a smooth combined value from the noise containers.
# Edges between on/off gets blended, with noise_container.edge_width as the blend factor.
func get_density(position: Vector2) -> float:
	var additive_value: float = 1.0
	var cutting_value: float = 0.0
	var has_additive := false

	for noise_container in noises:
		var noise_value = (noise_container.noise.get_noise_2d(position.x, position.y) + 1) / 2.0
		var threshold = noise_container.threshold
		var edge_width = noise_container.edge_width
		var smoothstep_value = smoothstep(threshold - edge_width, threshold + edge_width, noise_value)

		if noise_container.additive:
			additive_value = min(additive_value, smoothstep_value)
			has_additive = true
		else:
			cutting_value = max(cutting_value, smoothstep_value)

	if not has_additive:
		return cutting_value
	return max(additive_value, cutting_value)

# This is expensive to calculate, so results are cached in added_mask_textures for reuse
func generate_mask_texture(origin: Vector2, size: Vector2, resolution: int = 512) -> ImageTexture:
	var key = hash(origin) + hash(size) + resolution
	if added_mask_textures.has(key):
		return added_mask_textures[key]
	var img := Image.create(resolution, resolution, false, Image.FORMAT_R8)
	for y in resolution:
		for x in resolution:
			var world_x := origin.x + (float(x) / resolution) * size.x
			var world_z := origin.y + (float(y) / resolution) * size.y
			var value := get_density(Vector2(world_x, world_z))
			img.set_pixel(x, y, Color(value, value, value))
	var result = ImageTexture.create_from_image(img)
	added_mask_textures[key] = result
	return result

static func create_forest_noise(rng: RandomNumberGenerator) -> NoiseFunctions:
	var high_density_noise = NoiseContainer.new(rng.randi(), 0.006, 0.5)
	var low_density_noise = NoiseContainer.new(rng.randi(), 0.5, 0.2)
	var no_forest_noise = NoiseContainer.new(rng.randi(), 0.0006, 0.625, false)
	return NoiseFunctions.new([high_density_noise, low_density_noise, no_forest_noise])

static func create_rocks_noise(rng: RandomNumberGenerator) -> NoiseFunctions:
	var rocks_noise = NoiseContainer.new(rng.randi(), 0.01, 0.3)
	var no_rocks_noise = NoiseContainer.new(rng.randi(), 0.001, 0.5, false)
	return NoiseFunctions.new([rocks_noise, no_rocks_noise])
