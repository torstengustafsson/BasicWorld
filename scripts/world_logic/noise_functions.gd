class_name NoiseFunctions

class NoiseContainer:
	var noise: FastNoiseLite
	var threshold: float # Value between 0.0 and 1.0, 0.4 means keep ~40% of the area, 0.25 means keep ~25% of the area
	var additive = true

var noises: Array[NoiseContainer] = []

func _init(noises_array: Array[NoiseContainer]) -> void:
	noises = noises_array

func get_num_additive_noises() -> int:
	var result = 0
	for noise in noises:
		result += int(noise.additive)
	return result

func above_threshold(position: Vector3) -> bool:
	var num_true: int = 0
	var num_needed = get_num_additive_noises()
	for noise_container in noises:
		var noise_value = (noise_container.noise.get_noise_2d(position.x, position.z) + 1) / 2.0
		if noise_value > noise_container.threshold:
			if noise_container.additive:
				num_true += 1
			else:
				return true # Non-additive noise cuts directly
	return num_true == num_needed

static func create_forest_noise() -> NoiseFunctions:
	var high_density_noise = FastNoiseLite.new()
	high_density_noise.seed = randi()
	high_density_noise.frequency = 0.006
	var noise_container_1 = NoiseContainer.new()
	noise_container_1.noise = high_density_noise
	noise_container_1.threshold = 0.5

	var low_density_noise = FastNoiseLite.new()
	high_density_noise.seed = randi()
	low_density_noise.frequency = 0.5
	var noise_container_2 = NoiseContainer.new()
	noise_container_2.noise = low_density_noise
	noise_container_2.threshold = 0.25

	var no_forest_noise = FastNoiseLite.new()
	high_density_noise.seed = randi()
	no_forest_noise.frequency = 0.0006
	var noise_container_3 = NoiseContainer.new()
	noise_container_3.noise = no_forest_noise
	noise_container_3.threshold = 0.6
	noise_container_3.additive = false

	return NoiseFunctions.new([noise_container_1, noise_container_2, noise_container_3])

static func create_rocks_noise() -> NoiseFunctions:
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.8
	var noise_container_1 = NoiseContainer.new()
	noise_container_1.noise = noise
	noise_container_1.threshold = 0.3

	var no_rocks_noise = FastNoiseLite.new()
	no_rocks_noise.seed = randi()
	no_rocks_noise.frequency = 0.001
	var noise_container_2 = NoiseContainer.new()
	noise_container_2.noise = no_rocks_noise
	noise_container_2.threshold = 0.6
	noise_container_2.additive = false

	return NoiseFunctions.new([noise_container_1, noise_container_2])
