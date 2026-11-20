shader_type spatial;

uniform float lit_fraction = 0.0;
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
	float rocky_rim = smoothstep(27.5, 33.5, length(world_pos.xz));
	vec3 soil = mix(vec3(0.053, 0.125, 0.14), vec3(0.108, 0.219, 0.197), mottling);
	soil = mix(soil, vec3(0.083, 0.122, 0.169), rocky_rim * 0.65);
	ALBEDO = soil + speckle * 0.027 + lit_fraction * vec3(0.024, 0.02, 0.003);
	EMISSION = soil * 0.17;
	ROUGHNESS = 0.94;
}
