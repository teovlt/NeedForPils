// Gouttes de pluie sur le pare-brise. La carte "wet_map" (calculée par
// windshield_rain.gd) dit où la vitre est mouillée : les essuie-glaces la remettent à 0.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D wet_map : filter_linear, hint_default_black;
uniform float cells_x = 34.0;
uniform float aspect = 0.46;          // hauteur / largeur de la vitre
uniform float light = 1.0;            // luminosité ambiante (nuit = sombre)

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Une couche de gouttes : renvoie (opacité, reflet).
vec2 drops(vec2 uv, float scale, float wet, float seed) {
	vec2 g = uv * vec2(scale, scale * aspect);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float h = hash12(cell + seed);
	if (h > wet) {
		return vec2(0.0);
	}
	vec2 c = vec2(hash12(cell + seed + 3.1), hash12(cell + seed + 7.7)) * 0.6 + 0.2;
	float r = 0.12 + 0.22 * hash12(cell + seed + 1.3);
	float d = length(f - c) / r;
	float body = 1.0 - smoothstep(0.8, 1.0, d);
	float rim = smoothstep(0.55, 0.95, d) * body;
	float hl = 1.0 - smoothstep(0.0, 0.4, length(f - c + vec2(r * 0.35, -r * 0.35)) / r);
	return vec2(body * 0.12 + rim * 0.35, hl * body);
}

void fragment() {
	float wet = texture(wet_map, UV).r;
	vec2 a = drops(UV, cells_x, wet, 0.0);
	vec2 b = drops(UV, cells_x * 2.3, wet * 1.2, 17.0);
	float alpha = clamp(a.x + b.x * 0.8 + wet * 0.04, 0.0, 0.85);
	float hl = max(a.y, b.y * 0.8);
	ALBEDO = mix(vec3(0.45, 0.5, 0.56) * (0.25 + 0.75 * light), vec3(0.9, 0.95, 1.0) * (0.35 + 0.65 * light), hl);
	ALPHA = max(alpha, hl * 0.55);
}
