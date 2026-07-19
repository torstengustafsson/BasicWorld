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

uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);

uniform float barren_height;
uniform float snow_height;
uniform vec3 settlement_data[128]; // [pos_x, pos,z, radius]
uniform int settlement_count = 0;
uniform vec4 road_segments[1024]; // Two vec2:s of (from, to) points
uniform int road_edge_count = 0;
uniform float road_width = 0.0;
uniform vec4 grass_albedo_texture;
uniform vec4 road_albedo_texture;
uniform vec4 cliff_albedo_texture;
uniform vec4 barren_albedo_texture;
uniform vec4 snow_albedo_texture;
uniform vec4 forest_albedo_texture;
uniform sampler2D forest_mask;

const float blend_sharpness = 2.0;
varying vec3 world_position;
varying float terrain_slope;

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

vec3 mix_with_forest(vec3 input_color) {
    vec2 uv = (world_position.xz - chunk_position) / chunk_size;
    float mask = texture(forest_mask, uv).r;
    float blend = smoothstep(0.6, 0.0, mask);
    vec3 forest_color = mix(input_color, forest_albedo_texture.rgb, blend);
    return forest_color;
}

vec3 mix_with_cliff(vec3 input_color) {
    // Add transition between grass and cliffs
    float blend_factor = smoothstep(0.1, 0.3, terrain_slope);
    blend_factor = pow(blend_factor, blend_sharpness); // Apply sharpness

    vec3 flat_and_cliff_color = mix(input_color, cliff_albedo_texture.rgb, blend_factor);
    return flat_and_cliff_color;
}

vec3 mix_at_height(vec3 input_color, float height, float blend_distance_multiplier, vec4 to_mix_color) {
    float noise_frequency = 0.02;
    float noise_amplitude = 20.0;
    float n = noise(world_position.xz * noise_frequency);
    float noisy_elevation = height + (n - 0.5) * noise_amplitude;

    float blend_factor = smoothstep(noisy_elevation * (1.0 - blend_distance_multiplier), noisy_elevation * (1.0 + blend_distance_multiplier), world_position.y);
    blend_factor = pow(blend_factor, blend_sharpness); // Apply sharpness

    vec3 output_color = mix(input_color, to_mix_color.rgb, blend_factor);
    return output_color;
}

void vertex() {
    // Calculate the normal and tangent vectors for terrain slope detection
    vec3 normal = normalize(NORMAL);
    vec3 up = vec3(0.0, 1.0, 0.0);
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    terrain_slope = 1.0 - abs(dot(normal, up));
}

void fragment() {
    vec2 scaled_uv = (UV - uv_offset) * uv_scale;
    vec2 world_uv = chunk_position + (scaled_uv - 0.5) * chunk_size;

    if (scaled_uv.x < 0.0 || scaled_uv.x > 1.0 || scaled_uv.y < 0.0 || scaled_uv.y > 1.0) {
        // Skip chunk margins, neighboring chunks will render this
        discard;
    }
    float in_road = 0.0;

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
        float road_dist = point_to_segment_dist(world_uv, road_segments[i].xy, road_segments[i].zw);
        in_road = max(in_road, step(road_dist, road_width));
    }

    vec3 add_forest_color = mix_with_forest(grass_albedo_texture.rgb);
    vec3 add_road_color = mix(add_forest_color, road_albedo_texture.rgb, in_road);
    vec3 add_barren_color = mix_at_height(add_road_color, barren_height, 0.5, barren_albedo_texture);
    vec3 add_snow_color = mix_at_height(add_barren_color, snow_height, 0.15, snow_albedo_texture);
    vec3 final_color = mix_with_cliff(add_snow_color);

    ALBEDO = final_color;
}
