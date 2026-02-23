// color_areas.gdshader
shader_type spatial;

uniform float noise_strength = 5.0;  // how jagged the edge is
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

uniform vec2 world_size;
uniform vec3 settlement_data[16]; // [pos_x, pos,z, radius]
uniform int settlement_count = 0;
uniform vec4 grass_albedo_texture;
uniform vec4 road_albedo_texture;

void fragment() {
    float in_spot = 0.0;
	vec2 world_uv = (UV - 0.5) * world_size;
    for (int i = 0; i < settlement_count; i++) {

	    // Get angle from spot center, use it to sample noise
	    vec2 dir = world_uv - settlement_data[i].xy;
	    float angle = atan(dir.y, dir.x);

	    float n = noise1d(angle * noise_scale);
	    float radius = settlement_data[i].z + (n - 0.5) * 2.0 * noise_strength;
        float dist = length(dir);
        in_spot = max(in_spot, step(dist, radius));
    }
	ALBEDO = mix(grass_albedo_texture.rgb, road_albedo_texture.rgb, in_spot);

}