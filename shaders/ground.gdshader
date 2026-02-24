// color_areas.gdshader
shader_type spatial;

uniform float noise_strength = 3.0;  // how jagged the edge is
uniform float noise_scale = 2.0;     // frequency of the noise
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
uniform float road_width = 1.5;
float point_to_segment_dist(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    vec2 ap = p - a;
    float t = clamp(dot(ap, ab) / dot(ab, ab), 0.0, 1.0);
    vec2 closest = a + t * ab;
    return length(p - closest);
}


uniform vec2 world_size;
uniform vec3 settlement_data[16]; // [pos_x, pos,z, radius]
uniform int settlement_count = 0;
uniform vec4 grass_albedo_texture;
uniform vec4 road_albedo_texture;

void fragment() {
    float in_road = 0.0;
    vec2 world_uv = (UV - 0.5) * world_size;

    // Create spots under settlements
    for (int i = 0; i < settlement_count; i++) {
        vec2 dir = world_uv - settlement_data[i].xy;
        float angle = atan(dir.y, dir.x);

        float n = noise1d(angle * noise_scale);
        float radius = settlement_data[i].z + (n - 0.5) * 2.0 * noise_strength;
        float dist = length(dir);
        in_road = max(in_road, step(dist, radius));
    }

    // Create roads between settlements
    if (settlement_count > 1) {
        for (int i = 1; i < settlement_count; i++) {
            float road_dist = point_to_segment_dist(world_uv, settlement_data[i].xy, settlement_data[i-1].xy);
            in_road = max(in_road, step(road_dist, road_width));
        }
    }

    ALBEDO = mix(grass_albedo_texture.rgb, road_albedo_texture.rgb, in_road);

}