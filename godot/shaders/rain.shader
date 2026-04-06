shader_type canvas_item;

uniform float speed    : hint_range(0.1, 3.0) = 1.2;
uniform float density  : hint_range(0.0, 1.0) = 0.35;
uniform float darkness : hint_range(0.0, 0.8) = 0.28;

float hash(vec2 p) {
	p = fract(p * vec2(127.34, 311.45));
	p += dot(p, p + 35.12);
	return fract(p.x * p.y);
}

// No early returns — multiply by step(r, dens) instead
float streak(vec2 uv, float cell_h, float t, float lean, float dens) {
	vec2 px   = uv / SCREEN_PIXEL_SIZE;
	px.x     += px.y * lean;
	px.y     -= t;

	vec2 cell_sz = vec2(20.0, cell_h);
	vec2 cell    = floor(px / cell_sz);
	vec2 local   = fract(px / cell_sz);

	float r  = hash(cell);
	float cx = hash(cell + vec2(13.7, 5.3));
	float dx = abs(local.x - cx) * cell_sz.x;
	float ax = 1.0 - smoothstep(0.5, 1.5, dx);

	float sh = 0.45 + hash(cell + vec2(3.1, 8.9)) * 0.35;
	float ay = step(local.y, sh) * smoothstep(0.0, 0.08, local.y);

	// step(r, dens): 1.0 when r <= dens (cell has rain), 0.0 otherwise
	return ax * ay * step(r, dens);
}

void fragment() {
	float t    = TIME * speed * 800.0;
	float lean = -0.10;

	float r1 = streak(UV, 120.0, t,        lean,        density);
	float r2 = streak(UV,  80.0, t * 0.55, lean * 0.6, density * 0.65) * 0.45;
	float rain = clamp(r1 + r2, 0.0, 1.0);

	vec3  tint       = vec3(0.05, 0.08, 0.18);
	vec3  streak_col = vec3(0.70, 0.78, 0.90);
	float base_a     = darkness;
	float total_a    = base_a + rain * (1.0 - base_a);
	vec3  final_rgb  = mix(tint, streak_col, rain / max(total_a, 0.001));

	COLOR = vec4(final_rgb, total_a);
}
