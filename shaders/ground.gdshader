// color_areas.gdshader
shader_type spatial;

uniform float NOISE_STRENGTH = 3.0;  // how jagged the edge is
uniform float NOISE_SCALE = 2.0;     // frequency of the noise
float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}
float noise1d(float x) {
    float i = floor(x);
    float f = fract(x);
    float u = f * f * (3.0 - 2.0 * f); // smoothstep
    return mix(hash(i), hash(i + 1.0), u);
}

// Used for roads
float point_to_segment_dist(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    vec2 ap = p - a;
    float t = clamp(dot(ap, ab) / dot(ab, ab), 0.0, 1.0);
    vec2 closest = a + t * ab;
    return length(p - closest);
}


uniform vec2 chunk_position;
uniform vec2 chunk_size;
uniform vec3 settlement_data[128]; // [pos_x, pos,z, radius]
uniform int settlement_count = 0;
uniform vec4 road_edges[1024]; // Two vec2:s of (from, to) points
uniform int road_edge_count = 0;
uniform float road_width = 0.0;
uniform vec4 grass_albedo_texture;
uniform vec4 road_albedo_texture;
uniform vec4 cliff_albedo_texture;
uniform vec4 snow_albedo_texture;

const float blend_sharpness = 2.0;
const float snow_height = 90.0;
varying vec3 world_position;
varying float slope;


// 2D noise function (replace with your own or use Godot's noise if available)
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);

    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void vertex() {
    // Calculate the normal and tangent vectors for slope detection
    vec3 normal = normalize(NORMAL);
    vec3 up = vec3(0.0, 1.0, 0.0);
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    slope = 1.0 - abs(dot(normal, up));
}

void fragment() {
    float in_road = 0.0;
    vec2 world_uv = chunk_position + (UV - 0.5) * chunk_size;

    // Create spots under settlements
    for (int i = 0; i < settlement_count; i++) {
        vec2 dir = world_uv - settlement_data[i].xy;
        float angle = atan(dir.y, dir.x);
        float n = noise1d(angle * NOISE_SCALE);
        float radius = settlement_data[i].z + (n - 0.5) * 2.0 * NOISE_STRENGTH;
        float dist = length(dir);
        in_road = max(in_road, step(dist, radius));
    }

    // Create roads between road edges
    for (int i = 0; i < road_edge_count; i++) {
        float road_dist = point_to_segment_dist(world_uv, road_edges[i].xy, road_edges[i].zw);
        in_road = max(in_road, step(road_dist, road_width));
    }

    vec3 flat_color = mix(grass_albedo_texture.rgb, road_albedo_texture.rgb, in_road);

    // Add transition between grass and cliffs
    float blend_factor = smoothstep(0.1, 0.3, slope);
    blend_factor = pow(blend_factor, blend_sharpness); // Apply sharpness

    vec3 flat_and_cliff_color = mix(flat_color, cliff_albedo_texture.rgb, blend_factor);

    // Add transition between grass/cliffs and snow
    float noise_frequency = 0.02;
    float noise_amplitude = 20.0;
    float n = noise(world_position.xz * noise_frequency);
    float noisy_elevation = snow_height + (n - 0.5) * noise_amplitude;

    // Calculate snow amount based on noisy elevation
    float snow_amount = smoothstep(noisy_elevation - 1.0, noisy_elevation + 1.0, world_position.y);

    blend_factor = smoothstep(noisy_elevation * 0.85, noisy_elevation * 1.15, world_position.y);
    blend_factor = pow(blend_factor, blend_sharpness); // Apply sharpness

    ALBEDO = mix(flat_and_cliff_color, snow_albedo_texture.rgb, blend_factor);
}
