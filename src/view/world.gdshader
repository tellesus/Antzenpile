shader_type canvas_item;
render_mode unshaded;
// Draws the map as the colony senses it: dim terrain where known, black where
// not, and scent as light. Output is HDR; values above 1 feed the bloom.

uniform sampler2D terrain_tex : filter_nearest, repeat_disable;
uniform sampler2D known_tex : filter_linear, repeat_disable;
uniform sampler2D food_tex : filter_linear, repeat_disable;
uniform sampler2D trail_tex : filter_linear, repeat_disable;
uniform sampler2D attract_tex : filter_linear, repeat_disable;
uniform sampler2D alarm_tex : filter_linear, repeat_disable;
uniform sampler2D repel_tex : filter_linear, repeat_disable;
uniform sampler2D seek_tex : filter_linear, repeat_disable;
uniform vec2 grid = vec2(200.0, 200.0);
uniform float now_tick = 0.0;
uniform float anim_time = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec3 terrain_color(float id) {
	if (id < 0.5) return vec3(0.050, 0.038, 0.030); // soil
	if (id < 1.5) return vec3(0.022, 0.055, 0.030); // grass
	if (id < 2.5) return vec3(0.060, 0.062, 0.070); // stone
	if (id < 3.5) return vec3(0.012, 0.030, 0.075); // water
	return vec3(0.075, 0.064, 0.036);               // sand
}

void fragment() {
	vec2 cell = UV * grid;
	float id = floor(texture(terrain_tex, UV).r * 255.0 + 0.5);
	float age = now_tick - texture(known_tex, UV).r;
	float known = smoothstep(60000.0, 20000.0, age);
	float live = exp(-max(age, 0.0) / 40.0);
	float memory = 1.0 - 0.6 * smoothstep(600.0, 3000.0, age);
	float fresh = exp(-max(age, 0.0) / 6.0);

	float grain = 0.8 + 0.4 * hash21(floor(cell * 4.0));
	vec3 col = terrain_color(id) * grain * known * mix(0.55 * memory, 1.7, live);
	col += vec3(0.05, 0.07, 0.08) * fresh * known;   // shimmer where news just landed

	float t = anim_time;
	float food = texture(food_tex, UV).r;
	float sparkle = 0.75 + 0.25 * sin(t * 3.0 + hash21(floor(cell)) * 6.28);
	col += vec3(0.45, 1.9, 0.35) * smoothstep(0.0, 5.0, food) * sparkle * known * (0.45 + 0.55 * live);

	float trail = texture(trail_tex, UV).r;
	col += vec3(2.2, 0.95, 0.12) * smoothstep(0.02, 1.6, trail) * 0.8;

	float attract = texture(attract_tex, UV).r;
	float ripple = 0.6 + 0.4 * sin(length(cell - floor(cell / 12.0) * 12.0 - 6.0) * 1.6 - t * 3.0);
	col += vec3(1.9, 1.25, 0.25) * attract * ripple;

	float alarm = texture(alarm_tex, UV).r;
	col += vec3(2.6, 0.18, 0.12) * alarm * (0.55 + 0.45 * sin(t * 9.0));

	float repel = texture(repel_tex, UV).r;
	float hatch = step(0.5, fract((cell.x + cell.y) * 0.5));
	col += vec3(1.1, 0.25, 2.2) * repel * (0.45 + 0.55 * hatch);

	float seek = texture(seek_tex, UV).r;
	float drift = 0.55 + 0.45 * sin((cell.x - cell.y) * 0.9 - t * 4.0);
	col += vec3(0.15, 1.5, 2.1) * seek * drift;

	COLOR = vec4(col, 1.0);
}
