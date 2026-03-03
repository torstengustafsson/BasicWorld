class_name NoiseFunctions

class NoiseContainer:
	var noise: FastNoiseLite
	var threshold: float # Value between 0.0 and 1.0, 0.4 means keep 40% of the area, 0.25 means keep 25% of the area

var noises: Array[NoiseContainer] = []

func _init(noises_array: Array[NoiseContainer]) -> void:
	noises = noises_array

func above_threshold(position: Vector3) -> bool:
	var num_true: int = 0
	for noise_container in noises:
		var noise_value = (noise_container.noise.get_noise_2d(position.x, position.z) + 1) / 2.0
		if noise_value > noise_container.threshold:
			num_true += 1
	return num_true == noises.size()

static func create_forest_noise() -> NoiseFunctions:
	var high_density_noise = FastNoiseLite.new()
	high_density_noise.frequency = 0.006
	var noise_container_1 = NoiseContainer.new()
	noise_container_1.noise = high_density_noise
	noise_container_1.threshold = 0.5

	var low_density_noise = FastNoiseLite.new()
	low_density_noise.frequency = 0.5
	var noise_container_2 = NoiseContainer.new()
	noise_container_2.noise = low_density_noise
	noise_container_2.threshold = 0.25

	return NoiseFunctions.new([noise_container_1, noise_container_2])

static func create_rocks_noise() -> NoiseFunctions:
	var noise = FastNoiseLite.new()
	noise.frequency = 0.8
	var noise_container = NoiseContainer.new()
	noise_container.noise = noise
	noise_container.threshold = 0.3

	return NoiseFunctions.new([noise_container])
