extends Node

class_name TerrainNoise

var noise_terraintype : Noise
var noise_terraintype1 : Noise
var noise_terraintype2 : Noise
var noise_terraintype3 : Noise


func _init(rng: RandomNumberGenerator):
	noise_terraintype = FastNoiseLite.new()
	noise_terraintype.seed = rng.seed
	noise_terraintype.frequency = 0.001
	noise_terraintype.fractal_octaves = 2
	noise_terraintype.fractal_lacunarity = 4.0
	noise_terraintype.fractal_gain = 0.5

	# Mountains
	noise_terraintype1 = FastNoiseLite.new()
	noise_terraintype1.seed = rng.seed
	noise_terraintype1.frequency = 0.00001
	noise_terraintype1.fractal_octaves = 3
	noise_terraintype1.fractal_lacunarity = 10.0
	noise_terraintype1.fractal_gain = 0.8

	# Small hills and details
	noise_terraintype2 = FastNoiseLite.new()
	noise_terraintype2.seed = rng.seed
	noise_terraintype2.frequency = 0.01
	noise_terraintype2.fractal_octaves = 2
	noise_terraintype2.fractal_lacunarity = 2.0
	noise_terraintype2.fractal_gain = 0.5

	# Plains
	noise_terraintype3 = FastNoiseLite.new()
	noise_terraintype3.seed = rng.seed
	noise_terraintype3.frequency = 0.0005
	noise_terraintype3.fractal_octaves = 3
	noise_terraintype3.fractal_lacunarity = 1.5
	noise_terraintype3.fractal_gain = 0.5

func get_height_at(x, z):
		# Determine size of the noise
		# get_noise_2d function returns a value between -1.0 and 1.0. We add 1 to those we only want positive range.
		var type_val = (noise_terraintype.get_noise_2d(x, z) + 1.0) / 2.0
		var noise1 = (noise_terraintype1.get_noise_2d(x, z) + 1.0) * 100.0
		var noise2 = noise_terraintype2.get_noise_2d(x, z) / 2.0 * 25.0
		var noise3 = noise_terraintype3.get_noise_2d(x, z) / 2.0 * 25.0

		# Determine position of the noise.
		#  Use a hill function on type_val. If 2 noise values are "positioned" (meaning hill center)
		# at around the same area around type_val, they will overlap in those areas.
		var noise1_val = MathFunctions.hill(type_val, 0.1, 0.1) * noise1
		var noise2_val = MathFunctions.hill(type_val, 0.25, 0.2) * noise2
		var noise3_val = MathFunctions.hill(type_val, 0.5, 0.3) * noise3
		return noise1_val + noise2_val + noise3_val
