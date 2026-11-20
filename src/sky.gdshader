shader_type sky;

float hash2(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void sky() {
	float height = smoothstep(-0.28, 0.72, EYEDIR.y);
	vec3 color = mix(vec3(0.17, 0.23, 0.36), vec3(0.035, 0.052, 0.13), height);
	vec2 uv = SKY_COORDS * vec2(420.0, 210.0);
	float star_hash = hash2(floor(uv));
	float star = (1.0 - smoothstep(0.04, 0.21, length(fract(uv) - 0.5)))
		* step(0.971, star_hash) * smoothstep(-0.06, 0.22, EYEDIR.y);
	vec3 moon_dir = normalize(vec3(-0.32, 0.18, 1.0));
	float moon_dist = length(EYEDIR - moon_dir);
	float halo = pow(max(1.0 - moon_dist / 0.42, 0.0), 4.0);
	float moon = 1.0 - smoothstep(0.039, 0.042, moon_dist);
	color += vec3(0.29, 0.35, 0.55) * halo + vec3(0.85, 0.89, 0.83) * moon;
	COLOR = color + star * vec3(0.48, 0.65, 0.8);
}
