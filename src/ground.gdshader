shader_type spatial;

uniform float lit_fraction = 0.0;
uniform vec4 grass : source_color = vec4(0.184, 0.365, 0.314, 1.0);
varying vec3 world_pos;

float hash2(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 uv) {
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(cell), hash2(cell + vec2(1.0, 0.0)), f.x),
		mix(hash2(cell + vec2(0.0, 1.0)), hash2(cell + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float mottling = noise2(world_pos.xz * 0.34);
	float speckle = noise2(world_pos.xz * 6.0);
	vec3 soil = grass.rgb * (0.92 + mottling * 0.13 + speckle * 0.035);
	ALBEDO = soil;
	EMISSION = soil * (0.12 + lit_fraction * 0.12);
	ROUGHNESS = 0.94;
}
