shader_type canvas_item;
render_mode unshaded, blend_add;

// Explicit presentation time freezes on pause and ignores simulation speed.
uniform float visual_time = 0.0;
uniform float phase = 0.0;
uniform vec4 tint : source_color = vec4(0.4, 0.9, 1.0, 1.0);
uniform float level = 1.0;
uniform int chemistry = 0;
uniform float recognition = 0.0;
uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform sampler2D impression_mask : repeat_disable, filter_linear_mipmap;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float clock = visual_time * (chemistry == 4 ? 0.065 : 0.028);
	vec2 drift = vec2(clock, -clock * 0.73) + vec2(phase * 0.17);
	float n0 = texture(flow_noise, UV * 1.55 + drift).r;
	float n1 = texture(flow_noise, UV * 2.3 - drift * 0.63 + vec2(0.37, 0.19)).r;
	vec2 warp = (vec2(n0, n1) - vec2(0.5)) * 0.17;
	vec4 a = texture(TEXTURE, clamp(UV + warp + vec2(0.018 * sin(clock + phase), 0.0), vec2(0.0), vec2(1.0)));
	vec2 turned = vec2(0.5) + mat2(vec2(0.87, 0.5), vec2(-0.5, 0.87)) * p * 1.08;
	vec4 b = texture(TEXTURE, clamp(turned - warp * 0.8, vec2(0.0), vec2(1.0)));
	float envelope = 1.0 - smoothstep(0.28, 0.5, length(p));
	float density = (a.r * a.a * 0.83 + b.r * b.a * 0.55) * envelope;
	float filament = 1.0 - smoothstep(0.018, 0.09, abs(n0 - 0.51 + 0.12 * sin(n1 * 9.0 + clock)));
	float strands = density * filament;
	float haze = exp(-dot(p, p) * 17.0) * (0.12 + 0.17 * n1);
	// Anatomy is only a dissolved memory mask, never a moving physical animal.
	vec2 mask_uv = vec2(0.5) + p * 1.33 + warp * 0.14;
	float mask = texture(impression_mask, clamp(mask_uv, vec2(0.0), vec2(1.0))).a;
	float apparition = mask * recognition * (0.55 + 0.45 * smoothstep(0.25, 0.7, n1));
	float shroud = 1.0 - recognition * 0.48;
	float light = (density * 0.95 + strands * 0.55 + haze) * shroud + apparition * 2.5;
	vec3 secondary = mix(tint.rgb, tint.gbr, 0.28);
	vec3 color = mix(secondary, tint.rgb, smoothstep(0.08, 0.4, density));
	color = mix(color, vec3(0.92, 0.98, 1.0), clamp(strands * 0.68 + apparition * 0.23, 0.0, 0.5));
	COLOR = vec4(color * vertex_tint.rgb, clamp(light * level, 0.0, 0.95) * envelope * vertex_tint.a);
}
