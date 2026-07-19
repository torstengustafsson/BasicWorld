# Contains constants used by the terrain and the world map
class_name TerrainConstants

const HEIGHT_BARREN = 40.0
const HEIGHT_SNOW = 100.0

# Barren and snowy terrain blend in their color on the ground, so we add a margin before showing it on the world map
const BLEND_MARGIN = 5.0

const ANGLE_CLIFF = 35.0
const CLIFF_SLOPE_THRESHOLD = tan(deg_to_rad(ANGLE_CLIFF))

const COLOR_GRASS = Color(0.25, 0.5, 0.25)
const COLOR_FOREST = Color(0.35, 0.5, 0.25, 1.0)
const COLOR_BARREN = Color(0.35, 0.3, 0.2)
const COLOR_CLIFF = Color(0.35, 0.35, 0.35)
const COLOR_SNOW = Color(0.9, 0.9, 0.9)
const COLOR_ROAD = Color(0.5, 0.5, 0.2)
const COLOR_SETTLEMENT = Color(0.75, 0.5, 0.5)
const COLOR_PLAYER = Color(1.0, 0.5, 0.25)
