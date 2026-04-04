class_name MathFunctions

# Expects x to be between 0.0 and 1.0. Returns value between 0.0 and 1.0.
# Return 1.0 when x is 0.0, and tapers down to 0.0, with threshold being the falloff point (x=threshold return 0.5).
# Sharpness of 10 and threshold of 0.5 means x=1.0 return ~0.0. Lower sharpness means hight value at 1.0, and
# higher sharpness means 0.0 falloff is earlier.
static func taper(x, threshold, sharpness = 10):
	return 1 / (1 + exp(sharpness * (x - threshold)))

# Expects x to be between 0.0 and 1.0. Returns value between 0.0 and 1.0.
# Returns high values when x is close to center. Tapers of to 0.0 at the edges. Taper down strength is determined ny width.
static func hill(x, center, width):
	return exp(-pow(x - center, 2) / (2 * width * width))
